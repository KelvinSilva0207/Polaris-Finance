import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/settings/save_location.dart';

/// El usuario cerró el selector de archivos sin elegir destino.
class SaveCanceledException implements Exception {
  const SaveCanceledException();

  @override
  String toString() => 'Guardado cancelado';
}

/// Abre el selector del sistema y guarda [bytes] donde el usuario elija.
///
/// En Android/iOS se usa el selector de documentos (SAF), que escribe los
/// bytes directamente. En escritorio se escribe con `dart:io` sobre la ruta
/// devuelta. Si el selector no está disponible se cae a la carpeta de
/// documentos de la app para no perder la exportación.
Future<String> saveBackupFile(String filename, List<int> bytes) async {
  final data = Uint8List.fromList(bytes);
  Uri? target;
  var pickerFailed = false;
  final initialDirectory = await preferredSaveDirectory();
  try {
    target = await FilePicker.saveFile(
      dialogTitle: 'Guardar $filename',
      fileName: filename,
      type: FileType.any,
      bytes: data,
      initialDirectory: initialDirectory,
    );
  } catch (_) {
    pickerFailed = true;
  }

  if (target == null) {
    if (!pickerFailed) throw const SaveCanceledException();
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(data, flush: true);
    return file.path;
  }

  if (target.isScheme('file')) {
    final file = File(target.toFilePath());
    if (!await file.exists() || await file.length() != data.length) {
      await file.writeAsBytes(data, flush: true);
    }
    return file.path;
  }
  return target.toString();
}
