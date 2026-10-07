import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';

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