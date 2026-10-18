import 'package:flutter/material.dart';

import '../../shared/widgets/brand_logo.dart';

const String appVersion = '1.0.0';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _features = <(IconData, String, String)>[
    (
      Icons.swap_vert_circle_outlined,
      'Movimientos',
      'Ingresos, egresos, transferencias y pagos móviles.',
    ),
    (
      Icons.account_balance_wallet_outlined,
      'Cuentas multimoneda',
      'VES, USD, EUR y Binance con equivalente en dólares.',
    ),
    (
      Icons.currency_exchange,
      'Tasas y calculadora',
      'BCV, Binance y Euro en vivo, más conversión instantánea.',
    ),
    (
      Icons.savings_outlined,
      'Metas y ahorros',
      'Objetivos con progreso y ahorro libre sin meta fija.',
    ),
    (
      Icons.pie_chart_outline,
      'Presupuestos',
      'Límites por categoría y alertas de gasto.',
    ),
    (
      Icons.insights_outlined,
      'Análisis',
      'Flujo de efectivo, patrimonio neto e informes.',
    ),
    (
      Icons.notifications_active_outlined,
      'Recordatorios',
      'Avisos de servicios y deudas a tu medida.',
    ),
    (
      Icons.auto_awesome_outlined,
      'Personalización',
      'Tema, color de acento y tipografías premium.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          const Center(child: BrandLogo(height: 88)),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Polaris Finance',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Versión $appVersion',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Gestión financiera personal, minimalista, modular y '
                'multimoneda. Pensada para que registrar y entender tu dinero '
                'sea tan simple como debe ser.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(
              'Lo que puedes hacer',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < _features.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    leading: Icon(_features[i].$1, color: scheme.primary),
                    title: Text(_features[i].$2),
                    subtitle: Text(_features[i].$3),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.favorite,
                    color: scheme.primary.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Hecha con mucho cariño y dedicación para que tus '
                      'finanzas fluyan como los polos.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '© ${DateTime.now().year} Polaris Finance',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
