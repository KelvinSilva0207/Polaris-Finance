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

String _amountInput(double value) {
  return value % 1 == 0 ? value.toStringAsFixed(0) : value.toString();
}

double? _parseAmount(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  Future<void> _createGoal(BuildContext context, WidgetRef ref, List<Account> accounts) async {
    if (accounts.isEmpty) {
      _message(context, 'Crea una cuenta antes de definir una meta');
      return;
    }
    final draft = await _showGoalDialog(context, accounts: accounts);
    if (draft == null) return;
    await ref.read(appDatabaseProvider).addGoal(
          name: draft.name,
          targetAmount: draft.targetAmount,
          accountId: draft.accountId,
          deadline: draft.deadline,
        );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, SavingsGoal goal, List<Account> accounts) async {
    final draft = await _showGoalDialog(context, accounts: accounts, initial: goal);
    if (draft == null) return;
    await ref.read(appDatabaseProvider).updateGoal(
          goal.copyWith(
            name: draft.name,
            targetAmount: draft.targetAmount,
            accountId: draft.accountId,
            deadline: Value(draft.deadline),
          ),
        );
  }

  Future<void> _allocate(BuildContext context, WidgetRef ref, SavingsGoal goal, List<Account> accounts) async {
    final draft = await _showAllocateDialog(
      context,
      accounts: accounts,
      initialAccountId: goal.accountId,
    );
    if (draft == null) return;
    await ref.read(appDatabaseProvider).allocateToGoal(
          goal: goal,
          amount: draft.amount,
          fundingAccountId: draft.accountId,
        );
  }

  Future<void> _reduce(BuildContext context, WidgetRef ref, SavingsGoal goal) async {
    final amount = await _showAmountDialog(context, 'Reducir aporte');
    if (amount == null || amount <= 0) return;
    final remaining = goal.allocatedAmount - amount;
    final nuevo = remaining < 0 ? 0.0 : remaining;
    await ref.read(appDatabaseProvider).updateGoal(
          goal.copyWith(allocatedAmount: nuevo),
        );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, SavingsGoal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar meta'),
        content: Text('¿Eliminar "${goal.name}"?'),
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
      await ref.read(appDatabaseProvider).deleteGoal(goal.id);
    }
  }

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    final accounts = ref.watch(accountsProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Metas')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nueva meta',
        onPressed: () => _createGoal(context, ref, accounts),
        child: const Icon(Icons.add),
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (goals) {
          if (goals.isEmpty) {
            return _EmptyGoalsView(onPressed: () => _createGoal(context, ref, accounts));
          }
          final accountById = {for (final account in accounts) account.id: account};
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: goals.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final goal = goals[index];
              final account = accountById[goal.accountId];
              final currency = account?.currency ?? '';
              final percent = goal.targetAmount <= 0
                  ? 0.0
                  : (goal.allocatedAmount / goal.targetAmount).clamp(0.0, 1.0);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(goal.name, style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if (account != null) account.name,
                                    if (goal.deadline != null)
                                      'hasta ${DateFormat('dd/MM/yyyy').format(goal.deadline!)}',
                                  ].join(' · '),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (action) {
                              switch (action) {
                                case 'allocate':
                                  _allocate(context, ref, goal, accounts);
                                case 'reduce':
                                  _reduce(context, ref, goal);
                                case 'edit':
                                  _edit(context, ref, goal, accounts);
                                case 'delete':
                                  _delete(context, ref, goal);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'allocate', child: Text('Aportar')),
                              PopupMenuItem(value: 'reduce', child: Text('Reducir aporte')),
                              PopupMenuItem(value: 'edit', child: Text('Editar')),
                              PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '${_fmt(goal.allocatedAmount)} / ${_fmt(goal.targetAmount)} $currency',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const Spacer(),
                          if (goal.allocatedAmount >= goal.targetAmount)
                            const Icon(Icons.check_circle, size: 16, color: Color(0xFF66BB6A))
                          else
                            Text(
                              '${(percent * 100).round()}%',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
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

class _EmptyGoalsView extends StatelessWidget {
  const _EmptyGoalsView({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.savings_outlined, size: 72),
            const SizedBox(height: 16),
            Text('Aún no tienes metas', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Define objetivos y aporta desde tus cuentas.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.add),
              label: const Text('Crear meta'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalDraft {
  const _GoalDraft(this.name, this.targetAmount, this.accountId, this.deadline);

  final String name;
  final double targetAmount;
  final String accountId;
  final DateTime? deadline;
}

Future<_GoalDraft?> _showGoalDialog(
  BuildContext context, {
  required List<Account> accounts,
  SavingsGoal? initial,
}) {
  return showDialog<_GoalDraft>(
    context: context,
    builder: (context) => _GoalDialog(accounts: accounts, initial: initial),
  );
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({required this.accounts, this.initial});

  final List<Account> accounts;
  final SavingsGoal? initial;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late String? _accountId;
  late DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _targetController = TextEditingController(
      text: initial == null ? '' : _amountInput(initial.targetAmount),
    );
    _accountId = initial?.accountId ?? (widget.accounts.isNotEmpty ? widget.accounts.first.id : null);
    _deadline = initial?.deadline;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime(DateTime.now().year + 1),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  void _save() {
    final name = _nameController.text.trim();
    final target = _parseAmount(_targetController.text);
    if (name.isEmpty || target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa el nombre y un objetivo mayor a cero')),
      );
      return;
    }
    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una cuenta')),
      );
      return;
    }
    Navigator.of(context).pop(
      _GoalDraft(name, target, _accountId!, _deadline),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nueva meta' : 'Editar meta'),
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
            TextField(
              controller: _targetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Objetivo'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: const InputDecoration(labelText: 'Cuenta vinculada'),
              items: [
                for (final account in widget.accounts)
                  DropdownMenuItem(value: account.id, child: Text(account.name)),
              ],
              onChanged: (value) => setState(() => _accountId = value),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDeadline,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(
                      _deadline == null
                          ? 'Sin fecha límite'
                          : DateFormat('dd/MM/yyyy').format(_deadline!),
                    ),
                  ),
                ),
                if (_deadline != null)
                  IconButton(
                    tooltip: 'Quitar fecha',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _deadline = null),
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
          child: Text(widget.initial == null ? 'Crear meta' : 'Guardar'),
        ),
      ],
    );
  }
}

class _AllocateDraft {
  const _AllocateDraft(this.amount, this.accountId);

  final double amount;
  final String accountId;
}

Future<_AllocateDraft?> _showAllocateDialog(
  BuildContext context, {
  required List<Account> accounts,
  required String initialAccountId,
}) {
  return showDialog<_AllocateDraft>(
    context: context,
    builder: (context) => _AllocateDialog(
      accounts: accounts,
      initialAccountId: initialAccountId,
    ),
  );
}

class _AllocateDialog extends StatefulWidget {
  const _AllocateDialog({required this.accounts, required this.initialAccountId});

  final List<Account> accounts;
  final String initialAccountId;

  @override
  State<_AllocateDialog> createState() => _AllocateDialogState();
}

class _AllocateDialogState extends State<_AllocateDialog> {
  final TextEditingController _amountController = TextEditingController();
  late String? _accountId;

  @override
  void initState() {
    super.initState();
    _accountId = widget.initialAccountId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    final amount = _parseAmount(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un monto mayor a cero')),
      );
      return;
    }
    if (_accountId == null) return;
    Navigator.of(context).pop(_AllocateDraft(amount, _accountId!));
  }

  @override
  Widget build(BuildContext context) {
    final sameAccount = _accountId == widget.initialAccountId;
    return AlertDialog(
      title: const Text('Aportar a la meta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Monto'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _accountId,
            decoration: const InputDecoration(labelText: 'Cuenta de origen'),
            items: [
              for (final account in widget.accounts)
                DropdownMenuItem(value: account.id, child: Text(account.name)),
            ],
            onChanged: (value) => setState(() => _accountId = value),
          ),
          if (sameAccount) ...[
            const SizedBox(height: 12),
            const Text(
              'Asignación virtual: reserva saldo dentro de la misma cuenta sin mover fondos.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Aportar'),
        ),
      ],
    );
  }
}

Future<double?> _showAmountDialog(BuildContext context, String title) {
  final controller = TextEditingController();
  return showDialog<double>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Monto'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final value = _parseAmount(controller.text);
            Navigator.of(context).pop(value);
          },
          child: const Text('Aceptar'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}