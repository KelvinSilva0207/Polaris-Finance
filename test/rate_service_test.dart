import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:polaris_finance/data/database/app_database.dart';
import 'package:polaris_finance/data/models/enums.dart';
import 'package:polaris_finance/data/services/rate_service.dart';

const bcvTodayBody =
    '{"USD":873.867,"EUR":984.26,"updated_at":"2026-10-06T23:31:09+00:00","date":"2026-10-07"}';

const bcvHtmlSnippet = '''
<div id="dolar" class="col-sm-12 col-xs-12 ">
  <div class="field-content">
    <div class="row recuadrotsmc">
      <div class="col-sm-6 col-xs-6 centrado textp">
        <strong class="strong-tb">873,86700000</strong>
      </div>
    </div>
  </div>
</div>
''';

const binanceBody = '{"code":"000000","message":null,"data":[{"adv":{"price":"1015.000"}}]}';

class _FakeSource implements RateProviderSource {
  _FakeSource(this.provider, {this.rate, this.error});

  @override
  final RateProvider provider;
  final double? rate;
  final Object? error;

  @override
  Future<double> fetchVesPerUsd() async {
    final error = this.error;
    if (error != null) throw error;
    return rate!;
  }
}

void main() {
  test('parsea la tasa BCV desde bcv.today', () {
    expect(parseBcvTodayRate(bcvTodayBody), 873.867);
    expect(
      () => parseBcvTodayRate('{"USD":0}'),
      throwsA(isA<RateFetchException>()),
    );
    expect(
      () => parseBcvTodayRate('no es json'),
      throwsA(isA<FormatException>()),
    );
  });

  test('parsea la tasa BCV desde el HTML oficial', () {
    expect(parseBcvHtmlRate(bcvHtmlSnippet), closeTo(873.867, 0.0001));
    expect(
      () => parseBcvHtmlRate('<html><body>sin tasa</body></html>'),
      throwsA(isA<RateFetchException>()),
    );
  });

  test('parsea la tasa P2P de Binance', () {
    expect(parseBinanceP2pRate(binanceBody), 1015);
    expect(
      () => parseBinanceP2pRate('{"data":[]}'),
      throwsA(isA<RateFetchException>()),
    );
  });

  test('BcvRateSource usa bcv.today y cae al HTML del BCV si falla', () async {
    final source = BcvRateSource(
      client: MockClient((request) async {
        if (request.url.host == 'bcv.today') {
          return http.Response(bcvTodayBody, 200);
        }
        return http.Response(bcvHtmlSnippet, 200);
      }),
    );
    expect(await source.fetchVesPerUsd(), closeTo(873.867, 0.0001));

    final fallback = BcvRateSource(
      client: MockClient((request) async {
        if (request.url.host == 'bcv.today') {
          return http.Response('error del servidor', 500);
        }
        return http.Response(bcvHtmlSnippet, 200);
      }),
    );
    expect(await fallback.fetchVesPerUsd(), closeTo(873.867, 0.0001));

    final offline = BcvRateSource(
      client: MockClient((_) async => throw http.ClientException('sin red')),
    );
    await expectLater(
      offline.fetchVesPerUsd(),
      throwsA(isA<RateFetchException>()),
    );
  });

  test('BinanceRateSource devuelve la primera oferta P2P', () async {
    final source = BinanceRateSource(
      client: MockClient((_) async => http.Response(binanceBody, 200)),
    );
    expect(await source.fetchVesPerUsd(), 1015);
  });

  test('RateService guarda la tasa al tener éxito y no si falla', () async {
    final database = AppDatabase.memory();
    addTearDown(database.close);

    final ok = RateService(
      database,
      sources: {RateProvider.bcv: _FakeSource(RateProvider.bcv, rate: 900)},
    );
    final result = await ok.refresh(RateProvider.bcv);
    expect(result.error, isNull);
    expect(result.rate, 900);
    final saved = await database.select(database.currencyRates).get();
    expect(saved, hasLength(1));
    expect(saved.first.rate, 900);
    expect(saved.first.provider, RateProvider.bcv.name);

    final failing = RateService(
      database,
      sources: {
        RateProvider.binance: _FakeSource(
          RateProvider.binance,
          error: const RateFetchException('Binance P2P: sin ofertas'),
        ),
      },
    );
    final failed = await failing.refresh(RateProvider.binance);
    expect(failed.error, 'Binance P2P: sin ofertas');
    expect(failed.rate, 0);
    expect(await database.select(database.currencyRates).get(), hasLength(1));

    final manual = RateService(database, sources: {});
    final manualResult = await manual.refresh(RateProvider.manual, manualRate: 850);
    expect(manualResult.rate, 850);
    expect(manualResult.error, isNull);
    final all = await database.select(database.currencyRates).get();
    expect(all, hasLength(2));
    expect(all.any((rate) => rate.isManual), isTrue);
  });
}
