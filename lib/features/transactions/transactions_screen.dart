import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database/database_providers.dart';
import '../../data/models/enums.dart';
import '../../shared/utils/transaction_math.dart';
import '../../shared/widgets/amount_text.dart';

(IconData, Color) _typeVisual(TransactionType type) {
  return switch (type) {
    TransactionType.income => (Icons.arrow_downward, const Color(0xFF66BB6A)),
    TransactionType.expense => (Icons.arrow_upward, const Color(0xFFEF5350)),
    TransactionType.transfer => (Icons.swap_horiz, const Color(0xFF4FC3F7)),
  };
}

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos')),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swap_horiz, size: 72),
                    SizedBox(height: 16),
                    Text('Aún no hay movimientos'),
                    SizedBox(height: 8),
                    Text(
                      'Registrar ingresos y egresos llegará en la Fase 1.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          final accounts = accountsAsync.value ?? const [];
          final categories = categoriesAsync.value ?? const [];
          final accountById = {for (final account in accounts) account.id: account};
          final categoryById = {for (final category in categories) category.id: category};
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              final type = TransactionType.fromStorage(transaction.type);
              final (icon, color) = _typeVisual(type);
              final account = accountById[transaction.accountId];
              final category = categoryById[transaction.categoryId];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.16),
                    child: Icon(icon, color: color),
                  ),
                  title: Text(category?.name ?? account?.name ?? 'Sin categoría'),
                  subtitle: Text(
                    '${account?.name ?? 'Cuenta'} · ${DateFormat('dd/MM/yyyy HH:mm').format(transaction.date)}',
                  ),
                  trailing: AmountText(
                    signedAmount(transaction),
                    currency: transaction.currency,
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