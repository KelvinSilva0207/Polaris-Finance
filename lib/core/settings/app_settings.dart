import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/enums.dart';
import '../feature_module.dart';

const _moduleKeyPrefix = 'module_';
const _accentKey = 'accent_color';
const _providerKey = 'rate_provider';
const _hideBalancesKey = 'hide_balances';
const _themeModeKey = 'theme_mode';
const _remindersKey = 'reminders_enabled';
const _dashboardOrderKey = 'dashboard_order';

/// Secciones del dashboard que el usuario puede reordenar.
const dashboardSectionIds = <String>[
  'summary',
  'accounts',
  'services',
  'goals',
  'loans',
  'recent',
];

final initialSettingsProvider = Provider<AppSettingsState>((ref) {
  throw UnimplementedError('Debe sobrescribirse en ProviderScope');
});

final appSettingsProvider = NotifierProvider<AppSettingsController, AppSettingsState>(
  AppSettingsController.new,
);

class AppSettingsState {
  const AppSettingsState({
    this.enabledModules = FeatureModule.allIds,
    this.accentColorValue = 0xFF9C6BFF,
    this.referenceProvider = RateProvider.bcv,
    this.hideBalances = false,
    this.themeMode = ThemeMode.system,
    this.remindersEnabled = false,
    this.dashboardOrder = dashboardSectionIds,
  });

  static const defaults = AppSettingsState();

  final List<String> enabledModules;
  final int accentColorValue;
  final RateProvider referenceProvider;
  final bool hideBalances;
  final ThemeMode themeMode;
  final bool remindersEnabled;
  final List<String> dashboardOrder;

  Color get accentColor => Color(accentColorValue);

  bool isEnabled(String moduleId) => enabledModules.contains(moduleId);

  List<FeatureModule> get activeModules =>
      FeatureModule.all.where((m) => enabledModules.contains(m.id)).toList();

  factory AppSettingsState.fromPrefs(SharedPreferences prefs) {
    final enabled = <String>[
      for (final module in FeatureModule.all)
        if (module.core || (prefs.getBool('$_moduleKeyPrefix${module.id}') ?? true)) module.id,
    ];
    final themeName = prefs.getString(_themeModeKey);
    final storedOrder = prefs.getStringList(_dashboardOrderKey) ?? const [];
    return AppSettingsState(
      enabledModules: enabled,
      accentColorValue: prefs.getInt(_accentKey) ?? defaults.accentColorValue,
      referenceProvider: RateProvider.fromStorage(prefs.getString(_providerKey)),
      hideBalances: prefs.getBool(_hideBalancesKey) ?? false,
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == themeName,
        orElse: () => ThemeMode.system,
      ),
      remindersEnabled: prefs.getBool(_remindersKey) ?? false,
      dashboardOrder: [
        for (final id in storedOrder)
          if (dashboardSectionIds.contains(id)) id,
        for (final id in dashboardSectionIds)
          if (!storedOrder.contains(id)) id,
      ],
    );
  }

  AppSettingsState copyWith({
    List<String>? enabledModules,
    int? accentColorValue,
    RateProvider? referenceProvider,
    bool? hideBalances,
    ThemeMode? themeMode,
    bool? remindersEnabled,
    List<String>? dashboardOrder,
  }) {
    return AppSettingsState(
      enabledModules: enabledModules ?? this.enabledModules,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      referenceProvider: referenceProvider ?? this.referenceProvider,
      hideBalances: hideBalances ?? this.hideBalances,
      themeMode: themeMode ?? this.themeMode,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      dashboardOrder: dashboardOrder ?? this.dashboardOrder,
    );
  }
}

class AppSettingsController extends Notifier<AppSettingsState> {
  @override
  AppSettingsState build() => ref.watch(initialSettingsProvider);

  Future<void> toggleModule(String moduleId) async {
    if (FeatureModule.all.any((m) => m.id == moduleId && m.core)) return;
    final prefs = await SharedPreferences.getInstance();
    final enabled = {...state.enabledModules};
    if (!enabled.remove(moduleId)) enabled.add(moduleId);
    final ordered = [
      for (final module in FeatureModule.all)
        if (module.core || enabled.contains(module.id)) module.id,
    ];
    state = state.copyWith(enabledModules: ordered);
    await prefs.setBool('$_moduleKeyPrefix$moduleId', enabled.contains(moduleId));
  }

  Future<void> setAccentColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(accentColorValue: color.toARGB32());
    await prefs.setInt(_accentKey, color.toARGB32());
  }

  Future<void> setReferenceProvider(RateProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(referenceProvider: provider);
    await prefs.setString(_providerKey, provider.name);
  }

  Future<void> setHideBalances(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(hideBalances: value);
    await prefs.setBool(_hideBalancesKey, value);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(themeMode: mode);
    await prefs.setString(_themeModeKey, mode.name);
  }

  Future<void> setRemindersEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(remindersEnabled: value);
    await prefs.setBool(_remindersKey, value);
  }

  Future<void> setDashboardOrder(List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    final valid = [
      for (final id in order)
        if (dashboardSectionIds.contains(id)) id,
    ];
    state = state.copyWith(dashboardOrder: valid);
    await prefs.setStringList(_dashboardOrderKey, valid);
  }
}