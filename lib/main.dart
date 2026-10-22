import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/security/app_lock.dart';
import 'core/settings/app_settings.dart';
import 'data/services/backup_service.dart';
import 'data/sync/sync_config.dart';
import 'data/sync/sync_providers.dart';

/// DSN opcional inyectado en tiempo de compilación:
/// `flutter build apk --dart-define=SENTRY_DSN=https://...`.
/// Si está vacío la app funciona igual, pero sin telemetría de errores.
const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  try {
    await applyPendingRestore(prefs);
  } catch (error) {
    debugPrint('No se pudo aplicar la restauración pendiente: $error');
  }
  final initialSettings = AppSettingsState.fromPrefs(prefs);
  final initialLock = AppLockState.fromPrefs(prefs);
  final initialSync = await SyncConfig.load(prefs);

  void run() {
    runApp(
      ProviderScope(
        overrides: [
          initialSettingsProvider.overrideWithValue(initialSettings),
          initialAppLockProvider.overrideWithValue(initialLock),
          initialSyncConfigProvider.overrideWithValue(initialSync),
        ],
        child: const PolarisFinanceAppWrapper(),
      ),
    );
  }

  if (_sentryDsn.isEmpty) {
    _installFallbackErrorHandlers();
    run();
    return;
  }

  await SentryFlutter.init((options) {
    options.dsn = _sentryDsn;
    options.environment = kReleaseMode ? 'production' : 'debug';
    options.release = 'polaris-finance@1.0.0';
    options.tracesSampleRate = 0.1;
    options.sendDefaultPii = false;
    options.attachScreenshot = false;
  }, appRunner: run);
}

/// Sin DSN, al menos registra los errores no capturados en la consola para
/// que no pasen desapercibidos durante el desarrollo.
void _installFallbackErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Error no capturado: $error\n$stack');
    return true;
  };
}
