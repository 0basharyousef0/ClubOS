import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/constants.dart';

/// Accent color for a club role, reused across directory cards and the
/// member profile so a role always reads the same color app-wide.
Color roleColor(String role) => switch (role) {
  AppConstants.rolePresident => AppColors.primary,
  AppConstants.roleVicePresident => const Color(0xFF3B82F6),
  AppConstants.roleDirector => const Color(0xFF10B981),
  _ => AppColors.textSecondary,
};

/// A small colored pill showing a role's display name.
class RolePill extends StatelessWidget {
  const RolePill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// A small muted pill, e.g. "You".
class MutedTag extends StatelessWidget {
  const MutedTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
