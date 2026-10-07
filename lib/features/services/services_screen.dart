import 'package:flutter/material.dart';

import '../../shared/widgets/module_placeholder.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Servicios')),
      body: const ModulePlaceholder(
        icon: Icons.receipt_long_outlined,
        title: 'Gastos fijos y servicios',
        description:
            'Pagos periódicos con "Marcar como pagado" en 1 clic y ajuste del monto final del recibo.',
        phase: '3',
      ),
    );
  }
}