import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/providers.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_providers.dart';
import '../../data/models/enums.dart';
import 'file_saver.dart';

String _timestamp() {
  final now = DateTime.now();
  final stamp = DateFormat('yyyyMMdd_HHmmss').format(now);
  return stamp;
}

double _round(double value) => double.parse(value.toStringAsFixed(2));

String _csvField(String value) {
  if (value.contains(';') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String buildTransactionsCsv(
  List<Transaction> transactions,
  List<Account> accounts,
  List<Category> categories,
) {
  final accountNames = {for (final account in accounts) account.id: account.name};
  final categoryNames = {for (final category in categories) category.id: category.name};
  final sorted = [...transactions]
    ..sort((a, b) => b.date.compareTo(a.date));
  final buffer = StringBuffer()
    ..writeln('fecha;tipo;monto;moneda;comision;cuenta;categoria;nota;etiquetas');
  for (final transaction in sorted) {
    buffer.writeln(
      [
        DateFormat('yyyy-MM-dd HH:mm').format(transaction.date),
        TransactionType.fromStorage(transaction.type).label,
        _round(transaction.amount).toString(),
        transaction.currency,
        _round(transaction.feeAmount).toString(),
        accountNames[transaction.accountId] ?? '',
        transaction.categoryId == null
            ? ''
            : (categoryNames[transaction.categoryId] ?? ''),
        _csvField(transaction.note ?? ''),
        _csvField(transaction.tags ?? ''),
      ].join(';'),
    );
  }
  return buffer.toString();
}

String buildExportJson({
  required List<Account> accounts,
  required List<Category> categories,
  required List<Transaction> transactions,
  required List<FeeRule> feeRules,
  required List<SavingsGoal> goals,
  required List<RecurringService> services,
  required List<CurrencyRate> rates,
  required List<Loan> loans,
  required List<LoanPayment> loanPayments,
  required List<Budget> budgets,
}) {
  return const JsonEncoder.withIndent('  ').convert({
    'exportedAt': DateTime.now().toIso8601String(),
    'app': 'Polaris Finance',
    'accounts': accounts.map((account) => account.toJson()).toList(),
    'categories': categories.map((category) => category.toJson()).toList(),
    'transactions': transactions.map((transaction) => transaction.toJson()).toList(),
    'feeRules': feeRules.map((rule) => rule.toJson()).toList(),
    'goals': goals.map((goal) => goal.toJson()).toList(),
    'services': services.map((service) => service.toJson()).toList(),
    'rates': rates.map((rate) => rate.toJson()).toList(),
    'loans': loans.map((loan) => loan.toJson()).toList(),
    'loanPayments': loanPayments.map((payment) => payment.toJson()).toList(),
    'budgets': budgets.map((budget) => budget.toJson()).toList(),
  });
}

Future<List<int>> buildExportPdf({
  required List<Transaction> transactions,
  required List<Account> accounts,
  required List<Category> categories,
}) async {
  final document = pw.Document();
  final accountNames = {for (final account in accounts) account.id: account.name};
  final categoryNames = {for (final category in categories) category.id: category.name};
  final sorted = [...transactions]
    ..sort((a, b) => b.date.compareTo(a.date));

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Polaris Finance',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Movimientos exportados el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
      build: (context) => [
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: ['Fecha', 'Tipo', 'Monto', 'Moneda', 'Cuenta', 'Categoría', 'Nota'],
          data: [
            for (final transaction in sorted)
              [
                DateFormat('dd/MM/yyyy').format(transaction.date),
                TransactionType.fromStorage(transaction.type).label,
                _round(transaction.amount).toString(),
                transaction.currency,
                accountNames[transaction.accountId] ?? '',
                transaction.categoryId == null
                    ? ''
                    : (categoryNames[transaction.categoryId] ?? ''),
                transaction.note ?? '',
              ],
          ],
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: pw.BoxDecoration(
            color: PdfColors.grey300,
          ),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            2: pw.Alignment.centerRight,
          },
        ),
      ],
    ),
  );
  return document.save();
}

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _busy = false;

  Future<void> _run(Future<String> Function() action, {String? copyText}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final saved = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Guardado: $saved'),
          action: copyText == null
              ? null
              : SnackBarAction(
                  label: 'Copiar',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: copyText));
                  },
                ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _exportCsv() async {
    final csv = buildTransactionsCsv(
      ref.read(transactionsProvider).value ?? const [],
      ref.read(accountsProvider).value ?? const [],
      ref.read(categoriesProvider).value ?? const [],
    );
    return saveBackupFile(
      'polaris_movimientos_${_timestamp()}.csv',
      const Utf8Encoder().convert(csv),
    );
  }

  Future<String> _exportJson() async {
    final json = buildExportJson(
      accounts: ref.read(accountsProvider).value ?? const [],
      categories: ref.read(categoriesProvider).value ?? const [],
      transactions: ref.read(transactionsProvider).value ?? const [],
      feeRules: ref.read(feeRulesProvider).value ?? const [],
      goals: ref.read(goalsProvider).value ?? const [],
      services: ref.read(servicesProvider).value ?? const [],
      rates: ref.read(ratesProvider).value ?? const [],
      loans: ref.read(loansProvider).value ?? const [],
      loanPayments: ref.read(loanPaymentsProvider).value ?? const [],
      budgets: ref.read(budgetsProvider).value ?? const [],
    );
    return saveBackupFile(
      'polaris_respaldo_${_timestamp()}.json',
      const Utf8Encoder().convert(json),
    );
  }

  String _backupText() {
    return buildExportJson(
      accounts: ref.read(accountsProvider).value ?? const [],
      categories: ref.read(categoriesProvider).value ?? const [],
      transactions: ref.read(transactionsProvider).value ?? const [],
      feeRules: ref.read(feeRulesProvider).value ?? const [],
      goals: ref.read(goalsProvider).value ?? const [],
      services: ref.read(servicesProvider).value ?? const [],
      rates: ref.read(ratesProvider).value ?? const [],
      loans: ref.read(loansProvider).value ?? const [],
      loanPayments: ref.read(loanPaymentsProvider).value ?? const [],
      budgets: ref.read(budgetsProvider).value ?? const [],
    );
  }

  Future<void> _copyBackup() async {
    final text = _backupText();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Respaldo copiado al portapapeles')),
    );
  }

  Future<void> _restoreFromClipboard() async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(
          text: '',
        );
        return AlertDialog(
          title: const Text('Restaurar respaldo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pega aquí el contenido del respaldo JSON. Esto reemplaza todos los datos actuales.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 8,
                decoration:
                    const InputDecoration(hintText: '{"app": "Polaris Finance", ...}'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Restaurar'),
            ),
          ],
        );
      },
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final decoded = jsonDecode(text) as Map<String, dynamic>;
      await ref.read(appDatabaseProvider).restoreBackup(decoded);
      messenger.showSnackBar(
        const SnackBar(content: Text('Respaldo restaurado')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Respaldo inválido: $error')),
      );
    }
  }

  Future<String> _exportPdf() async {
    final bytes = await buildExportPdf(
      transactions: ref.read(transactionsProvider).value ?? const [],
      accounts: ref.read(accountsProvider).value ?? const [],
      categories: ref.read(categoriesProvider).value ?? const [],
    );
    return saveBackupFile('polaris_movimientos_${_timestamp()}.pdf', bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exportar datos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Los archivos se guardan en los documentos de la aplicación.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Movimientos (CSV)', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  const Text('Una fila por movimiento, separador ";" para Excel.'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _run(_exportCsv),
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Guardar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Respaldo completo (JSON)', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  const Text(
                    'Todas las cuentas, categorías, movimientos, metas, préstamos, servicios y tasas.',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _run(_exportJson),
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Guardar'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _copyBackup,
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copiar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estado de cuentas (PDF)', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  const Text('Listado de todos los movimientos en formato imprimible.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _run(_exportPdf),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Guardar'),
                  ),
                ],
              ),
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Restaurar respaldo', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  const Text(
                    'Reemplaza todos los datos actuales con los de un respaldo JSON.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _restoreFromClipboard,
                    icon: const Icon(Icons.restore_outlined),
                    label: const Text('Pegar y restaurar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
