import 'package:flutter/material.dart';

import '../../shared/widgets/module_placeholder.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analítica')),
      body: const ModulePlaceholder(
        icon: Icons.insert_chart_outlined,
        title: 'Analítica avanzada',
        description:
            'Gastos hormiga, gráficos por día/semana/mes/año, métricas de ahorro y reportes exportables.',
        phase: '3',
      ),
    );
  }
}