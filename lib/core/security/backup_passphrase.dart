import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Formato de la frase de respaldo: envuelve la clave del dispositivo para que
/// una copia pueda restaurarse en otro equipo.
///
/// `{"v":1,"kdf":"pbkdf2-sha256","iterations":N,"salt":"<base64url>",` +
/// `"box":"<base64url nonce+cipher+mac>"}`
///
/// La frase solo protege la clave del dispositivo: la copia en sí ya viene
/// cifrada con SQLCipher a partir de esa clave.
const _formatVersion = 1;
const _kdfName = 'pbkdf2-sha256';
const _defaultIterations = 200000;
const _minIterations = 10000;
const _maxIterations = 1000000;
const _saltLength = 16;
const _nonceLength = 12;
const _macLength = 16;
const _keyBits = 256;

/// Contraseña incorrecta al leer una copia protegida con frase.
class InvalidPassphrase implements Exception {
  const InvalidPassphrase();

  @override
  String toString() => 'La frase de respaldo no es correcta';
}

/// Ruta del archivo lateral que acompaña a una copia con frase.
String backupKeyFilePath(String backupPath) => '$backupPath.key.json';

/// Deriva [deviceKey] con [passphrase] y devuelve el JSON del archivo lateral.
/// Se ejecuta en un aislante para no congelar la interfaz.
Future<String> wrapBackupKey({
  required String deviceKey,
  required String passphrase,
}) {
  return Isolate.run(() => _wrap(deviceKey: deviceKey, passphrase: passphrase));
}

/// Lee el JSON del archivo lateral y devuelve la clave del dispositivo.
/// Lanza [InvalidPassphrase] si la frase no corresponde.
Future<String> unwrapBackupKey({
  required String keyFileContents,
  required String passphrase,
}) {
  return Isolate.run(
    () => _unwrap(keyFileContents: keyFileContents, passphrase: passphrase),
  );
}

Future<String> _wrap({
  required String deviceKey,
  required String passphrase,
}) async {
  final salt = _randomBytes(_saltLength);
  final key = await _derive(passphrase, salt, _defaultIterations);
  final box = await AesGcm.with256bits().encrypt(
    utf8.encode(deviceKey),
    secretKey: key,
    nonce: _randomBytes(_nonceLength),
  );
  return jsonEncode({
    'v': _formatVersion,
    'kdf': _kdfName,
    'iterations': _defaultIterations,
    'salt': base64Url.encode(salt),
    'box': base64Url.encode(box.concatenation()),
  });
}

Future<String> _unwrap({
  required String keyFileContents,
  required String passphrase,
}) async {
  final Object? decoded;
  try {
    decoded = jsonDecode(keyFileContents);
  } on FormatException {
    throw const FormatException('El archivo de clave de la copia no es válido');
  }
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('El archivo de clave de la copia no es válido');
  }
  if (decoded['v'] != _formatVersion || decoded['kdf'] != _kdfName) {
    throw const FormatException('La copia usa un formato no soportado');
  }

  final iterations = decoded['iterations'];
  if (iterations is! int ||
      iterations < _minIterations ||
      iterations > _maxIterations) {
    throw const FormatException('La copia usa un formato no soportado');
  }

  final salt = _decode(decoded['salt'], 'salt');
  final box = _decode(decoded['box'], 'box');
  if (salt.length != _saltLength || box.length < _nonceLength + _macLength) {
    throw const FormatException('La copia usa un formato no soportado');
  }

  final secretBox = SecretBox.fromConcatenation(
    box,
    nonceLength: _nonceLength,
    macLength: _macLength,
  );
  try {
    final key = await _derive(passphrase, salt, iterations);
    final plain = await AesGcm.with256bits().decrypt(secretBox, secretKey: key);
    return utf8.decode(plain);
  } on SecretBoxAuthenticationError {
    throw const InvalidPassphrase();
  }
}

Future<SecretKey> _derive(String passphrase, List<int> salt, int iterations) {
  final kdf = Pbkdf2.hmacSha256(iterations: iterations, bits: _keyBits);
  return kdf.deriveKey(
    secretKey: SecretKey(utf8.encode(passphrase)),
    nonce: salt,
  );
}

List<int> _decode(Object? value, String field) {
  if (value is! String) {
    throw const FormatException('El archivo de clave de la copia no es válido');
  }
  try {
    return base64Url.decode(value);
  } on FormatException {
    throw FormatException('El campo $field de la copia no es válido');
  }
}

List<int> _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256), growable: false),
  );
}
