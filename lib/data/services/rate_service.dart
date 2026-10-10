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
    this.unchanged = false,
  });

  final double rate;
  final String source;
  final DateTime date;
  final String? error;

  /// Indica que el valor recibido era igual al ya guardado: no se creó
  /// registro nuevo (el dólar suele moverse 1-2 veces al día laborable y no
  /// cambia los fines de semana).
  final bool unchanged;
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

/// Tasa del euro expresada en USD (`USD/EUR`): cuántos euros vale un dólar.
double parseEuroUsdRate(String body) {
  final json = jsonDecode(body);
  final rates = json is Map<String, dynamic> ? json['rates'] : null;
  final price = rates is Map<String, dynamic> ? rates['EUR'] : null;
  final rate = price == null ? null : double.tryParse(price.toString());
  if (rate == null || rate <= 0) {
    throw const RateFetchException('Euro: respuesta inesperada');
  }
  return rate;
}

class EuroRateSource {
  EuroRateSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _url = 'https://open.er-api.com/v6/latest/USD';

  Future<double> fetchEurPerUsd() async {
    final res = await _client
        .get(Uri.parse(_url), headers: const {'accept': 'application/json'})
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw RateFetchException('Euro: HTTP ${res.statusCode}');
    }
    return parseEuroUsdRate(res.body);
  }
}

class RateService {
  RateService(
    this._db, {
    Map<RateProvider, RateProviderSource>? sources,
    EuroRateSource? euroSource,
  })  : _sources = sources ??
            {
              RateProvider.bcv: BcvRateSource(),
              RateProvider.binance: BinanceRateSource(),
            },
        _euroSource = euroSource ?? EuroRateSource();

  final AppDatabase _db;
  final Map<RateProvider, RateProviderSource> _sources;
  final EuroRateSource _euroSource;

  Future<RateResult> refresh(RateProvider provider, {double? manualRate}) async {
    if (provider == RateProvider.manual) {
      final value = manualRate ?? 0;
      final last = await _db.latestRateFor('USD/VES', provider.name);
      final unchanged = last != null && (last.rate - value).abs() < 0.005;
      if (!unchanged) {
        await _db.insertRate(
          code: 'VES',
          rateCode: 'USD/VES',
          provider: provider.name,
          rate: value,
          isManual: true,
        );
      }
      return RateResult(
        rate: value,
        source: 'Manual',
        date: unchanged ? last.date : DateTime.now(),
        unchanged: unchanged,
      );
    }
    try {
      final value = await _sources[provider]!.fetchVesPerUsd();
      final rounded = double.parse(value.toStringAsFixed(4));
      final last = await _db.latestRateFor('USD/VES', provider.name);
      final unchanged = last != null && (last.rate - rounded).abs() < 0.005;
      if (!unchanged) {
        await _db.insertRate(
          code: 'VES',
          rateCode: 'USD/VES',
          provider: provider.name,
          rate: rounded,
          isManual: false,
        );
      }
      return RateResult(
        rate: rounded,
        source: provider.label,
        date: unchanged ? last.date : DateTime.now(),
        unchanged: unchanged,
      );
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

  /// Actualiza la tasa `USD/EUR` (euros por dólar) desde open.er-api.com.
  Future<RateResult> refreshEuro() async {
    const source = 'Euro';
    try {
      final value = await _euroSource.fetchEurPerUsd();
      final rounded = double.parse(value.toStringAsFixed(4));
      final last = await _db.latestRateFor('USD/EUR', 'api');
      final unchanged = last != null && (last.rate - rounded).abs() < 0.0005;
      if (!unchanged) {
        await _db.insertRate(
          code: 'EUR',
          rateCode: 'USD/EUR',
          provider: 'api',
          rate: rounded,
        );
      }
      return RateResult(
        rate: rounded,
        source: source,
        date: unchanged ? last.date : DateTime.now(),
        unchanged: unchanged,
      );
    } on RateFetchException catch (error) {
      return RateResult(rate: 0, source: source, date: DateTime.now(), error: error.message);
    } catch (error) {
      return RateResult(
        rate: 0,
        source: source,
        date: DateTime.now(),
        error: 'Error de red: $error',
      );
    }
  }
}

final rateServiceProvider = Provider<RateService>((ref) {
  return RateService(ref.watch(appDatabaseProvider));
});