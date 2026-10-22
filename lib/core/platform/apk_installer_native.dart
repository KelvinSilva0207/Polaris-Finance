import 'package:flutter/services.dart';

/// Canal nativo para instalar el APK descargado (solo Android).
const MethodChannel apkInstallerChannel = MethodChannel(
  'polaris_finance/update',
);

/// Abre el instalador del sistema con el APK de [path].
///
/// Devuelve `false` si la plataforma no lo soporta o si el sistema no tiene
/// un instalador de paquetes disponible.
Future<bool> installApk(String path) async {
  try {
    final installed = await apkInstallerChannel.invokeMethod<bool>(
      'installApk',
      <String, Object?>{'path': path},
    );
    return installed ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}
