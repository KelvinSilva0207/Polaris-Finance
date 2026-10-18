import 'package:flutter/material.dart';

import '../../shared/widgets/brand_logo.dart';

class _TutorialPage {
  const _TutorialPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.points,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<String> points;
}

const _pages = <_TutorialPage>[
  _TutorialPage(
    icon: Icons.waving_hand_outlined,
    title: 'Bienvenido a Polaris Finance',
    description:
        'Tu centro de control financiero personal. Te mostramos lo esencial en '
        'menos de un minuto.',
    points: [
      'Minimalista, modular y multimoneda',
      'Pensada para Venezuela: BCV, Binance y Euro',
      'Todos tus datos se guardan en tu dispositivo',
    ],
  ),
  _TutorialPage(
    icon: Icons.swap_vert_circle_outlined,
    title: 'Registra tus movimientos',
    description:
        'Anota ingresos, egresos, transferencias y pagos móviles. Cada monto se '
        'formatea solo mientras escribes.',
    points: [
      'Categorías ampliadas para saber de dónde viene cada bolívar',
      'Comisiones automáticas por cuenta',
      'Notas y etiquetas para no perder detalle',
    ],
  ),
  _TutorialPage(
    icon: Icons.account_balance_wallet_outlined,
    title: 'Cuentas y multimoneda',
    description:
        'Administra cuentas en bolívares, dólares, euros y Binance con su saldo '
        'real y equivalente en USD.',
    points: [
      'Tasas de cambio en vivo (BCV, Binance y Euro)',
      'Calculadora de monedas integrada',
      'Saldo total convertido al instante',
    ],
  ),
  _TutorialPage(
    icon: Icons.savings_outlined,
    title: 'Metas y ahorros',
    description:
        'Crea metas con objetivo y fecha, o simplemente ahorra libremente sin '
        'una cifra en mente.',
    points: [
      'Progreso visual de cada meta',
      'Aportes y retiros cuando quieras',
      'Ahorro libre: guardar por el simple hecho de guardar',
    ],
  ),
  _TutorialPage(
    icon: Icons.insights_outlined,
    title: 'Analiza y decide',
    description:
        'Gráficos, presupuestos, patrimonio neto e informes para entender hacia '
        'dónde va tu dinero.',
    points: [
      'Flujo de efectivo y comparación de meses',
      'Presupuestos por categoría',
      'Exporta tus datos cuando lo necesites',
    ],
  ),
  _TutorialPage(
    icon: Icons.auto_awesome_outlined,
    title: 'Hazla tuya',
    description:
        'Personaliza el color, el tema, la tipografía y los recordatorios de '
        'pagos desde Ajustes.',
    points: [
      'Tipografías premium y tema claro u oscuro',
      'Recordatorios de servicios y deudas a tu medida',
      'Consejos de ahorro e inversión dentro de la app',
    ],
  ),
];

/// Tutorial de primer uso. Llama a [onDone] al terminar o al omitir.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= _pages.length - 1) {
      widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLast = _index == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  const BrandLogo(height: 30),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onDone,
                    child: const Text('Omitir'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.primary.withValues(alpha: 0.12),
                            border: Border.all(
                              color: scheme.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            page.icon,
                            size: 50,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        for (final point in page.points)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    point,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _pages.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _index ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: i == _index
                                ? scheme.primary
                                : scheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _next,
                      icon: Icon(
                        isLast
                            ? Icons.rocket_launch_outlined
                            : Icons.arrow_forward,
                      ),
                      label: Text(isLast ? 'Empezar' : 'Siguiente'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
