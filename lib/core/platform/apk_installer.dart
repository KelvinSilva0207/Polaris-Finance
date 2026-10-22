// Lanza el instalador del sistema para un APK ya descargado.
//
// Usa importacion condicional porque web no puede instalar APKs: en ese caso
// la funcion devuelve `false` y la app ofrece la descarga por el navegador.
export 'apk_installer_stub.dart'
    if (dart.library.io) 'apk_installer_native.dart';
