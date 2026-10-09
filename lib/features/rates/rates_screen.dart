import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/settings/app_settings.dart';
import '../../data/database/app_database.dart';
import '../../data/database/database_providers.dart';
import '../../data/models/enums.dart';
import '../../data/services/rate_service.dart';
import '../../shared/utils/amount_format.dart';
import '../../shared/utils/transaction_math.dart';

class RatesScreen extends ConsumerStatefulWidget {
  const RatesScreen({super.key});

  @override
  ConsumerState<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends ConsumerState<RatesScreen> {
  final Set<RateProvider> _busy = {};
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _refreshLive(silent: true),
    );
    _refreshLive(silent: true);
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshLive({bool silent = true}) async {
    final service = ref.read(rateServiceProvider);
    for (final provider in [RateProvider.bcv, RateProvider.binance]) {
      if (_busy.contains(provider)) continue;
      setState(() => _busy.add(provider));
      final result = await service.refresh(provider);
      if (!mounted) return;
      setState(() => _busy.remove(provider));
      if (!silent) _notify(result);
    }
  }

  Future<void> _refresh(RateProvider provider) => _refreshLive(silent: false);

  void _notify(RateResult result) {
    if (result.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tasa ${result.source}: ${formatVeNumber(result.rate)} VES/USD',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error!)),
    );
  }

  Future<void> _refreshManual() async {
    final controller = TextEditingController();
    final input = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tasa manual (VES por USD)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [veAmountFormatter()],
          decoration: const InputDecoration(labelText: 'Tasa'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = parseAmountInput(controller.text);
              Navigator.of(context).pop(value);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (input != null && input > 0) {
      await ref.read(rateServiceProvider).refresh(
            RateProvider.manual,
            manualRate: input,
          );
    }
  }

  Widget _liveRow({
    required String title,
    required String subtitle,
    required String debugLabel,
    required CurrencyRate? rate,
    required bool busy,
    required bool isManual,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: Icon(
        isManual ? Icons.edit_outlined : Icons.currency_exchange,
        color: theme.colorScheme.primary,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              rate == null
                  ? '—'
                  : '${formatVeNumber(rate.rate)} VES'
                      '\n${DateFormat('HH:mm:ss').format(rate.date)}',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ratesAsync = ref.watch(ratesProvider);
    final settings = ref.watch(appSettingsProvider);
    final rates = ratesAsync.value ?? const [];
    final bcv = latestReferenceRate(rates, RateProvider.bcv);
    final binance = latestReferenceRate(rates, RateProvider.binance);

    return Scaffold(
      appBar: AppBar(title: const Text('Monedas')),
      body: ratesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (_) {
          final now = DateFormat('HH:mm:ss').format(DateTime.now());
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.sensors, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Tasas en vivo · se actualizan cada 60 s',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                      _liveRow(
                        title: 'BCV',
                        subtitle: 'Banco Central de Venezuela',
                        debugLabel: 'bcv',
                        rate: bcv,
                        busy: _busy.contains(RateProvider.bcv),
                        isManual: bcv?.isManual == true,
                      ),
                      _liveRow(
                        title: 'Binance P2P',
                        subtitle: 'Tasa P2P USD/VES',
                        debugLabel: 'binance',
                        rate: binance,
                        busy: _busy.contains(RateProvider.binance),
                        isManual: binance?.isManual == true,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Última comprobación: $now',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Referencia activa: ${settings.referenceProvider.label}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        settings.referenceProvider.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _busy.contains(RateProvider.bcv)
                                ? null
                                : () => _refresh(RateProvider.bcv),
                            icon: _busy.contains(RateProvider.bcv)
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh, size: 18),
                            label: const Text('Actualizar BCV'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _busy.contains(RateProvider.binance)
                                ? null
                                : () => _refresh(RateProvider.binance),
                            icon: _busy.contains(RateProvider.binance)
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh, size: 18),
                            label: const Text('Actualizar Binance'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy.contains(RateProvider.manual)
                                ? null
                                : _refreshManual,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Manual'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (rates.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Sin tasas guardadas todavía.',
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text('Historial', style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final rate in rates.take(20))
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.currency_exchange),
                      title: Text('${rate.rateCode} · ${rate.provider}'),
                      subtitle: Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(rate.date),
                      ),
                      trailing: Text(
                        '${formatVeNumber(rate.rate)} → ${rate.isManual ? 'manual' : 'auto'}',
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}