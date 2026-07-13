import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1E40AF);
  static const Color primaryLight = Color(0xFF60A5FA);
  
  // Secondary Colors
  static const Color secondaryTeal = Color(0xFF14B8A6);
  static const Color secondaryGreen = Color(0xFF22C55E);
  
  // Gradient Colors
  static const Color gradientStart = Color(0xFF2563EB);
  static const Color gradientMiddle = Color(0xFF14B8A6);
  static const Color gradientEnd = Color(0xFF22C55E);
  
  // Background Colors
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color inputBackground = Color(0xFFF1F5F9);
  
  // Text Colors
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMedium = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);
  
  // Status Colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  
  // Card Gradients
  static const LinearGradient identityCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2563EB),
      Color(0xFF14B8A6),
    ],
  );
  
  static const LinearGradient healthCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF14B8A6),
      Color(0xFF22C55E),
    ],
  );
  
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF2563EB),
      Color(0xFF1E40AF),
    ],
  );
}
