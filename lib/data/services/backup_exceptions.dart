/// Lanzada cuando una copia de seguridad está protegida con frase y la
/// llamada a `scheduleRestore` no la incluye: la pantalla debe pedirla al
/// usuario y volver a intentarlo.
class BackupPassphraseRequired implements Exception {
  const BackupPassphraseRequired();

  @override
  String toString() => 'Esta copia está protegida con una frase de respaldo';
}
