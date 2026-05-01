// sentio_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SentioColors {
  static const bgTop = Color(0xFF02080D);
  static const bgBottom = Color(0xFF07131B);

  static const card = Color(0xFF101820);
  static const cardAlt = Color(0xFF111A22);
  static const cardBorder = Color(0xFF22313D);

  static const cyan = Color(0xFF00D9FF);
  static const cyanSoft = Color(0xFF1ECFFF);
  static const purple = Color(0xFF782CFF);
  static const green = Color(0xFF00C48C);
  static const yellow = Color(0xFFFFC107);
  static const red = Color(0xFFFF4D4D);

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9AA6B2);
  static const textMuted = Color(0xFF6F7B86);
}

// Legacy aliases used by existing screens
const kBg = SentioColors.bgTop;
const kBg2 = SentioColors.card;
const kText = SentioColors.textPrimary;
const kMuted = SentioColors.textSecondary;
const kBorder = SentioColors.cardBorder;

const kCyan = SentioColors.cyan;
const kBlue = SentioColors.cyanSoft;
const kPurple = SentioColors.purple;
const kGreen = SentioColors.green;
const kAmber = SentioColors.yellow;
const kRed = SentioColors.red;

const kSm = 8.0;
const kMd = 16.0;
const kLg = 24.0;
const kXl = 32.0;

final sentioTheme = SentioTheme.dark();

Color emotionColor(String emotion) {
  switch (emotion.toLowerCase().trim()) {
    case 'calm':
      return kCyan;
    case 'focused':
    case 'focus':
      return kGreen;
    case 'relaxed':
    case 'relax':
      return kPurple;
    case 'stressed':
    case 'stress':
      return kRed;
    case 'excited':
    case 'excitement':
      return kAmber;
    default:
      return kMuted;
  }
}

String emotionLabel(String emotion) {
  switch (emotion.toLowerCase().trim()) {
    case 'calm':
      return 'Calm';
    case 'focused':
    case 'focus':
      return 'Focused';
    case 'relaxed':
    case 'relax':
      return 'Relaxed';
    case 'stressed':
    case 'stress':
      return 'Stressed';
    case 'excited':
    case 'excitement':
      return 'Excited';
    default:
      return 'Neutral';
  }
}
class SentioTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: SentioColors.bgTop,
      primaryColor: SentioColors.cyan,
      colorScheme: const ColorScheme.dark(
        primary: SentioColors.cyan,
        secondary: SentioColors.purple,
        surface: SentioColors.card,
        error: SentioColors.red,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: SentioColors.textPrimary,
        displayColor: SentioColors.textPrimary,
      ),
      iconTheme: const IconThemeData(
        color: SentioColors.textSecondary,
        size: 24,
      ),
      cardTheme: CardThemeData(
        color: SentioColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: SentioColors.cardBorder),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: SentioColors.cyan,
        inactiveTrackColor: SentioColors.cardBorder,
        thumbColor: SentioColors.cyan,
        overlayColor: SentioColors.cyan.withOpacity(0.18),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: SentioColors.card,
        selectedItemColor: SentioColors.cyan,
        unselectedItemColor: SentioColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}

class SentioDecorations {
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      SentioColors.bgTop,
      SentioColors.bgBottom,
    ],
  );

  static BoxDecoration card() {
    return BoxDecoration(
      color: SentioColors.card.withOpacity(0.86),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: SentioColors.cardBorder.withOpacity(0.8),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.35),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  static BoxDecoration neonCard({Color glow = SentioColors.cyan}) {
    return BoxDecoration(
      color: SentioColors.cardAlt.withOpacity(0.9),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(
        color: glow.withOpacity(0.25),
      ),
      boxShadow: [
        BoxShadow(
          color: glow.withOpacity(0.16),
          blurRadius: 28,
          spreadRadius: 1,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.45),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  static const primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      SentioColors.cyan,
      SentioColors.purple,
    ],
  );
  
}