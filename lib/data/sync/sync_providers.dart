import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../database/app_database.dart';
import 'sync_config.dart';
import 'sync_engine.dart';
import 'sync_models.dart';
import 'sync_store.dart';

/// Configuración de sincronización cargada al arrancar la app.
final initialSyncConfigProvider = Provider<SyncConfig>((ref) {
  return const SyncConfig(deviceId: 'local');
});

/// Estado visible de la sincronización.
class SyncState {
  const SyncState({
    required this.config,
    this.phase = SyncPhase.idle,
    this.lastSyncAt,
    this.lastError,
    this.lastSummary,
    this.pendingCount = 0,
  });

  final SyncConfig config;
  final SyncPhase phase;
  final DateTime? lastSyncAt;
  final String? lastError;
  final SyncSummary? lastSummary;

  /// Cambios locales que todavía no se han enviado.
  final int pendingCount;

  bool get isBusy => phase == SyncPhase.syncing;

  bool get isConfigured => config.isConfigured;

  SyncState copyWith({
    SyncConfig? config,
    SyncPhase? phase,
    DateTime? lastSyncAt,
    String? lastError,
    SyncSummary? lastSummary,
    int? pendingCount,
    bool clearError = false,
  }) {
    return SyncState(
      config: config ?? this.config,
      phase: phase ?? this.phase,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastSummary: lastSummary ?? this.lastSummary,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }
}

/// Controlador de la sincronización: configuración, estado y ejecución.
class SyncController extends Notifier<SyncState> {
  Timer? _timer;

  @override
  SyncState build() {
    final config = ref.watch(initialSyncConfigProvider);
    // La base de datos necesita saber qué dispositivo originó cada cambio.
    ref.read(appDatabaseProvider).syncDeviceId = config.deviceId;
    Future<void>.microtask(() async {
      await refreshPending();
      if (config.enabled && config.isConfigured) {
        await syncNow();
        _startAutoSync();
      }
    });
    ref.onDispose(() => _timer?.cancel());
    return SyncState(config: config);
  }

  AppDatabase get _database => ref.read(appDatabaseProvider);

  /// Motor de sincronización con el servidor configurado.
  SyncEngine _buildEngine(SyncConfig config) => SyncEngine(
    database: _database,
    store: RestSyncStore(baseUrl: config.endpoint, token: config.token),
    deviceId: config.deviceId,
  );

  /// Sincroniza ahora: sube los cambios locales y aplica los remotos.
  Future<SyncSummary?> syncNow() async {
    final config = state.config;
    if (!config.enabled || !config.isConfigured) {
      state = state.copyWith(
        phase: SyncPhase.disabled,
        lastError: config.isConfigured
            ? 'Activa la sincronización para empezar'
            : 'Configura la dirección del servidor de sincronización',
      );
      return null;
    }
    if (state.isBusy) return null;

    state = state.copyWith(phase: SyncPhase.syncing, clearError: true);
    try {
      final summary = await _buildEngine(config).syncNow();
      state = state.copyWith(
        phase: SyncPhase.success,
        lastSyncAt: summary.finishedAt,
        lastSummary: summary,
        clearError: true,
      );
      await refreshPending();
      return summary;
    } catch (error) {
      state = state.copyWith(phase: SyncPhase.error, lastError: '$error');
      return null;
    }
  }

  /// Actualiza y guarda la configuración.
  Future<void> updateConfig(SyncConfig config) async {
    final previousToken = state.config.token;
    state = state.copyWith(config: config);
    final prefs = await SharedPreferences.getInstance();
    try {
      await config.save(prefs, previousToken: previousToken);
    } catch (error) {
      state = state.copyWith(lastError: 'No se pudo guardar el token: $error');
      rethrow;
    }
    _database.syncDeviceId = config.deviceId;
    await refreshPending();
    if (config.enabled && config.isConfigured) {
      _startAutoSync();
      await syncNow();
    } else {
      _timer?.cancel();
      _timer = null;
      state = state.copyWith(phase: SyncPhase.disabled);
    }
  }

  /// Cambia solo un campo de la configuración.
  Future<void> patch({
    bool? enabled,
    String? endpoint,
    String? token,
    String? deviceName,
    bool? autoSync,
  }) {
    return updateConfig(
      state.config.copyWith(
        enabled: enabled,
        endpoint: endpoint,
        token: token,
        deviceName: deviceName,
        autoSync: autoSync,
      ),
    );
  }

  /// Recalcula cuántos cambios locales quedan por enviar.
  Future<void> refreshPending() async {
    try {
      final state0 = await _database.readSyncState();
      final rows = await _database.pendingChanges(
        afterSeq: state0?.lastPushedSeq ?? 0,
        limit: 1000,
      );
      state = state.copyWith(pendingCount: rows.length);
    } catch (error) {
      state = state.copyWith(
        lastError: 'No se pudo revisar los cambios: $error',
      );
    }
  }

  /// Exporta el estado completo para llevarlo a otro dispositivo.
  Future<String> exportDeviceState() async {
    final config = state.config;
    final engine = SyncEngine(
      database: _database,
      store: MemorySyncStore(),
      deviceId: config.deviceId,
    );
    final documents = await engine.pendingDocuments(limit: 20000);
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'Polaris Finance',
      'type': 'sync-transfer',
      'deviceId': config.deviceId,
      'deviceName': config.deviceName,
      'exportedAt': DateTime.now().toIso8601String(),
      'documents': documents.map((d) => d.toJson()).toList(),
    });
  }

  /// Aplica un estado exportado desde otro dispositivo.
  Future<SyncSummary?> importDeviceState(String raw) async {
    final config = state.config;
    final documents = parseTransfer(raw);
    if (documents.isEmpty) {
      state = state.copyWith(lastError: 'El archivo no contiene cambios');
      return null;
    }
    final engine = SyncEngine(
      database: _database,
      store: MemorySyncStore(),
      deviceId: config.deviceId,
    );
    try {
      final summary = await engine.mergeDocuments(documents);
      state = state.copyWith(
        phase: SyncPhase.success,
        lastSyncAt: summary.finishedAt,
        lastSummary: summary,
        clearError: true,
      );
      await refreshPending();
      return summary;
    } catch (error) {
      state = state.copyWith(phase: SyncPhase.error, lastError: '$error');
      return null;
    }
  }

  /// Lee los documentos de un archivo de transferencia.
  static List<SyncDocument> parseTransfer(String raw) {
    final decoded = jsonDecode(raw);
    final list = decoded is Map ? decoded['documents'] : decoded;
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map) SyncDocument.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  void _startAutoSync() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => syncNow());
  }
}

/// Controlador de sincronización de la app.
final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);
