import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_finance/core/security/app_lock.dart';
import 'package:polaris_finance/core/security/pin_hasher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('el hash verifica el PIN y rechaza otro distinto', () {
    final salt = generatePinSalt();
    final hash = hashPin('1234', salt);
    expect(hash, isNot('1234'));
    expect(verifyPinHash('1234', salt: salt, hash: hash), isTrue);
    expect(verifyPinHash('0000', salt: salt, hash: hash), isFalse);
  });

  test('cada salt produce un hash distinto para el mismo PIN', () {
    final saltA = generatePinSalt();
    final saltB = generatePinSalt();
    expect(hashPin('1234', saltA), isNot(hashPin('1234', saltB)));
  });

  test('activar, bloquear, verificar y desactivar', () async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        initialAppLockProvider.overrideWithValue(AppLockState.fromPrefs(prefs)),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(appLockProvider.notifier);

    expect(container.read(appLockProvider).enabled, isFalse);

    await controller.enable('4321');
    var state = container.read(appLockProvider);
    expect(state.enabled, isTrue);
    expect(state.locked, isFalse);

    controller.lock();
    expect(container.read(appLockProvider).requiresUnlock, isTrue);

    expect(await controller.verifyPin('0000'), isFalse);
    expect(container.read(appLockProvider).locked, isTrue);

    expect(await controller.verifyPin('4321'), isTrue);
    expect(container.read(appLockProvider).locked, isFalse);

    await controller.disable();
    state = container.read(appLockProvider);
    expect(state.enabled, isFalse);
    expect(state.requiresUnlock, isFalse);
    expect(prefs.getString(appLockPinHashKey), isNull);
    expect(prefs.getString(appLockPinSaltKey), isNull);
  });

  test('estado inicial queda bloqueado si hay PIN guardado', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(appLockPinSaltKey, 'salt');
    await prefs.setString(appLockPinHashKey, 'hash');
    await prefs.setBool(appLockEnabledKey, true);
    await prefs.setBool(appLockBiometricKey, true);
    final state = AppLockState.fromPrefs(prefs);
    expect(state.enabled, isTrue);
    expect(state.biometricEnabled, isTrue);
    expect(state.requiresUnlock, isTrue);
  });

  test('sin hash guardado el bloqueo permanece desactivado', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(appLockEnabledKey, true);
    expect(AppLockState.fromPrefs(prefs).enabled, isFalse);
  });
}
