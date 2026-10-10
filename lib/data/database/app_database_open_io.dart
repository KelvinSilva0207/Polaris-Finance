import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

AppDatabase openAppDatabase() {
  return AppDatabase(
    driftDatabase(
      name: 'polaris_finance',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
      native: DriftNativeOptions(databaseDirectory: _databaseDirectory),
    ),
  );
}

/// Guarda la base de datos dentro de la carpeta de datos de la app
/// (AppData en Windows) en lugar de Documentos, y migra una vez el archivo
/// antiguo si existía en Documentos.
Future<Directory> _databaseDirectory() async {
  final support = await getApplicationSupportDirectory();
  final sep = Platform.pathSeparator;
  final directory = Directory('${support.path}${sep}polaris_finance');
  await directory.create(recursive: true);

  final newFile = File('${directory.path}${sep}polaris_finance.sqlite');
  if (!await newFile.exists()) {
    final documents = await getApplicationDocumentsDirectory();
    final legacy = File('${documents.path}${sep}polaris_finance.sqlite');
    if (await legacy.exists()) {
      await legacy.copy(newFile.path);
    }
  }
  return directory;
}
