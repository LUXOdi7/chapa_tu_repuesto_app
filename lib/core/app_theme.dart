import 'package:flutter/material.dart';

/// Paleta de marca ChapaTuRepuesto.
/// Azul profesional (confianza / B2B) + ámbar mecánico (acción / CTA).
const kBrandBlue = Color(0xFF1A365D);
const kBrandAmber = Color(0xFFF59E0B);

/// Material 3 generado desde la semilla azul, con el ámbar forzado como
/// `secondary` para que botones, chips y badges usen el acento de marca.
/// ponytail: un solo builder para light/dark; separar si divergen de verdad.
ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: kBrandBlue,
    brightness: brightness,
  ).copyWith(secondary: kBrandAmber, tertiary: kBrandAmber);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: brightness == Brightness.dark ? scheme.surface : kBrandBlue,
      foregroundColor: brightness == Brightness.dark ? scheme.onSurface : Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kBrandAmber,
        foregroundColor: Colors.black87,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    cardTheme: CardThemeData(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    chipTheme: const ChipThemeData(side: BorderSide.none),
  );
}
