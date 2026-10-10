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
              final eurRate = latestEurRate(rates)?.rate;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SummaryCard(
                    accounts: accounts,
                    balances: balances,
                    bcvRate: bcvRate,
                    binanceRate: binanceRate,
                    eurPerUsd: eurRate,
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
                                eurPerUsd: eurRate,
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
    required this.eurPerUsd,
    required this.hidden,
  });

  final List<Account> accounts;
  final Map<String, double> balances;
  final CurrencyRate? bcvRate;
  final CurrencyRate? binanceRate;
  final double? eurPerUsd;
  final bool hidden;

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  RateProvider _provider = RateProvider.bcv;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = _provider == RateProvider.binance
        ? widget.binanceRate
        : widget.bcvRate;
    final converted = rate == null
        ? null
        : totalUsdOf(
            widget.balances,
            widget.accounts,
            rate.rate,
            eurPerUsd: widget.eurPerUsd,
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Saldo total en USD',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                SegmentedButton<RateProvider>(
                  segments: const [
                    ButtonSegment(value: RateProvider.bcv, label: Text('BCV')),
                    ButtonSegment(
                      value: RateProvider.binance,
                      label: Text('Binance'),
                    ),
                  ],
                  selected: {_provider},
                  onSelectionChanged: (selection) =>
                      setState(() => _provider = selection.first),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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