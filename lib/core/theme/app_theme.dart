import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Laravel DREAM Brand Colors
  static const Color cyan = Color(0xFF00DBE9);
  static const Color pink = Color(0xFFFFABF0);
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF0D1527);
  static const Color surfaceBorder = Color(0x14FFFFFF);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0x99FFFFFF); // 60% white — good contrast on dark
  static const Color textMuted = Color(0x80FFFFFF); // 50% white — WCAG AA on dark
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Font style helpers — minimum 10px for all labels
  static TextStyle soraBold(double size) => GoogleFonts.sora(fontSize: size, fontWeight: FontWeight.bold, color: textPrimary);
  static TextStyle soraSemiBold(double size) => GoogleFonts.sora(fontSize: size, fontWeight: FontWeight.w600, color: textPrimary);
  static TextStyle soraBlack(double size) => GoogleFonts.sora(fontSize: size, fontWeight: FontWeight.w900, color: textPrimary);
  static TextStyle soraMedium(double size) => GoogleFonts.sora(fontSize: size, fontWeight: FontWeight.w500, color: textPrimary);
  static TextStyle geistBold(double size) => GoogleFonts.geist(fontSize: size, fontWeight: FontWeight.w700, color: textPrimary);
  static TextStyle geistMedium(double size) => GoogleFonts.geist(fontSize: size, fontWeight: FontWeight.w500, color: textPrimary);
  static TextStyle hankenBold(double size) => GoogleFonts.hankenGrotesk(fontSize: size, fontWeight: FontWeight.w700, color: textPrimary);
  static TextStyle hankenSemiBold(double size) => GoogleFonts.hankenGrotesk(fontSize: size, fontWeight: FontWeight.w600, color: textPrimary);
  static TextStyle hankenMedium(double size) => GoogleFonts.hankenGrotesk(fontSize: size, fontWeight: FontWeight.w500, color: textPrimary);
}

class AppTheme {
  // Legacy aliases — maps AppTheme.xxx to AppColors.xxx
  static const Color primary = AppColors.cyan;
  static const Color primaryLight = AppColors.cyan;
  static const Color primaryDark = Color(0xFF0891B2);
  static const Color accent = AppColors.pink;
  static const Color secondary = AppColors.cyan;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color success = AppColors.success;
  static const Color error = AppColors.error;
  static const Color warning = AppColors.warning;

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.cyan,
      secondary: AppColors.pink,
      surface: AppColors.surface,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.background,
    textTheme: GoogleFonts.hankenGroteskTextTheme(
      const TextTheme(
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textSecondary),
        bodySmall: TextStyle(color: AppColors.textMuted),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
    ),
  );
}
