import 'package:flutter/material.dart';

class PremiumThemePreset {
  const PremiumThemePreset({
    required this.key,
    required this.name,
    required this.nameBn,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.heroColors,
  });

  final String key;
  final String name;
  final String nameBn;
  final Color primary;
  final Color secondary;
  final Color accent;
  final List<Color> heroColors;

  LinearGradient get heroGradient => LinearGradient(
        colors: heroColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get premiumGradient => LinearGradient(
        colors: [primary, secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

class AppTheme {
  static const Color primary = Color(0xFF111827);
  static const Color primaryDark = Color(0xFF020617);
  static const Color secondary = Color(0xFF374151);
  static const Color accent = Color(0xFF2563EB);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF06B6D4);
  static const Color background = Color(0xFFF5F7FB);
  static const Color card = Colors.white;
  static const Color text = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color muted2 = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);

  static const List<PremiumThemePreset> presets = [
    PremiumThemePreset(
      key: 'mono_luxe',
      name: 'Mono Luxe',
      nameBn: 'Mono Luxe',
      primary: Color(0xFF111827),
      secondary: Color(0xFF4B5563),
      accent: Color(0xFF2563EB),
      heroColors: [Color(0xFF0B1120), Color(0xFF111827), Color(0xFF374151)],
    ),
    PremiumThemePreset(
      key: 'porcelain_blue',
      name: 'Porcelain Blue',
      nameBn: 'Porcelain Blue',
      primary: Color(0xFF2563EB),
      secondary: Color(0xFF60A5FA),
      accent: Color(0xFF0EA5E9),
      heroColors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF60A5FA)],
    ),
    PremiumThemePreset(
      key: 'forest_mint',
      name: 'Forest Mint',
      nameBn: 'Forest Mint',
      primary: Color(0xFF047857),
      secondary: Color(0xFF10B981),
      accent: Color(0xFF14B8A6),
      heroColors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF10B981)],
    ),
    PremiumThemePreset(
      key: 'ivory_gold',
      name: 'Ivory Gold',
      nameBn: 'Ivory Gold',
      primary: Color(0xFF92400E),
      secondary: Color(0xFFD97706),
      accent: Color(0xFF111827),
      heroColors: [Color(0xFF78350F), Color(0xFFB45309), Color(0xFFF59E0B)],
    ),
    PremiumThemePreset(
      key: 'navy_slate',
      name: 'Navy Slate',
      nameBn: 'Navy Slate',
      primary: Color(0xFF1E293B),
      secondary: Color(0xFF334155),
      accent: Color(0xFF38BDF8),
      heroColors: [Color(0xFF020617), Color(0xFF1E293B), Color(0xFF334155)],
    ),
    PremiumThemePreset(
      key: 'lavender_soft',
      name: 'Lavender Soft',
      nameBn: 'Lavender Soft',
      primary: Color(0xFF7C3AED),
      secondary: Color(0xFFA78BFA),
      accent: Color(0xFFEC4899),
      heroColors: [Color(0xFF4C1D95), Color(0xFF7C3AED), Color(0xFFA78BFA)],
    ),
    PremiumThemePreset(
      key: 'coral_pop',
      name: 'Coral Pop',
      nameBn: 'Coral Pop',
      primary: Color(0xFFF97316),
      secondary: Color(0xFFFB7185),
      accent: Color(0xFF7C3AED),
      heroColors: [Color(0xFF9A3412), Color(0xFFF97316), Color(0xFFFB7185)],
    ),
    PremiumThemePreset(
      key: 'royal_blue',
      name: 'Royal Blue',
      nameBn: 'Royal Blue',
      primary: Color(0xFF2563EB),
      secondary: Color(0xFF7C3AED),
      accent: Color(0xFFF97316),
      heroColors: [Color(0xFF0F172A), Color(0xFF1D4ED8), Color(0xFF7C3AED)],
    ),
    PremiumThemePreset(
      key: 'emerald_luxe',
      name: 'Emerald Luxe',
      nameBn: 'Emerald Luxe',
      primary: Color(0xFF059669),
      secondary: Color(0xFF0F766E),
      accent: Color(0xFFF59E0B),
      heroColors: [Color(0xFF052E2B), Color(0xFF059669), Color(0xFF14B8A6)],
    ),
    PremiumThemePreset(
      key: 'rose_neon',
      name: 'Rose Neon',
      nameBn: 'Rose Neon',
      primary: Color(0xFFEC4899),
      secondary: Color(0xFF8B5CF6),
      accent: Color(0xFF06B6D4),
      heroColors: [Color(0xFF4A044E), Color(0xFFEC4899), Color(0xFF8B5CF6)],
    ),
  ];

  static PremiumThemePreset preset(String? key) {
    return presets.firstWhere(
      (item) => item.key == key,
      orElse: () => presets.first,
    );
  }

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0B1120), Color(0xFF111827), Color(0xFF374151)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient premiumGradient = LinearGradient(
    colors: [Color(0xFF111827), Color(0xFF4B5563)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFF97316), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient infoGradient = LinearGradient(
    colors: [Color(0xFF0891B2), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.06),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> glowShadow([String? themeKey]) {
    final p = preset(themeKey);
    return [
      BoxShadow(
        color: p.primary.withOpacity(0.14),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ];
  }

  static ThemeData light({String? themeKey}) {
    final p = preset(themeKey);
    final scheme = ColorScheme.fromSeed(
      seedColor: p.primary,
      primary: p.primary,
      secondary: p.secondary,
      tertiary: p.accent,
      surface: card,
      brightness: Brightness.light,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamilyFallback: const ['Noto Sans Bengali', 'Noto Serif Bengali', 'Noto Sans', 'sans-serif'],
    );

    final textTheme = base.textTheme.apply(
      bodyColor: text,
      displayColor: text,
      fontFamilyFallback: const ['Noto Sans Bengali', 'Noto Serif Bengali', 'Noto Sans', 'sans-serif'],
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: p.primary.withOpacity(0.12),
        height: 66,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(fontSize: 11.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? p.primary : muted);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? p.primary : muted, size: selected ? 24 : 22);
        }),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: background),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shadowColor: Colors.black.withOpacity(0.05),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.primary, width: 1.4)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: p.primary.withOpacity(0.22),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}
