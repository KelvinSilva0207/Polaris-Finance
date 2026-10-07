import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons.dart';
import '../../core/providers.dart';
import '../../data/database/app_database.dart';
import '../../data/database/seeds.dart';
import '../../data/models/currencies.dart';
import '../../data/models/enums.dart';
import '../../shared/utils/transaction_math.dart';
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
  late final TextEditingController _balanceController;
  late AccountType _type;
  late String _currency;
  late int _color;
  late String _icon;
  bool _saving = false;
  bool _balanceTouched = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _balanceController = TextEditingController();
    _type = AccountType.fromStorage(initial?.type);
    _currency = initial?.currency ?? 'VES';
    _color = initial?.colorValue ?? 0xFF9C6BFF;
    _icon = initial?.icon ?? 'account_balance';
    if (initial != null) {
      _loadCurrentBalance(initial);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentBalance(Account account) async {
    final db = ref.read(appDatabaseProvider);
    final transactions = await db.select(db.transactions).get();
    final delta = balancesOf(transactions)[account.id] ?? 0;
    if (!mounted || _balanceTouched) return;
    setState(() {
      _balanceController.text = _formatAmount(account.openingBalance + delta);
    });
  }

  String _formatAmount(double value) {
    final rounded = double.parse(value.toStringAsFixed(2));
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toString();
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
    final rawBalance = _balanceController.text.trim().replaceAll(',', '.');
    double? targetBalance;
    if (rawBalance.isNotEmpty) {
      targetBalance = double.tryParse(rawBalance);
      if (targetBalance == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saldo no válido: usa números (puede ser negativo)'),
          ),
        );
        return;
      }
    }
    setState(() => _saving = true);
    final db = ref.read(appDatabaseProvider);
    try {
      if (_isEditing) {
        var updated = widget.initial!.copyWith(
          name: name,
          type: _type.name,
          currency: _currency,
          colorValue: _color,
          icon: _icon,
        );
        if (targetBalance != null) {
          final transactions = await db.select(db.transactions).get();
          final delta = balancesOf(transactions)[widget.initial!.id] ?? 0;
          updated = updated.copyWith(
            openingBalance: targetBalance - delta,
          );
        }
        await db.updateAccount(updated);
      } else {
        await db.addAccount(
          name: name,
          type: _type,
          currency: _currency,
          colorValue: _color,
          icon: _icon,
          openingBalance: targetBalance ?? 0,
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
            const SizedBox(height: 16),
            TextField(
              controller: _balanceController,
              onChanged: (_) => _balanceTouched = true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [AmountInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Saldo actual',
                helperText:
                    'Solo números; puede ser negativo. No se registra como ingreso',
              ),
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

class AmountInputFormatter extends TextInputFormatter {
  static final RegExp _valid = RegExp(r'^-?\d*([.,]\d*)?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (_valid.hasMatch(newValue.text)) return newValue;
    return oldValue;
  }
}