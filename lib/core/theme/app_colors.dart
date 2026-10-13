import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFFD297B);
  static const Color primaryDark = Color(0xFFFF655B);
  static const Color secondary = Color(0xFFFF5864);
  
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundDark = Color(0xFF121212);
  
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight = Color(0xFFFFFFFF);
  
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  
  // Gradient for primary buttons (Tinder-like gradient)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );
}
