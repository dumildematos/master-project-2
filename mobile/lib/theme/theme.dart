import 'package:flutter/material.dart';

// ── Colour tokens ──────────────────────────────────────────────────────────────
const Color kBg      = Color(0xFF080C10);
const Color kBg2     = Color(0xFF0F1419);
const Color kBorder  = Color(0xFF1A2233);
const Color kText    = Color(0xFFE8F0FE);
const Color kMuted   = Color(0xFF6B7FA3);
const Color kCyan    = Color(0xFF29D9C8);
const Color kAmber   = Color(0xFFF5A623);
const Color kMagenta = Color(0xFFC45AEC);

// ── Emotion colours ────────────────────────────────────────────────────────────
const Map<String, Color> kEmotionColors = {
  'calm':     Color(0xFF29D9C8),
  'relaxed':  Color(0xFF52B788),
  'focused':  Color(0xFF3A86FF),
  'excited':  Color(0xFFFF006E),
  'stressed': Color(0xFFD00000),
  'neutral':  Color(0xFF6B7FA3),
};

const Map<String, String> kEmotionLabels = {
  'calm':     'Calm',
  'relaxed':  'Relaxed',
  'focused':  'Focused',
  'excited':  'Excited',
  'stressed': 'Stressed',
  'neutral':  'Neutral',
};

Color emotionColor(String emotion) =>
    kEmotionColors[emotion.toLowerCase()] ?? kMuted;

String emotionLabel(String emotion) =>
    kEmotionLabels[emotion.toLowerCase()] ??
    '${emotion[0].toUpperCase()}${emotion.substring(1).toLowerCase()}';

// ── Spacing ────────────────────────────────────────────────────────────────────
const double kXs  = 4;
const double kSm  = 8;
const double kMd  = 16;
const double kLg  = 24;
const double kXl  = 32;

// ── Text styles ────────────────────────────────────────────────────────────────
const TextStyle kMono = TextStyle(fontFamily: 'monospace', color: kText);

// ── App ThemeData ──────────────────────────────────────────────────────────────
final ThemeData sentioTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kBg,
  colorScheme: const ColorScheme.dark(
    primary:   kCyan,
    secondary: kMagenta,
    surface:   kBg2,
    onPrimary: kBg,
    onSurface: kText,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: kBg,
    foregroundColor: kText,
    elevation: 0,
    titleTextStyle: TextStyle(
      fontFamily: 'monospace', fontSize: 13,
      letterSpacing: 3, color: kCyan,
    ),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor:      kBg2,
    selectedItemColor:    kCyan,
    unselectedItemColor:  kMuted,
    selectedLabelStyle:   TextStyle(fontFamily: 'monospace', fontSize: 10, letterSpacing: 1),
    unselectedLabelStyle: TextStyle(fontFamily: 'monospace', fontSize: 10, letterSpacing: 1),
  ),
  dividerColor: kBorder,
  cardColor:    kBg2,
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: kBg,
    hintStyle: const TextStyle(color: kMuted, fontFamily: 'monospace'),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kCyan),
    ),
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: kText, fontFamily: 'monospace'),
    bodySmall:  TextStyle(color: kMuted, fontFamily: 'monospace', fontSize: 11),
  ),
);
