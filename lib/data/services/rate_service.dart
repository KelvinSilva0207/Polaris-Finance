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
  const RateFetchException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class RateProviderSource {
  RateProvider get provider;

  Future<double> fetchVesPerUsd();
}

const _timeout = Duration(seconds: 15);

double parseBcvTodayRate(String body) {
  final json = jsonDecode(body);
  final price = json is Map<String, dynamic> ? json['USD'] : null;
  final rate = price == null ? null : double.tryParse(price.toString());
  if (rate == null || rate <= 0) {
    throw const RateFetchException('BCV: respuesta inesperada');
  }
  return rate;
}

double parseBcvHtmlRate(String html) {
  final match = RegExp(r'id="dolar"[\s\S]*?<strong[^>]*>([\d.,]+)</strong>')
      .firstMatch(html);
  if (match == null) {
    throw const RateFetchException('BCV: no se encontró la tasa en la página');
  }
  return _parseVeNumber(match.group(1)!);
}

double _parseVeNumber(String raw) {
  var text = raw.trim();
  if (text.contains(',') && text.contains('.')) {
    text = text.replaceAll('.', '').replaceAll(',', '.');
  } else {
    text = text.replaceAll(',', '.');
  }
  final rate = double.tryParse(text);
  if (rate == null || rate <= 0) {
    throw const RateFetchException('BCV: tasa inválida');
  }
  return rate;
}

class BcvRateSource implements RateProviderSource {
  BcvRateSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _jsonUrl = 'https://bcv.today/api/v1/rate.json';
  static const _htmlUrl = 'https://www.bcv.org.ve/';

  @override
  RateProvider get provider => RateProvider.bcv;

  @override
  Future<double> fetchVesPerUsd() async {
    Object? jsonError;
    try {
      final res = await _client
          .get(
            Uri.parse(_jsonUrl),
            headers: const {'accept': 'application/json'},
          )
          .timeout(_timeout);
      if (res.statusCode == 200) return parseBcvTodayRate(res.body);
      jsonError = 'HTTP ${res.statusCode}';
    } catch (error) {
      jsonError = error;
    }
    try {
      final res = await _client
          .get(
            Uri.parse(_htmlUrl),
            headers: const {'user-agent': 'Mozilla/5.0'},
          )
          .timeout(_timeout);
      if (res.statusCode != 200) {
        throw RateFetchException('BCV: HTTP ${res.statusCode}');
      }
      return parseBcvHtmlRate(res.body);
    } on RateFetchException {
      rethrow;
    } catch (error) {
      throw RateFetchException('BCV: sin conexión ($jsonError / $error)');
    }
  }
}

double parseBinanceP2pRate(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  final data = json['data'] as List?;
  if (data == null || data.isEmpty) {
    throw const RateFetchException('Binance P2P: sin ofertas disponibles');
  }
  final adv = (data.first as Map<String, dynamic>)['adv'] as Map<String, dynamic>;
  final rate = double.tryParse(adv['price'].toString());
  if (rate == null || rate <= 0) {
    throw const RateFetchException('Binance P2P: precio inválido');
  }
  return rate;
}

class BinanceRateSource implements RateProviderSource {
  BinanceRateSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final _url =
      Uri.parse('https://p2p.binance.com/bapi/c2c/v2/friendly/c2c/adv/search');

  @override
  RateProvider get provider => RateProvider.binance;

  @override
  Future<double> fetchVesPerUsd() async {
    final res = await _client
        .post(
          _url,
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
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw RateFetchException('Binance P2P: HTTP ${res.statusCode}');
    }
    return parseBinanceP2pRate(res.body);
  }
}

class RateService {
  RateService(this._db, {Map<RateProvider, RateProviderSource>? sources})
      : _sources = sources ??
            {
              RateProvider.bcv: BcvRateSource(),
              RateProvider.binance: BinanceRateSource(),
            };

  final AppDatabase _db;
  final Map<RateProvider, RateProviderSource> _sources;

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