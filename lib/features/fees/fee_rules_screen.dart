import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_providers.dart';

final _numberFormat = NumberFormat.decimalPatternDigits(
  locale: 'es',
  decimalDigits: 2,
);

String _fmt(double value) => _numberFormat.format(value);

double? _parseAmount(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

class FeeRulesScreen extends ConsumerWidget {
  const FeeRulesScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final draft = await _showFeeEditor(context);
    if (draft == null) return;
    await ref.read(appDatabaseProvider).addFeeRule(
          name: draft.name,
          fixedAmount: draft.fixed,
          percent: draft.percent,
          minAmount: draft.minimum,
          maxAmount: draft.maximum,
          isActive: draft.isActive,
        );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, FeeRule rule) async {
    final draft = await _showFeeEditor(context, initial: rule);
    if (draft == null) return;
    await ref.read(appDatabaseProvider).updateFeeRule(
          rule.copyWith(
            name: draft.name,
            fixedAmount: draft.fixed,
            percent: draft.percent,
            minAmount: Value(draft.minimum),
            maxAmount: Value(draft.maximum),
            isActive: draft.isActive,
          ),
        );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, FeeRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar regla'),
        content: Text('¿Eliminar "${rule.name}"?'),
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
    if (confirmed == true) {
      await ref.read(appDatabaseProvider).deleteFeeRule(rule.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(feeRulesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Comisiones')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nueva regla',
        onPressed: () => _create(context, ref),
        child: const Icon(Icons.add),
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (rules) {
          if (rules.isEmpty) {
            return const Center(child: Text('Aún no hay reglas de comisión.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rules.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final rule = rules[index];
              final description = [
                if (rule.fixedAmount > 0) '${_fmt(rule.fixedAmount)} fijo',
                if (rule.percent > 0) '${_fmt(rule.percent)}%',
                if (rule.minAmount != null) 'mín ${_fmt(rule.minAmount!)}',
                if (rule.maxAmount != null) 'máx ${_fmt(rule.maxAmount!)}',
              ].join(' + ');
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      rule.isActive ? Icons.price_change_outlined : Icons.lock_outline,
                    ),
                  ),
                  title: Text(rule.name),
                  subtitle: Text(description.isEmpty ? 'Sin montos' : description),
                  isThreeLine: false,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: rule.isActive,
                        onChanged: (value) async {
                          await ref.read(appDatabaseProvider).updateFeeRule(
                                rule.copyWith(isActive: value),
                              );
                        },
                      ),
                      PopupMenuButton<String>(
                        onSelected: (action) {
                          switch (action) {
                            case 'edit':
                              _edit(context, ref, rule);
                            case 'delete':
                              _delete(context, ref, rule);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Editar')),
                          PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FeeDraft {
  const _FeeDraft(this.name, this.fixed, this.percent, this.minimum, this.maximum, this.isActive);

  final String name;
  final double fixed;
  final double percent;
  final double? minimum;
  final double? maximum;
  final bool isActive;
}

Future<_FeeDraft?> _showFeeEditor(BuildContext context, {FeeRule? initial}) {
  return showDialog<_FeeDraft>(
    context: context,
    builder: (context) => _FeeEditorDialog(initial: initial),
  );
}

class _FeeEditorDialog extends StatefulWidget {
  const _FeeEditorDialog({this.initial});

  final FeeRule? initial;

  @override
  State<_FeeEditorDialog> createState() => _FeeEditorDialogState();
}

class _FeeEditorDialogState extends State<_FeeEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _fixedController;
  late final TextEditingController _percentController;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _fixedController = TextEditingController(text: _field(initial?.fixedAmount));
    _percentController = TextEditingController(text: _field(initial?.percent));
    _minController = TextEditingController(
      text: initial?.minAmount == null ? '' : _field(initial!.minAmount),
    );
    _maxController = TextEditingController(
      text: initial?.maxAmount == null ? '' : _field(initial!.maxAmount),
    );
    _isActive = widget.initial?.isActive ?? true;
  }

  static String _field(double? value) {
    if (value == null) return '';
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fixedController.dispose();
    _percentController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final fixed = _parseAmount(_fixedController.text) ?? 0;
    final percent = _parseAmount(_percentController.text) ?? 0;
    final minValue = _parseAmount(_minController.text);
    final maxValue = _parseAmount(_maxController.text);
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un nombre para la regla')),
      );
      return;
    }
    Navigator.of(context).pop(
      _FeeDraft(name, fixed, percent, minValue, maxValue, _isActive),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nueva regla' : 'Editar regla'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _fixedController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Fijo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _percentController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '% sobre monto'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Mínimo (opc.)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Máximo (opc.)'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(widget.initial == null ? 'Crear regla' : 'Guardar'),
        ),
      ],
    );
  }
}