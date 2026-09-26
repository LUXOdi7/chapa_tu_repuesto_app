import 'package:flutter/material.dart';

/// Tokens de marca ChapaTuRepuesto. Fuente unica: `design.md` en la raiz del
/// proyecto (§1 Identidad Visual). Si cambia design.md, se cambia aqui.
///
/// Azul marino = confianza / taller. Naranja = accion, precio, CTA.
const kBrandBlue = Color(0xFF1A365D); // Primary
const kBrandOrange = Color(0xFFF4731A); // Accent
const kBrandInk = Color(0xFF1B2A3A); // azul casi negro del logotipo

/// Alias historico: medio proyecto todavia importa `kBrandAmber`.
const kBrandAmber = kBrandOrange;

// Tema claro (design.md §1)
const _lightBg = Color(0xFFF8FAFC);
const _lightSurface = Color(0xFFFFFFFF);
const _lightText = Color(0xFF0F172A);
const _lightText2 = Color(0xFF64748B);
const _lightBorder = Color(0xFFE2E8F0);
const _lightField = Color(0xFFF1F5F9); // fondo de inputs: marca area editable

// Tema oscuro (design.md §1)
const _darkBg = Color(0xFF0B1120);
const _darkSurface = Color(0xFF1E293B);
const _darkText = Color(0xFFF8FAFC);
const _darkText2 = Color(0xFF94A3B8);
const _darkBorder = Color(0xFF334155);

/// Puntos de ruptura de design.md §4.
const kTabletWidth = 600.0;
const kDesktopWidth = 900.0;

/// Ancho maximo de un formulario en escritorio: inputs de 1400 px no se leen.
const kFormWidth = 600.0;

/// `true` desde tablet: la navegacion pasa de barra inferior a riel lateral.
bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kTabletWidth;

/// `true` en escritorio: el riel se muestra extendido (icono + texto).
bool isDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDesktopWidth;

/// Material 3 con la paleta de design.md. Un solo builder para claro y oscuro:
/// las diferencias son los seis tokens de arriba, no dos disenos distintos.
///
/// Nota de design.md: en oscuro el azul pierde contraste, asi que el color de
/// interaccion principal pasa a ser el naranja.
ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;

  final bg = dark ? _darkBg : _lightBg;
  final surface = dark ? _darkSurface : _lightSurface;
  final text = dark ? _darkText : _lightText;
  final text2 = dark ? _darkText2 : _lightText2;
  final border = dark ? _darkBorder : _lightBorder;

  final scheme =
      ColorScheme.fromSeed(
        seedColor: kBrandBlue,
        brightness: brightness,
      ).copyWith(
        primary: dark ? kBrandOrange : kBrandBlue,
        onPrimary: Colors.white,
        secondary: kBrandOrange,
        onSecondary: Colors.white,
        secondaryContainer: dark
            ? const Color(0xFF5A2E0C)
            : const Color(0xFFFFE3CF),
        onSecondaryContainer: dark
            ? const Color(0xFFFFD9BF)
            : const Color(0xFF5A2E0C),
        tertiary: kBrandOrange,
        surface: surface,
        onSurface: text,
        onSurfaceVariant: text2,
        outline: text2,
        outlineVariant: border,
      );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final t = base.textTheme;

  return base.copyWith(
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    // design.md §2: titulos en SemiBold/Bold, cuerpo Regular, labels Medium.
    textTheme: t.copyWith(
      headlineSmall: t.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: t.bodyMedium?.copyWith(height: 1.35),
      bodySmall: t.bodySmall?.copyWith(color: text2),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w500),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? surface : kBrandBlue,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: t.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    // design.md §3: indicador naranja, inactivos en gris.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: kBrandOrange,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? Colors.white : text2,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => t.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected) ? text : text2,
        ),
      ),
    ),
    // design.md §3: riel azul marino, texto blanco, indicador naranja.
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: dark ? surface : kBrandBlue,
      indicatorColor: kBrandOrange,
      selectedIconTheme: const IconThemeData(color: Colors.white),
      unselectedIconTheme: IconThemeData(
        color: Colors.white.withValues(alpha: 0.7),
      ),
      selectedLabelTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
      ),
      useIndicator: true,
    ),
    // design.md §3: radio 8-12 px, "mecanico", no pildora.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kBrandOrange,
        foregroundColor: Colors.white,
        disabledBackgroundColor: kBrandOrange.withValues(alpha: 0.35),
        disabledForegroundColor: Colors.white70,
        minimumSize: const Size.fromHeight(48),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: dark ? kBrandOrange : kBrandBlue,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: dark ? kBrandOrange : kBrandBlue, width: 1.2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: dark ? kBrandOrange : kBrandBlue,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF16233A) : _lightField,
      labelStyle: TextStyle(color: text2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBrandOrange, width: 2),
      ),
    ),
    // design.md §3: plano con borde definido; en claro una sombra minima
    // (0.05 / blur 10), en oscuro ninguna.
    cardTheme: CardThemeData(
      clipBehavior: Clip.antiAlias,
      elevation: dark ? 0 : 1,
      shadowColor: dark
          ? Colors.transparent
          : Colors.black.withValues(alpha: 0.05),
      color: surface,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: border),
      ),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide(color: border),
      backgroundColor: dark ? const Color(0xFF16233A) : _lightField,
      selectedColor: scheme.secondaryContainer,
      labelStyle: t.labelLarge?.copyWith(color: text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    listTileTheme: ListTileThemeData(iconColor: text2, textColor: text),
    dividerTheme: DividerThemeData(color: border),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: kBrandOrange,
    ),
  );
}
