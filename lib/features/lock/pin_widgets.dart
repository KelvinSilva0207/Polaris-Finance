import 'package:flutter/material.dart';

/// Fila de puntos que indica cuántos dígitos del PIN se han ingresado.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, required this.filled});

  final int length;
  final int filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? scheme.primary : Colors.transparent,
              border: Border.all(
                color: i < filled ? scheme.primary : scheme.outlineVariant,
                width: 2,
              ),
            ),
          ),
      ],
    );
  }
}

/// Teclado numérico para ingresar el PIN. [leading] permite colocar el botón
/// de biometría en la esquina inferior izquierda.
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.leading,
    this.enabled = true,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final Widget? leading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < 3; row++)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var col = 0; col < 3; col++)
                _KeypadButton(
                  label: '${row * 3 + col + 1}',
                  onTap: enabled ? () => onDigit(row * 3 + col + 1) : null,
                ),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: leading == null
                  ? null
                  : Center(child: leading),
            ),
            _KeypadButton(label: '0', onTap: enabled ? () => onDigit(0) : null),
            _KeypadButton(
              icon: Icons.backspace_outlined,
              onTap: enabled ? onBackspace : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 84,
      height: 84,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 26)
                  : Text(
                      label ?? '',
                      style: theme.textTheme.headlineSmall,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
