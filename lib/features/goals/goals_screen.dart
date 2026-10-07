import 'package:flutter/material.dart';

import '../../shared/widgets/module_placeholder.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Metas')),
      body: const ModulePlaceholder(
        icon: Icons.savings_outlined,
        title: 'Metas de ahorro',
        description:
            'Metas vinculadas a cuentas y sub-asignación de saldo virtual dentro de una misma cuenta.',
        phase: '2',
      ),
    );
  }
}