import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/app_lock.dart';
import '../../core/security/pin_hasher.dart';
import 'pin_widgets.dart';

/// Crea y confirma un nuevo PIN. Devuelve `true` al guardarlo.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _first = '';
  String _pin = '';
  bool _confirming = false;
  String? _error;

  void _onDigit(int digit) {
    if (_pin.length >= kPinLength) return;
    setState(() {
      _pin += '$digit';
      _error = null;
    });
    if (_pin.length == kPinLength) _submit();
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (!_confirming) {
      setState(() {
        _first = _pin;
        _pin = '';
        _confirming = true;
      });
      return;
    }
    if (_pin != _first) {
      setState(() {
        _pin = '';
        _first = '';
        _confirming = false;
        _error = 'Los PIN no coinciden. Intenta de nuevo.';
      });
      return;
    }
    await ref.read(appLockProvider.notifier).enable(_first);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('PIN de seguridad')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.pin_outlined,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  _confirming ? 'Confirma tu PIN' : 'Crea tu PIN',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Usa $kPinLength dígitos para proteger tus datos.',
                  textAlign: TextAlign.center,
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
                PinKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
