import 'package:flutter/material.dart';

/// A selectable accent color for the app. Each one generates a full
/// Material 3 tonal palette (for both light and dark) from a single seed
/// color via [ColorScheme.fromSeed].
enum AppThemeColor {
  purple,
  blue,
  red,
  teal,
  amber;

  Color get seed {
    switch (this) {
      case AppThemeColor.purple:
        return const Color(0xFF6C5CE7);
      case AppThemeColor.blue:
        return const Color(0xFF2E86FF);
      case AppThemeColor.red:
        return const Color(0xFFE53946);
      case AppThemeColor.teal:
        return const Color(0xFF00BFA6);
      case AppThemeColor.amber:
        return const Color(0xFFFF9F1C);
    }
  }

  String get label {
    switch (this) {
      case AppThemeColor.purple:
        return 'Violet';
      case AppThemeColor.blue:
        return 'Ocean';
      case AppThemeColor.red:
        return 'Cinema Red';
      case AppThemeColor.teal:
        return 'Emerald';
      case AppThemeColor.amber:
        return 'Amber';
    }
  }

  String get storageKey => name;

  static AppThemeColor fromKey(String? key) {
    return AppThemeColor.values.firstWhere(
      (c) => c.storageKey == key,
      orElse: () => AppThemeColor.purple,
    );
  }
}

extension ThemeModeStorage on ThemeMode {
  String get storageKey {
    switch (this) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode fromKey(String? key) {
    switch (key) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }
}

class ThemeSettings {
  final AppThemeColor color;
  final ThemeMode mode;

  /// Opacity of the black tint drawn over the fixed backdrop image on
  /// movie/show detail pages. Defaults to 0.5 (50%).
  final double backdropOverlayOpacity;

  const ThemeSettings({
    required this.color,
    required this.mode,
    this.backdropOverlayOpacity = 0.5,
  });

  ThemeSettings copyWith({
    AppThemeColor? color,
    ThemeMode? mode,
    double? backdropOverlayOpacity,
  }) {
    return ThemeSettings(
      color: color ?? this.color,
      mode: mode ?? this.mode,
      backdropOverlayOpacity:
          backdropOverlayOpacity ?? this.backdropOverlayOpacity,
    );
  }
}

ThemeData buildAppTheme(AppThemeColor color, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: color.seed,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    extensions: <ThemeExtension<dynamic>>[AppColors.fromScheme(scheme)],
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHighest,
    ),
  );
}

/// Semantic color tokens for the app, derived from the active
/// [ColorScheme]. Widgets read these through [AppThemeContext] instead
/// of hardcoding white/black values, so changing the theme later only
/// ever means editing this file.
class AppColors extends ThemeExtension<AppColors> {
  /// Primary text on app surfaces (was white70).
  final Color textPrimary;

  /// Secondary text on app surfaces (was white54).
  final Color textSecondary;

  /// Hint / tertiary text and icons on app surfaces (was white38).
  final Color textHint;

  /// Subtle fill for placeholders and avatars (was white10).
  final Color surfaceSubtle;

  /// Subtle border / divider color (was white12).
  final Color borderSubtle;

  /// Panel fill for cards and progress tracks (was white at 0.05/0.06).
  final Color surfacePanel;

  /// Tinted background for selected items (was primary at 0.18 alpha).
  final Color selectionTint;

  /// Accent color for icons and highlights (was hardcoded light purple).
  final Color accent;

  const AppColors({
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.surfaceSubtle,
    required this.borderSubtle,
    required this.surfacePanel,
    required this.selectionTint,
    required this.accent,
  });

  factory AppColors.fromScheme(ColorScheme scheme) {
    return AppColors(
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      textHint: scheme.onSurfaceVariant.withValues(alpha: 0.65),
      surfaceSubtle: scheme.surfaceContainerHighest,
      borderSubtle: scheme.outlineVariant,
      surfacePanel: scheme.surfaceContainerHighest,
      selectionTint: scheme.primary.withValues(alpha: 0.18),
      accent: scheme.primary,
    );
  }

  @override
  AppColors copyWith({
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
    Color? surfaceSubtle,
    Color? borderSubtle,
    Color? surfacePanel,
    Color? selectionTint,
    Color? accent,
  }) {
    return AppColors(
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textHint: textHint ?? this.textHint,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      surfacePanel: surfacePanel ?? this.surfacePanel,
      selectionTint: selectionTint ?? this.selectionTint,
      accent: accent ?? this.accent,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      surfacePanel: Color.lerp(surfacePanel, other.surfacePanel, t)!,
      selectionTint: Color.lerp(selectionTint, other.selectionTint, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
