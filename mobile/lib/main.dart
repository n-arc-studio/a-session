import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'l10n/app_strings.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ASessionApp());
}

class ASessionApp extends StatelessWidget {
  const ASessionApp({super.key});

  ThemeData _buildTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF0F3D5E),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF1E847F),
      onSecondary: Color(0xFFFFFFFF),
      error: Color(0xFFC0392B),
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF1E2A36),
    );

    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    final textTheme = GoogleFonts.notoSansJpTextTheme(base.textTheme).copyWith(
      displaySmall: GoogleFonts.mPlus1p(
        fontWeight: FontWeight.w700,
        fontSize: 34,
        color: colorScheme.onSurface,
      ),
      headlineMedium: GoogleFonts.mPlus1p(
        fontWeight: FontWeight.w700,
        fontSize: 26,
        color: colorScheme.onSurface,
      ),
      headlineSmall: GoogleFonts.mPlus1p(
        fontWeight: FontWeight.w700,
        fontSize: 22,
        color: colorScheme.onSurface,
      ),
      titleLarge: GoogleFonts.notoSansJp(
        fontWeight: FontWeight.w700,
        fontSize: 19,
        color: colorScheme.onSurface,
      ),
      titleMedium: GoogleFonts.notoSansJp(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: colorScheme.onSurface,
      ),
      bodyLarge: GoogleFonts.notoSansJp(
        fontWeight: FontWeight.w500,
        fontSize: 15,
        color: colorScheme.onSurface,
      ),
      bodyMedium: GoogleFonts.notoSansJp(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        color: colorScheme.onSurface,
      ),
      labelLarge: GoogleFonts.notoSansJp(
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF6F8FB),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: const Color(0xFFF6F8FB),
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFDCE3EC)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          side: const BorderSide(color: Color(0xFFD2DCE8)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FBFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD2DCE8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD2DCE8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF0F3D5E), width: 1.4),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 1,
        height: 76,
        indicatorColor: const Color(0xFFDDEDF7),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : const Color(0xFF5E6B78),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: const BorderSide(color: Color(0xFFD2DCE8)),
        backgroundColor: const Color(0xFFF3F7FC),
        selectedColor: const Color(0xFFD8EAF9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppStrings.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppStrings.supportedLocales,
      theme: _buildTheme(),
      home: const HomeScreen(),
    );
  }
}
