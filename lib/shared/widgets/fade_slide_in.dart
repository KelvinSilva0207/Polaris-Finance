import 'package:flutter/material.dart';

/// Entrada animada sutil: fundido + deslizamiento corto con retardo opcional.
///
/// El retardo se resuelve con una curva `Interval` (no con timers), por lo que
/// las animaciones siempre terminan en el primer ciclo de frames y los tests
/// con `pumpAndSettle` se estabilizan sin dejar timers pendientes.
/// Respeta `MediaQuery.disableAnimations` y no se repite cuando el padre se
/// reconstruye.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offset = const Offset(0, 0.05),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration + widget.delay,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (!MediaQuery.disableAnimationsOf(context)) {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    final total = widget.duration + widget.delay;
    final start =
        (total.inMicroseconds == 0
                ? 0.0
                : widget.delay.inMicroseconds / total.inMicroseconds)
            .clamp(0.0, 0.999);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      reverseCurve: Interval(start, 1, curve: Curves.easeInCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: widget.offset,
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}
