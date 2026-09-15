import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class AppLogo extends StatelessWidget {
  final double height;
  final bool dark;

  const AppLogo({super.key, this.height = 48, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final color = dark ? AppColors.textOnBrand : AppColors.brandPrimary;
    final textColor = dark ? AppColors.textOnBrand : AppColors.textPrimary;
    final markSize = height * 0.75;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: markSize,
          height: markSize,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(markSize * 0.28),
          ),
          alignment: Alignment.center,
          child: Text(
            'S',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              color: AppColors.textOnBrand,
              fontSize: markSize * 0.55,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
        SizedBox(width: height * 0.28),
        Text(
          'SteryMed',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            color: textColor,
            fontSize: height * 0.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1,
          ),
        ),
      ],
    );
  }
}
