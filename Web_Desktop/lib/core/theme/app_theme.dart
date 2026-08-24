import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Brand Colors
  static const Color brand = Color(0xFFEF7A1E);
  static const Color brandLight = Color(0xFFFF963D);
  static const Color brandDark = Color(0xFFC85F0D);

  // Backgrounds & Surfaces
  static const Color background = Color(0xFF0B0B0D);
  static const Color surface = Color(0xFF121214);
  static const Color surfaceCard = Color(0xFF19191C);
  static const Color surfaceElevated = Color(0xFF222226);
  static const Color border = Color(0xFF2C2C31);

  // Typography
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFA5A5AA);
  static const Color textDisabled = Color(0xFF5F5F64);

  // States
  static const Color success = Color(0xFF35C759);
  static const Color error = Color(0xFFFF453A);
  static const Color warning = Color(0xFFFFB340);
  static const Color info = Color(0xFF4DA3FF);

  // Player
  static const Color playerBackground = Color(0xFF080809);
  static const Color progressTrack = Color(0xFF39393D);

  static const auristvDarkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: brand,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF5A2A08),
    onPrimaryContainer: Color(0xFFFFDBC7),
    secondary: brandLight,
    onSecondary: Color(0xFF2A1205),
    secondaryContainer: Color(0xFF3D1D0A),
    onSecondaryContainer: Color(0xFFFFDBC7),
    tertiary: info,
    onTertiary: Color(0xFF001A33),
    error: error,
    onError: Color(0xFFFFFFFF),
    surface: surface,
    onSurface: textPrimary,
    surfaceContainerHighest: surfaceElevated,
    onSurfaceVariant: textSecondary,
    outline: border,
    outlineVariant: Color(0xFF202024),
    inverseSurface: textPrimary,
    onInverseSurface: Color(0xFF171719),
    inversePrimary: brandDark,
  );

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: auristvDarkScheme,
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      useMaterial3: true,
      
      // Extensiones de color personalizadas
      extensions: [
        AurisColors(
          success: success,
          warning: warning,
          info: info,
          playerBackground: playerBackground,
          progressTrack: progressTrack,
          surfaceCard: surfaceCard,
          surfaceElevated: surfaceElevated,
          border: border,
          textDisabled: textDisabled,
        ),
      ],

      // FocusTheme más visible para navegación con control remoto (Android TV)
      focusColor: brand.withValues(alpha: 0.3),
      
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: brand,
        selectionColor: brand.withValues(alpha: 0.3),
        selectionHandleColor: brand,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
      ),

      cardTheme: const CardThemeData(
        color: surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: const Color(0xFF3D1D0A),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: brand);
          }
          return const IconThemeData(color: Color(0xFF7D7D83));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: brand, fontWeight: FontWeight.bold);
          }
          return const TextStyle(color: Color(0xFF7D7D83));
        }),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: surfaceElevated,
          disabledForegroundColor: textDisabled,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return brandDark;
            if (states.contains(WidgetState.hovered)) return brandLight;
            return brand;
          }),
        ),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: brand,
        inactiveTrackColor: progressTrack,
        thumbColor: brand,
        overlayColor: brand.withValues(alpha: 0.2),
        trackHeight: 4.0,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
      ),

      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: surfaceCard,
        hintStyle: TextStyle(color: textSecondary),
        labelStyle: TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: brand),
        ),
      ),
    );
  }
}

/// Extensión para colores que no están en el ColorScheme estándar
class AurisColors extends ThemeExtension<AurisColors> {
  final Color success;
  final Color warning;
  final Color info;
  final Color playerBackground;
  final Color progressTrack;
  final Color surfaceCard;
  final Color surfaceElevated;
  final Color border;
  final Color textDisabled;

  const AurisColors({
    required this.success,
    required this.warning,
    required this.info,
    required this.playerBackground,
    required this.progressTrack,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.border,
    required this.textDisabled,
  });

  @override
  ThemeExtension<AurisColors> copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? playerBackground,
    Color? progressTrack,
    Color? surfaceCard,
    Color? surfaceElevated,
    Color? border,
    Color? textDisabled,
  }) {
    return AurisColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      playerBackground: playerBackground ?? this.playerBackground,
      progressTrack: progressTrack ?? this.progressTrack,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      textDisabled: textDisabled ?? this.textDisabled,
    );
  }

  @override
  ThemeExtension<AurisColors> lerp(ThemeExtension<AurisColors>? other, double t) {
    if (other is! AurisColors) return this;
    return AurisColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      playerBackground: Color.lerp(playerBackground, other.playerBackground, t)!,
      progressTrack: Color.lerp(progressTrack, other.progressTrack, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
    );
  }
}
