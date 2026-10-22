import 'dart:convert';

/// Un cambio de un registro que viaja entre dispositivos.
///
/// Cada documento corresponde a un registro de una colección (cuenta,
/// categoría, movimiento…) e incluye la marca de tiempo del cambio y el
/// dispositivo que lo originó, para poder resolver conflictos.
class SyncDocument {
  const SyncDocument({
    required this.id,
    required this.collection,
    required this.recordId,
    required this.updatedAt,
    required this.deleted,
    required this.deviceId,
    required this.payload,
    this.seq = 0,
    this.updatedAtMs = 0,
  });

  /// Identificador global del cambio: `coleccion:idDelRegistro`.
  final String id;

  /// Colección a la que pertenece el registro (`transactions`, `accounts`…).
  final String collection;

  /// Identificador del registro dentro de su colección.
  final String recordId;

  /// Momento en que se produjo el cambio (reloj del dispositivo origen).
  final DateTime updatedAt;

  /// `true` si el registro fue borrado (lápida).
  final bool deleted;

  /// Dispositivo que originó el cambio.
  final String deviceId;

  /// Datos del registro (vacío en las lápidas).
  final Map<String, dynamic> payload;

  /// Número de secuencia del cambio en la bitácora del dispositivo origen.
  ///
  /// Solo es comparable entre cambios del mismo dispositivo; sirve para
  /// desempatar dos cambios hechos en el mismo instante.
  final int seq;

  /// Fecha del cambio en milisegundos desde epoch.
  ///
  /// La base de datos guarda las fechas con precisión de segundos, así que
  /// este valor es el que se usa para comparar cambios entre dispositivos.
  final int updatedAtMs;

  static String buildId(String collection, String recordId) =>
      '$collection:$recordId';

  factory SyncDocument.fromJson(Map<String, dynamic> json) {
    final collection = (json['collection'] ?? '').toString();
    final recordId = (json['recordId'] ?? '').toString();
    final seq = json['seq'];
    final updatedAtMs = json['updatedAtMs'];
    final updatedAt =
        DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return SyncDocument(
      id: (json['id'] ?? buildId(collection, recordId)).toString(),
      collection: collection,
      recordId: recordId,
      updatedAt: updatedAt,
      deleted: json['deleted'] == true,
      deviceId: (json['deviceId'] ?? '').toString(),
      payload: decodePayload(json['payload']),
      seq: seq is int ? seq : int.tryParse('$seq') ?? 0,
      updatedAtMs: updatedAtMs is int
          ? updatedAtMs
          : int.tryParse('$updatedAtMs') ?? updatedAt.millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'collection': collection,
    'recordId': recordId,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'updatedAtMs': updatedAtMs,
    'deleted': deleted,
    'deviceId': deviceId,
    'payload': payload,
    'seq': seq,
  };

  /// Convierte el payload a un mapa, aceptando tanto el mapa como el texto
  /// JSON en el que se guarda dentro de la base de datos.
  static Map<String, dynamic> decodePayload(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } on FormatException {
        return <String, dynamic>{};
      }
    }
    return <String, dynamic>{};
  }
}

/// Estado del proceso de sincronización.
enum SyncPhase {
  /// Sin sincronizar todavía.
  idle,

  /// Sincronización en curso.
  syncing,

  /// Última sincronización correcta.
  success,

  /// La última sincronización falló.
  error,

  /// La sincronización está desactivada o no hay servidor configurado.
  disabled,
}

/// Resumen de una sincronización.
class SyncSummary {
  const SyncSummary({
    this.pushed = 0,
    this.pulled = 0,
    this.applied = 0,
    this.skipped = 0,
    this.finishedAt,
    this.error,
  });

  /// Cambios locales enviados al servidor.
  final int pushed;

  /// Cambios recibidos del servidor.
  final int pulled;

  /// Cambios aplicados de verdad en la base de datos local.
  final int applied;

  /// Cambios descartados por estar desactualizados.
  final int skipped;

  /// Fin de la sincronización.
  final DateTime? finishedAt;

  /// Mensaje de error, si lo hubo.
  final String? error;

  bool get ok => error == null;

  @override
  String toString() =>
      'SyncSummary(pushed: $pushed, pulled: $pulled, applied: $applied, '
      'skipped: $skipped, error: $error)';
}
