import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// En web la descarga es inmediata; existe por compatibilidad de API.
class SaveCanceledException implements Exception {
  const SaveCanceledException();

  @override
  String toString() => 'Guardado cancelado';
}

Future<String> saveBackupFile(String filename, List<int> bytes) async {
  final data = Uint8List.fromList(bytes);
  final blob = web.Blob(
    [data.toJS].toJS,
    web.BlobPropertyBag(type: 'application/octet-stream'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
  return filename;
}
