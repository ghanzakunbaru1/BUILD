import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Core brand colors (futuristic neon)
  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF14141C);
  static const Color surfaceLight = Color(0xFFF4F5FA);
  static const Color backgroundLight = Color(0xFFFFFFFF);

  static const Color neonBlue = Color(0xFF3DDCFF);
  static const Color neonPurple = Color(0xFFB14EFF);
  static const Color neonBlueDeep = Color(0xFF2E6BFF);

  static const Color bubbleUserDark = Color(0xFF1E2233);
  static const Color bubbleAiDark = Color(0xFF17131F);
  static const Color bubbleUserLight = Color(0xFFE9EEFF);
  static const Color bubbleAiLight = Color(0xFFF1E9FF);

  static const Color textPrimaryDark = Color(0xFFF5F6FA);
  static const Color textSecondaryDark = Color(0xFFA3A6B8);
  static const Color textPrimaryLight = Color(0xFF14141C);
  static const Color textSecondaryLight = Color(0xFF6A6D7C);

  static const Color error = Color(0xFFFF5C7A);
  static const Color success = Color(0xFF3DFFA2);

  static const LinearGradient neonGradient = LinearGradient(
    colors: [neonBlue, neonPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
