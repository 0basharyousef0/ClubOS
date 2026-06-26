import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/constants.dart';
import '../../../shared/models/activity_log_model.dart';
import '../../../shared/models/user_club_role_model.dart';
import '../../../shared/widgets/gradient_header.dart';
import '../providers/activity_log_providers.dart';

/// President-only feed of club activity — task updates, RSVPs, announcements,
/// and poll votes — with filters by action type, member, and date range.
class ActivityLogScreen extends ConsumerWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(activityLogProvider);
    final filter = ref.watch(activityFilterProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            GradientHeader(
              title: 'Activity Log',
              trailing: filter.isActive
                  ? TextButton(
                      onPressed: () => ref
                          .read(activityFilterProvider.notifier)
                          .state = const ActivityFilter(),
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text('Clear'),
                    )
                  : null,
            ),
            const _FilterBar(),
            Expanded(
              child: activityAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2.5,
                  ),
                ),
                error: (_, _) => _ErrorState(
                  onRetry: () => ref.invalidate(activityLogProvider),
                ),
                data: (items) => RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.invalidate(activityLogProvider),
                  child: items.isEmpty
                      ? _EmptyState(filtered: filter.isActive)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _ActivityTile(entry: items[i]),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter bar ──────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(activityFilterProvider);

    void setActionType(String? type) =>
        ref.read(activityFilterProvider.notifier).state = ActivityFilter(
          actorId: filter.actorId,
          actionType: type,
          range: filter.range,
        );

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _TypeChip(
                  label: 'All',
                  selected: filter.actionType == null,
                  onTap: () => setActionType(null),
                ),
                for (final type in _actionTypes) ...[
                  const SizedBox(width: 8),
                  _TypeChip(
                    label: _actionLabel(type),
                    selected: filter.actionType == type,
                    onTap: () => setActionType(type),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: _MemberFilterButton()),
                SizedBox(width: 10),
                Expanded(child: _DateFilterButton()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary.withValues(alpha: 0.12),
      side: BorderSide(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.45)
            : AppColors.border,
      ),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: selected ? AppColors.primary : AppColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

class _MemberFilterButton extends ConsumerWidget {
  const _MemberFilterButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(activityFilterProvider);
    final members = ref.watch(activityMembersProvider).valueOrNull ?? const [];

    var label = 'All members';
    if (filter.actorId != null) {
      label = 'Member';
      for (final m in members) {
        if (m.userId == filter.actorId) {
          label = m.profile?.fullName ?? 'Member';
          break;
        }
      }
    }

    return _FilterPillButton(
      icon: Icons.person_outline_rounded,
      label: label,
      active: filter.actorId != null,
      onTap: () => _showMemberPicker(context, ref, members, filter),
    );
  }
}

class _DateFilterButton extends ConsumerWidget {
  const _DateFilterButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(activityFilterProvider);
    final range = filter.range;
    final label = range == null
        ? 'Any time'
        : '${DateFormat('MMM d').format(range.start)} – '
            '${DateFormat('MMM d').format(range.end)}';

    return _FilterPillButton(
      icon: Icons.calendar_today_rounded,
      label: label,
      active: range != null,
      onTap: () => _pickDateRange(context, ref, filter),
    );
  }
}

class _FilterPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterPillButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textSecondary;
    return Material(
      color:
          active ? AppColors.primary.withValues(alpha: 0.07) : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: active ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tile ────────────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  final ActivityLogModel entry;
  const _ActivityTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = _actionColor(entry.actionType);
    final subject = entry.subjectTitle;
    final sentence = _actionSentence(entry.actionType);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
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
            child: Icon(_actionIcon(entry.actionType), color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        entry.actorName ?? 'A member',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo(entry.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subject == null ? sentence : '$sentence · $subject',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty / error states ────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool filtered;
  const _EmptyState({required this.filtered});

  @override
  Widget build(BuildContext context) {
    // Scrollable so pull-to-refresh still works with an empty list.
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
                  Icon(
                    filtered
                        ? Icons.filter_alt_off_rounded
                        : Icons.history_rounded,
                    size: 56,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    filtered ? 'No matching activity' : 'No activity yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    filtered
                        ? 'Try adjusting or clearing your filters.'
                        : 'Task updates, RSVPs, announcements, and votes will appear here.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
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
            const Icon(Icons.cloud_off_rounded,
                size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              "Couldn't load activity",
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
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
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

// ── Filter actions ──────────────────────────────────────────────

Future<void> _pickDateRange(
  BuildContext context,
  WidgetRef ref,
  ActivityFilter filter,
) async {
  final now = DateTime.now();
  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(now.year - 2),
    lastDate: now,
    initialDateRange: filter.range,
  );
  if (picked != null) {
    ref.read(activityFilterProvider.notifier).state = ActivityFilter(
      actorId: filter.actorId,
      actionType: filter.actionType,
      range: picked,
    );
  }
}

void _showMemberPicker(
  BuildContext context,
  WidgetRef ref,
  List<UserClubRoleModel> members,
  ActivityFilter filter,
) {
  void select(String? actorId) {
    ref.read(activityFilterProvider.notifier).state = ActivityFilter(
      actorId: actorId,
      actionType: filter.actionType,
      range: filter.range,
    );
    Navigator.of(context).pop();
  }

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Filter by member',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.background,
                    child: Icon(Icons.groups_outlined,
                        color: AppColors.textSecondary, size: 20),
                  ),
                  title: const Text('All members'),
                  trailing: filter.actorId == null
                      ? const Icon(Icons.check_rounded, color: AppColors.primary)
                      : null,
                  onTap: () => select(null),
                ),
                for (final m in members)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        _initials(m.profile?.fullName),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    title: Text(m.profile?.fullName ?? 'Member'),
                    subtitle: Text(m.roleDisplayName),
                    trailing: filter.actorId == m.userId
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.primary)
                        : null,
                    onTap: () => select(m.userId),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Action-type display helpers ─────────────────────────────────

const _actionTypes = <String>[
  AppConstants.actionTaskCompleted,
  AppConstants.actionTaskStarted,
  AppConstants.actionEventRsvp,
  AppConstants.actionAnnouncementPosted,
  AppConstants.actionPollVote,
];

String _actionLabel(String type) => switch (type) {
  AppConstants.actionTaskCompleted => 'Completed',
  AppConstants.actionTaskStarted => 'Started',
  AppConstants.actionEventRsvp => 'RSVPs',
  AppConstants.actionAnnouncementPosted => 'Announced',
  AppConstants.actionPollVote => 'Votes',
  _ => 'Other',
};

String _actionSentence(String type) => switch (type) {
  AppConstants.actionTaskCompleted => 'Completed a task',
  AppConstants.actionTaskStarted => 'Started a task',
  AppConstants.actionEventRsvp => 'RSVP’d to an event',
  AppConstants.actionAnnouncementPosted => 'Posted an announcement',
  AppConstants.actionPollVote => 'Voted in a poll',
  _ => 'Recorded an action',
};

IconData _actionIcon(String type) => switch (type) {
  AppConstants.actionTaskCompleted => Icons.check_circle_outline_rounded,
  AppConstants.actionTaskStarted => Icons.play_circle_outline_rounded,
  AppConstants.actionEventRsvp => Icons.event_available_outlined,
  AppConstants.actionAnnouncementPosted => Icons.campaign_outlined,
  AppConstants.actionPollVote => Icons.how_to_vote_outlined,
  _ => Icons.history_rounded,
};

Color _actionColor(String type) => switch (type) {
  AppConstants.actionTaskCompleted => AppColors.success,
  AppConstants.actionTaskStarted => const Color(0xFF3B82F6),
  AppConstants.actionEventRsvp => AppColors.primary,
  AppConstants.actionAnnouncementPosted => AppColors.warning,
  AppConstants.actionPollVote => const Color(0xFF8B5CF6),
  _ => AppColors.textSecondary,
};

String _initials(String? name) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

String _timeAgo(DateTime dt) {
  final d = DateTime.now().difference(dt.toLocal());
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return DateFormat('MMM d').format(dt.toLocal());
}
