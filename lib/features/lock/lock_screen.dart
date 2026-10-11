import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/app_lock.dart';
import '../../core/security/biometric_service.dart';
import '../../core/security/pin_hasher.dart';
import 'pin_widgets.dart';

/// Pantalla de bloqueo: pide el PIN o la biometría antes de mostrar la app.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  String? _error;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBiometric());
  }

  Future<void> _maybeBiometric() async {
    if (!ref.read(appLockProvider).biometricEnabled) return;
    final service = ref.read(biometricServiceProvider);
    if (!await service.isAvailable()) return;
    if (mounted) await _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    final ok = await ref
        .read(biometricServiceProvider)
        .authenticate(reason: 'Desbloquea Polaris Finance');
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) {
      ref.read(appLockProvider.notifier).unlock();
    } else {
      setState(() => _error = 'No se pudo verificar. Usa tu PIN.');
    }
  }

  void _onDigit(int digit) {
    if (_checking || _pin.length >= kPinLength) return;
    setState(() {
      _pin += '$digit';
      _error = null;
    });
    if (_pin.length == kPinLength) _verify();
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verify() async {
    final pin = _pin;
    final ok = await ref.read(appLockProvider.notifier).verifyPin(pin);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _pin = '';
        _error = 'PIN incorrecto';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lock = ref.watch(appLockProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text('Polaris Finance', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Ingresa tu PIN para continuar',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                PinDots(length: kPinLength, filled: _pin.length),
                const SizedBox(height: 12),
                SizedBox(
                  height: 24,
                  child: _error == null
                      ? null
                      : Text(
                          _error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                PinKeypad(
                  enabled: !_checking,
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                  leading: lock.biometricEnabled
                      ? IconButton.filledTonal(
                          tooltip: 'Usar biometría',
                          onPressed: _checking ? null : _tryBiometric,
                          icon: const Icon(Icons.fingerprint),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
