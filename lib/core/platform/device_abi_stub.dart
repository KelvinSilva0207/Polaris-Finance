/// Version web (y cualquier plataforma sin `dart:ffi`): no se puede detectar la
/// arquitectura, asi que se devuelve `null` y se usa el APK universal.
String? currentDeviceAbi() => null;
