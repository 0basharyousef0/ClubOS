import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/tab_header_hero.dart';
import '../../../features/auth/providers/auth_providers.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(activeClubRoleProvider);
    final isPresident = role?.isPresident ?? false;

    final destinations = [
      _Destination(
        icon: Icons.people_alt_rounded,
        label: 'Directory',
        route: '/directory',
        color: const Color(0xFF10B981),
      ),
      _Destination(
        icon: Icons.how_to_vote_rounded,
        label: 'Polls',
        route: '/polls',
        color: AppColors.primary,
      ),
      _Destination(
        icon: Icons.groups_rounded,
        label: 'Meetings',
        route: '/meetings',
        color: const Color(0xFF0EA5E9),
      ),
      _Destination(
        icon: Icons.notifications_rounded,
        label: 'Notifications',
        route: '/notifications',
        color: const Color(0xFFF59E0B),
      ),
      _Destination(
        icon: Icons.menu_book_rounded,
        label: 'Resources',
        route: '/resources',
        color: const Color(0xFF8B5CF6),
      ),
      if (isPresident)
        _Destination(
          icon: Icons.how_to_reg_rounded,
          label: 'Join Requests',
          route: '/approvals',
          color: const Color(0xFF3B82F6),
        ),
      if (isPresident)
        _Destination(
          icon: Icons.bar_chart_rounded,
          label: 'Activity Log',
          route: '/activity-log',
          color: const Color(0xFFEF4444),
        ),
      _Destination(
        icon: Icons.settings_rounded,
        label: 'Settings',
        route: '/settings',
        color: const Color(0xFF6B7280),
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            TabHeaderHero(child: _MoreHeader(clubName: role?.club?.name)),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.1,
                ),
                itemCount: destinations.length,
                itemBuilder: (context, i) => _DestinationCard(
                  destination: destinations[i],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Destination {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  const _Destination({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
  });
}

class _MoreHeader extends StatelessWidget {
  final String? clubName;
  const _MoreHeader({this.clubName});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Text(
            'More',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          if (clubName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.grid_view_rounded,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    clubName!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  final _Destination destination;
  const _DestinationCard({required this.destination});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(destination.route),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: destination.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(destination.icon,
                  color: destination.color, size: 24),
            ),
            const Spacer(),
            Text(
              destination.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
