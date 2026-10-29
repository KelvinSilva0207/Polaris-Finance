import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database/app_database.dart';
import '../../data/database/database_providers.dart';
import '../../data/models/currencies.dart';
import '../../data/models/enums.dart';
import '../../shared/utils/amount_format.dart';
import '../../shared/utils/transaction_filter.dart';
import '../../shared/utils/transaction_math.dart';
import '../../shared/widgets/amount_text.dart';
import 'transaction_form_screen.dart';

(IconData, Color) _typeVisual(TransactionType type) {
  return switch (type) {
    TransactionType.income => (Icons.arrow_downward, const Color(0xFF66BB6A)),
    TransactionType.expense => (Icons.arrow_upward, const Color(0xFFEF5350)),
    TransactionType.transfer => (Icons.swap_horiz, const Color(0xFF4FC3F7)),
    TransactionType.pagoMovil => (Icons.phone_android, const Color(0xFF7E57C2)),
  };
}

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  final _selectedTags = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openEditor(BuildContext context, {Transaction? initial}) {
    Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (context) => TransactionFormScreen(initial: initial),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          final accountById = {
            for (final account in accounts) account.id: account,
          };
          final categoryById = {
            for (final category in categories) category.id: category,
          };
          final filtered = filterTransactions(
            transactions,
            query: _query,
            tags: _selectedTags,
          );
          final availableTags = allTags(transactions);
          if (transactions.isEmpty) {
            return const _EmptyTransactionsView();
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nota o etiqueta...',
                        prefixIcon: const Icon(Icons.search_outlined),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
                    ),
                    if (availableTags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: availableTags.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final tag = availableTags[index];
                            final selected = _selectedTags.contains(tag);
                            return FilterChip(
                              label: Text(tag),
                              selected: selected,
                              onSelected: (value) {
                                setState(() {
                                  if (value) {
                                    _selectedTags.add(tag);
                                  } else {
                                    _selectedTags.remove(tag);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No se encontraron movimientos',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final transaction = filtered[index];
                          final type = TransactionType.fromStorage(
                            transaction.type,
                          );
                          final (icon, color) = _typeVisual(type);
                          final account = accountById[transaction.accountId];
                          final category = categoryById[transaction.categoryId];
                          final destination = transaction.transferToId == null
                              ? null
                              : accountById[transaction.transferToId];
                          final tags = parseTags(transaction.tags);
                          return Card(
                            child: ListTile(
                              onTap: () =>
                                  _openEditor(context, initial: transaction),
                              leading: CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.16),
                                child: Icon(icon, color: color),
                              ),
                              title: Text(
                                type == TransactionType.transfer ||
                                        type == TransactionType.pagoMovil
                                    ? '${account?.name ?? 'Cuenta'} → ${destination?.name ?? '…'}'
                                    : category?.name ??
                                          account?.name ??
                                          'Sin categoría',
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${account?.name ?? 'Cuenta'} · ${DateFormat('dd/MM/yyyy HH:mm').format(transaction.date)}',
                                  ),
                                  if (transaction.feeAmount > 0)
                                    Text(
                                      'Comisión: ${formatVeNumber(transaction.feeAmount)} ${currencySymbol(transaction.currency)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  if (tags.isNotEmpty)
                                    Text(
                                      tags.map((t) => '#$t').join(' '),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                ],
                              ),
                              trailing: AmountText(
                                signedAmount(transaction),
                                currency: transaction.currency,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: color),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
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
            Text(
              'Aún no hay movimientos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
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
