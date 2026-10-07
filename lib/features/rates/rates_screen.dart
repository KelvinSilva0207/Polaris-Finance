import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/settings/app_settings.dart';
import '../../data/database/database_providers.dart';

class RatesScreen extends ConsumerWidget {
  const RatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratesAsync = ref.watch(ratesProvider);
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Monedas')),
      body: ratesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(error.toString())),
        data: (rates) {
          if (rates.isEmpty) {
            return const Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.currency_exchange, size: 72),
                    SizedBox(height: 16),
                    Text('Sin tasas de referencia'),
                    SizedBox(height: 8),
                    Text(
                      'BCV, Binance P2P y API personalizadas llegarán en la Fase 1.',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    Chip(label: Text('Fase 1')),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text('Referencia activa'),
                  subtitle: Text(
                    '${settings.referenceProvider.label} — ${settings.referenceProvider.description}',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final rate in rates.take(20))
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.currency_exchange),
                    title: Text(rate.rateCode),
                    subtitle: Text(
                      '${rate.provider} · ${DateFormat('dd/MM/yyyy HH:mm').format(rate.date)}',
                    ),
                    trailing: Text(rate.rate.toStringAsFixed(2)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}