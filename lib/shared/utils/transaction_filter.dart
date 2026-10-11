import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';

/// Convierte el texto almacenado en [Transaction.tags] (separado por comas) en
/// una lista limpia de etiquetas.
List<String> parseTags(String? raw) {
  if (raw == null) return const [];
  return [
    for (final part in raw.split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ];
}

/// Etiquetas únicas presentes en [transactions], ordenadas alfabéticamente. La
/// comparación no distingue mayúsculas (se conserva la primera grafía vista).
List<String> allTags(Iterable<Transaction> transactions) {
  final byLower = <String, String>{};
  for (final transaction in transactions) {
    for (final tag in parseTags(transaction.tags)) {
      byLower.putIfAbsent(tag.toLowerCase(), () => tag);
    }
  }
  return byLower.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

/// Filtra movimientos por texto (nota o etiqueta), etiquetas y tipo.
///
/// El texto se compara sin distinguir mayúsculas. Si se pasan varias
/// [tags], basta con que el movimiento tenga alguna (OR).
List<Transaction> filterTransactions(
  Iterable<Transaction> transactions, {
  String query = '',
  Set<String> tags = const {},
  TransactionType? type,
}) {
  final needle = query.trim().toLowerCase();
  final result = <Transaction>[];
  for (final transaction in transactions) {
    if (type != null && TransactionType.fromStorage(transaction.type) != type) {
      continue;
    }
    final transactionTags = parseTags(transaction.tags);
    if (tags.isNotEmpty) {
      final transactionLower =
          transactionTags.map((tag) => tag.toLowerCase()).toSet();
      final selectedLower = tags.map((tag) => tag.toLowerCase()).toSet();
      if (!transactionLower.any(selectedLower.contains)) continue;
    }
    if (needle.isNotEmpty) {
      final note = (transaction.note ?? '').toLowerCase();
      final matchesNote = note.contains(needle);
      final matchesTag =
          transactionTags.any((tag) => tag.toLowerCase().contains(needle));
      if (!matchesNote && !matchesTag) continue;
    }
    result.add(transaction);
  }
  return result;
}
