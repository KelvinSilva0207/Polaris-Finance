import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Envuelve `local_auth` para consultar y usar el desbloqueo biométrico.
/// En plataformas sin soporte (web) devuelve siempre `false`.
class BiometricService {
  BiometricService([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// `true` si el dispositivo tiene algún método biométrico disponible.
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Lanza el diálogo biométrico. Devuelve `true` si el usuario se autenticó.
  Future<bool> authenticate({required String reason}) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

final biometricServiceProvider = Provider<BiometricService>(
  (ref) => BiometricService(),
);

/// Disponibilidad de biometría en el dispositivo actual.
final biometricAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricServiceProvider).isAvailable(),
);
