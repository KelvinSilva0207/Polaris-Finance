import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_finance/core/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('orden por defecto cuando no hay nada guardado', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AppSettingsState.fromPrefs(prefs);
    expect(state.dashboardOrder, dashboardSectionIds);
  });

  test('respeta el orden guardado y conserva el resto', () async {
    SharedPreferences.setMockInitialValues({
      'dashboard_order': ['recent', 'summary', 'accounts'],
    });
    final prefs = await SharedPreferences.getInstance();
    final state = AppSettingsState.fromPrefs(prefs);
    expect(state.dashboardOrder, [
      'recent',
      'summary',
      'accounts',
      'services',
      'goals',
      'loans',
    ]);
  });

  test('ignora identificadores desconocidos', () async {
    SharedPreferences.setMockInitialValues({
      'dashboard_order': ['recent', 'desconocido', 'summary'],
    });
    final prefs = await SharedPreferences.getInstance();
    final state = AppSettingsState.fromPrefs(prefs);
    expect(state.dashboardOrder.first, 'recent');
    expect(state.dashboardOrder, isNot(contains('desconocido')));
    expect(state.dashboardOrder.toSet(), dashboardSectionIds.toSet());
  });
}