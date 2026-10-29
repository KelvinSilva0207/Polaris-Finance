import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clave donde se guarda la carpeta elegida para exportaciones y respaldos.
const saveDirectoryKey = 'save_directory';

/// Carpeta preferida por el usuario, o `null` si no ha elegido ninguna.
Future<String?> preferredSaveDirectory() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(saveDirectoryKey);
    return (path == null || path.trim().isEmpty) ? null : path;
  } catch (_) {
    return null;
  }
}

/// Abre el selector nativo de carpetas y recuerda la elección.
///
/// Devuelve la ruta elegida o `null` si el usuario canceló o la plataforma no
/// permite elegir carpetas.
Future<String?> pickSaveDirectory() async {
  try {
    final directory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Elige dónde guardar reportes y respaldos',
    );
    if (directory == null) return null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(saveDirectoryKey, directory);
    return directory;
  } catch (_) {
    return null;
  }
}

/// Vuelve a usar el selector del sistema en cada guardado.
Future<void> clearSaveDirectory() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(saveDirectoryKey);
}
