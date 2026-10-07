import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/icons.dart';
import '../../core/providers.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_providers.dart';
import '../../data/models/currencies.dart';

final _numberFormat = NumberFormat.decimalPatternDigits(
  locale: 'es',
  decimalDigits: 2,
);

String _fmt(double value) => _numberFormat.format(value);

double? _parseAmount(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

class _BudgetDraft {
  const _BudgetDraft(this.categoryId, this.amount, this.currency);

  final String categoryId;
  final double amount;
  final String currency;
}

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final draft = await _showBudgetDialog(
      context,
      categories: ref.read(categoriesProvider).value ?? const [],
      existing: ref.read(budgetsProvider).value ?? const [],
    );
    if (draft == null) return;
    await ref.read(appDatabaseProvider).addBudget(
          categoryId: draft.categoryId,
          amount: draft.amount,
          currency: draft.currency,
        );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Budget budget) async {
    final draft = await _showBudgetDialog(
      context,
      initial: budget,
      categories: ref.read(categoriesProvider).value ?? const [],
      existing: ref.read(budgetsProvider).value ?? const [],
    );
    if (draft == null) return;
    await ref.read(appDatabaseProvider).updateBudget(
          budget.copyWith(
            categoryId: draft.categoryId,
            amount: draft.amount,
            currency: draft.currency,
          ),
        );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Budget budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar presupuesto'),
        content: const Text('¿Eliminar este presupuesto mensual?'),
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
      await ref.read(appDatabaseProvider).deleteBudget(budget.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final transactions = ref.watch(transactionsProvider).value ?? const [];

    final categoryById = {for (final category in categories) category.id: category};
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    return Scaffold(
      appBar: AppBar(title: const Text('Presupuestos')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuevo presupuesto',
        onPressed: () => _create(context, ref),
        child: const Icon(Icons.add),
      ),
      body: budgetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (budgets) {
          if (budgets.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.donut_large_outlined, size: 72),
                    const SizedBox(height: 16),
                    Text(
                      'Aún no hay presupuestos',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Define un límite mensual por categoría y sigue tu gasto en tiempo real.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _create(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Crear presupuesto'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: budgets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final budget = budgets[index];
              final category = categoryById[budget.categoryId];
              var spent = 0.0;
              for (final transaction in transactions) {
                if (transaction.categoryId != budget.categoryId) continue;
                if (transaction.currency != budget.currency) continue;
                if (transaction.date.isBefore(monthStart) ||
                    !transaction.date.isBefore(monthEnd)) {
                  continue;
                }
                if (transaction.type != 'expense') continue;
                spent += transaction.amount + transaction.feeAmount;
              }
              final ratio = budget.amount <= 0 ? 0.0 : spent / budget.amount;
              final color = ratio >= 1
                  ? const Color(0xFFEF5350)
                  : ratio >= 0.8
                      ? const Color(0xFFFFA726)
                      : const Color(0xFF66BB6A);
              final remaining = budget.amount - spent;
              final colorValue = Color(category?.colorValue ?? 0xFF78909C);
              return Card(
                child: ListTile(
                  onTap: () => _edit(context, ref, budget),
                  onLongPress: () => _delete(context, ref, budget),
                  leading: CircleAvatar(
                    backgroundColor: colorValue.withValues(alpha: 0.16),
                    child: Icon(
                      category == null
                          ? Icons.donut_large_outlined
                          : iconFromName(category.icon),
                      color: colorValue,
                    ),
                  ),
                  title: Text(category?.name ?? 'Categoría borrada'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        '${_fmt(spent)} de ${_fmt(budget.amount)} ${budget.currency}'
                        ' · ${remaining >= 0 ? 'quedan ${_fmt(remaining)}' : 'excedido ${_fmt(-remaining)}'}',
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio.clamp(0.0, 1.0),
                          minHeight: 8,
                          color: color,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _edit(context, ref, budget);
                      } else {
                        await _delete(context, ref, budget);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Eliminar'),
                          contentPadding: EdgeInsets.zero,
                        ),
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

Future<_BudgetDraft?> _showBudgetDialog(
  BuildContext context, {
  Budget? initial,
  required List<Category> categories,
  required List<Budget> existing,
}) async {
  final amountController = TextEditingController(
    text: initial == null
        ? ''
        : (initial.amount % 1 == 0
            ? initial.amount.toStringAsFixed(0)
            : initial.amount.toString()),
  );
  var categoryId = initial?.categoryId;
  var currency = initial?.currency ?? 'VES';

  final taken = {
    for (final budget in existing)
      if (budget.id != initial?.id) budget.categoryId,
  };
  final available = [
    for (final category in categories)
      if (!category.isIncome && (!taken.contains(category.id) || category.id == initial?.categoryId))
        category,
  ];

  return showDialog<_BudgetDraft>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final amount = _parseAmount(amountController.text);
        final canSave = categoryId != null && amount != null && amount > 0;
        return AlertDialog(
          title: Text(initial == null ? 'Nuevo presupuesto' : 'Editar presupuesto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (available.isEmpty)
                  const Text(
                    'Crea primero una categoría de egreso.',
                    textAlign: TextAlign.center,
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey('budget-cat-${categoryId ?? 'none'}'),
                    initialValue: categoryId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    hint: const Text('Elegir categoría'),
                    items: [
                      for (final category in available)
                        DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => categoryId = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Límite mensual',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 104,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('budget-currency-$currency'),
                          initialValue: currency,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Moneda'),
                          items: [
                            for (final code in commonCurrencies)
                              DropdownMenuItem(value: code, child: Text(code)),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => currency = value);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: canSave
                  ? () => Navigator.of(context).pop(
                        _BudgetDraft(categoryId!, amount, currency),
                      )
                  : null,
              child: Text(initial == null ? 'Crear' : 'Guardar'),
            ),
          ],
        );
      },
    ),
  );
}
