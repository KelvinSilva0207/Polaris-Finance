import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/settings/app_settings.dart';
import '../../data/database/database_providers.dart';
import '../../data/models/enums.dart';
import '../../data/services/rate_service.dart';

class RatesScreen extends ConsumerStatefulWidget {
  const RatesScreen({super.key});

  @override
  ConsumerState<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends ConsumerState<RatesScreen> {
  final Set<RateProvider> _busy = {};

  Future<void> _refresh(RateProvider provider, {double? manualRate}) async {
    setState(() => _busy.add(provider));
    final result = await ref.read(rateServiceProvider).refresh(provider, manualRate: manualRate);
    if (!mounted) return;
    setState(() => _busy.remove(provider));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.error == null
              ? 'Tasa ${result.source}: ${result.rate.toStringAsFixed(2)} VES/USD'
              : result.error!,
        ),
      ),
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
          decoration: const InputDecoration(labelText: 'Tasa'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim().replaceAll(',', '.'));
              Navigator.of(context).pop(value);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (input != null && input > 0) {
      await _refresh(RateProvider.manual, manualRate: input);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratesAsync = ref.watch(ratesProvider);
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Monedas')),
      body: ratesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (rates) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                                : const Icon(Icons.cloud_download_outlined, size: 18),
                            label: const Text('BCV'),
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
                                : const Icon(Icons.currency_exchange, size: 18),
                            label: const Text('Binance P2P'),
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
                        '${rate.rate.toStringAsFixed(2)} → ${rate.isManual ? 'manual' : 'auto'}',
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