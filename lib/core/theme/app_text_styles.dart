import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle display({double size = 32, FontWeight weight = FontWeight.w800}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: -0.02 * size,
        color: AppColors.textPrimary,
      );

  static TextStyle body({
    double size = 15,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.textPrimary,
  }) =>
      GoogleFonts.instrumentSans(fontSize: size, fontWeight: weight, color: color);

  static TextStyle bodySecondary({double size = 14}) =>
      body(size: size, weight: FontWeight.w500, color: AppColors.textSecondary);
}
