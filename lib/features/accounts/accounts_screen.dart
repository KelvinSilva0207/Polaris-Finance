import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_providers.dart';
import '../../shared/utils/transaction_math.dart';
import '../../shared/widgets/account_card.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cuentas')),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (accounts) {
          if (accounts.isEmpty) {
            return const Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 72),
                    SizedBox(height: 16),
                    Text('Aún no tienes cuentas'),
                    SizedBox(height: 8),
                    Text(
                      'Bancos, billeteras y efectivo: llegan en la Fase 1.',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    Chip(label: Text('Fase 1')),
                  ],
                ),
              ),
            );
          }
          final balances = balancesOf(transactionsAsync.value ?? const []);
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: accounts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => AccountCard(
              account: accounts[index],
              balance: balances[accounts[index].id] ?? 0,
            ),
          );
        },
      ),
    );
  }
}