import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/settings/app_settings.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_providers.dart';
import '../../data/models/enums.dart';
import '../../shared/utils/amount_format.dart';
import '../../shared/utils/schedule.dart';
import '../../shared/utils/transaction_math.dart';
import '../../shared/widgets/account_card.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/brand_logo.dart';
import '../accounts/account_form_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _reordering = false;

  void _openAccountEditor(BuildContext context, {Account? initial}) {
    Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (context) => AccountFormScreen(initial: initial),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final accountsAsync = ref.watch(accountsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final rates = ref.watch(ratesProvider).value ?? const [];
    final services = ref.watch(servicesProvider).value ?? const <RecurringService>[];
    final goals = ref.watch(goalsProvider).value ?? const <SavingsGoal>[];
    final loans = ref.watch(loansProvider).value ?? const <Loan>[];
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
          if (hasAccounts)
            IconButton(
              tooltip: _reordering ? 'Listo' : 'Reordenar',
              icon: Icon(_reordering ? Icons.check : Icons.reorder),
              onPressed: () => setState(() => _reordering = !_reordering),
            ),
        ],
      ),
      floatingActionButton: hasAccounts && !_reordering
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
              final binanceRate =
                  latestReferenceRate(rates, RateProvider.binance);
              final eurRate = latestEurRate(rates)?.rate;
              final accountCurrency = {
                for (final account in accounts) account.id: account.currency,
              };

              final sections = <String, Widget>{
                'summary': _SummaryCard(
                  accounts: accounts,
                  balances: balances,
                  bcvRate: bcvRate,
                  binanceRate: binanceRate,
                  eurPerUsd: eurRate,
                  hidden: settings.hideBalances,
                ),
                'accounts': _accountsSection(
                  context,
                  accounts,
                  balances,
                  bcvRate,
                  eurRate,
                  settings.hideBalances,
                ),
                if (services.any((s) => s.isActive))
                  'services': _servicesSection(context, services),
                if (goals.isNotEmpty) 'goals': _goalsSection(context, goals, accountCurrency),
                if (loans.any((l) => l.isActive))
                  'loans': _loansSection(context, loans, accountCurrency),
                if (transactions.isNotEmpty)
                  'recent': _recentSection(context, transactions),
              };

              final order = [
                for (final id in settings.dashboardOrder)
                  if (sections.containsKey(id)) id,
              ];

              return ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                buildDefaultDragHandles: false,
                itemCount: order.length,
                onReorderItem: (oldIndex, newIndex) {
                  final visible = [...order];
                  final moved = visible.removeAt(oldIndex);
                  visible.insert(newIndex, moved);
                  final hidden = [
                    for (final id in settings.dashboardOrder)
                      if (!order.contains(id)) id,
                  ];
                  controller.setDashboardOrder([...visible, ...hidden]);
                },
                itemBuilder: (context, index) {
                  final id = order[index];
                  return Padding(
                    key: ValueKey(id),
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_reordering)
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.only(top: 8, right: 4),
                              child: Icon(Icons.drag_indicator),
                            ),
                          ),
                        Expanded(child: sections[id]!),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _accountsSection(
    BuildContext context,
    List<Account> accounts,
    Map<String, double> balances,
    CurrencyRate? bcvRate,
    double? eurRate,
    bool hidden,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              hidden: hidden,
              onTap: () => _openAccountEditor(context, initial: account),
            ),
          ),
      ],
    );
  }

  Widget _servicesSection(BuildContext context, List<RecurringService> services) {
    final today = DateTime.now();
    final today0 = DateTime(today.year, today.month, today.day);
    final active = services.where((s) => s.isActive).toList()
      ..sort(
        (a, b) => nextServiceDue(a.dayOfMonth, today0, a.lastPaidDate)
            .compareTo(nextServiceDue(b.dayOfMonth, today0, b.lastPaidDate)),
      );
    final shown = active.take(4).toList();
    final money = NumberFormat('#,##0.00', 'es');
    return _SectionCard(
      title: 'Servicios por pagar',
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          for (final service in shown)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_repeat, size: 20),
              title: Text(service.name),
              subtitle: Text(
                'Vence el ${DateFormat('d/M/yyyy').format(nextServiceDue(service.dayOfMonth, today0, service.lastPaidDate))}',
              ),
              trailing: Text(
                '${money.format(service.amount)} ${service.currency}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          if (active.length > shown.length)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '+ ${active.length - shown.length} más',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _goalsSection(
    BuildContext context,
    List<SavingsGoal> goals,
    Map<String, String> accountCurrency,
  ) {
    final sorted = [...goals]
      ..sort((a, b) {
        final pa = a.targetAmount <= 0 ? 0.0 : a.allocatedAmount / a.targetAmount;
        final pb = b.targetAmount <= 0 ? 0.0 : b.allocatedAmount / b.targetAmount;
        return pb.compareTo(pa);
      });
    final money = NumberFormat('#,##0.00', 'es');
    return _SectionCard(
      title: 'Metas de ahorro',
      icon: Icons.savings_outlined,
      child: Column(
        children: [
          for (final goal in sorted.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(goal.name)),
                      Text(
                        '${(goal.targetAmount <= 0 ? 0 : (goal.allocatedAmount / goal.targetAmount * 100)).clamp(0, 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: goal.targetAmount <= 0
                          ? 0
                          : (goal.allocatedAmount / goal.targetAmount).clamp(0.0, 1.0),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${money.format(goal.allocatedAmount)} / ${money.format(goal.targetAmount)} ${accountCurrency[goal.accountId] ?? ''}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _loansSection(
    BuildContext context,
    List<Loan> loans,
    Map<String, String> accountCurrency,
  ) {
    final active = loans
        .where((l) => l.isActive && (l.principal - l.paidAmount) > 0)
        .toList();
    final money = NumberFormat('#,##0.00', 'es');
    return _SectionCard(
      title: 'Préstamos pendientes',
      icon: Icons.request_quote_outlined,
      child: Column(
        children: [
          for (final loan in active.take(4))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_balance, size: 20),
              title: Text(loan.name),
              subtitle: loan.dueDate == null
                  ? null
                  : Text(
                      'Vence el ${DateFormat('d/M/yyyy').format(loan.dueDate!)}',
                    ),
              trailing: Text(
                '${money.format(loan.principal - loan.paidAmount)} ${loan.currency}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFEF5350),
                    ),
              ),
            ),
          if (active.length > 4)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '+ ${active.length - 4} más',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _recentSection(BuildContext context, List<Transaction> transactions) {
    final sorted = [...transactions]
      ..sort((a, b) => b.date.compareTo(a.date));
    final shown = sorted.take(5).toList();
    return _SectionCard(
      title: 'Últimos movimientos',
      icon: Icons.history,
      child: Column(
        children: [
          for (final transaction in shown)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _transactionIcon(TransactionType.fromStorage(transaction.type)),
                size: 20,
              ),
              title: Text(
                transaction.note?.isNotEmpty ?? false
                    ? transaction.note!
                    : TransactionType.fromStorage(transaction.type).label,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                DateFormat('d/M/yyyy').format(transaction.date),
              ),
              trailing: AmountText(
                signedAmount(transaction),
                currency: transaction.currency,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: signedAmount(transaction) >= 0
                          ? const Color(0xFF66BB6A)
                          : const Color(0xFFEF5350),
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

IconData _transactionIcon(TransactionType type) => switch (type) {
  TransactionType.income => Icons.arrow_downward,
  TransactionType.expense => Icons.arrow_upward,
  TransactionType.transfer => Icons.swap_horiz,
  TransactionType.pagoMovil => Icons.phone_android,
};

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: child,
          ),
        ),
      ],
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
