import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_hasher.dart';

const appLockEnabledKey = 'app_lock_enabled';
const appLockPinHashKey = 'app_lock_pin_hash';
const appLockPinSaltKey = 'app_lock_pin_salt';
const appLockBiometricKey = 'app_lock_biometric';

final initialAppLockProvider = Provider<AppLockState>((ref) {
  throw UnimplementedError('Debe sobrescribirse en ProviderScope');
});

final appLockProvider = NotifierProvider<AppLockController, AppLockState>(
  AppLockController.new,
);

/// Estado del bloqueo de la app: si está activo, si acepta biometría y si en
/// este momento está bloqueado a la espera del PIN.
class AppLockState {
  const AppLockState({
    this.enabled = false,
    this.biometricEnabled = false,
    this.locked = false,
  });

  final bool enabled;
  final bool biometricEnabled;
  final bool locked;

  bool get requiresUnlock => enabled && locked;

  AppLockState copyWith({bool? enabled, bool? biometricEnabled, bool? locked}) {
    return AppLockState(
      enabled: enabled ?? this.enabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      locked: locked ?? this.locked,
    );
  }

  factory AppLockState.fromPrefs(SharedPreferences prefs) {
    final hasPin = prefs.getString(appLockPinHashKey) != null;
    final enabled = hasPin && (prefs.getBool(appLockEnabledKey) ?? false);
    return AppLockState(
      enabled: enabled,
      biometricEnabled: enabled && (prefs.getBool(appLockBiometricKey) ?? false),
      locked: enabled,
    );
  }
}

class AppLockController extends Notifier<AppLockState> {
  @override
  AppLockState build() => ref.watch(initialAppLockProvider);

  /// Activa el bloqueo con [pin] y desactiva la biometría hasta que el usuario
  /// la habilite explícitamente.
  Future<void> enable(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = generatePinSalt();
    final hash = hashPin(pin, salt);
    await prefs.setString(appLockPinSaltKey, salt);
    await prefs.setString(appLockPinHashKey, hash);
    await prefs.setBool(appLockEnabledKey, true);
    await prefs.setBool(appLockBiometricKey, false);
    state = state.copyWith(
      enabled: true,
      biometricEnabled: false,
      locked: false,
    );
  }

  /// Desactiva el bloqueo y borra el PIN almacenado.
  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(appLockPinSaltKey);
    await prefs.remove(appLockPinHashKey);
    await prefs.setBool(appLockEnabledKey, false);
    await prefs.setBool(appLockBiometricKey, false);
    state = state.copyWith(
      enabled: false,
      biometricEnabled: false,
      locked: false,
    );
  }

  /// Verifica [pin]; si es correcto desbloquea y devuelve true.
  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = prefs.getString(appLockPinSaltKey);
    final hash = prefs.getString(appLockPinHashKey);
    if (salt == null || hash == null) return false;
    final ok = verifyPinHash(pin, salt: salt, hash: hash);
    if (ok) {
      state = state.copyWith(locked: false);
    }
    return ok;
  }

  Future<void> setBiometricEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(appLockBiometricKey, value);
    state = state.copyWith(biometricEnabled: value);
  }

  /// Desbloquea sin comprobar el PIN (usado tras una autenticación biométrica).
  void unlock() {
    if (!state.enabled) return;
    state = state.copyWith(locked: false);
  }

  /// Vuelve a bloquear la app (por ejemplo, al pasar a segundo plano).
  void lock() {
    if (!state.enabled) return;
    state = state.copyWith(locked: true);
  }
}
