import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_finance/features/settings/tips_data.dart';

void main() {
  final allTips = [for (final topic in financeTipTopics) ...topic.tips];

  test('el mismo día devuelve siempre el mismo consejo', () {
    final morning = DateTime(2026, 10, 22, 6, 30);
    final night = DateTime(2026, 10, 22, 23, 59);
    expect(tipOfTheDay(morning).title, tipOfTheDay(night).title);
  });

  test('cada día cambia el consejo', () {
    final today = DateTime(2026, 10, 22);
    final tomorrow = DateTime(2026, 10, 23);
    expect(tipOfTheDay(today).title, isNot(tipOfTheDay(tomorrow).title));
  });

  test('recorre todo el catálogo antes de repetir', () {
    final start = DateTime(2026, 1, 1);
    final seen = <String>{};
    for (var day = 0; day < allTips.length; day++) {
      seen.add(tipOfTheDay(start.add(Duration(days: day))).title);
    }
    expect(seen.length, allTips.length);
    expect(
      tipOfTheDay(start.add(Duration(days: allTips.length))).title,
      tipOfTheDay(start).title,
    );
  });
}
