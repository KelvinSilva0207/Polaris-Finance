import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/settings/app_settings.dart';
import 'data/services/backup_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  try {
    await applyPendingRestore(prefs);
  } catch (error) {
    debugPrint('No se pudo aplicar la restauración pendiente: $error');
  }
  final initialSettings = AppSettingsState.fromPrefs(prefs);
  runApp(
    ProviderScope(
      overrides: [initialSettingsProvider.overrideWithValue(initialSettings)],
      child: const PolarisFinanceAppWrapper(),
    ),
  );
}
