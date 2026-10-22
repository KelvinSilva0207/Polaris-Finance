import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'sync_models.dart';
import 'sync_store.dart';

/// Motor de sincronización entre dispositivos.
///
/// El flujo es siempre el mismo:
///
/// 1. Se sube a la nube los cambios locales pendientes (bitácora `sync_records`).
/// 2. Se descargan los cambios remotos.
/// 3. Se fusiona cada cambio remoto con el local aplicando *última
///    escritura gana* (LWW) según la marca de tiempo del cambio.
///
/// Cada cambio lleva el dispositivo de origen, así que un dispositivo nunca
/// reenvía como propios los cambios que acaba de recibir.
class SyncEngine {
  SyncEngine({
    required this.database,
    required this.store,
    required this.deviceId,
  });

  final AppDatabase database;
  final SyncStore store;

  /// Identificador del dispositivo local.
  final String deviceId;

  /// Orden en que se aplican los cambios remotos para respetar las claves
  /// foráneas (cuentas y categorías antes que los movimientos).
  static const _applyOrder = <String>[
    'accounts',
    'categories',
    'loans',
    'goals',
    'services',
    'rates',
    'feeRules',
    'transactions',
    'loanPayments',
    'budgets',
  ];

  /// Sincroniza: sube los cambios locales y aplica los remotos.
  Future<SyncSummary> syncNow() async {
    final state = await database.readSyncState();
    await _ensureBaseline();

    final pending = await database.pendingChanges(
      afterSeq: state?.lastPushedSeq ?? 0,
    );
    var pushed = 0;
    if (pending.isNotEmpty) {
      final documents = pending.map(_toDocument).toList();
      await store.push(documents);
      pushed = documents.length;
      var newest = pending.first.seq;
      for (final row in pending) {
        if (row.seq > newest) newest = row.seq;
      }
      await database.writeSyncState(deviceId: deviceId, lastPushedSeq: newest);
    }

    // Se pide un pequeño margen hacia atrás porque las fechas se guardan
    // con precisión de segundos: así ningún cambio se queda fuera.
    final since = state?.lastPulledAt?.subtract(const Duration(seconds: 5));
    final remote = await store.pull(since: since);
    final merged = await mergeDocuments(remote);

    final now = DateTime.now();
    await database.writeSyncState(
      deviceId: deviceId,
      lastPulledAt: now,
      lastSyncAt: now,
    );
    return SyncSummary(
      pushed: pushed,
      pulled: merged.pulled,
      applied: merged.applied,
      skipped: merged.skipped,
      finishedAt: now,
    );
  }

  /// Aplica cambios venidos de otro dispositivo (nube u otro móvil).
  Future<SyncSummary> mergeDocuments(List<SyncDocument> documents) async {
    var applied = 0;
    var skipped = 0;
    final ordered = [...documents]
      ..sort((a, b) {
        final ai = _applyOrder.indexOf(a.collection);
        final bi = _applyOrder.indexOf(b.collection);
        return (ai == -1 ? _applyOrder.length : ai).compareTo(
          bi == -1 ? _applyOrder.length : bi,
        );
      });

    for (final document in ordered) {
      if (document.collection.isEmpty || document.recordId.isEmpty) {
        skipped++;
        continue;
      }
      if (document.deviceId.isNotEmpty && document.deviceId == deviceId) {
        // Es un cambio propio que vuelve del servidor: no hay que aplicarlo.
        skipped++;
        continue;
      }
      final local = await database.findSyncRecord(
        document.collection,
        document.recordId,
      );
      if (local != null &&
          !_remoteWins(
            localUpdatedAtMs: local.updatedAtMs,
            localDeviceId: local.deviceId,
            localOriginSeq: local.originSeq,
            remoteUpdatedAtMs: document.updatedAtMs,
            remoteDeviceId: document.deviceId,
            remoteSeq: document.seq,
          )) {
        // El cambio local es más reciente (o es el mismo): gana lo local.
        skipped++;
        continue;
      }
      try {
        if (document.deleted) {
          await _detachReferences(document.collection, document.recordId);
        }
        final appliedOk = await database.applyRemoteChange(
          collection: document.collection,
          recordId: document.recordId,
          payload: document.payload,
          deleted: document.deleted,
        );
        if (!appliedOk) {
          skipped++;
          continue;
        }
        await database.logRemoteChange(
          collection: document.collection,
          recordId: document.recordId,
          updatedAt: document.updatedAt,
          updatedAtMs: document.updatedAtMs,
          originSeq: document.seq,
          deviceId: document.deviceId,
          payload: document.payload,
          deleted: document.deleted,
        );
        applied++;
      } catch (error) {
        // Un cambio que no se puede aplicar (por ejemplo, una referencia
        // que todavía no existe) no debe tumbar la sincronización completa.
        skipped++;
      }
    }

    return SyncSummary(
      pulled: documents.length,
      applied: applied,
      skipped: skipped,
      finishedAt: DateTime.now(),
    );
  }

  /// Cambios locales pendientes de enviar.
  Future<List<SyncDocument>> pendingDocuments({int limit = 500}) async {
    await _ensureBaseline();
    final rows = await database.pendingChanges(limit: limit);
    return rows.map(_toDocument).toList();
  }

  /// Prepara la bitácora la primera vez: sube el estado completo del
  /// dispositivo para que el resto reciba todos los datos.
  Future<void> _ensureBaseline() async {
    final rows = await database.pendingChanges(limit: 1);
    if (rows.isNotEmpty) return;
    await database.logAllRecords();
  }

  /// Suelta las referencias que impedirían borrar un registro.
  Future<void> _detachReferences(String collection, String recordId) async {
    if (collection == 'categories') {
      // Los movimientos quedan sin categoría y los presupuestos de esa
      // categoría se eliminan, igual que al borrarla en este dispositivo.
      await (database.update(database.transactions)
            ..where((t) => t.categoryId.equals(recordId)))
          .write(TransactionsCompanion(categoryId: const Value(null)));
      await (database.delete(
        database.budgets,
      )..where((t) => t.categoryId.equals(recordId))).go();
    } else if (collection == 'loans') {
      await (database.delete(
        database.loanPayments,
      )..where((t) => t.loanId.equals(recordId))).go();
    }
  }

  /// Decide si el cambio remoto debe aplicarse sobre el local.
  ///
  /// Gana el cambio más reciente (comparado en milisegundos). Si el
  /// instante coincide, gana el cambio más nuevo de la bitácora cuando es
  /// el mismo dispositivo, o el dispositivo con el identificador más alto
  /// cuando son distintos. Así todos los dispositivos convergen al mismo
  /// resultado.
  static bool _remoteWins({
    required int localUpdatedAtMs,
    required String localDeviceId,
    required int localOriginSeq,
    required int remoteUpdatedAtMs,
    required String remoteDeviceId,
    required int remoteSeq,
  }) {
    if (remoteUpdatedAtMs > localUpdatedAtMs) return true;
    if (remoteUpdatedAtMs < localUpdatedAtMs) return false;
    if (remoteDeviceId == localDeviceId) return remoteSeq > localOriginSeq;
    return remoteDeviceId.compareTo(localDeviceId) > 0;
  }

  SyncDocument _toDocument(SyncRecord row) => SyncDocument(
    id: row.id,
    collection: row.collection,
    recordId: row.recordId,
    updatedAt: row.updatedAt,
    deleted: row.deleted,
    deviceId: row.deviceId,
    payload: SyncDocument.decodePayload(row.payload),
    seq: row.originSeq,
    updatedAtMs: row.updatedAtMs,
  );
}
