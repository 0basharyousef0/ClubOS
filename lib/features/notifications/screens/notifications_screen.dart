import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/constants.dart';
import '../../../shared/models/notification_model.dart';
import '../../../shared/widgets/gradient_header.dart';
import '../providers/notifications_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            GradientHeader(
              title: 'Notifications',
              trailing: unread > 0
                  ? TextButton(
                      onPressed: () => _markAll(ref),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Mark all read'),
                    )
                  : null,
            ),
            Expanded(
              child: notifsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2.5,
                  ),
                ),
                error: (_, _) => _ErrorState(
                  onRetry: () => ref.invalidate(notificationsProvider),
                ),
                data: (items) => RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.invalidate(notificationsProvider),
                  child: items.isEmpty
                      ? const _EmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _NotificationTile(
                            notification: items[i],
                            onTap: () => _handleTap(context, ref, items[i]),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAll(WidgetRef ref) async {
    await ref.read(notificationsRepositoryProvider).markAllAsRead();
    ref.invalidate(notificationsProvider);
  }

  Future<void> _handleTap(
    BuildContext context,
    WidgetRef ref,
    NotificationModel n,
  ) async {
    if (!n.read) {
      await ref.read(notificationsRepositoryProvider).markAsRead(n.id);
      ref.invalidate(notificationsProvider);
    }
    final route = _routeForType(n.type);
    if (route != null && context.mounted) context.go(route);
  }
}

// ── Type → visuals / destination ────────────────────────────────

IconData _typeIcon(String type) => switch (type) {
  AppConstants.notifTaskAssigned => Icons.assignment_outlined,
  AppConstants.notifEventPosted => Icons.event_outlined,
  AppConstants.notifAnnouncement => Icons.campaign_outlined,
  AppConstants.notifPollCreated => Icons.how_to_vote_outlined,
  AppConstants.notifMembershipApproved => Icons.verified_user_outlined,
  AppConstants.notifJoinRequest => Icons.person_add_alt_1_outlined,
  _ => Icons.notifications_outlined,
};

Color _typeColor(String type) => switch (type) {
  AppConstants.notifTaskAssigned => const Color(0xFF3B82F6),
  AppConstants.notifEventPosted => AppColors.primary,
  AppConstants.notifAnnouncement => const Color(0xFFF59E0B),
  AppConstants.notifPollCreated => AppColors.primary,
  AppConstants.notifMembershipApproved => const Color(0xFF10B981),
  AppConstants.notifJoinRequest => const Color(0xFFF59E0B),
  _ => AppColors.textSecondary,
};

/// Where tapping a notification takes the user. The schema stores no entity id,
/// so we route to the relevant section rather than a specific item.
String? _routeForType(String type) => switch (type) {
  AppConstants.notifTaskAssigned => '/tasks',
  AppConstants.notifEventPosted => '/events',
  AppConstants.notifAnnouncement => '/announcements',
  AppConstants.notifPollCreated => '/polls',
  AppConstants.notifJoinRequest => '/approvals',
  _ => null,
};

String _timeAgo(DateTime dt) {
  final d = DateTime.now().difference(dt.toLocal());
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return DateFormat('MMM d').format(dt.toLocal());
}

// ── Tile ────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(notification.type);
    final unread = !notification.read;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: unread
                ? AppColors.primary.withValues(alpha: 0.20)
                : AppColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_typeIcon(notification.type), color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(notification.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (unread) ...[
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── States ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    // Scrollable so pull-to-refresh works even with no notifications.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    size: 56,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "You're all caught up",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'No notifications yet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              "Couldn't load notifications",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
