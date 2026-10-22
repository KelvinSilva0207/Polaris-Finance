import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Progreso de la descarga del APK.
class ApkDownloadProgress {
  const ApkDownloadProgress({
    required this.received,
    required this.total,
    this.bytesPerSecond,
  });

  /// Bytes descargados hasta el momento.
  final int received;

  /// Tamaño total esperado, si el servidor lo informa.
  final int? total;

  /// Velocidad aproximada de descarga.
  final double? bytesPerSecond;

  /// Fracción descargada (0..1) o `null` si no se conoce el total.
  double? get fraction {
    final totalBytes = total;
    if (totalBytes == null || totalBytes <= 0) return null;
    return (received / totalBytes).clamp(0.0, 1.0);
  }

  bool get isComplete => total != null && received >= total!;
}

/// Error durante la descarga del APK.
class ApkDownloadException implements Exception {
  const ApkDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// La descarga fue cancelada por el usuario.
class ApkDownloadCancelled implements Exception {
  const ApkDownloadCancelled();

  @override
  String toString() => 'Descarga cancelada';
}

/// Descarga el APK de actualizacion dentro de la app.
///
/// A diferencia de abrir el enlace en el navegador, aqui se controla la
/// descarga: se puede reanudar si la conexion se cae, se muestra el progreso
/// real y se verifica que el archivo completo antes de instalarlo.
class ApkDownloader {
  ApkDownloader({
    http.Client? client,
    Future<Directory> Function()? directoryProvider,
    this.maxAttempts = 4,
    this.stallTimeout = const Duration(seconds: 45),
  }) : _client = client ?? http.Client(),
       _directoryProvider = directoryProvider ?? getTemporaryDirectory;

  /// Intentos totales (el ultimo reintento reanuda la descarga parcial).
  final int maxAttempts;

  /// Tiempo maximo sin recibir datos antes de cortar el intento y reanudar.
  final Duration stallTimeout;

  final http.Client _client;
  final Future<Directory> Function() _directoryProvider;

  /// Descarga [url] en [fileName] dentro del directorio temporal de la app.
  ///
  /// Si la conexion se interrumpe, el archivo parcial se conserva y el
  /// siguiente intento continua desde donde se quedo (solicitando el rango
  /// restante al servidor).
  Future<File> download(
    Uri url, {
    required String fileName,
    void Function(ApkDownloadProgress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final base = await _directoryProvider();
    final directory = Directory('${base.path}${Platform.pathSeparator}updates');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    final target = File('${directory.path}${Platform.pathSeparator}$fileName');
    final partial = File('${target.path}.part');
    if (target.existsSync()) {
      return target;
    }

    ApkDownloadException? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (isCancelled?.call() ?? false) {
        throw const ApkDownloadCancelled();
      }
      try {
        await _attempt(
          url,
          partial,
          onProgress: onProgress,
          isCancelled: isCancelled,
        );
        if (partial.existsSync()) {
          if (target.existsSync()) target.deleteSync();
          partial.renameSync(target.path);
        }
        return target;
      } on ApkDownloadCancelled {
        rethrow;
      } on ApkDownloadException catch (error) {
        lastError = error;
        // Se conserva el parcial para que el siguiente intento lo reanude.
        if (attempt >= maxAttempts) break;
        await Future<void>.delayed(const Duration(milliseconds: 800));
      } on TimeoutException {
        lastError = const ApkDownloadException(
          'La descarga se quedó sin datos. Se intenta reanudar.',
        );
        if (attempt >= maxAttempts) break;
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
    }
    throw lastError ?? const ApkDownloadException('No se pudo descargar.');
  }

  Future<void> _attempt(
    Uri url,
    File partial, {
    void Function(ApkDownloadProgress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    var existing = partial.existsSync() ? partial.lengthSync() : 0;
    final request = http.Request('GET', url);
    request.headers['user-agent'] = 'PolarisFinance-Updater';
    if (existing > 0) {
      request.headers['range'] = 'bytes=$existing-';
    }

    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 60));

    final status = response.statusCode;
    if (status == 416) {
      // El servidor dice que el rango pedido no existe: el archivo ya esta
      // completo (o es mas grande de lo esperado).
      final total = _totalFromContentRange(response.headers['content-range']);
      final size = partial.existsSync() ? partial.lengthSync() : 0;
      if (total != null && size == total) {
        onProgress?.call(ApkDownloadProgress(received: size, total: total));
        return;
      }
      if (partial.existsSync()) partial.deleteSync();
      throw const ApkDownloadException(
        'La descarga anterior estaba dañada. Se vuelve a intentarlo.',
      );
    }

    final append = status == 206;
    if (status != 200 && status != 206) {
      throw ApkDownloadException('El servidor respondió HTTP $status.');
    }
    if (status == 200 && existing > 0) {
      // El servidor no respeta el rango: se reinicia la descarga.
      existing = 0;
    }

    final total = append
        ? _totalFromContentRange(response.headers['content-range'])
        : _intHeader(response.headers['content-length']);
    var received = append ? existing : 0;
    final startedAt = DateTime.now();

    final sink = partial.openWrite(
      mode: append ? FileMode.append : FileMode.write,
    );
    try {
      await for (final chunk in response.stream.timeout(stallTimeout)) {
        if (isCancelled?.call() ?? false) {
          throw const ApkDownloadCancelled();
        }
        sink.add(chunk);
        received += chunk.length;
        final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
        onProgress?.call(
          ApkDownloadProgress(
            received: received,
            total: total,
            bytesPerSecond: elapsed > 0 ? received / elapsed * 1000 : null,
          ),
        );
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    final size = partial.existsSync() ? partial.lengthSync() : 0;
    if (total != null && size != total) {
      throw ApkDownloadException(
        'La descarga se interrumpió ($size de $total bytes).',
      );
    }
    if (size == 0) {
      throw const ApkDownloadException('El archivo descargado está vacío.');
    }
    if (!_looksLikeZip(partial)) {
      throw const ApkDownloadException(
        'El archivo descargado no es un APK válido.',
      );
    }
    onProgress?.call(ApkDownloadProgress(received: size, total: total));
  }

  /// Extrae el total de un encabezado `Content-Range: bytes 0-99/1234`.
  static int? _totalFromContentRange(String? header) {
    if (header == null) return null;
    final parts = header.split('/');
    if (parts.length < 2) return null;
    final total = int.tryParse(parts.last.trim());
    if (total == null || total <= 0) return null;
    return total;
  }

  static int? _intHeader(String? header) {
    if (header == null) return null;
    final value = int.tryParse(header.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  /// Un APK es un ZIP: comprobamos la firma `PK`.
  static bool _looksLikeZip(File file) {
    try {
      final handle = file.openSync();
      try {
        final bytes = handle.readSync(2);
        return bytes.length == 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;
      } finally {
        handle.closeSync();
      }
    } catch (_) {
      return false;
    }
  }
}
