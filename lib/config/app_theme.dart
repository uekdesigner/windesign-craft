// lib/config/app_theme.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Win11 tarzı soft seed renk (daha neutral)
  static const Color _seedColor = Color(0xFF5B9BD5);

  // Win11 acrylic arka plan için opacity değerleri
  static const double _surfaceOpacity = 0.95;

  // -------------------- Light Theme (Win11 Soft Aesthetic) --------------------
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Win11 tarzı soft color scheme
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ).copyWith(
          surface: const Color(0xFFF9F9F9),
          surfaceContainerHighest: const Color(0xFFF3F3F3),
          outline: const Color(0xFFE0E0E0),
          outlineVariant: const Color(0xFFEEEEEE),
        ),

    // -------------------- AppBar (Win11 Title Bar Tarzı) --------------------
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      backgroundColor: Color(0xFFF9F9F9),
      foregroundColor: Color(0xFF1F1F1F),
      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F1F1F),
        letterSpacing: -0.2,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),

    // -------------------- ElevatedButton --------------------
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: const Color(0xFF5B9BD5),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
    ),

    // -------------------- OutlinedButton --------------------
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        elevation: 0,
        foregroundColor: const Color(0xFF1F1F1F),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),

    // -------------------- TextButton --------------------
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF5B9BD5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),

    // -------------------- Card --------------------
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFFF9F9F9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE8E8E8)),
      ),
    ),

    // -------------------- Dialog --------------------
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFFFCFCFC),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F1F1F),
      ),
    ),

    // -------------------- Input --------------------
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF3F3F3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFF5B9BD5), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintStyle: const TextStyle(color: Color(0xFF999999), fontSize: 14),
      labelStyle: const TextStyle(color: Color(0xFF666666), fontSize: 14),
    ),

    // -------------------- ListTile --------------------
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minLeadingWidth: 24,
      iconColor: Color(0xFF5B9BD5),
    ),

    // -------------------- Chip (Win11 Pill Style) --------------------
    chipTheme: const ChipThemeData(
      backgroundColor: Color(0xFFF0F0F0),
      selectedColor: Color(0xFFE3F2FD),
      disabledColor: Color(0xFFE0E0E0),
      deleteIconColor: Color(0xFF666666),
      labelStyle: TextStyle(fontSize: 12, color: Color(0xFF1F1F1F)),
      secondaryLabelStyle: TextStyle(fontSize: 12, color: Color(0xFF666666)),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: StadiumBorder(), // Win11'deki oval/pill şekli
    ),

    // -------------------- Divider --------------------
    dividerTheme: const DividerThemeData(
      color: Color(0xFFEEEEEE),
      thickness: 1,
      space: 1,
    ),

    // -------------------- Tooltip --------------------
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xFF2B2B2B).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: const TextStyle(fontSize: 12, color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),

    // -------------------- Typography --------------------
    fontFamily: 'Roboto',

    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F1F1F),
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F1F1F),
        letterSpacing: -0.3,
      ),
      displaySmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F1F1F),
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F1F1F),
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Color(0xFF1F1F1F),
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: Color(0xFF1F1F1F),
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color(0xFF1F1F1F),
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: Color(0xFF666666),
      ),
    ),

    visualDensity: VisualDensity.comfortable,
  );
}
