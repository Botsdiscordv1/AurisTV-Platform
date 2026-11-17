import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auris_core/auris_core.dart';

/// Bloquea el contrato de accesibilidad de la paleta de marca.
///
/// Si alguien cambia un color de la paleta y rompe un ratio WCAG,
/// este test falla en CI antes de llegar a producción.
void main() {
  group('AurisPalette — identidad de marca', () {
    test('el color de marca es el extraído de los logos oficiales', () {
      // rgb(239,122,30) en auris-logo-web-flat_v3.svg y auris-tv-icon.svg
      expect(AurisPalette.brand, const Color(0xFFEF7A1E));
    });

    test('la escala mantiene el tono 26° de la marca', () {
      const scale = [
        AurisPalette.brand50,
        AurisPalette.brand100,
        AurisPalette.brand200,
        AurisPalette.brand300,
        AurisPalette.brand400,
        AurisPalette.brand500,
        AurisPalette.brand600,
        AurisPalette.brand700,
        AurisPalette.brand800,
        AurisPalette.brand900,
        AurisPalette.brand950,
      ];

      for (final color in scale) {
        final hsl = HSLColor.fromColor(color);
        // Tolerancia de ±3° por el redondeo de cada paso de la escala.
        expect(
          (hsl.hue - 26).abs(),
          lessThanOrEqualTo(3),
          reason: 'Fuera de tono: ${color.toARGB32().toRadixString(16)}',
        );
      }
    });
  });

  group('AurisPalette — contraste WCAG (texto, AA ≥ 4.5:1)', () {
    test('texto principal', () {
      expect(
        AurisPalette.contrastRatio(AurisPalette.foreground, AurisPalette.background),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('texto naranja de marca sobre el fondo', () {
      // Exacto: 6.9975:1 → AA con holgura y a un pelo de AAA (7:1).
      expect(
        AurisPalette.contrastRatio(AurisPalette.brand, AurisPalette.background),
        greaterThanOrEqualTo(6.99),
      );
      expect(
        AurisPalette.contrastRatio(AurisPalette.brand, AurisPalette.background),
        lessThan(7.0),
      );
    });

    test('BOTÓN PRIMARIO: negro sobre naranja (igual que el logo)', () {
      expect(
        AurisPalette.contrastRatio(AurisPalette.onPrimary, AurisPalette.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('texto atenuado sobre fondo y sobre card', () {
      expect(
        AurisPalette.contrastRatio(AurisPalette.mutedForeground, AurisPalette.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        AurisPalette.contrastRatio(AurisPalette.mutedForeground, AurisPalette.card),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('texto sobre card', () {
      expect(
        AurisPalette.contrastRatio(AurisPalette.cardForeground, AurisPalette.card),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('naranja de acento sobre card (brand500)', () {
      expect(
        AurisPalette.contrastRatio(AurisPalette.brand500, AurisPalette.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('alternativa de botón: blanco sobre brand700', () {
      expect(
        AurisPalette.contrastRatio(AurisPalette.white, AurisPalette.brand700),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('AurisPalette — contraste no textual (UI, ≥ 3:1)', () {
    test('borde principal sobre fondo y sobre card', () {
      expect(AurisPalette.passesNonText(AurisPalette.border, AurisPalette.background), isTrue);
      expect(AurisPalette.passesNonText(AurisPalette.border, AurisPalette.surface), isTrue);
    });

    test('anillo de foco sobre fondo', () {
      expect(AurisPalette.passesNonText(AurisPalette.focusRing, AurisPalette.background), isTrue);
    });

    test('brand400 como texto/borde sobre fondo', () {
      expect(AurisPalette.passesNonText(AurisPalette.brand400, AurisPalette.background), isTrue);
    });
  });

  group('AurisPalette — trampas conocidas documentadas', () {
    test('blanco sobre el ámbar F4A724 NO sirve para texto (2.02:1)', () {
      expect(
        AurisPalette.contrastRatio(AurisPalette.white, AurisPalette.amber),
        lessThan(4.5),
      );
      // Por eso el token correcto es el negro (10.40:1).
      expect(
        AurisPalette.contrastRatio(AurisPalette.black, AurisPalette.amber),
        greaterThanOrEqualTo(7.0),
      );
    });

    test('brand sobre blanco NO sirve para texto (2.81:1)', () {
      expect(
        AurisPalette.contrastRatio(AurisPalette.brand, AurisPalette.white),
        lessThan(4.5),
      );
    });

    test('borderSubtle solo es válido sobre el fondo, no sobre card', () {
      expect(
        AurisPalette.contrastRatio(AurisPalette.borderSubtle, AurisPalette.background),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        AurisPalette.contrastRatio(AurisPalette.borderSubtle, AurisPalette.surface),
        lessThan(3.0),
      );
    });
  });

  group('AurisPalette — helpers', () {
    test('passesAA refleja el umbral 4.5:1', () {
      expect(AurisPalette.passesAA(AurisPalette.foreground, AurisPalette.background), isTrue);
      expect(AurisPalette.passesAA(AurisPalette.brand, AurisPalette.white), isFalse);
    });

    test('ratio simétrico y acotado', () {
      final ab = AurisPalette.contrastRatio(AurisPalette.brand, AurisPalette.background);
      final ba = AurisPalette.contrastRatio(AurisPalette.background, AurisPalette.brand);
      expect(ab, closeTo(ba, 1e-9));
      expect(ab, inInclusiveRange(1.0, 21.0));
    });

    test('contraste consigo mismo es 1:1', () {
      expect(
        AurisPalette.contrastRatio(AurisPalette.brand, AurisPalette.brand),
        closeTo(1.0, 1e-9),
      );
    });
  });
}
