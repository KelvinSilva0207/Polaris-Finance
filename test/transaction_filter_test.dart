import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/data/models/enums.dart';
import 'package:polaris_finance/shared/utils/transaction_filter.dart';

Transaction _tx({
  required String id,
  String type = 'expense',
  String? note,
  String? tags,
}) {
  return Transaction(
    id: id,
    accountId: 'a',
    type: type,
    amount: 10,
    currency: 'USD',
    date: DateTime(2026, 6, 1),
    note: note,
    tags: tags,
    feeAmount: 0,
  );
}

void main() {
  test('parseTags limpia espacios y vacíos', () {
    expect(parseTags('viaje, comida , ,trabajo'), ['viaje', 'comida', 'trabajo']);
    expect(parseTags(null), isEmpty);
    expect(parseTags(''), isEmpty);
  });

  test('allTags devuelve etiquetas únicas y ordenadas', () {
    final tags = allTags([
      _tx(id: '1', tags: 'viaje, Comida'),
      _tx(id: '2', tags: 'comida, auto'),
      _tx(id: '3'),
    ]);
    expect(tags, ['auto', 'Comida', 'viaje']);
  });

  test('filtra por texto de la nota', () {
    final result = filterTransactions(
      [
        _tx(id: '1', note: 'Mercado semanal'),
        _tx(id: '2', note: 'Gasolina'),
      ],
      query: 'mercado',
    );
    expect(result.map((t) => t.id), ['1']);
  });

  test('filtra por etiqueta (OR) y por tipo', () {
    final transactions = [
      _tx(id: '1', type: 'expense', tags: 'viaje'),
      _tx(id: '2', type: 'income', tags: 'trabajo'),
      _tx(id: '3', type: 'expense', tags: 'comida'),
    ];
    expect(
      filterTransactions(transactions, tags: {'viaje', 'comida'}).map((t) => t.id),
      ['1', '3'],
    );
    expect(
      filterTransactions(transactions, type: TransactionType.income).map((t) => t.id),
      ['2'],
    );
  });

  test('el texto coincide con etiquetas también', () {
    final result = filterTransactions(
      [_tx(id: '1', tags: 'vacaciones')],
      query: 'vac',
    );
    expect(result.map((t) => t.id), ['1']);
  });

  test('sin filtros devuelve todo', () {
    final transactions = [_tx(id: '1'), _tx(id: '2')];
    expect(filterTransactions(transactions).length, 2);
  });
}
