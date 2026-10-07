import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final initialSettings = AppSettingsState.fromPrefs(prefs);
  runApp(
    ProviderScope(
      overrides: [
        initialSettingsProvider.overrideWithValue(initialSettings),
      ],
      child: const PolarisFinanceAppWrapper(),
    ),
  );
}