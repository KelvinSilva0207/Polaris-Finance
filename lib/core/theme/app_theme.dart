import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_fonts.dart';

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

  // Tema claro suave: evita el blanco puro para descansar la vista.
  static const lightBackground = Color(0xFFF5F7FA);
  static const lightSurface = Color(0xFFF9FAFC);
  static const lightInput = Color(0xFFEDF1F7);
  static const lightBorder = Color(0xFFE0E6EF);

  /// Aplica la tipografía elegida sobre un tema base. [family] null mantiene la
  /// fuente del sistema.
  static ThemeData _withFont(ThemeData base, String? family) {
    if (family == null) return base;
    if (family == AppFonts.customFamily) {
      return base.copyWith(
        textTheme: base.textTheme.apply(fontFamily: family),
        primaryTextTheme: base.primaryTextTheme.apply(fontFamily: family),
      );
    }
    return base.copyWith(
      textTheme: GoogleFonts.getTextTheme(family, base.textTheme),
      primaryTextTheme: GoogleFonts.getTextTheme(family, base.primaryTextTheme),
    );
  }

  static ThemeData dark(
    Color seed, {
    String? fontFamily,
    Color? secondary,
    Color? background,
    Color? panel,
  }) {
    final base = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    final canvas = background ?? AppTheme.background;
    final panelBase = panel ?? Color.alphaBlend(
      Colors.white.withValues(alpha: 0.035),
      canvas,
    );
    final raised = panelBase;
    final elevated = panel == null
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.06), canvas)
        : Color.alphaBlend(Colors.white.withValues(alpha: 0.02), panelBase);
    final line = Color.alphaBlend(Colors.white.withValues(alpha: 0.12), canvas);
    final scheme = base.copyWith(
      primary: seed,
      secondary: secondary ?? base.secondary,
      surface: elevated,
      surfaceContainerLowest: canvas,
      surfaceContainerLow: raised,
      surfaceContainer: elevated,
      surfaceContainerHigh: Color.alphaBlend(
        Colors.white.withValues(alpha: 0.08),
        canvas,
      ),
      surfaceContainerHighest: raised,
      outlineVariant: line,
    );
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      pageTransitionsTheme: _pageTransitions,
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: raised,
        indicatorColor: scheme.primary.withValues(alpha: 0.24),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: raised,
        indicatorColor: scheme.primary.withValues(alpha: 0.24),
      ),
      cardTheme: CardThemeData(
        color: elevated,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dividerTheme: DividerThemeData(color: line),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
      ),
      dialogTheme: DialogThemeData(backgroundColor: elevated),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color.alphaBlend(
          Colors.white.withValues(alpha: 0.08),
          canvas,
        ),
        contentTextStyle: TextStyle(color: scheme.onSurface),
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

  static ThemeData light(
    Color seed, {
    String? fontFamily,
    Color? secondary,
    Color? panel,
  }) {
    final base = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    final surface = panel ?? lightSurface;
    final scheme = base.copyWith(
      primary: seed,
      secondary: secondary ?? base.secondary,
      surface: surface,
      surfaceContainerLowest: lightBackground,
      surfaceContainerLow: surface,
      surfaceContainer: lightInput,
      surfaceContainerHigh: lightInput,
      surfaceContainerHighest: lightInput,
      outlineVariant: lightBorder,
    );
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: lightBackground,
      pageTransitionsTheme: _pageTransitions,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ).copyWith(indicatorColor: scheme.primary.withValues(alpha: 0.16)),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
      ).copyWith(indicatorColor: scheme.primary.withValues(alpha: 0.16)),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dividerTheme: const DividerThemeData(color: lightBorder),
      dialogTheme: DialogThemeData(backgroundColor: surface),
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
