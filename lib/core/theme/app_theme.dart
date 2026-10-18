import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Transición de página (para `MaterialPageRoute`): fundido + deslizamiento
/// corto, en todas las plataformas y respetando ajustes de accesibilidad.
class FadeSlideTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlideTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

const _pageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: FadeSlideTransitionsBuilder(),
    TargetPlatform.iOS: FadeSlideTransitionsBuilder(),
    TargetPlatform.windows: FadeSlideTransitionsBuilder(),
    TargetPlatform.linux: FadeSlideTransitionsBuilder(),
    TargetPlatform.macOS: FadeSlideTransitionsBuilder(),
    TargetPlatform.fuchsia: FadeSlideTransitionsBuilder(),
  },
);

abstract final class AppTheme {
  static const background = Color(0xFF0B0E14);
  static const surface = Color(0xFF12151D);
  static const surfaceHigh = Color(0xFF161B26);
  static const border = Color(0xFF232A3A);

  /// Aplica la tipografía elegida sobre un tema base. [family] null mantiene la
  /// fuente del sistema.
  static ThemeData _withFont(ThemeData base, String? family) {
    if (family == null) return base;
    return base.copyWith(
      textTheme: GoogleFonts.getTextTheme(family, base.textTheme),
      primaryTextTheme: GoogleFonts.getTextTheme(family, base.primaryTextTheme),
    );
  }

  static ThemeData dark(Color seed, {String? fontFamily}) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ).copyWith(
          surface: surfaceHigh,
          surfaceContainerLowest: background,
          surfaceContainerLow: surface,
          surfaceContainer: surfaceHigh,
          surfaceContainerHigh: const Color(0xFF1B2130),
          surfaceContainerHighest: surface,
          outlineVariant: border,
        );
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      pageTransitionsTheme: _pageTransitions,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.24),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.24),
      ),
      cardTheme: CardThemeData(
        color: surfaceHigh,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dividerTheme: const DividerThemeData(color: border),
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white70,
        textColor: Colors.white,
      ),
      dialogTheme: const DialogThemeData(backgroundColor: surfaceHigh),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E2635),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
    return _withFont(theme, fontFamily);
  }

  static ThemeData light(Color seed, {String? fontFamily}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      pageTransitionsTheme: _pageTransitions,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      dialogTheme: DialogThemeData(backgroundColor: scheme.surfaceContainerLow),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
    return _withFont(theme, fontFamily);
  }
}
