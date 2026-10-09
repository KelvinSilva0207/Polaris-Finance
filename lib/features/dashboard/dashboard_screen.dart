import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_settings.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_providers.dart';
import '../../data/models/enums.dart';
import '../../shared/utils/amount_format.dart';
import '../../shared/utils/transaction_math.dart';
import '../../shared/widgets/account_card.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/brand_logo.dart';
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
    final rates = ref.watch(ratesProvider).value ?? const [];
    final hasAccounts = (accountsAsync.value ?? const []).isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const BrandLogo(height: 30),
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
              final bcvRate = latestReferenceRate(rates, RateProvider.bcv);
              final binanceRate = latestReferenceRate(rates, RateProvider.binance);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SummaryCard(
                    accounts: accounts,
                    balances: balances,
                    bcvRate: bcvRate,
                    binanceRate: binanceRate,
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
                        usdValue: bcvRate == null
                            ? null
                            : usdEquivalent(
                                balances[account.id] ?? 0,
                                account.currency,
                                bcvRate.rate,
                              ),
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

class _SummaryCard extends StatefulWidget {
  const _SummaryCard({
    required this.accounts,
    required this.balances,
    required this.bcvRate,
    required this.binanceRate,
    required this.hidden,
  });

  final List<Account> accounts;
  final Map<String, double> balances;
  final CurrencyRate? bcvRate;
  final CurrencyRate? binanceRate;
  final bool hidden;

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  int _page = 0;

  Widget _buildPage({
    required CurrencyRate? rate,
    required String title,
  }) {
    final theme = Theme.of(context);
    final converted = rate == null
        ? null
        : totalUsdOf(widget.balances, widget.accounts, rate.rate);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          if (converted != null) ...[
            AmountText(
              converted.total,
              currency: 'USD',
              hidden: widget.hidden,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.hidden
                  ? '≈ ···· Bs'
                  : '≈ ${formatVeNumber(converted.total * rate!.rate)} Bs',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ] else ...[
            Text(
              '—',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              rate == null
                  ? 'Sin tasa guardada. Abre Monedas para obtener la referencia.'
                  : 'Sin cuentas convertibles (solo VES/USD).',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(
              height: 140,
              child: PageView(
                onPageChanged: (index) => setState(() => _page = index),
                children: [
                  _buildPage(
                    rate: widget.bcvRate,
                    title: 'Saldo en USD · BCV',
                  ),
                  _buildPage(
                    rate: widget.binanceRate,
                    title: 'Saldo en USD · Binance P2P',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 2; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Desliza para ver la referencia de Binance',
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const BrandLogo(height: 96),
              const SizedBox(height: 20),
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