import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_providers.dart';
import '../../data/models/enums.dart';

final _numberFormat = NumberFormat.decimalPatternDigits(
  locale: 'es',
  decimalDigits: 2,
);

String _fmt(double value) => _numberFormat.format(value);

double? _parseAmount(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

class LoanPaymentDraft {
  const LoanPaymentDraft(this.amount, this.date, this.note);

  final double amount;
  final DateTime date;
  final String note;
}

Future<LoanPaymentDraft?> showLoanPaymentDialog(
  BuildContext context, {
  required Loan loan,
  required String title,
}) {
  return showDialog<LoanPaymentDraft>(
    context: context,
    builder: (context) => _LoanPaymentDialog(title: title, currency: loan.currency),
  );
}

class _LoanPaymentDialog extends StatefulWidget {
  const _LoanPaymentDialog({required this.title, required this.currency});

  final String title;
  final String currency;

  @override
  State<_LoanPaymentDialog> createState() => _LoanPaymentDialogState();
}

class _LoanPaymentDialogState extends State<_LoanPaymentDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final amount = _parseAmount(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un monto mayor a cero')),
      );
      return;
    }
    final note = _noteController.text.trim();
    Navigator.of(context).pop(
      LoanPaymentDraft(amount, _date, note),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto',
              prefixText: '${widget.currency} ',
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
              IconButton(
                tooltip: 'Hoy',
                icon: const Icon(Icons.today_outlined, size: 18),
                onPressed: () => setState(() => _date = DateTime.now()),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class LoanDetailScreen extends ConsumerWidget {
  const LoanDetailScreen({super.key, required this.loan});

  final Loan loan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(loansProvider);
    final paymentsAsync = ref.watch(loanPaymentsProvider);
    final current = loansAsync.value == null
        ? loan
        : loansAsync.value!.where((l) => l.id == loan.id).toList().isEmpty
            ? loan
            : loansAsync.value!.firstWhere((l) => l.id == loan.id);

    final type = LoanType.fromStorage(current.type);
    final payments = (paymentsAsync.value ?? const []).where((p) => p.loanId == current.id).toList();
    final remaining = current.principal - current.paidAmount;

    return Scaffold(
      appBar: AppBar(title: Text(current.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final draft = await showLoanPaymentDialog(
            context,
            loan: current,
            title: type == LoanType.debt ? 'Registrar pago' : 'Registrar cobro',
          );
          if (draft == null) return;
          await ref.read(appDatabaseProvider).addLoanPayment(
                loan: current,
                amount: draft.amount,
                date: draft.date,
                note: draft.note,
              );
        },
        icon: const Icon(Icons.add),
        label: Text(type == LoanType.debt ? 'Pagar' : 'Cobrar'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(type.icon, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(type.label, style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      Chip(
                        label: Text(current.isActive ? 'Abierta' : 'Cerrada'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoRow('Original', '${_fmt(current.principal)} ${current.currency}'),
                  _InfoRow('Pagado', '${_fmt(current.paidAmount)} ${current.currency}'),
                  _InfoRow('Pendiente', '${_fmt(remaining < 0 ? 0 : remaining)} ${current.currency}'),
                  if (current.interestRate > 0) _InfoRow('Interés', '${_fmt(current.interestRate)}%'),
                  _InfoRow('Desde', DateFormat('dd/MM/yyyy').format(current.startDate)),
                  if (current.dueDate != null)
                    _InfoRow('Vence', DateFormat('dd/MM/yyyy').format(current.dueDate!)),
                  if (current.note != null && current.note!.isNotEmpty)
                    _InfoRow('Nota', current.note!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text('Pagos', style: Theme.of(context).textTheme.titleMedium),
          ),
          if (payments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Sin pagos registrados.'),
            )
          else
            for (final payment in payments)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text('${_fmt(payment.amount)} ${current.currency}'),
                  subtitle: Text(
                    [
                      DateFormat('dd/MM/yyyy').format(payment.date),
                      if (payment.note != null && payment.note!.isNotEmpty) payment.note!,
                    ].join(' · '),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}