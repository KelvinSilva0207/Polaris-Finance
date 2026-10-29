import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import 'monthly_report.dart';

String _money(double value) => NumberFormat('#,##0.00', 'es').format(value);

String _compact(double value) {
  if (value.abs() >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value.abs() >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return value.toStringAsFixed(0);
}

/// Arma el PDF de estadísticas: resumen del mes, dona de ingresos vs egresos,
/// categorías con porcentaje, comparativa de 6 meses, saldos y movimientos.
///
/// [months] debe venir ordenado del más antiguo al más reciente (el último es
/// el periodo del resumen).
Future<List<int>> buildStatisticsPdf({
  required List<MonthlyReportData> months,
  required List<Account> accounts,
  required Map<String, double> balances,
  required List<Transaction> transactions,
  required List<Category> categories,
}) async {
  final document = pw.Document();
  final current = months.last;
  final accountNames = {
    for (final account in accounts) account.id: account.name,
  };
  final categoryNames = {
    for (final category in categories) category.id: category.name,
  };
  final monthStart = DateTime(current.month.year, current.month.month, 1);
  final monthEnd = DateTime(current.month.year, current.month.month + 1, 1);
  final monthTx =
      transactions
          .where(
            (t) =>
                !t.date.isBefore(monthStart) &&
                t.date.isBefore(monthEnd) &&
                TransactionType.fromStorage(t.type) != TransactionType.transfer,
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  final totalExpense = current.expenseVes;
  final savings = current.incomeVes <= 0
      ? 0.0
      : (current.balanceVes / current.incomeVes) * 100;
  final maxTrend = months.fold<double>(
    0,
    (max, month) => [max, month.incomeVes, month.expenseVes].reduce(math.max),
  );

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 36, 32, 32),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Polaris Finance',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF1B2440),
                ),
              ),
              pw.Text('Estadísticas', style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Container(
            height: 2,
            decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF1B2440)),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Periodo: ${current.monthLabel} · Generado el '
            '${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Página ${context.pageNumber} de ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ),
      build: (context) => [
        pw.SizedBox(height: 12),
        pw.Text(
          'Resumen de ${current.monthLabel}',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(
              width: 168,
              height: 150,
              child: pw.Stack(
                alignment: pw.Alignment.center,
                children: [
                  pw.CustomPaint(
                    size: const PdfPoint(168, 150),
                    painter: (canvas, size) => _paintDonut(canvas, size, [
                      (
                        value: current.incomeVes,
                        color: PdfColor.fromInt(0xFF66BB6A),
                      ),
                      (
                        value: current.expenseVes,
                        color: PdfColor.fromInt(0xFFEF5350),
                      ),
                    ]),
                  ),
                  pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Balance',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        _compact(current.balanceVes),
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(
                            current.balanceVes >= 0 ? 0xFF2E7D32 : 0xFFC62828,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _summaryRow(
                    'Ingresos',
                    current.incomeVes,
                    PdfColor.fromInt(0xFF66BB6A),
                  ),
                  pw.SizedBox(height: 4),
                  _summaryRow(
                    'Egresos',
                    current.expenseVes,
                    PdfColor.fromInt(0xFFEF5350),
                  ),
                  pw.SizedBox(height: 4),
                  _summaryRow(
                    'Balance',
                    current.balanceVes,
                    PdfColor.fromInt(0xFF42A5F5),
                  ),
                  pw.SizedBox(height: 10),
                  _infoRow('Movimientos', '${current.transactionCount}'),
                  _infoRow(
                    'Ahorro',
                    current.incomeVes <= 0
                        ? '—'
                        : '${savings.toStringAsFixed(1)} %',
                  ),
                  if (current.feeVes > 0)
                    _infoRow('Comisiones', '${_money(current.feeVes)} Bs'),
                  if (current.skipped > 0)
                    _infoRow('Sin tasa', '${current.skipped} movimiento(s)'),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Egresos por categoría',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (current.expensesByCategory.isEmpty)
          pw.Text(
            'Sin egresos registrados en el periodo.',
            style: const pw.TextStyle(fontSize: 9),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: ['Categoría', 'Monto (Bs)', '% del total'],
            data: [
              for (final entry in current.expensesByCategory)
                [
                  entry.label,
                  _money(entry.total),
                  totalExpense <= 0
                      ? '0,0 %'
                      : '${(entry.total / totalExpense * 100).toStringAsFixed(1)} %',
                ],
              [
                'Total',
                _money(totalExpense),
                totalExpense <= 0 ? '0,0 %' : '100,0 %',
              ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
            },
          ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Últimos ${months.length} meses',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(2.2),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _cell('Mes', bold: true),
                _cell('Ingresos', bold: true, right: true),
                _cell('Egresos', bold: true, right: true),
                _cell('Balance', bold: true, right: true),
                _cell('Ingresos / egresos', bold: true),
              ],
            ),
            for (final month in months)
              pw.TableRow(
                children: [
                  _cell(month.monthLabel),
                  _cell(_money(month.incomeVes), right: true),
                  _cell(_money(month.expenseVes), right: true),
                  _cell(
                    _money(month.balanceVes),
                    right: true,
                    color: month.balanceVes >= 0
                        ? PdfColor.fromInt(0xFF2E7D32)
                        : PdfColor.fromInt(0xFFC62828),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _bar(
                          month.incomeVes,
                          maxTrend,
                          PdfColor.fromInt(0xFF66BB6A),
                        ),
                        pw.SizedBox(height: 2),
                        _bar(
                          month.expenseVes,
                          maxTrend,
                          PdfColor.fromInt(0xFFEF5350),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Saldos de cuentas',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Cuenta', 'Moneda', 'Saldo'],
          data: [
            for (final account in accounts)
              [
                account.name,
                account.currency,
                _money(balances[account.id] ?? 0),
              ],
          ],
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignments: {2: pw.Alignment.centerRight},
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Movimientos del periodo',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (monthTx.isEmpty)
          pw.Text(
            'Sin movimientos registrados.',
            style: const pw.TextStyle(fontSize: 9),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: [
              'Fecha',
              'Tipo',
              'Monto',
              'Comisión',
              'Mon.',
              'Cuenta',
              'Categoría',
              'Nota',
            ],
            data: [
              for (final transaction in monthTx.take(40))
                [
                  DateFormat('dd/MM').format(transaction.date),
                  TransactionType.fromStorage(transaction.type).label,
                  _money(transaction.amount),
                  transaction.feeAmount > 0
                      ? _money(transaction.feeAmount)
                      : '',
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
              fontSize: 8,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7),
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignments: {
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            columnWidths: {
              0: const pw.FixedColumnWidth(44),
              2: const pw.FixedColumnWidth(52),
              3: const pw.FixedColumnWidth(50),
              4: const pw.FixedColumnWidth(32),
            },
          ),
        if (monthTx.length > 40)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              'Se muestran los 40 movimientos más recientes de '
              '${monthTx.length}.',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
      ],
    ),
  );
  return document.save();
}

pw.Widget _cell(
  String text, {
  bool bold = false,
  bool right = false,
  PdfColor? color,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: pw.Text(
      text,
      textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      ),
    ),
  );
}

pw.Widget _bar(double value, double max, PdfColor color) {
  final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
  return pw.Container(
    height: 4,
    width: 110,
    alignment: pw.Alignment.centerLeft,
    decoration: pw.BoxDecoration(color: PdfColors.grey300),
    child: pw.Container(
      height: 4,
      width: 110 * fraction,
      decoration: pw.BoxDecoration(color: color),
    ),
  );
}

pw.Widget _summaryRow(String label, double value, PdfColor color) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Row(
        children: [
          pw.Container(width: 8, height: 8, color: color),
          pw.SizedBox(width: 6),
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
      pw.Text(
        '${_money(value)} Bs',
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    ],
  );
}

pw.Widget _infoRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
  );
}

/// Dibuja una dona con los sectores indicados. Se usan polígonos porque el
/// paquete pdf no expone arcos de relleno.
void _paintDonut(
  PdfGraphics canvas,
  PdfPoint size,
  List<({double value, PdfColor color})> slices,
) {
  final center = PdfPoint(size.x / 2, size.y / 2);
  final radius = math.min(size.x, size.y) / 2 - 2;
  final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);
  if (total <= 0) {
    canvas.setColor(PdfColor.fromInt(0xFFE0E0E0));
    canvas.drawEllipse(center.x, center.y, radius, radius);
    canvas.fillPath();
    return;
  }
  var start = -math.pi / 2;
  for (final slice in slices) {
    if (slice.value <= 0) continue;
    final sweep = slice.value / total * 2 * math.pi;
    canvas.setColor(slice.color);
    canvas.moveTo(center.x, center.y);
    final steps = math.max(2, (sweep / (2 * math.pi) * 64).ceil());
    for (var step = 0; step <= steps; step++) {
      final angle = start + sweep * step / steps;
      canvas.lineTo(
        center.x + radius * math.cos(angle),
        center.y - radius * math.sin(angle),
      );
    }
    canvas.closePath();
    canvas.fillPath();
    start += sweep;
  }
  canvas.setColor(PdfColors.white);
  final inner = radius * 0.62;
  canvas.moveTo(center.x, center.y - inner);
  canvas.curveTo(
    center.x + inner * 0.551784,
    center.y - inner,
    center.x + inner,
    center.y - inner * 0.551784,
    center.x + inner,
    center.y,
  );
  canvas.curveTo(
    center.x + inner,
    center.y + inner * 0.551784,
    center.x + inner * 0.551784,
    center.y + inner,
    center.x,
    center.y + inner,
  );
  canvas.curveTo(
    center.x - inner * 0.551784,
    center.y + inner,
    center.x - inner,
    center.y + inner * 0.551784,
    center.x - inner,
    center.y,
  );
  canvas.curveTo(
    center.x - inner,
    center.y - inner * 0.551784,
    center.x - inner * 0.551784,
    center.y - inner,
    center.x,
    center.y - inner,
  );
  canvas.closePath();
  canvas.fillPath();
}
