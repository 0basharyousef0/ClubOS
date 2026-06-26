import 'package:flutter/material.dart';

import 'tab_header_hero.dart';

/// The app's signature purple gradient header, shared across the primary
/// destinations and the More-section pages.
///
/// It's wrapped in a [TabHeaderHero] (shared tag) so that when one of these
/// screens swaps to another inside the shell — e.g. More → Settings, or a tab
/// switch — the purple band stays anchored while the title and the content
/// beneath it animate. Keep the header to the *consistent* purple chrome only
/// (title + optional badge / action); page-specific controls like tab bars
/// belong in the content below so they don't ride along in the Hero flight.
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.title,
    this.badge,
    this.trailing,
  });

  /// The large white title, e.g. "Polls".
  final String title;

  /// Optional pill rendered beneath the title (see [GradientHeaderBadge]).
  final Widget? badge;

  /// Optional trailing action(s) on the title row (e.g. Save / sign out).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return TabHeaderHero(
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
            24, MediaQuery.of(context).padding.top + 16, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            if (badge != null) ...[
              const SizedBox(height: 8),
              badge!,
            ],
          ],
        ),
      ),
    );
  }
}

/// The translucent white pill used inside a [GradientHeader] (e.g. club name).
class GradientHeaderBadge extends StatelessWidget {
  const GradientHeaderBadge({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
