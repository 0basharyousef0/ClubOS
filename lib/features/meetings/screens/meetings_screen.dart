import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/gradient_header.dart';
import '../../../features/auth/providers/auth_providers.dart';
import '../../../shared/models/meeting_model.dart';
import '../providers/meetings_providers.dart';

class MeetingsScreen extends ConsumerWidget {
  const MeetingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(activeClubRoleProvider);
    final canCreate =
        role?.isPresident == true || role?.isVicePresident == true;
    final meetingsAsync = ref.watch(meetingsProvider);

    return DefaultTabController(
      length: 2,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButton: canCreate
              ? FloatingActionButton.extended(
                  onPressed: () => context.go('/meetings/create'),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Schedule'),
                )
              : null,
          body: Column(
            children: [
              GradientHeader(
                title: 'Meetings',
                badge: meetingsAsync.whenOrNull(
                  data: (meetings) {
                    final upcoming =
                        meetings.where((m) => !m.isPast).length;
                    return GradientHeaderBadge(
                      icon: Icons.groups_rounded,
                      label: '$upcoming upcoming',
                    );
                  },
                ),
              ),
              Material(
                color: AppColors.background,
                child: const TabBar(
                  tabs: [Tab(text: 'Upcoming'), Tab(text: 'Past')],
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                ),
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    _MeetingsList(upcoming: true),
                    _MeetingsList(upcoming: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeetingsList extends ConsumerWidget {
  final bool upcoming;
  const _MeetingsList({required this.upcoming});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(meetingsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (all) {
        final meetings =
            all.where((m) => upcoming ? !m.isPast : m.isPast).toList();
        if (!upcoming) {
          // Most recent past meeting first.
          meetings.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
        }

        if (meetings.isEmpty) {
          return Center(
            child: Text(
              upcoming ? 'No upcoming meetings.' : 'No past meetings.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(meetingsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: meetings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _MeetingCard(meeting: meetings[i]),
          ),
        );
      },
    );
  }
}

class _MeetingCard extends ConsumerWidget {
  final MeetingModel meeting;
  const _MeetingCard({required this.meeting});

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel meeting?'),
        content: Text(
            'Everyone invited to "${meeting.title}" will be notified that '
            'it was cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel meeting'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(meetingsRepositoryProvider).deleteMeeting(meeting.id);
      ref.invalidate(meetingsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUserId = ref.watch(activeClubRoleProvider)?.userId;
    final isCreator = meeting.createdBy == myUserId;
    final attendeeNames = [
      for (final a in meeting.attendees) a.fullName ?? 'Member',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  meeting.title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  meeting.audienceDisplayName,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.event_rounded,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                DateFormat('EEE, MMM d · h:mm a').format(meeting.scheduledAt),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary),
              ),
              if (meeting.isRecurring) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.repeat_rounded,
                          size: 11, color: Color(0xFF10B981)),
                      const SizedBox(width: 3),
                      Text(
                        meeting.recurrenceDisplayName,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (meeting.notes != null && meeting.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              meeting.notes!,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.people_outline_rounded,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  attendeeNames.isEmpty
                      ? '${meeting.attendees.length} invited'
                      : attendeeNames.join(', '),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (meeting.reminderDisplayName != null || isCreator) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (meeting.reminderDisplayName != null) ...[
                  const Icon(Icons.alarm_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Reminder ${meeting.reminderDisplayName}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
                const Spacer(),
                if (isCreator && !meeting.isPast)
                  GestureDetector(
                    onTap: () => _confirmCancel(context, ref),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.error),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
