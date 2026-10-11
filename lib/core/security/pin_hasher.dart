import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Longitud del PIN de la app.
const int kPinLength = 4;

/// Genera un salt aleatorio (16 bytes) codificado en base64Url.
String generatePinSalt([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  return base64Url.encode(bytes);
}

/// Deriva el hash del PIN con [salt] aplicando SHA-256 de forma iterada.
String hashPin(String pin, String salt, {int iterations = 10000}) {
  List<int> value = utf8.encode('$salt:$pin');
  for (var i = 0; i < iterations; i++) {
    value = sha256.convert(value).bytes;
  }
  return base64.encode(value);
}

/// Comprueba [pin] contra el hash y salt almacenados.
bool verifyPinHash(
  String pin, {
  required String salt,
  required String hash,
  int iterations = 10000,
}) {
  final candidate = hashPin(pin, salt, iterations: iterations);
  return _constantTimeEquals(candidate, hash);
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
