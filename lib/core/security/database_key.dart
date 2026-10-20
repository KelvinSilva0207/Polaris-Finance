import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Clave que cifra la base de datos en reposo: 32 bytes aleatorios en base64.
///
/// Se guarda en el Keystore/Keychain del dispositivo con
/// `flutter_secure_storage`. Si ese almacenamiento no está disponible
/// (algunos escritorios sin libsecret o entornos de prueba) se usa un archivo
/// de respaldo dentro de la carpeta de soporte de la app.
///
/// La clave protege la base local y las copias creadas en este equipo. Las
/// copias transportables llevan la clave envuelta con la frase del usuario
/// (ver [wrapBackupKey]); si se pierde la clave del dispositivo, una copia sin
/// frase no podrá leerse.
class DatabaseKeyStore {
  DatabaseKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _secureKeyName = 'polaris_db_key_v1';
  static const _fallbackFileName = '.polaris_db_key';
  static const _keyLength = 32;

  final FlutterSecureStorage _storage;

  /// Devuelve la clave guardada o crea una nueva y la persiste.
  Future<String> loadOrCreate() async {
    final existing = await read();
    if (existing != null) return existing;
    final key = _newKey();
    await save(key);
    return key;
  }

  /// Devuelve la clave guardada o `null` si no existe.
  Future<String?> read() async {
    try {
      final stored = await _storage.read(key: _secureKeyName);
      if (stored != null && stored.isNotEmpty) return stored;
    } catch (error) {
      debugPrint('Almacenamiento seguro no disponible: $error');
    }
    try {
      final file = await _fallbackFile();
      if (file != null && await file.exists()) {
        final stored = (await file.readAsString()).trim();
        if (stored.isNotEmpty) return stored;
      }
    } catch (error) {
      debugPrint('No se pudo leer la clave alternativa: $error');
    }
    return null;
  }

  /// Persiste [key]. Deja un único origen: si el almacenamiento seguro
  /// funciona elimina el archivo alternativo y viceversa.
  Future<void> save(String key) async {
    var secured = false;
    try {
      await _storage.write(key: _secureKeyName, value: key);
      secured = true;
    } catch (error) {
      debugPrint('Almacenamiento seguro no disponible: $error');
    }

    try {
      final file = await _fallbackFile();
      if (file == null) return;
      if (secured) {
        if (await file.exists()) await file.delete();
      } else {
        await file.writeAsString(key, flush: true);
      }
    } catch (error) {
      debugPrint('No se pudo guardar la clave alternativa: $error');
    }
  }

  String _newKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(
      _keyLength,
      (_) => random.nextInt(256),
      growable: false,
    );
    return base64Url.encode(bytes);
  }

  Future<File?> _fallbackFile() async {
    try {
      final support = await getApplicationSupportDirectory();
      final sep = Platform.pathSeparator;
      // En Windows flutter_secure_storage guarda un único archivo
      // `flutter_secure_storage.dat` (cifrado con DPAPI) en esta carpeta:
      // reconstruirlo nunca puede funcionar, así que se prefiere la clave
      // directa para no perder los datos al actualizar desde una versión sin
      // cifrado.
      if (Platform.isWindows &&
          await File(
            '${support.path}$sep'
            'flutter_secure_storage.dat',
          ).exists()) {
        return null;
      }
      return File('${support.path}$sep$_fallbackFileName');
    } catch (error) {
      debugPrint('Sin carpeta de soporte para la clave: $error');
      return null;
    }
  }
}
