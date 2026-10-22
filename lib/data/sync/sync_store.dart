import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sync_models.dart';

/// Error legible de sincronización (red, servidor o formato de datos).
class SyncException implements Exception {
  const SyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Almacén remoto de cambios.
///
/// La implementación de referencia es [RestSyncStore], que habla con un
/// servicio HTTP propio. Cualquier otra fuente (un servicio de Supabase,
/// Firebase, un servidor de la familia…) se puede añadir implementando esta
/// interfaz.
abstract class SyncStore {
  /// Envía cambios locales al almacén remoto.
  Future<void> push(List<SyncDocument> documents);

  /// Recibe los cambios remotos posteriores a [since].
  Future<List<SyncDocument>> pull({DateTime? since});
}

/// Almacén remoto por HTTP.
///
/// Contrato esperado del servidor:
///
/// * `POST {baseUrl}/sync/push`
///   cuerpo: `{"documents": [ ... ]}` → responde `200`/`201`/`204`.
/// * `GET {baseUrl}/sync/pull?since=ISO8601`
///   respuesta: `{"documents": [ ... ]}`.
///
/// La autenticación se hace con `Authorization: Bearer {token}`.
class RestSyncStore implements SyncStore {
  RestSyncStore({required this.baseUrl, this.token, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final String? token;
  final http.Client _client;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    final normalized = path.startsWith('/') ? path : '/$path';
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(
      path: '$basePath$normalized',
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  @override
  Future<void> push(List<SyncDocument> documents) async {
    if (documents.isEmpty) return;
    late http.Response response;
    try {
      response = await _client
          .post(
            _uri('/sync/push'),
            headers: _headers,
            body: jsonEncode({
              'documents': documents.map((d) => d.toJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 30));
    } on SyncException {
      rethrow;
    } catch (error) {
      throw SyncException('No se pudo enviar los cambios: $error');
    }
    if (response.statusCode >= 400) {
      throw SyncException(
        'El servidor rechazó los cambios (código ${response.statusCode})',
      );
    }
  }

  @override
  Future<List<SyncDocument>> pull({DateTime? since}) async {
    late http.Response response;
    try {
      response = await _client
          .get(
            _uri(
              '/sync/pull',
              since == null ? null : {'since': since.toUtc().toIso8601String()},
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));
    } on SyncException {
      rethrow;
    } catch (error) {
      throw SyncException('No se pudieron recibir los cambios: $error');
    }
    if (response.statusCode >= 400) {
      throw SyncException(
        'El servidor no devolvió los cambios (código ${response.statusCode})',
      );
    }
    return parseDocuments(response.body);
  }

  /// Convierte la respuesta del servidor en documentos.
  static List<SyncDocument> parseDocuments(String body) {
    if (body.trim().isEmpty) return const [];
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SyncException(
        'La respuesta del servidor no es un JSON válido',
      );
    }
    final List<dynamic> raw;
    if (decoded is List) {
      raw = decoded;
    } else if (decoded is Map && decoded['documents'] is List) {
      raw = decoded['documents'] as List<dynamic>;
    } else {
      throw const SyncException(
        'La respuesta del servidor no contiene la lista de cambios',
      );
    }
    return [
      for (final item in raw)
        if (item is Map) SyncDocument.fromJson(Map<String, dynamic>.from(item)),
    ];
  }
}

/// Almacén remoto en memoria.
///
/// Sirve para las pruebas y para probar la sincronización entre dos
/// "dispositivos" dentro del mismo proceso.
class MemorySyncStore implements SyncStore {
  MemorySyncStore();

  final Map<String, SyncDocument> _documents = {};

  /// Documentos guardados actualmente.
  List<SyncDocument> get documents => _documents.values.toList();

  @override
  Future<void> push(List<SyncDocument> documents) async {
    for (final document in documents) {
      final current = _documents[document.id];
      if (current == null || !current.updatedAt.isAfter(document.updatedAt)) {
        _documents[document.id] = document;
      }
    }
  }

  @override
  Future<List<SyncDocument>> pull({DateTime? since}) async {
    return _documents.values
        .where((document) => since == null || document.updatedAt.isAfter(since))
        .toList();
  }
}
