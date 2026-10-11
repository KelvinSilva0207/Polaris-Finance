import 'package:intl/intl.dart';
import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/data/models/enums.dart';

class CsvImportResult {
  const CsvImportResult({
    required this.imported,
    required this.skipped,
    required this.errors,
  });

  final int imported;
  final int skipped;
  final List<String> errors;
}

class _ImportRow {
  _ImportRow({
    required this.line,
    required this.fecha,
    required this.tipo,
    required this.monto,
    required this.moneda,
    required this.comision,
    required this.cuenta,
    required this.categoria,
    required this.nota,
    required this.etiquetas,
  });

  final int line;
  final String fecha;
  final String tipo;
  final String monto;
  final String moneda;
  final String comision;
  final String cuenta;
  final String categoria;
  final String nota;
  final String etiquetas;
}

List<String> _parseCsvLine(String line) {
  final fields = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  var index = 0;
  while (index < line.length) {
    final char = line[index];
    if (inQuotes) {
      if (char == '"') {
        if (index + 1 < line.length && line[index + 1] == '"') {
          buffer.write('"');
          index += 2;
        } else {
          inQuotes = false;
          index += 1;
        }
      } else {
        buffer.write(char);
        index += 1;
      }
    } else if (char == '"') {
      inQuotes = true;
      index += 1;
    } else if (char == ';') {
      fields.add(buffer.toString().trim());
      buffer.clear();
      index += 1;
    } else {
      buffer.write(char);
      index += 1;
    }
  }
  fields.add(buffer.toString().trim());
  return fields;
}

bool _isHeader(List<String> fields) {
  if (fields.isEmpty) return false;
  final first = fields.first.trim().toLowerCase();
  return first == 'fecha' || first.startsWith('fecha;');
}

List<_ImportRow> _parseRows(String csv) {
  final rows = <_ImportRow>[];
  final lines = csv.split('\n');
  for (var index = 0; index < lines.length; index++) {
    final raw = lines[index].trimRight();
    if (raw.trim().isEmpty) continue;
    final fields = _parseCsvLine(raw);
    if (_isHeader(fields)) continue;
    if (fields.length < 7) continue;
    rows.add(
      _ImportRow(
        line: index + 1,
        fecha: fields[0],
        tipo: fields[1],
        monto: fields[2],
        moneda: fields[3],
        comision: fields[4],
        cuenta: fields[5],
        categoria: fields[6],
        nota: fields.length > 7 ? fields[7] : '',
        etiquetas: fields.length > 8 ? fields[8] : '',
      ),
    );
  }
  return rows;
}

final _dateFormats = <DateFormat>[
  DateFormat('yyyy-MM-dd HH:mm'),
  DateFormat('yyyy-MM-dd H:mm'),
  DateFormat('yyyy-MM-dd'),
  DateFormat('dd/MM/yyyy HH:mm'),
  DateFormat('dd/MM/yyyy H:mm'),
  DateFormat('dd/MM/yyyy'),
];

DateTime? _dateOf(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  for (final format in _dateFormats) {
    try {
      return format.parse(value);
    } catch (_) {
      // prueba el siguiente formato
    }
  }
  return null;
}

TransactionType? _typeOf(String raw) {
  final value = raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-zñ ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  switch (value) {
    case 'ingreso':
    case 'income':
      return TransactionType.income;
    case 'egreso':
    case 'gasto':
    case 'expense':
      return TransactionType.expense;
    case 'transferencia':
    case 'transfer':
      return TransactionType.transfer;
    case 'pago movil':
    case 'pago_movil':
    case 'pagomovil':
      return TransactionType.pagoMovil;
  }
  return null;
}

double? _amountOf(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  final noSpaces = value.replaceAll(RegExp(r'\s'), '');
  final decimal = double.tryParse(noSpaces.replaceAll(',', '.'));
  if (decimal != null) return decimal;
  final european = noSpaces.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(european);
}

Future<CsvImportResult> importTransactionsCsv({
  required String csv,
  required AppDatabase db,
  required List<Account> accounts,
  required List<Category> categories,
}) async {
  final accountByName = {
    for (final account in accounts) account.name.trim().toLowerCase(): account,
  };
  final categoryByName = {
    for (final category in categories) category.name.trim().toLowerCase(): category,
  };
  final rows = _parseRows(csv);
  var imported = 0;
  var skipped = 0;
  final errors = <String>[];

  for (final row in rows) {
    final type = _typeOf(row.tipo);
    if (type == null) {
      errors.add('Línea ${row.line}: tipo no reconocido "${row.tipo}"');
      continue;
    }
    if (type == TransactionType.transfer) {
      skipped++;
      continue;
    }
    final account = accountByName[row.cuenta.trim().toLowerCase()];
    if (account == null) {
      errors.add('Línea ${row.line}: no existe la cuenta "${row.cuenta}"');
      continue;
    }
    Category? category;
    if (row.categoria.trim().isNotEmpty) {
      category = categoryByName[row.categoria.trim().toLowerCase()];
      if (category == null) {
        errors.add(
          'Línea ${row.line}: no existe la categoría "${row.categoria}"',
        );
        continue;
      }
    }
    final amount = _amountOf(row.monto);
    if (amount == null || amount <= 0) {
      errors.add('Línea ${row.line}: monto inválido "${row.monto}"');
      continue;
    }
    final date = _dateOf(row.fecha);
    if (date == null) {
      errors.add('Línea ${row.line}: fecha inválida "${row.fecha}"');
      continue;
    }
    final currency = row.moneda.trim().isEmpty
        ? account.currency
        : row.moneda.trim().toUpperCase();
    final feeAmount = _amountOf(row.comision) ?? 0;
    final tags = row.etiquetas
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    await db.addTransaction(
      accountId: account.id,
      type: type,
      categoryId: category?.id,
      amount: amount,
      currency: currency,
      date: date,
      note: row.nota.trim().isEmpty ? null : row.nota.trim(),
      tags: tags,
      feeAmount: feeAmount,
      creditedAmount: type == TransactionType.pagoMovil ? amount : null,
      creditedCurrency: type == TransactionType.pagoMovil ? currency : null,
    );
    imported++;
  }

  return CsvImportResult(imported: imported, skipped: skipped, errors: errors);
}