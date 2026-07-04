import 'package:flutter/material.dart';

import '../../app/theme.dart';

class AppLogo extends StatelessWidget {
  final bool onDark;
  final double size;

  const AppLogo({super.key, this.onDark = false, this.size = 88});

  @override
  Widget build(BuildContext context) {
    // The PNG is full-bleed artwork, so clip it into the rounded square
    // and let it cover the tile edge to edge (app-icon style).
    final tileSize = size * 1.18;
    final tile = ClipRRect(
      borderRadius: BorderRadius.circular(tileSize * 0.24),
      child: Image.asset(
        'assets/images/logo.png',
        width: tileSize,
        height: tileSize,
        fit: BoxFit.cover,
      ),
    );

    if (onDark) {
      // On purple background: subtle glow so the logo stands out
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tileSize * 0.24),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.30),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: tile,
      );
    }

    // On light background: soft primary-color glow ring behind the tile
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
        tile,
      ],
    );
  }
}
