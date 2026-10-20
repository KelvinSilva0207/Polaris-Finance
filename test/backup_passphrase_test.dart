import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_finance/core/security/backup_passphrase.dart';

void main() {
  const passphrase = 'una frase bastante larga';

  String sampleKey() => base64Url.encode(List<int>.filled(32, 7));

  test('la frase envuelve y devuelve la misma clave', () async {
    final key = sampleKey();
    final wrapped = await wrapBackupKey(deviceKey: key, passphrase: passphrase);

    final decoded = jsonDecode(wrapped) as Map<String, Object?>;
    expect(decoded['kdf'], 'pbkdf2-sha256');
    expect(decoded['iterations'], greaterThanOrEqualTo(10000));

    final restored = await unwrapBackupKey(
      keyFileContents: wrapped,
      passphrase: passphrase,
    );
    expect(restored, key);
  });

  test('una frase distinta no abre el archivo', () async {
    final wrapped = await wrapBackupKey(
      deviceKey: sampleKey(),
      passphrase: passphrase,
    );

    await expectLater(
      unwrapBackupKey(keyFileContents: wrapped, passphrase: 'otra frase'),
      throwsA(isA<InvalidPassphrase>()),
    );
  });

  test('rechaza un archivo lateral corrupto', () async {
    await expectLater(
      unwrapBackupKey(keyFileContents: 'no es json', passphrase: passphrase),
      throwsA(isA<FormatException>()),
    );

    final wrongShape = jsonEncode({'v': 1});
    await expectLater(
      unwrapBackupKey(keyFileContents: wrongShape, passphrase: passphrase),
      throwsA(isA<FormatException>()),
    );
  });

  test('rechaza un número de iteraciones manipulado', () async {
    final wrapped = jsonDecode(
      await wrapBackupKey(deviceKey: sampleKey(), passphrase: passphrase),
    ) as Map<String, Object?>;
    wrapped['iterations'] = 1000000000;

    await expectLater(
      unwrapBackupKey(
        keyFileContents: jsonEncode(wrapped),
        passphrase: passphrase,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('dos envolturas de la misma clave usan sal distintas', () async {
    final key = sampleKey();
    final first = jsonDecode(
      await wrapBackupKey(deviceKey: key, passphrase: passphrase),
    ) as Map<String, Object?>;
    final second = jsonDecode(
      await wrapBackupKey(deviceKey: key, passphrase: passphrase),
    ) as Map<String, Object?>;

    expect(first['salt'], isNot(second['salt']));
    expect(first['box'], isNot(second['box']));
  });
}
