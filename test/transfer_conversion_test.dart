import 'package:flutter_test/flutter_test.dart';

import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/data/models/enums.dart';
import 'package:polaris_finance/shared/utils/transaction_math.dart';

void main() {
  test('Transferencia entre monedas acredita el equivalente (credAmount)',
      () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final ves = await db.addAccount(
      name: 'Banesco',
      type: AccountType.bank,
      currency: 'VES',
      colorValue: 0xFF42A5F5,
      openingBalance: 100000,
    );
    final usd = await db.addAccount(
      name: 'Dólares',
      type: AccountType.bank,
      currency: 'USD',
      colorValue: 0xFF42A5F5,
      openingBalance: 100,
    );
    const amount = 9000.0;
    const credited = 100.0; // 9000 VES ÷ 90
    await db.addTransaction(
      accountId: ves.id,
      transferToId: usd.id,
      type: TransactionType.transfer,
      amount: amount,
      currency: 'VES',
      date: DateTime(2026, 10, 9),
      creditedAmount: credited,
      creditedCurrency: 'USD',
    );

    final txs = await db.select(db.transactions).get();
    final balances = balancesOf(txs, accounts: [ves, usd]);
    expect(balances[ves.id], closeTo(100000 - amount, 0.001));
    expect(balances[usd.id], closeTo(100 + credited, 0.001));
    expect(txs.single.credAmount, credited);
    expect(txs.single.credCurrency, 'USD');
  });

  test('Transferencia legada sin credAmount acredita el monto bruto', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final a = await db.addAccount(
      name: 'A',
      type: AccountType.bank,
      currency: 'VES',
      colorValue: 0xFF42A5F5,
      openingBalance: 1000,
    );
    final b = await db.addAccount(
      name: 'B',
      type: AccountType.bank,
      currency: 'VES',
      colorValue: 0xFF42A5F5,
      openingBalance: 500,
    );
    await db.addTransaction(
      accountId: a.id,
      transferToId: b.id,
      type: TransactionType.transfer,
      amount: 300,
      currency: 'VES',
      date: DateTime(2026, 10, 9),
    );

    final txs = await db.select(db.transactions).get();
    final balances = balancesOf(txs, accounts: [a, b]);
    expect(balances[a.id], 700);
    expect(balances[b.id], 800);
  });

  test('usdEquivalent y totalUsdOf convierten solo VES/USD', () {
    expect(usdEquivalent(9000, 'VES', 90), closeTo(100, 0.001));
    expect(usdEquivalent(50, 'USD', 90), 50);
    expect(usdEquivalent(10, 'EUR', 90), isNull);
  });

  test('totalUsdOf suma cuentas convertibles y reporta excluidas', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final ves = await db.addAccount(
      name: 'VES',
      type: AccountType.bank,
      currency: 'VES',
      colorValue: 1,
      openingBalance: 900,
    );
    final usd = await db.addAccount(
      name: 'USD',
      type: AccountType.bank,
      currency: 'USD',
      colorValue: 2,
      openingBalance: 10,
    );
    final eur = await db.addAccount(
      name: 'EUR',
      type: AccountType.bank,
      currency: 'EUR',
      colorValue: 3,
      openingBalance: 5,
    );
    const rate = 90.0;
    final result = totalUsdOf({ves.id: 900, usd.id: 10, eur.id: 5}, [ves, usd, eur], rate);
    expect(result, isNotNull);
    expect(result!.total, closeTo(20, 0.001)); // 900/90 + 10
    expect(result.currenciesExcluded, {'EUR'});
  });
}