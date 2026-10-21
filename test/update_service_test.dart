import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:polaris_finance/data/services/update_service.dart';

void main() {
  group('parseVersion', () {
    test('extrae números de v1.2.3', () {
      expect(parseVersion('v1.2.3'), [1, 2, 3]);
    });

    test('ignora build number tras +', () {
      expect(parseVersion('1.0.2+15'), [1, 0, 2]);
    });

    test('devuelve null para strings sin números', () {
      expect(parseVersion('latest'), isNull);
      expect(parseVersion(null), isNull);
      expect(parseVersion(''), isNull);
    });
  });

  group('compareVersions', () {
    test('detecta actualización cuando latest es mayor', () {
      expect(compareVersions('1.0.2', '1.0.1') > 0, isTrue);
      expect(compareVersions('2.0.0', '1.9.9') > 0, isTrue);
      expect(compareVersions('1.1.0', '1.0.9') > 0, isTrue);
    });

    test('iguales si son la misma versión', () {
      expect(compareVersions('1.0.2', '1.0.2'), 0);
      expect(compareVersions('v1.0.2', '1.0.2+3'), 0);
    });

    test('negativo si local es mayor', () {
      expect(compareVersions('1.0.1', '1.0.2') < 0, isTrue);
    });
  });

  group('urlForAbi', () {
    const downloads = {
      'arm64-v8a': 'https://example.com/polaris-finance-arm64-v8a.apk',
      'armeabi-v7a': 'https://example.com/polaris-finance-armeabi-v7a.apk',
    };
    const universal = 'https://example.com/polaris-finance.apk';

    test('elige el APK de la arquitectura del dispositivo', () {
      expect(
        urlForAbi('arm64-v8a', downloads, universal),
        'https://example.com/polaris-finance-arm64-v8a.apk',
      );
      expect(
        urlForAbi('armeabi-v7a', downloads, universal),
        'https://example.com/polaris-finance-armeabi-v7a.apk',
      );
    });

    test('usa el universal si no hay APK para esa arquitectura', () {
      expect(urlForAbi('x86_64', downloads, universal), universal);
      expect(urlForAbi(null, downloads, universal), universal);
    });
  });

  group('abiFromApkName', () {
    test('extrae la arquitectura del nombre del APK', () {
      expect(abiFromApkName('polaris-finance-arm64-v8a.apk'), 'arm64-v8a');
      expect(abiFromApkName('polaris-finance-armeabi-v7a.apk'), 'armeabi-v7a');
      expect(abiFromApkName('polaris-finance-x86_64.apk'), 'x86_64');
    });

    test('devuelve null para el APK universal', () {
      expect(abiFromApkName('polaris-finance.apk'), isNull);
      expect(abiFromApkName('version.json'), isNull);
    });
  });

  group('UpdateService', () {
    test('lee version.json y detecta actualización', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('version.json')) {
          return http.Response(
            jsonEncode({'version': '1.0.2', 'notes': 'Novedades'}),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final service = UpdateService(
        owner: 'x',
        repo: 'y',
        client: client,
        currentVersionLoader: () async => '1.0.0',
      );

      final info = await service.check();
      expect(info.status, UpdateStatus.updateAvailable);
      expect(info.latestVersion, '1.0.2');
      expect(info.currentVersion, '1.0.0');
      expect(info.releaseNotes, 'Novedades');
      expect(info.downloadUrl, contains('polaris-finance.apk'));
    });

    test('lee el mapa de APKs por arquitectura del manifiesto', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('version.json')) {
          return http.Response(
            jsonEncode({
              'version': '1.0.2',
              'download_url': 'https://example.com/polaris-finance.apk',
              'downloads': {
                'arm64-v8a':
                    'https://example.com/polaris-finance-arm64-v8a.apk',
                'armeabi-v7a':
                    'https://example.com/polaris-finance-armeabi-v7a.apk',
              },
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final service = UpdateService(
        owner: 'x',
        repo: 'y',
        client: client,
        currentVersionLoader: () async => '1.0.0',
      );

      final info = await service.check();
      expect(info.status, UpdateStatus.updateAvailable);
      // En el host de pruebas la ABI no es Android, asi que se usa el
      // universal; el mapa por arquitectura se valida en urlForAbi.
      expect(info.downloadUrl, 'https://example.com/polaris-finance.apk');
    });

    test('está al día si las versiones son iguales', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('version.json')) {
          return http.Response(jsonEncode({'version': '1.0.1'}), 200);
        }
        return http.Response('not found', 404);
      });

      final service = UpdateService(
        owner: 'x',
        repo: 'y',
        client: client,
        currentVersionLoader: () async => '1.0.1',
      );

      final info = await service.check();
      expect(info.status, UpdateStatus.upToDate);
      expect(info.hasUpdate, isFalse);
    });

    test('cae a GitHub API si no hay version.json', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'raw.githubusercontent.com') {
          return http.Response('not found', 404);
        }
        if (request.url.path.endsWith('/releases/latest')) {
          return http.Response(
            jsonEncode({
              'tag_name': 'latest',
              'body': 'Notas',
              'assets': [
                {
                  'name': 'polaris-finance.apk',
                  'browser_download_url': 'https://example.com/app.apk',
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/tags')) {
          return http.Response(
            jsonEncode([
              {'name': '1.0.3'},
              {'name': 'v1.0.2'},
            ]),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final service = UpdateService(
        owner: 'x',
        repo: 'y',
        client: client,
        currentVersionLoader: () async => '1.0.0',
      );

      final info = await service.check();
      expect(info.status, UpdateStatus.updateAvailable);
      expect(info.latestVersion, '1.0.3');
      expect(info.downloadUrl, 'https://example.com/app.apk');
    });

    test('retorna error si no hay información de versiones', () async {
      final client = MockClient((request) async {
        return http.Response('not found', 404);
      });

      final service = UpdateService(
        owner: 'x',
        repo: 'y',
        client: client,
        currentVersionLoader: () async => '1.0.0',
      );

      final info = await service.check();
      expect(info.status, UpdateStatus.error);
      expect(info.error, isNotNull);
      expect(info.hasUpdate, isFalse);
    });

    test('openDownload usa la url del release si no se pasa ninguna', () async {
      final opened = <Uri>[];
      final service = UpdateService(
        owner: 'KelvinSilva0207',
        repo: 'Polaris-Finance',
        currentVersionLoader: () async => '1.0.0',
        launcherFn: (uri) async {
          opened.add(uri);
          return true;
        },
      );

      final result = await service.openDownload(null);
      expect(result, isTrue);
      expect(opened.first.toString(), contains('polaris-finance.apk'));
    });
  });
}
