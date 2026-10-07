import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database/app_database.dart';
import '../../data/database/database_providers.dart';
import '../../data/models/enums.dart';
import '../../shared/utils/transaction_math.dart';
import '../../shared/widgets/amount_text.dart';
import 'transaction_form_screen.dart';

(IconData, Color) _typeVisual(TransactionType type) {
  return switch (type) {
    TransactionType.income => (Icons.arrow_downward, const Color(0xFF66BB6A)),
    TransactionType.expense => (Icons.arrow_upward, const Color(0xFFEF5350)),
    TransactionType.transfer => (Icons.swap_horiz, const Color(0xFF4FC3F7)),
  };
}

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  void _openEditor(BuildContext context, {Transaction? initial}) {
    Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (context) => TransactionFormScreen(initial: initial),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        tooltip: 'Nuevo movimiento',
        child: const Icon(Icons.add),
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (transactions) {
          if (transactions.isEmpty) {
            return const _EmptyTransactionsView();
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
              final destination = transaction.transferToId == null
                  ? null
                  : accountById[transaction.transferToId];
              return Card(
                child: ListTile(
                  onTap: () => _openEditor(context, initial: transaction),
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.16),
                    child: Icon(icon, color: color),
                  ),
                  title: Text(
                    type == TransactionType.transfer
                        ? '${account?.name ?? 'Cuenta'} → ${destination?.name ?? '…'}'
                        : category?.name ?? account?.name ?? 'Sin categoría',
                  ),
                  subtitle: Text(
                    '${account?.name ?? 'Cuenta'} · ${DateFormat('dd/MM/yyyy HH:mm').format(transaction.date)}',
                  ),
                  trailing: AmountText(
                    signedAmount(transaction),
                    currency: transaction.currency,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
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

class _EmptyTransactionsView extends StatelessWidget {
  const _EmptyTransactionsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.swap_horiz, size: 72),
            const SizedBox(height: 16),
            Text('Aún no hay movimientos', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Registra ingresos, egresos y transferencias entre cuentas.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<bool>(
                  builder: (context) => const TransactionFormScreen(),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo movimiento'),
            ),
          ],
        ),
      ),
    );
  }
}