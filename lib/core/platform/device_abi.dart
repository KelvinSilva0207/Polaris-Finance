// Detecta la arquitectura (ABI) del dispositivo para elegir el APK correcto.
//
// Usa importacion condicional porque `dart:ffi` no existe en web: la version
// web devuelve siempre `null` y la app usa el APK universal.
export 'device_abi_stub.dart' if (dart.library.ffi) 'device_abi_native.dart';
