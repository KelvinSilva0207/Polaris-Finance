import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_settings.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_providers.dart';
import '../../data/models/enums.dart';
import '../../shared/utils/transaction_math.dart';
import '../../shared/widgets/account_card.dart';
import '../../shared/widgets/amount_text.dart';
import '../accounts/account_form_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _openAccountEditor(BuildContext context, {Account? initial}) {
    Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (context) => AccountFormScreen(initial: initial),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final accountsAsync = ref.watch(accountsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final ratesAsync = ref.watch(ratesProvider);
    final hasAccounts = (accountsAsync.value ?? const []).isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Polaris Finance'),
        actions: [
          IconButton(
            tooltip: settings.hideBalances ? 'Mostrar montos' : 'Ocultar montos',
            icon: Icon(
              settings.hideBalances
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () => controller.setHideBalances(!settings.hideBalances),
          ),
        ],
      ),
      floatingActionButton: hasAccounts
          ? FloatingActionButton.extended(
              onPressed: () => _openAccountEditor(context),
              icon: const Icon(Icons.add),
              label: const Text('Cuenta'),
            )
          : null,
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (accounts) {
          if (accounts.isEmpty) return const _WelcomeView();
          return transactionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text(error.toString())),
            data: (transactions) {
              final balances = balancesOf(transactions, accounts: accounts);
              final singleCurrency = accounts.map((a) => a.currency).toSet().length == 1;
              final total = accounts.fold<double>(
                0,
                (sum, account) => sum + (balances[account.id] ?? 0),
              );
              final rate = latestReferenceRate(
                ratesAsync.value ?? const [],
                settings.referenceProvider,
              );
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SummaryCard(
                    total: total,
                    currency: singleCurrency ? accounts.first.currency : null,
                    rate: rate,
                    provider: settings.referenceProvider,
                    hidden: settings.hideBalances,
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('Cuentas', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(height: 8),
                  for (final account in accounts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AccountCard(
                        account: account,
                        balance: balances[account.id] ?? 0,
                        hidden: settings.hideBalances,
                        onTap: () => _openAccountEditor(context, initial: account),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.currency,
    required this.rate,
    required this.provider,
    required this.hidden,
  });

  final double total;
  final String? currency;
  final CurrencyRate? rate;
  final RateProvider provider;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo total',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            AmountText(
              total,
              currency: currency,
              hidden: hidden,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (currency == null) ...[
              const SizedBox(height: 4),
              Text(
                'Múltiples monedas: la tasa de referencia no suma directamente.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (rate != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.currency_exchange,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '1 USD = ${rate!.rate.toStringAsFixed(2)} VES · ${provider.label}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WelcomeView extends StatelessWidget {
  const _WelcomeView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.savings_outlined, size: 72, color: scheme.primary),
              const SizedBox(height: 16),
              Text(
                'Bienvenido a Polaris Finance',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Gestión financiera personal, minimalista y multimoneda.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<bool>(
                    builder: (context) => const AccountFormScreen(),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Crear mi primera cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}