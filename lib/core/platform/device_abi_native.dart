import 'dart:ffi';

/// Arquitectura del dispositivo en el formato que usa el manifiesto de
/// versiones (`arm64-v8a`, `armeabi-v7a`, `x86_64`).
///
/// Devuelve `null` en plataformas que no son Android o cuya ABI no esta
/// contemplada, en cuyo caso se debe usar el APK universal.
String? currentDeviceAbi() {
  final abi = Abi.current();
  if (abi == Abi.androidArm64) return 'arm64-v8a';
  if (abi == Abi.androidArm) return 'armeabi-v7a';
  if (abi == Abi.androidIA32) return 'armeabi-v7a';
  if (abi == Abi.androidX64) return 'x86_64';
  if (abi == Abi.androidRiscv64) return 'riscv64';
  return null;
}
