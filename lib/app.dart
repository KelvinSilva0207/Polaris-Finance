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
import 'features/onboarding/tutorial_screen.dart';
import 'features/splash/splash_screen.dart';

const onboardingDoneKey = 'onboarding_done';
const tutorialDoneKey = 'tutorial_done';

class PolarisFinanceApp extends ConsumerWidget {
  const PolarisFinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Polaris Finance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(
        settings.accentColor,
        fontFamily: settings.fontFamily,
        secondary: settings.secondaryColor,
      ),
      darkTheme: AppTheme.dark(
        settings.accentColor,
        fontFamily: settings.fontFamily,
        secondary: settings.secondaryColor,
        background: settings.backgroundColor,
      ),
      themeMode: settings.themeMode,
      routerConfig: router,
    );
  }
}

class PolarisFinanceAppWrapper extends ConsumerStatefulWidget {
  const PolarisFinanceAppWrapper({super.key});

  @override
  ConsumerState<PolarisFinanceAppWrapper> createState() =>
      _PolarisFinanceAppWrapperState();
}

class _PolarisFinanceAppWrapperState
    extends ConsumerState<PolarisFinanceAppWrapper>
    with WidgetsBindingObserver {
  bool? _onboardingDone;
  bool? _tutorialDone;
  bool _splashDone = false;

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
    setState(() {
      _onboardingDone = prefs.getBool(onboardingDoneKey) ?? false;
      _tutorialDone = prefs.getBool(tutorialDoneKey) ?? false;
    });
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingDoneKey, true);
    if (!mounted) return;
    setState(() => _onboardingDone = true);
  }

  Future<void> _finishTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(tutorialDoneKey, true);
    if (!mounted) return;
    setState(() => _tutorialDone = true);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final router = ref.watch(appRouterProvider);
    final theme = AppTheme.light(
      settings.accentColor,
      fontFamily: settings.fontFamily,
      secondary: settings.secondaryColor,
    );
    final darkTheme = AppTheme.dark(
      settings.accentColor,
      fontFamily: settings.fontFamily,
      secondary: settings.secondaryColor,
      background: settings.backgroundColor,
    );
    final themeMode = settings.themeMode;
    ref.watch(reminderSyncProvider);

    Widget shell(Widget home) => MaterialApp(
      title: 'Polaris Finance',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home: home,
    );

    if (_onboardingDone == null || _tutorialDone == null) {
      return shell(
        const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    if (!_splashDone) {
      return shell(
        SplashScreen(onDone: () => setState(() => _splashDone = true)),
      );
    }
    if (_onboardingDone == false) {
      return shell(OnboardingScreen(onDone: _finishOnboarding));
    }
    if (_tutorialDone == false) {
      return shell(TutorialScreen(onDone: _finishTutorial));
    }
    final lock = ref.watch(appLockProvider);
    if (lock.requiresUnlock) {
      return shell(const LockScreen());
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
