import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paleta de marca AurisTV — sistema de color completo.
///
/// Generada a partir del color oficial extraído de los logos originales
/// (`auris-logo-web-flat_v3.svg`, `auris-tv-icon.svg` y
/// `auris-launcher-foreground.svg`), todos coinciden en:
///
/// ```text
/// rgb(239, 122, 30) == #EF7A1E   (HSL 26°, 87%, 53%)
/// ```
///
/// La escala [brand50]–[brand950] mantiene el tono 26° y varía la luz;
/// la saturación se reduce 5–20 % en los tonos claros (50–400) para
/// evitar pasteles estridentes y se conserva al 100 % en 500–950.
///
/// La app es **dark-first**: el fondo real es `#0B0B0D`, por eso los
/// tokens semánticos están mapeados sobre fondo oscuro.
///
/// ### Contraste verificado (WCAG 2.1, sobre los colores reales de la app)
///
/// | Par | Ratio | WCAG |
/// |-----|-------|------|
/// | [brand] sobre [background] | 6.9975:1 | AA (casi AAA) |
/// | [onPrimary] (negro) sobre [brand] — botón primario | 7.47:1 | AAA |
/// | blanco sobre [background] | 19.66:1 | AAA |
/// | [mutedText] sobre [background] | 7.34:1 | AAA |
/// | [mutedText] sobre [surface] | 6.30:1 | AA |
/// | blanco sobre [surface] | 16.87:1 | AAA |
/// | [brand300] sobre [surface] | 9.69:1 | AAA |
/// | [brand400] sobre [background] | 8.38:1 | AAA |
/// | [brand500] sobre [surface] | 5.21:1 | AA |
/// | [brand600] como borde sobre [background] | 4.39:1 | UI ≥3 ✓ |
/// | negro sobre [amber] | 10.40:1 | AAA |
/// | blanco sobre [brand700] (botón alternativo) | 6.14:1 | AA |
/// | ⚠ blanco sobre [amber] | 2.02:1 | **FALLO** |
/// | ⚠ [brand] sobre blanco | 2.81:1 | **FALLO** |
/// | ⚠ [brand700] sobre [surface] | 2.75:1 | **FALLO** |
///
/// **Regla AurisTV:** el naranja siempre lleva texto **negro** (igual que
/// el logo). Nunca blanco: no llega a 4.5:1.
///
/// Uso básico:
/// ```dart
/// import 'package:auris_core/auris_core.dart';
///
/// Container(color: AurisPalette.background);
/// Text('Hola', style: TextStyle(color: AurisPalette.foreground));
/// FilledButton(onPressed: ..., style: FilledButton.styleFrom(
///   backgroundColor: AurisPalette.primary,
///   foregroundColor: AurisPalette.onPrimary, // negro → 7.47:1
/// ));
/// ```
class AurisPalette {
  const AurisPalette._();

  // ─────────────────────────────────────────────────────────────
  // Color de marca
  // ─────────────────────────────────────────────────────────────

  /// Color oficial de marca: `rgb(239,122,30)`.
  ///
  /// Fidelidad obligatoria en logotipos e iconografía. Para superficies
  /// grandes, estados y bordes usa la escala [brand50]–[brand950].
  static const Color brand = Color(0xFFEF7A1E);

  // ─────────────────────────────────────────────────────────────
  // Escala 50–950 (mismo tono, luz variable)
  // ─────────────────────────────────────────────────────────────

  /// 50 · Fondos sutiles y estados de hover muy tenues.
  static const Color brand50 = Color(0xFFFDF7F2);

  /// 100 · Fondos secundarios, chips y badges sobre oscuro.
  static const Color brand100 = Color(0xFFFAEEE5);

  /// 200 · Divisores decorativos sobre fondos claros.
  static const Color brand200 = Color(0xFFF6DBC5);

  /// 300 · Texto naranja secundario sobre superficie oscura (9.69:1 AAA).
  ///       También tooltips sobre naranja claro (negro encima: 12.07:1).
  static const Color brand300 = Color(0xFFF1B98E);

  /// 400 · Enfoque/focus ring (8.38:1 sobre fondo) y texto de acento.
  static const Color brand400 = Color(0xFFEF934E);

  /// 500 · Naranja vibrante para iconos y texto de acento sobre cards
  ///       (5.21:1 AA).
  static const Color brand500 = Color(0xFFE56C10);

  /// 600 · **Borde principal** (4.39:1 sobre fondo, 3.76:1 sobre card —
  ///       cumple 3:1 para componentes de UI en ambos).
  static const Color brand600 = Color(0xFFBF5A0D);

  /// 700 · Botón primario alternativo con texto blanco (6.14:1 AA).
  ///       ⚠ No usar como borde sobre [surface] (2.75:1).
  static const Color brand700 = Color(0xFF9D4A0B);

  /// 800 · Contenedores secundarios oscuros; blanco encima: 8.06:1.
  static const Color brand800 = Color(0xFF813D09);

  /// 900 · Superficie naranja oscura; blanco encima: 11.26:1.
  static const Color brand900 = Color(0xFF5F2D07);

  /// 950 · Tinte naranja más profundo, para gradientes y sombras.
  static const Color brand950 = Color(0xFF301703);

  // ─────────────────────────────────────────────────────────────
  // Neutrales de la app (valores ya en uso en las 3 plataformas)
  // ─────────────────────────────────────────────────────────────

  /// Fondo principal (Web_Desktop / TV).
  static const Color background = Color(0xFF0B0B0D);

  /// Fondo negro puro (Movil).
  static const Color backgroundPure = Color(0xFF000000);

  /// Superficie de cards, paneles y menús.
  static const Color surface = Color(0xFF1A1D24);

  /// Variante de superficie usada en el explorador.
  static const Color surfaceAlt = Color(0xFF1A1D23);

  /// Tinta oscura para texto sobre naranja claro o superficies blancas.
  static const Color ink = Color(0xFF050505);

  /// Texto atenuado actual (7.34:1 sobre fondo, 6.30:1 sobre card).
  static const Color mutedText = Color(0xFF9E9E9E);

  /// Naranja ámbar de acento secundario.
  ///
  /// ⚠ Solo con texto **negro** (10.40:1). Blanco sobre [amber] da 2.02:1.
  static const Color amber = Color(0xFFF4A724);

  /// Blanco puro.
  static const Color white = Color(0xFFFFFFFF);

  /// Negro puro.
  static const Color black = Color(0xFF000000);

  // ─────────────────────────────────────────────────────────────
  // Tokens semánticos (dark-first)
  // ─────────────────────────────────────────────────────────────

  /// Color por defecto de la app.
  static const Color foreground = white;

  /// Fondo de página (token semántico sobre [background]).
  static const Color backgroundToken = background;

  /// Fondo de cards y popovers.
  static const Color card = surface;

  /// Texto sobre [card].
  static const Color cardForeground = white;

  /// Acción primaria: botones y links destacados.
  static const Color primary = brand;

  /// Texto sobre [primary]. **Negro**, no blanco (7.47:1 AAA).
  static const Color onPrimary = black;

  /// Estado hover/focus de la acción primaria.
  static const Color primaryHover = brand400;

  /// Estado presionado de la acción primaria.
  static const Color primaryPressed = brand600;

  /// Enlaces y texto interactivos (6.9975:1 sobre fondo — AA casi AAA).
  static const Color link = brand;

  /// Contenedor secundario (fondo oscuro con tinte naranja).
  static const Color secondary = brand900;

  /// Texto sobre [secondary] (11.26:1 AAA).
  static const Color onSecondary = white;

  /// Fondo de elementos deshabilitados o secciones apagadas.
  static const Color muted = brand950;

  /// Texto atenuado sobre [muted] o [background].
  static const Color mutedForeground = mutedText;

  /// Borde de inputs, separadores y outlines de componentes.
  ///
  /// Cumple 3:1 (mínimo WCAG 1.4.11) tanto sobre [background] como
  /// sobre [surface].
  static const Color border = brand600;

  /// Borde sutil decorativo — solo sobre [background] (3.20:1).
  /// ⚠ No usar sobre [surface] (2.75:1).
  static const Color borderSubtle = brand700;

  /// Anillo de foco (8.38:1 sobre fondo; muy visible en TV por D-pad).
  static const Color focusRing = brand400;

  /// Color de error/destructivo.
  static const Color destructive = Color(0xFFDC2626);

  /// Texto sobre [destructive].
  static const Color onDestructive = white;

  // ─────────────────────────────────────────────────────────────
  // Utilidades de contraste (usables en tests)
  // ─────────────────────────────────────────────────────────────

  /// Luminancia relativa WCAG 2.1 de este color (0.0–1.0).
  static double luminance(Color color) {
    double channel(double value) =>
        value <= 0.03928 ? value / 12.92 : math.pow((value + 0.055) / 1.055, 2.4).toDouble();

    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }

  /// Ratio de contraste WCAG entre dos colores (1.0–21.0).
  static double contrastRatio(Color a, Color b) {
    final la = luminance(a);
    final lb = luminance(b);
    final lighter = math.max(la, lb);
    final darker = math.min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// `true` si el par cumple AA para texto normal (≥ 4.5:1).
  static bool passesAA(Color foregroundColor, Color backgroundColor) =>
      contrastRatio(foregroundColor, backgroundColor) >= 4.5;

  /// `true` si el par cumple 3:1 (texto grande y componentes de UI).
  static bool passesNonText(Color foregroundColor, Color backgroundColor) =>
      contrastRatio(foregroundColor, backgroundColor) >= 3.0;

  // ─────────────────────────────────────────────────────────────
  // Material 3
  // ─────────────────────────────────────────────────────────────

  /// [ColorScheme] de Material 3 derivada de esta paleta (dark-first).
  ///
  /// ```dart
  /// MaterialApp(theme: ThemeData(colorScheme: AurisPalette.colorScheme()));
  /// ```
  static ColorScheme colorScheme() => const ColorScheme.dark(
        primary: brand,
        onPrimary: onPrimary,
        secondary: brand600,
        onSecondary: white,
        surface: surface,
        onSurface: foreground,
        outline: border,
        outlineVariant: borderSubtle,
        error: destructive,
        onError: onDestructive,
      );
}
