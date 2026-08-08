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
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
    ),
  );
}
