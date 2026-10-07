import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/providers.dart';
import '../database/app_database.dart';
import '../models/enums.dart';

class RateResult {
  const RateResult({
    required this.rate,
    required this.source,
    required this.date,
    this.error,
  });

  final double rate;
  final String source;
  final DateTime date;
  final String? error;
}

class RateFetchException implements Exception {
  RateFetchException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class RateProviderSource {
  RateProvider get provider;

  Future<double> fetchVesPerUsd();
}

class BcvRateSource implements RateProviderSource {
  @override
  RateProvider get provider => RateProvider.bcv;

  @override
  Future<double> fetchVesPerUsd() async {
    final res = await http
        .get(
          Uri.parse('https://pydolarve.org/api/v1/dollar?monetary=1&page=bcv'),
          headers: const {'accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw RateFetchException('BCV: HTTP ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final monitors = json['monitors'] as Map<String, dynamic>?;
    final price = monitors?['bcv']?['price'];
    if (price == null) {
      throw RateFetchException('BCV: respuesta inesperada');
    }
    return double.parse(price.toString());
  }
}

class BinanceRateSource implements RateProviderSource {
  @override
  RateProvider get provider => RateProvider.binance;

  @override
  Future<double> fetchVesPerUsd() async {
    final res = await http
        .post(
          Uri.parse('https://p2p.binance.com/bapi/c2c/v2/friendly/c2c/adv/search'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'page': 1,
            'rows': 1,
            'payTypes': [],
            'asset': 'USDT',
            'fiat': 'VES',
            'tradeType': 'SELL',
            'publisherType': null,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw RateFetchException('Binance P2P: HTTP ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = json['data'] as List?;
    if (data == null || data.isEmpty) {
      throw RateFetchException('Binance P2P: sin ofertas disponibles');
    }
    final adv = (data.first as Map<String, dynamic>)['adv'] as Map<String, dynamic>;
    return double.parse(adv['price'].toString());
  }
}

class RateService {
  RateService(this._db);

  final AppDatabase _db;

  final Map<RateProvider, RateProviderSource> _sources = {
    RateProvider.bcv: BcvRateSource(),
    RateProvider.binance: BinanceRateSource(),
  };

  Future<RateResult> refresh(RateProvider provider, {double? manualRate}) async {
    if (provider == RateProvider.manual) {
      final value = manualRate ?? 0;
      await _db.insertRate(
        code: 'VES',
        rateCode: 'USD/VES',
        provider: provider.name,
        rate: value,
        isManual: true,
      );
      return RateResult(rate: value, source: 'Manual', date: DateTime.now());
    }
    try {
      final value = await _sources[provider]!.fetchVesPerUsd();
      await _db.insertRate(
        code: 'VES',
        rateCode: 'USD/VES',
        provider: provider.name,
        rate: value,
        isManual: false,
      );
      return RateResult(rate: value, source: provider.label, date: DateTime.now());
    } on RateFetchException catch (error) {
      return RateResult(rate: 0, source: provider.label, date: DateTime.now(), error: error.message);
    } catch (error) {
      return RateResult(
        rate: 0,
        source: provider.label,
        date: DateTime.now(),
        error: 'Error de red: $error',
      );
    }
  }
}

final rateServiceProvider = Provider<RateService>((ref) {
  return RateService(ref.watch(appDatabaseProvider));
});