import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_fonts.dart';

/// Bytes del archivo de tipografía elegido por el usuario (base64).
const customFontBytesKey = 'custom_font_bytes';

/// Tope de tamaño: una tipografía completa ronda 100-600 KB y no queremos
/// cargar las preferencias con archivos gigantes.
const maxCustomFontBytes = 1536 * 1024;

class CustomFontException implements Exception {
  const CustomFontException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// El usuario cerró el selector de archivos.
class CustomFontCanceledException implements Exception {
  const CustomFontCanceledException();
}

Future<void> _register(Uint8List bytes) async {
  final loader = FontLoader(AppFonts.customFamily)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

/// Registra en el motor la tipografía guardada (si existe). Devuelve si se
/// pudo cargar. Se llama antes de `runApp` para evitar el primer frame con la
/// fuente del sistema.
Future<bool> loadCustomFontFromPrefs(SharedPreferences prefs) async {
  final encoded = prefs.getString(customFontBytesKey);
  if (encoded == null || encoded.isEmpty) return false;
  try {
    await _register(base64Decode(encoded));
    return true;
  } catch (_) {
    return false;
  }
}

/// Abre el selector del sistema, valida el archivo, lo registra y lo guarda.
/// Devuelve el nombre del archivo elegido.
Future<String> pickCustomFont(SharedPreferences prefs) async {
  final result = await FilePicker.pickFiles(
    dialogTitle: 'Elige una tipografía (.ttf o .otf)',
    type: FileType.custom,
    allowedExtensions: const ['ttf', 'otf'],
  );
  final file = result.isEmpty ? null : result.first;
  if (file == null) {
    throw const CustomFontCanceledException();
  }
  final Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } catch (_) {
    throw const CustomFontException(
      'No se pudo leer el archivo. Usa un archivo .ttf o .otf válido.',
    );
  }
  if (bytes.length > maxCustomFontBytes) {
    throw const CustomFontException(
      'El archivo es muy grande (máximo 1,5 MB).',
    );
  }
  try {
    await _register(bytes);
  } catch (_) {
    throw const CustomFontException(
      'No se pudo leer la tipografía. Usa un archivo .ttf o .otf válido.',
    );
  }
  await prefs.setString(customFontBytesKey, base64Encode(bytes));
  return file.name;
}
