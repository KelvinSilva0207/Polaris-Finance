import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Configuración de la sincronización guardada en este dispositivo.
///
/// La dirección del servidor y el nombre del dispositivo se guardan en las
/// preferencias; el token de acceso, en el almacenamiento seguro del sistema.
class SyncConfig {
  const SyncConfig({
    this.enabled = false,
    this.endpoint = '',
    this.token = '',
    this.deviceId = '',
    this.deviceName = 'Este dispositivo',
    this.autoSync = true,
  });

  /// Activación de la sincronización en la nube.
  final bool enabled;

  /// Dirección del servidor de sincronización (por ejemplo
  /// `https://api.midominio.com`).
  final String endpoint;

  /// Token de acceso al servidor.
  final String token;

  /// Identificador único de este dispositivo.
  final String deviceId;

  /// Nombre legible del dispositivo.
  final String deviceName;

  /// Sincronización automática al abrir la app y cada cierto tiempo.
  final bool autoSync;

  /// `true` cuando hay un servidor configurado.
  bool get isConfigured => endpoint.trim().isNotEmpty;

  SyncConfig copyWith({
    bool? enabled,
    String? endpoint,
    String? token,
    String? deviceId,
    String? deviceName,
    bool? autoSync,
  }) {
    return SyncConfig(
      enabled: enabled ?? this.enabled,
      endpoint: endpoint ?? this.endpoint,
      token: token ?? this.token,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      autoSync: autoSync ?? this.autoSync,
    );
  }

  static const _enabledKey = 'sync_enabled';
  static const _endpointKey = 'sync_endpoint';
  static const _deviceIdKey = 'sync_device_id';
  static const _deviceNameKey = 'sync_device_name';
  static const _autoSyncKey = 'sync_auto';
  static const _tokenKey = 'polaris_sync_token_v1';

  /// Lee la configuración; crea el identificador del dispositivo si es la
  /// primera vez que se abre la app.
  static Future<SyncConfig> load(
    SharedPreferences prefs, {
    FlutterSecureStorage? storage,
  }) async {
    final secure = storage ?? const FlutterSecureStorage();
    var token = '';
    try {
      token = await secure.read(key: _tokenKey) ?? '';
    } catch (error) {
      debugPrint('No se pudo leer el token de sincronización: $error');
    }

    var deviceId = prefs.getString(_deviceIdKey) ?? '';
    if (deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    return SyncConfig(
      enabled: prefs.getBool(_enabledKey) ?? false,
      endpoint: (prefs.getString(_endpointKey) ?? '').trim(),
      token: token,
      deviceId: deviceId,
      deviceName: prefs.getString(_deviceNameKey) ?? 'Este dispositivo',
      autoSync: prefs.getBool(_autoSyncKey) ?? true,
    );
  }

  /// Guarda la configuración.
  Future<void> save(
    SharedPreferences prefs, {
    FlutterSecureStorage? storage,
    String? previousToken,
  }) async {
    await prefs.setBool(_enabledKey, enabled);
    await prefs.setString(_endpointKey, endpoint.trim());
    await prefs.setString(_deviceIdKey, deviceId);
    await prefs.setString(_deviceNameKey, deviceName);
    await prefs.setBool(_autoSyncKey, autoSync);

    if (token == previousToken) return;
    final secure = storage ?? const FlutterSecureStorage();
    try {
      if (token.isEmpty) {
        await secure.delete(key: _tokenKey);
      } else {
        await secure.write(key: _tokenKey, value: token);
      }
    } catch (error) {
      debugPrint('No se pudo guardar el token de sincronización: $error');
      rethrow;
    }
  }
}
