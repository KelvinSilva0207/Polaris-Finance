import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons.dart';
import '../../core/providers.dart';
import '../../data/database/seeds.dart';
import '../../shared/widgets/brand_logo.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final Set<String> _selected = {};
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _selected.addAll(venezuelaInstitutions.take(3).map((i) => i.name));
  }

  void _toggle(SeedInstitution institution, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(institution.name);
      } else {
        _selected.remove(institution.name);
      }
    });
  }

  Future<void> _createAccounts() async {
    if (_selected.isEmpty) {
      _message('Selecciona al menos una institución');
      return;
    }
    setState(() => _creating = true);
    final db = ref.read(appDatabaseProvider);
    try {
      for (final name in _selected.toList()) {
        final institution = venezuelaInstitutions.firstWhere((i) => i.name == name);
        await db.addAccount(
          name: institution.name,
          type: institution.type,
          currency: institution.currency == 'USDT' ? 'USDT' : institution.currency,
          colorValue: institution.colorValue,
          icon: institution.icon,
        );
      }
      if (!mounted) return;
      widget.onDone();
    } catch (error) {
      if (!mounted) return;
      setState(() => _creating = false);
      _message(error.toString());
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            const Center(child: BrandLogo(height: 72)),
            const SizedBox(height: 16),
            Text(
              'Bienvenido a Polaris Finance',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Elige tu país y crea tus cuentas para empezar a registrar tu día a día.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.public),
                title: const Text('País'),
                trailing: const Text('Venezuela'),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Sugerencias de cuentas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            for (final institution in venezuelaInstitutions)
              CheckboxListTile(
                value: _selected.contains(institution.name),
                onChanged: (value) => _toggle(institution, value ?? false),
                secondary: CircleAvatar(
                  backgroundColor: Color(institution.colorValue).withValues(alpha: 0.18),
                  child: Icon(
                    iconFromName(institution.icon),
                    color: Color(institution.colorValue),
                  ),
                ),
                title: Text(institution.name),
                subtitle: Text('${institution.type.label} · ${institution.currency}'),
                controlAffinity: ListTileControlAffinity.trailing,
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _creating ? null : _createAccounts,
              icon: _creating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(
                _creating ? 'Creando cuentas…' : 'Crear cuentas seleccionadas',
              ),
            ),
            TextButton(
              onPressed: _creating ? null : widget.onDone,
              child: const Text('Omitir por ahora'),
            ),
          ],
        ),
      ),
    );
  }
}