import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_providers.dart';
import '../../data/models/currencies.dart';
import '../../data/models/enums.dart';
import 'loan_detail_screen.dart';

final _numberFormat = NumberFormat.decimalPatternDigits(
  locale: 'es',
  decimalDigits: 2,
);

String _fmt(double value) => _numberFormat.format(value);

double? _parseAmount(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

class LoansScreen extends ConsumerWidget {
  const LoansScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final draft = await _showLoanEditor(context);
    if (draft == null) return;
    await ref.read(appDatabaseProvider).addLoan(
          name: draft.name,
          type: draft.type,
          currency: draft.currency,
          principal: draft.principal,
          interestRate: draft.interestRate,
          startDate: DateTime.now(),
          dueDate: draft.dueDate,
          note: draft.note,
        );
  }

  Future<void> _pay(BuildContext context, WidgetRef ref, Loan loan) async {
    final draft = await showLoanPaymentDialog(
      context,
      loan: loan,
      title: LoanType.fromStorage(loan.type) == LoanType.debt
          ? 'Registrar pago'
          : 'Registrar cobro',
    );
    if (draft == null) return;
    await ref.read(appDatabaseProvider).addLoanPayment(
          loan: loan,
          amount: draft.amount,
          date: draft.date,
          note: draft.note,
        );
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref, Loan loan) async {
    await ref.read(appDatabaseProvider).updateLoan(
          loan.copyWith(isActive: !loan.isActive),
        );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Loan loan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar préstamo'),
        content: Text('¿Eliminar "${loan.name}" y su historial de pagos?'),
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
      await ref.read(appDatabaseProvider).deleteLoan(loan.id);
    }
  }

  void _openDetail(BuildContext context, Loan loan) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => LoanDetailScreen(loan: loan),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(loansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Préstamos')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuevo préstamo',
        onPressed: () => _create(context, ref),
        child: const Icon(Icons.add),
      ),
      body: loansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (loans) {
          if (loans.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.request_quote_outlined, size: 72),
                    const SizedBox(height: 16),
                    Text('Aún no hay préstamos', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text(
                      'Deudas a pagar (Debo) y dinero que prestas (Me deben).',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _create(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Crear préstamo'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: loans.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final loan = loans[index];
              final type = LoanType.fromStorage(loan.type);
              final active = loan.isActive;
              final remaining = loan.principal - loan.paidAmount;
              final percent = loan.principal <= 0
                  ? 0.0
                  : (loan.paidAmount / loan.principal).clamp(0.0, 1.0);
              return Card(
                child: Column(
                  children: [
                    ListTile(
                      onTap: () => _openDetail(context, loan),
                      leading: CircleAvatar(
                        backgroundColor: type == LoanType.debt
                            ? const Color(0xFFEF5350).withValues(alpha: 0.16)
                            : const Color(0xFF66BB6A).withValues(alpha: 0.16),
                        child: Icon(
                          type.icon,
                          color: type == LoanType.debt
                              ? const Color(0xFFEF5350)
                              : const Color(0xFF66BB6A),
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(loan.name, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            type.label,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                      subtitle: Text(
                        [
                          loan.currency,
                          if (loan.dueDate != null)
                            'vence ${DateFormat('dd/MM/yyyy').format(loan.dueDate!)}',
                        ].join(' · '),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Queda ${_fmt(remaining < 0 ? 0 : remaining)}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            '${_fmt(loan.paidAmount)} pagado',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percent,
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          PopupMenuButton<String>(
                            onSelected: (action) {
                              switch (action) {
                                case 'pay':
                                  _pay(context, ref, loan);
                                case 'toggle':
                                  _toggleActive(context, ref, loan);
                                case 'delete':
                                  _delete(context, ref, loan);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'pay',
                                child: Text(
                                  type == LoanType.debt ? 'Registrar pago' : 'Registrar cobro',
                                ),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(active ? 'Marcar como cerrada' : 'Reabrir'),
                              ),
                              const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LoanDraft {
  const _LoanDraft(
    this.name,
    this.type,
    this.currency,
    this.principal,
    this.interestRate,
    this.dueDate,
    this.note,
  );

  final String name;
  final LoanType type;
  final String currency;
  final double principal;
  final double interestRate;
  final DateTime? dueDate;
  final String? note;
}

Future<_LoanDraft?> _showLoanEditor(BuildContext context) {
  return showDialog<_LoanDraft>(
    context: context,
    builder: (context) => _LoanEditorDialog(),
  );
}

class _LoanEditorDialog extends StatefulWidget {
  const _LoanEditorDialog();

  @override
  State<_LoanEditorDialog> createState() => _LoanEditorDialogState();
}

class _LoanEditorDialogState extends State<_LoanEditorDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _principalController = TextEditingController();
  final TextEditingController _interestController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _currency = 'VES';
  DateTime? _dueDate;
  LoanType _type = LoanType.debt;

  @override
  void dispose() {
    _nameController.dispose();
    _principalController.dispose();
    _interestController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime(DateTime.now().year + 1),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _save() {
    final name = _nameController.text.trim();
    final principal = _parseAmount(_principalController.text);
    final interest = _parseAmount(_interestController.text) ?? 0;
    if (name.isEmpty || principal == null || principal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa el nombre y un monto mayor a cero')),
      );
      return;
    }
    final note = _noteController.text.trim();
    Navigator.of(context).pop(
      _LoanDraft(name, _type, _currency, principal, interest, _dueDate, note.isEmpty ? null : note),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo préstamo'),
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
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<LoanType>(
                segments: [
                  for (final type in LoanType.values)
                    ButtonSegment(
                      value: type,
                      label: Text(type.label),
                      icon: Icon(type.icon, size: 18),
                    ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) => setState(() => _type = selection.first),
                showSelectedIcon: false,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('loan-currency-$_currency'),
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
              controller: _principalController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Monto original', prefixText: '$_currency '),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _interestController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Interés % (opcional)'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDueDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(
                      _dueDate == null
                          ? 'Sin fecha límite'
                          : DateFormat('dd/MM/yyyy').format(_dueDate!),
                    ),
                  ),
                ),
                if (_dueDate != null)
                  IconButton(
                    tooltip: 'Quitar fecha',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _dueDate = null),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nota (opcional)'),
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
          child: const Text('Crear'),
        ),
      ],
    );
  }
}