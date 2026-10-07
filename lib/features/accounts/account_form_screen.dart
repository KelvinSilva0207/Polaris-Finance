import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons.dart';
import '../../core/providers.dart';
import '../../data/database/app_database.dart';
import '../../data/database/seeds.dart';
import '../../data/models/currencies.dart';
import '../../data/models/enums.dart';
import '../../shared/widgets/color_picker_row.dart';
import '../../shared/widgets/icon_picker.dart';

class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({super.key, this.initial});

  final Account? initial;

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  late final TextEditingController _nameController;
  late AccountType _type;
  late String _currency;
  late int _color;
  late String _icon;
  bool _saving = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _type = AccountType.fromStorage(initial?.type);
    _currency = initial?.currency ?? 'VES';
    _color = initial?.colorValue ?? 0xFF9C6BFF;
    _icon = initial?.icon ?? 'account_balance';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _applyInstitution(SeedInstitution institution) {
    setState(() {
      _nameController.text = institution.name;
      _type = institution.type;
      _currency = institution.currency;
      _color = institution.colorValue;
      _icon = institution.icon;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un nombre para la cuenta')),
      );
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(appDatabaseProvider);
    try {
      if (_isEditing) {
        await db.updateAccount(
          widget.initial!.copyWith(
            name: name,
            type: _type.name,
            currency: _currency,
            colorValue: _color,
            icon: _icon,
          ),
        );
      } else {
        await db.addAccount(
          name: name,
          type: _type,
          currency: _currency,
          colorValue: _color,
          icon: _icon,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar cuenta' : 'Nueva cuenta')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _nameController,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AccountType>(
              key: ValueKey('type-${_type.name}'),
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final type in AccountType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('currency-$_currency'),
              initialValue: _currency,
              decoration: const InputDecoration(labelText: 'Moneda'),
              items: [
                for (final currency in commonCurrencies)
                  DropdownMenuItem(value: currency, child: Text(currency)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _currency = value);
              },
            ),
            const SizedBox(height: 20),
            Text('Sugerencias', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final institution in venezuelaInstitutions)
                  ActionChip(
                    label: Text(institution.name),
                    avatar: Icon(
                      iconFromName(institution.icon),
                      size: 18,
                      color: Color(institution.colorValue),
                    ),
                    onPressed: () => _applyInstitution(institution),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Icono', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            IconPicker(
              selected: _icon,
              selectedTint: Color(_color),
              onChanged: (value) => setState(() => _icon = value),
            ),
            const SizedBox(height: 16),
            Text('Color', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            ColorPickerRow(
              selected: _color,
              onChanged: (value) => setState(() => _color = value),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: Icon(_saving ? Icons.hourglass_top : Icons.check, color: scheme.onPrimary),
              label: Text(_isEditing ? 'Guardar cambios' : 'Crear cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}