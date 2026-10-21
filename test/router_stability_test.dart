import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaris_finance/core/router/app_router.dart';
import 'package:polaris_finance/core/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('cambiar un ajuste que no sea módulos no recrea el router', () async {
    final container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(AppSettingsState.defaults),
      ],
    );
    addTearDown(container.dispose);

    final routerBefore = container.read(appRouterProvider);
    final controller = container.read(appSettingsProvider.notifier);

    await controller.setAccentColor(const Color(0xFF00BCD4));
    await controller.setFontId('jakarta');
    await controller.setThemeMode(ThemeMode.dark);
    await controller.setHideBalances(true);

    expect(identical(container.read(appRouterProvider), routerBefore), isTrue);
  });

  test('cambiar los módulos activos sí recrea el router', () async {
    final container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(AppSettingsState.defaults),
      ],
    );
    addTearDown(container.dispose);

    final routerBefore = container.read(appRouterProvider);
    await container.read(appSettingsProvider.notifier).toggleModule('loans');
    final routerAfter = container.read(appRouterProvider);

    expect(identical(routerAfter, routerBefore), isFalse);
  });
}
