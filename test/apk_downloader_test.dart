import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:polaris_finance/data/services/apk_downloader.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('polaris_apk_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Contenido falso con la firma de un ZIP (`PK`) al principio.
  List<int> fakeApk(int size) {
    final bytes = List<int>.filled(size, 0);
    bytes[0] = 0x50;
    bytes[1] = 0x4B;
    return bytes;
  }

  test('Descarga el APK y reporta el progreso', () async {
    final content = fakeApk(4096);
    final client = MockClient((request) async {
      return http.Response.bytes(
        content,
        200,
        headers: {'content-length': '${content.length}'},
      );
    });

    final downloader = ApkDownloader(
      client: client,
      directoryProvider: () async => tempDir,
    );
    final progress = <int>[];

    final file = await downloader.download(
      Uri.parse('https://example.com/app.apk'),
      fileName: 'app.apk',
      onProgress: (p) => progress.add(p.received),
    );

    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), content.length);
    expect(progress, isNotEmpty);
    expect(progress.last, content.length);
  });

  test('Reanuda la descarga cuando la conexion se interrumpe', () async {
    final content = fakeApk(4096);
    final requests = <http.Request>[];

    final client = MockClient((request) async {
      requests.add(request);
      final range = request.headers['range'];
      if (range == null) {
        // Primera entrega: se corta a la mitad.
        return http.Response.bytes(
          content.sublist(0, 2048),
          200,
          headers: {'content-length': '${content.length}'},
        );
      }
      final start = int.parse(
        range.replaceAll('bytes=', '').replaceAll('-', ''),
      );
      return http.Response.bytes(
        content.sublist(start),
        206,
        headers: {
          'content-length': '${content.length - start}',
          'content-range':
              'bytes $start-${content.length - 1}/${content.length}',
        },
      );
    });

    final downloader = ApkDownloader(
      client: client,
      directoryProvider: () async => tempDir,
    );

    final file = await downloader.download(
      Uri.parse('https://example.com/app.apk'),
      fileName: 'app.apk',
    );

    expect(file.lengthSync(), content.length);
    expect(requests.length, 2);
    expect(requests[1].headers['range'], 'bytes=2048-');
  });

  test('Falla si el archivo descargado no es un APK', () async {
    final client = MockClient((request) async {
      final body = '<html>error</html>'.codeUnits;
      return http.Response.bytes(
        body,
        200,
        headers: {'content-length': '${body.length}'},
      );
    });

    final downloader = ApkDownloader(
      client: client,
      directoryProvider: () async => tempDir,
      maxAttempts: 1,
    );

    expect(
      () => downloader.download(
        Uri.parse('https://example.com/app.apk'),
        fileName: 'app.apk',
      ),
      throwsA(isA<ApkDownloadException>()),
    );
  });

  test('Falla si el servidor responde con error', () async {
    final client = MockClient((request) async {
      return http.Response('', 404);
    });

    final downloader = ApkDownloader(
      client: client,
      directoryProvider: () async => tempDir,
      maxAttempts: 1,
    );

    expect(
      () => downloader.download(
        Uri.parse('https://example.com/app.apk'),
        fileName: 'app.apk',
      ),
      throwsA(
        isA<ApkDownloadException>().having(
          (e) => e.message,
          'message',
          contains('404'),
        ),
      ),
    );
  });
}
