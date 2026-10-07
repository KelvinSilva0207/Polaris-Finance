import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router/app_router.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
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
      theme: AppTheme.dark(settings.accentColor),
      routerConfig: router,
    );
  }
}

class PolarisFinanceAppWrapper extends ConsumerStatefulWidget {
  const PolarisFinanceAppWrapper({super.key});

  @override
  ConsumerState<PolarisFinanceAppWrapper> createState() => _PolarisFinanceAppWrapperState();
}

class _PolarisFinanceAppWrapperState extends ConsumerState<PolarisFinanceAppWrapper> {
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    _loadFlag();
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
    final theme = AppTheme.dark(settings.accentColor);

    if (_onboardingDone == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
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
        home: OnboardingScreen(onDone: _finishOnboarding),
      );
    }
    return MaterialApp.router(
      title: 'Polaris Finance',
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: router,
    );
  }
}