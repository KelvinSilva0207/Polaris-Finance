import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/brand_logo.dart';

/// Animación de introducción que se muestra al abrir la app. Llama a [onDone]
/// cuando termina (o de inmediato si las animaciones están desactivadas).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  late final Animation<double> _logo = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.62, curve: Curves.easeOutBack),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.25, 0.8, curve: Curves.easeOut),
  );
  late final Animation<Offset> _rise =
      Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
        ),
      );
  bool _started = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    } else {
      _controller.forward();
    }
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.25),
                  radius: 1.1,
                  colors: [
                    scheme.primary.withValues(alpha: 0.22),
                    AppTheme.background,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _logo,
                  child: FadeTransition(
                    opacity: _logo,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary.withValues(alpha: 0.10),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const BrandLogo(height: 84),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _rise,
                    child: Column(
                      children: [
                        Text(
                          'Polaris Finance',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Finanzas claras, decisiones tranquilas',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: FadeTransition(
              opacity: _fade,
              child: Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
