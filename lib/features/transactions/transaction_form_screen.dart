import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_providers.dart';
import '../../data/models/enums.dart';
import '../../shared/utils/transaction_math.dart';
import '../categories/category_editor.dart';

String _amountInput(double value) {
  return value % 1 == 0 ? value.toStringAsFixed(0) : value.toString();
}

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key, this.initial});

  final Transaction? initial;

  @override
  ConsumerState<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  late TransactionType _type;
  String? _sourceAccountId;
  String? _destinationAccountId;
  String? _categoryId;
  late final TextEditingController _amountController;
  late final TextEditingController _tagsController;
  late final TextEditingController _noteController;
  late DateTime _date;
  String? _feeRuleId;
  bool _saving = false;

  bool get _isEditing => widget.initial != null;
  bool get _isTransfer => _type == TransactionType.transfer;

  static const _noneCategory = '_none';
  static const _newCategory = '_new';
  static const _noneFee = '_none';

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final type = initial == null
        ? TransactionType.expense
        : TransactionType.fromStorage(initial.type);
    _type = type;
    _sourceAccountId = initial?.accountId;
    _destinationAccountId = initial?.transferToId;
    _categoryId = (initial == null || type == TransactionType.transfer)
        ? null
        : initial.categoryId;
    _amountController = TextEditingController(
      text: initial == null ? '' : _amountInput(initial.amount),
    );
    _tagsController = TextEditingController(text: initial?.tags ?? '');
    _noteController = TextEditingController(text: initial?.note ?? '');
    _date = initial?.date ?? DateTime.now();
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() => setState(() {});

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _tagsController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onTypeChanged(Set<TransactionType> selection) {
    setState(() {
      _type = selection.first;
      _categoryId = null;
      _destinationAccountId = null;
    });
  }

  double? _parsedAmount() =>
      double.tryParse(_amountController.text.trim().replaceAll(',', '.'));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(_date.year, _date.month, _date.day, picked.hour, picked.minute);
      });
    }
  }

  Future<void> _onCategoryChanged(String? value) async {
    if (value == _newCategory) {
      final created = await showCategoryEditor(
        context,
        defaultIsIncome: _type == TransactionType.income,
      );
      if (created != null) setState(() => _categoryId = created.id.toString());
      return;
    }
    setState(() => _categoryId = value == _noneCategory ? null : value);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar movimiento'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(appDatabaseProvider).deleteTransaction(widget.initial!.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _save() async {
    final amount = _parsedAmount();
    if (amount == null || amount <= 0) {
      _showMessage('Escribe un monto válido mayor a cero');
      return;
    }
    final sourceId = _sourceAccountId;
    final destinationId = _isTransfer ? _destinationAccountId : null;
    if (sourceId == null) {
      _showMessage(_isTransfer
          ? 'Selecciona la cuenta de origen'
          : 'Selecciona la cuenta');
      return;
    }
    if (_isTransfer && destinationId == null) {
      _showMessage('Selecciona la cuenta de destino');
      return;
    }
    if (_isTransfer && destinationId == sourceId) {
      _showMessage('La cuenta de destino debe ser distinta');
      return;
    }

    final accounts = ref.read(accountsProvider).value ?? const [];
    final currency = accounts.firstWhere((a) => a.id == sourceId).currency;
    final categoryId = _isTransfer ? null : _categoryId;
    final tagsList = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    final tagsText = tagsList.join(', ');
    final noteText = _noteController.text.trim();

    final feeRules = ref.read(feeRulesProvider).value ?? const [];
    double feeAmount = 0;
    if (_feeRuleId != null) {
      for (final rule in feeRules) {
        if (rule.isActive && rule.id == _feeRuleId) {
          feeAmount = feeFor(rule, amount);
          break;
        }
      }
    }

    setState(() => _saving = true);
    final db = ref.read(appDatabaseProvider);
    try {
      if (_isEditing) {
        await db.updateTransaction(
          widget.initial!.copyWith(
            type: _type.name,
            accountId: sourceId,
            transferToId: Value(destinationId),
            categoryId: Value(categoryId),
            amount: amount,
            currency: currency,
            note: Value(noteText),
            tags: Value(tagsText),
            date: _date,
            feeAmount: feeAmount,
          ),
        );
      } else {
        await db.addTransaction(
          type: _type,
          accountId: sourceId,
          transferToId: destinationId,
          categoryId: categoryId,
          amount: amount,
          currency: currency,
          note: noteText,
          tags: tagsList,
          date: _date,
          feeAmount: feeAmount,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(error.toString());
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  List<Widget> _buildFeeSection() {
    final feeRules = ref.watch(feeRulesProvider).value ?? const [];
    final activeFeeRules = feeRules.where((r) => r.isActive).toList();
    if (activeFeeRules.isEmpty) return const [];
    FeeRule? selectedRule;
    if (_feeRuleId != null) {
      for (final rule in activeFeeRules) {
        if (rule.id == _feeRuleId) {
          selectedRule = rule;
          break;
        }
      }
    }
    final amount = _parsedAmount();
    final estimatedFee = selectedRule == null || amount == null
        ? null
        : feeFor(selectedRule, amount);
    return [
      DropdownButtonFormField<String>(
        key: ValueKey('fee-${_feeRuleId ?? 'none'}'),
        initialValue: _feeRuleId,
        decoration: const InputDecoration(labelText: 'Comisión'),
        hint: const Text('Sin comisión'),
        items: [
          const DropdownMenuItem(value: _noneFee, child: Text('Sin comisión')),
          for (final rule in activeFeeRules)
            DropdownMenuItem(value: rule.id, child: Text(rule.name)),
        ],
        onChanged: (value) => setState(() => _feeRuleId = value),
      ),
      if (estimatedFee != null)
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text(
            'Comisión estimada: $estimatedFee',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
    ];
  }

  Widget _buildConversionHint(Account? source) {
    final rates = ref.watch(ratesProvider).value ?? const [];
    final referenceProvider = ref.watch(appSettingsProvider).referenceProvider;
    final rate = latestReferenceRate(rates, referenceProvider);
    final amount = _parsedAmount();
    final vesPerUsd = rate?.rate;
    if (source == null || amount == null || vesPerUsd == null) {
      return const SizedBox.shrink();
    }
    final converted = convertedAmount(amount, source.currency, vesPerUsd);
    if (converted == null) return const SizedBox.shrink();
    final text = source.currency == 'VES'
        ? '≈ ${converted.toStringAsFixed(2)} USD (tasa ${vesPerUsd.toStringAsFixed(2)})'
        : '≈ ${converted.toStringAsFixed(2)} VES (tasa ${vesPerUsd.toStringAsFixed(2)})';
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar movimiento' : 'Nuevo movimiento'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (accounts) {
          if (accounts.isEmpty) return const _NoAccountsView();
          return _buildForm(context, accounts);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, List<Account> accounts) {
    final accountById = {for (final account in accounts) account.id: account};
    final source = _sourceAccountId == null ? null : accountById[_sourceAccountId!];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<TransactionType>(
            segments: const [
              ButtonSegment(
                value: TransactionType.income,
                label: Text('Ingreso'),
                icon: Icon(Icons.arrow_downward),
              ),
              ButtonSegment(
                value: TransactionType.expense,
                label: Text('Egreso'),
                icon: Icon(Icons.arrow_upward),
              ),
              ButtonSegment(
                value: TransactionType.transfer,
                label: Text('Transferencia'),
                icon: Icon(Icons.swap_horiz),
              ),
            ],
            selected: {_type},
            onSelectionChanged: _onTypeChanged,
            showSelectedIcon: false,
          ),
          const SizedBox(height: 20),
          if (_isTransfer)
            DropdownButtonFormField<String>(
              key: ValueKey('source-${_sourceAccountId ?? 'none'}'),
              initialValue: _sourceAccountId,
              decoration: const InputDecoration(labelText: 'Cuenta de origen'),
              items: [
                for (final account in accounts)
                  DropdownMenuItem(value: account.id, child: Text(account.name)),
              ],
              onChanged: (value) => setState(() => _sourceAccountId = value),
            )
          else
            DropdownButtonFormField<String>(
              key: ValueKey('source-${_sourceAccountId ?? 'none'}'),
              initialValue: _sourceAccountId,
              decoration: const InputDecoration(labelText: 'Cuenta'),
              items: [
                for (final account in accounts)
                  DropdownMenuItem(value: account.id, child: Text(account.name)),
              ],
              onChanged: (value) => setState(() => _sourceAccountId = value),
            ),
          if (_isTransfer) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('dest-${_destinationAccountId ?? 'none'}'),
              initialValue: _destinationAccountId,
              decoration: const InputDecoration(labelText: 'Cuenta de destino'),
              items: [
                for (final account in accounts)
                  DropdownMenuItem(value: account.id, child: Text(account.name)),
              ],
              onChanged: (value) => setState(() => _destinationAccountId = value),
            ),
          ],
          if (!_isTransfer) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('cat-${_type.name}-${_categoryId ?? 'none'}'),
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Categoría'),
              hint: const Text('Sin categoría'),
              items: [
                const DropdownMenuItem(value: _noneCategory, child: Text('Sin categoría')),
                for (final category in ref.read(categoriesProvider).value ?? const [])
                  if (category.isIncome == (_type == TransactionType.income))
                    DropdownMenuItem(value: category.id, child: Text(category.name)),
                const DropdownMenuItem(value: _newCategory, child: Text('Nueva categoría…')),
              ],
              onChanged: _onCategoryChanged,
            ),
          ],
          const SizedBox(height: 16),
          ..._buildFeeSection(),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto',
              prefixText: source == null ? null : '${source.currency} ',
            ),
          ),
          _buildConversionHint(source),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nota (opcional)'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tagsController,
            decoration: const InputDecoration(
              labelText: 'Etiquetas (opcional)',
              hintText: 'Comida, familia',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(DateFormat('dd/MM/yyyy').format(_date)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.access_time, size: 18),
                label: Text(DateFormat('HH:mm').format(_date)),
              ),
            ],
          ),
          if (_isTransfer) ...[
            const SizedBox(height: 12),
            const Text(
              'Descuenta el monto de origen y acredita el equivalente al destino.',
              style: TextStyle(fontSize: 12),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(_isEditing ? 'Guardar cambios' : 'Registrar'),
          ),
        ],
      ),
    );
  }
}

class _NoAccountsView extends StatelessWidget {
  const _NoAccountsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_balance_wallet_outlined, size: 64),
          const SizedBox(height: 16),
          const Text('Crea una cuenta antes de registrar movimientos'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.account_balance_wallet),
            label: const Text('Ir a cuentas'),
          ),
        ],
      ),
    );
  }
}