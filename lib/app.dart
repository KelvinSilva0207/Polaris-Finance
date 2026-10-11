import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/reminders/reminder_providers.dart';
import 'core/router/app_router.dart';
import 'core/security/app_lock.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'features/lock/lock_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

const onboardingDoneKey = 'onboarding_done';

class PolarisFinanceApp extends ConsumerWidget {
  const PolarisFinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Polaris Finance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(settings.accentColor),
      darkTheme: AppTheme.dark(settings.accentColor),
      themeMode: settings.themeMode,
      routerConfig: router,
    );
  }
}

class PolarisFinanceAppWrapper extends ConsumerStatefulWidget {
  const PolarisFinanceAppWrapper({super.key});

  @override
  ConsumerState<PolarisFinanceAppWrapper> createState() => _PolarisFinanceAppWrapperState();
}

class _PolarisFinanceAppWrapperState extends ConsumerState<PolarisFinanceAppWrapper>
    with WidgetsBindingObserver {
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFlag();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(appLockProvider.notifier).lock();
    }
  }

  Future<void> _loadFlag() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _onboardingDone = prefs.getBool(onboardingDoneKey) ?? false);
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingDoneKey, true);
    if (!mounted) return;
    setState(() => _onboardingDone = true);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final router = ref.watch(appRouterProvider);
    final theme = AppTheme.light(settings.accentColor);
    final darkTheme = AppTheme.dark(settings.accentColor);
    final themeMode = settings.themeMode;
    ref.watch(reminderSyncProvider);

    if (_onboardingDone == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_onboardingDone == false) {
      return MaterialApp(
        title: 'Polaris Finance',
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        home: OnboardingScreen(onDone: _finishOnboarding),
      );
    }
    final lock = ref.watch(appLockProvider);
    if (lock.requiresUnlock) {
      return MaterialApp(
        title: 'Polaris Finance',
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        home: const LockScreen(),
      );
    }
    return MaterialApp.router(
      title: 'Polaris Finance',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}