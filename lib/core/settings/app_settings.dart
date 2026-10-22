import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/enums.dart';
import '../feature_module.dart';
import '../theme/app_fonts.dart';

const _moduleKeyPrefix = 'module_';
const _accentKey = 'accent_color';
const _secondaryColorKey = 'secondary_color';
const _backgroundColorKey = 'background_color';
const _profileNameKey = 'profile_name';
const _profileAvatarKey = 'profile_avatar';
const _customFontNameKey = 'custom_font_name';
const _notifyUpdatesKey = 'notify_updates';
const _providerKey = 'rate_provider';
const _hideBalancesKey = 'hide_balances';
const _themeModeKey = 'theme_mode';
const _remindersKey = 'reminders_enabled';
const _reminderHourKey = 'reminder_hour';
const _reminderDaysBeforeKey = 'reminder_days_before';
const _notifyServicesKey = 'notify_services';
const _notifyLoansKey = 'notify_loans';
const _fontKey = 'font_family';
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

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettingsState>(
      AppSettingsController.new,
    );

/// Módulos activos aislados del resto de ajustes (tema, tipografía, colores).
///
/// El router depende solo de esta lista, de modo que cambiar cualquier otro
/// ajuste no recrea el [GoRouter] ni reinicia la navegación.
final activeModuleIdsProvider = Provider<List<String>>(
  (ref) => ref.watch(appSettingsProvider.select((s) => s.enabledModules)),
  dependencies: const [],
);

class AppSettingsState {
  const AppSettingsState({
    this.enabledModules = FeatureModule.allIds,
    this.accentColorValue = 0xFF9C6BFF,
    this.secondaryColorValue = 0xFF00BCD4,
    this.backgroundColorValue = 0xFF0B0E14,
    this.referenceProvider = RateProvider.bcv,
    this.hideBalances = false,
    this.themeMode = ThemeMode.system,
    this.remindersEnabled = false,
    this.reminderHour = 9,
    this.reminderDaysBefore = 1,
    this.notifyServices = true,
    this.notifyLoans = true,
    this.notifyUpdates = true,
    this.fontId = AppFonts.defaultId,
    this.customFontName = '',
    this.profileName = '',
    this.profileAvatar = '',
    this.dashboardOrder = dashboardSectionIds,
  });

  static const defaults = AppSettingsState();

  final List<String> enabledModules;
  final int accentColorValue;
  final int secondaryColorValue;
  final int backgroundColorValue;
  final RateProvider referenceProvider;
  final bool hideBalances;
  final ThemeMode themeMode;
  final bool remindersEnabled;
  final int reminderHour;
  final int reminderDaysBefore;
  final bool notifyServices;
  final bool notifyLoans;
  final bool notifyUpdates;
  final String fontId;
  final String customFontName;
  final String profileName;
  final String profileAvatar;
  final List<String> dashboardOrder;

  Color get accentColor => Color(accentColorValue);

  Color get secondaryColor => Color(secondaryColorValue);

  Color get backgroundColor => Color(backgroundColorValue);

  /// Familia tipográfica de Google Fonts a aplicar (null = fuente del sistema).
  String? get fontFamily => AppFonts.familyOf(fontId);

  bool isEnabled(String moduleId) => enabledModules.contains(moduleId);

  List<FeatureModule> get activeModules =>
      FeatureModule.all.where((m) => enabledModules.contains(m.id)).toList();

  factory AppSettingsState.fromPrefs(SharedPreferences prefs) {
    final enabled = <String>[
      for (final module in FeatureModule.all)
        if (module.core ||
            (prefs.getBool('$_moduleKeyPrefix${module.id}') ?? true))
          module.id,
    ];
    final themeName = prefs.getString(_themeModeKey);
    final storedOrder = prefs.getStringList(_dashboardOrderKey) ?? const [];
    return AppSettingsState(
      enabledModules: enabled,
      accentColorValue: prefs.getInt(_accentKey) ?? defaults.accentColorValue,
      secondaryColorValue:
          prefs.getInt(_secondaryColorKey) ?? defaults.secondaryColorValue,
      backgroundColorValue:
          prefs.getInt(_backgroundColorKey) ?? defaults.backgroundColorValue,
      referenceProvider: RateProvider.fromStorage(
        prefs.getString(_providerKey),
      ),
      hideBalances: prefs.getBool(_hideBalancesKey) ?? false,
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == themeName,
        orElse: () => ThemeMode.system,
      ),
      remindersEnabled: prefs.getBool(_remindersKey) ?? false,
      reminderHour: prefs.getInt(_reminderHourKey) ?? defaults.reminderHour,
      reminderDaysBefore:
          prefs.getInt(_reminderDaysBeforeKey) ?? defaults.reminderDaysBefore,
      notifyServices: prefs.getBool(_notifyServicesKey) ?? true,
      notifyLoans: prefs.getBool(_notifyLoansKey) ?? true,
      notifyUpdates: prefs.getBool(_notifyUpdatesKey) ?? true,
      fontId: prefs.getString(_fontKey) ?? AppFonts.defaultId,
      customFontName: prefs.getString(_customFontNameKey) ?? '',
      profileName: prefs.getString(_profileNameKey) ?? '',
      profileAvatar: prefs.getString(_profileAvatarKey) ?? '',
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
    int? secondaryColorValue,
    int? backgroundColorValue,
    RateProvider? referenceProvider,
    bool? hideBalances,
    ThemeMode? themeMode,
    bool? remindersEnabled,
    int? reminderHour,
    int? reminderDaysBefore,
    bool? notifyServices,
    bool? notifyLoans,
    bool? notifyUpdates,
    String? fontId,
    String? customFontName,
    String? profileName,
    String? profileAvatar,
    List<String>? dashboardOrder,
  }) {
    return AppSettingsState(
      enabledModules: enabledModules ?? this.enabledModules,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      secondaryColorValue: secondaryColorValue ?? this.secondaryColorValue,
      backgroundColorValue: backgroundColorValue ?? this.backgroundColorValue,
      referenceProvider: referenceProvider ?? this.referenceProvider,
      hideBalances: hideBalances ?? this.hideBalances,
      themeMode: themeMode ?? this.themeMode,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      notifyServices: notifyServices ?? this.notifyServices,
      notifyLoans: notifyLoans ?? this.notifyLoans,
      notifyUpdates: notifyUpdates ?? this.notifyUpdates,
      fontId: fontId ?? this.fontId,
      customFontName: customFontName ?? this.customFontName,
      profileName: profileName ?? this.profileName,
      profileAvatar: profileAvatar ?? this.profileAvatar,
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
    await prefs.setBool(
      '$_moduleKeyPrefix$moduleId',
      enabled.contains(moduleId),
    );
  }

  Future<void> setAccentColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(accentColorValue: color.toARGB32());
    await prefs.setInt(_accentKey, color.toARGB32());
  }

  Future<void> setSecondaryColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(secondaryColorValue: color.toARGB32());
    await prefs.setInt(_secondaryColorKey, color.toARGB32());
  }

  Future<void> setBackgroundColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(backgroundColorValue: color.toARGB32());
    await prefs.setInt(_backgroundColorKey, color.toARGB32());
  }

  Future<void> setProfileName(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final name = value.trim();
    state = state.copyWith(profileName: name);
    await prefs.setString(_profileNameKey, name);
  }

  Future<void> setProfileAvatar(String base64Image) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(profileAvatar: base64Image);
    await prefs.setString(_profileAvatarKey, base64Image);
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

  Future<void> setReminderHour(int value) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(reminderHour: value);
    await prefs.setInt(_reminderHourKey, value);
  }

  Future<void> setReminderDaysBefore(int value) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(reminderDaysBefore: value);
    await prefs.setInt(_reminderDaysBeforeKey, value);
  }

  Future<void> setNotifyServices(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(notifyServices: value);
    await prefs.setBool(_notifyServicesKey, value);
  }

  Future<void> setNotifyLoans(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(notifyLoans: value);
    await prefs.setBool(_notifyLoansKey, value);
  }

  Future<void> setNotifyUpdates(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(notifyUpdates: value);
    await prefs.setBool(_notifyUpdatesKey, value);
  }

  Future<void> setFontId(String value) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(fontId: value);
    await prefs.setString(_fontKey, value);
  }

  Future<void> setCustomFontName(String value) async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(customFontName: value);
    await prefs.setString(_customFontNameKey, value);
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
