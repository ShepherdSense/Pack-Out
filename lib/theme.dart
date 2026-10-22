import 'package:flutter/material.dart';

const kBg = Color(0xFF100D19);
const kCard = Color(0xFF1E1A30);
const kPurple = Color(0xFF8B5CF6);
const kPurpleDeep = Color(0xFF6D28D9);
const kPurpleLight = Color(0xFFA78BFA);
const kText = Color(0xFFF4F2FB);
const kDim = Color(0xFFA79FC0);
const kOk = Color(0xFF34D399);
const kWarn = Color(0xFFFBBF24);
const kRed = Color(0xFFF87171);

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: kBg,
    colorScheme: base.colorScheme.copyWith(
      primary: kPurple,
      surface: kCard,
      onSurface: kText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: kText,
      elevation: 0,
      centerTitle: false,
    ),
    cardColor: kCard,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kPurple,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kText,
        side: const BorderSide(color: kPurpleLight),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF131020),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFF3A3560)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFF3A3560)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: kPurple, width: 2),
      ),
      labelStyle: const TextStyle(color: kDim),
    ),
  );
}

Widget gradientButton({
  required String label,
  required VoidCallback? onPressed,
  IconData? icon,
  double fontSize = 22,
}) {
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [kPurple, kPurpleDeep]),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
            color: kPurple.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 8)),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: fontSize + 4),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
