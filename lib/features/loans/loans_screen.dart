import 'package:flutter/material.dart';

import '../../shared/widgets/module_placeholder.dart';

class LoansScreen extends StatelessWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Préstamos')),
      body: const ModulePlaceholder(
        icon: Icons.request_quote_outlined,
        title: 'Préstamos y deudas',
        description:
            'Registro de "Debo / Me Deben", abonos y liquidación con conversión en tiempo real según la tasa seleccionada.',
        phase: '2',
      ),
    );
  }
}