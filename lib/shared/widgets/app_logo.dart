import 'package:flutter/material.dart';

import '../../app/theme.dart';

class AppLogo extends StatelessWidget {
  final bool onDark;
  final double size;

  const AppLogo({super.key, this.onDark = false, this.size = 88});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    if (onDark) {
      // On purple background: white card with subtle glow so the logo stands out
      return Container(
        width: size * 1.18,
        height: size * 1.18,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.28),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.30),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        padding: EdgeInsets.all(size * 0.09),
        child: image,
      );
    }

    // On light background: just the image with a soft primary-color glow ring
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size * 1.27,
          height: size * 1.27,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.39),
            color: AppColors.primary.withValues(alpha: 0.07),
          ),
        ),
        image,
      ],
    );
  }
}
