import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../features/auth/providers/auth_providers.dart';
import '../../../features/dashboard/providers/dashboard_providers.dart';
import '../../../shared/models/event_model.dart';
import '../providers/events_providers.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() =>
      _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _rsvpLoading = false;

  Future<void> _confirmDelete(EventModel event) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final bottomPadding = MediaQuery.of(ctx).padding.bottom;
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Delete Event?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: '"'),
                    TextSpan(
                      text: event.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const TextSpan(
                        text: '" will be permanently removed and cannot be undone.'),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Delete'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true) return;
    try {
      await ref.read(eventsRepositoryProvider).deleteEvent(event.id);
      ref.invalidate(clubEventsProvider);
      ref.invalidate(upcomingEventsProvider);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete event. Try again.')),
        );
      }
    }
  }

  Future<void> _toggleRsvp(EventModel event) async {
    setState(() => _rsvpLoading = true);
    try {
      final repo = ref.read(eventsRepositoryProvider);
      if (event.currentUserRsvped) {
        await repo.cancelRsvp(event.id);
      } else {
        await repo.rsvp(event.id);
      }
      ref.invalidate(eventDetailProvider(widget.eventId));
      ref.invalidate(clubEventsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update RSVP. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _rsvpLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(activeClubRoleProvider);
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));

    final currentUserId = supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: AppColors.textPrimary,
          onPressed: () => context.pop(),
        ),
        title: const Text('Event Details'),
        centerTitle: true,
        actions: [
          if (eventAsync.whenOrNull(
                data: (e) => e.createdBy == currentUserId,
              ) ==
              true)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 22),
              color: AppColors.error,
              onPressed: () => _confirmDelete(eventAsync.value!),
            ),
        ],
      ),
      body: eventAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2.5),
        ),
        error: (_, _) => const Center(
          child: Text('Could not load event.',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        data: (event) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _DateBanner(event: event, isPresident: role?.isPresident ?? false),
            const SizedBox(height: 16),
            _DetailCard(event: event),
            const SizedBox(height: 16),
            if (role?.canRsvp == true && event.isUpcoming)
              _RsvpButton(
                event: event,
                loading: _rsvpLoading,
                onTap: () => _toggleRsvp(event),
              ),
            if (role?.canViewRsvps == true)
              _RsvpListSection(eventId: widget.eventId),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Date banner ───────────────────────────────────────────────

class _DateBanner extends StatelessWidget {
  final EventModel event;
  final bool isPresident;
  const _DateBanner({required this.event, required this.isPresident});

  @override
  Widget build(BuildContext context) {
    final date = event.eventDate;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('MMM').format(date).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  DateFormat('d').format(date),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  DateFormat('EEE').format(date).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        color: Colors.white70, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('h:mm a').format(date),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
                if (isPresident) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.people_outline_rounded,
                          color: Colors.white70, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        '${event.rsvpCount} going',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Detail card ───────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final EventModel event;
  const _DetailCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Row(
            icon: Icons.calendar_today_rounded,
            label: 'Date',
            value: DateFormat('EEEE, MMMM d, y').format(event.eventDate),
          ),
          const Divider(height: 20, color: AppColors.border),
          _Row(
            icon: Icons.access_time_rounded,
            label: 'Time',
            value: DateFormat('h:mm a').format(event.eventDate),
          ),
          if (event.createdByName != null) ...[
            const Divider(height: 20, color: AppColors.border),
            _Row(
              icon: Icons.person_outline_rounded,
              label: 'Posted by',
              value: event.createdByName!,
            ),
          ],
          if (event.description != null && event.description!.isNotEmpty) ...[
            const Divider(height: 20, color: AppColors.border),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    event.description!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
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

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      );
}

// ── RSVP button (VP / Director) ───────────────────────────────

class _RsvpButton extends StatelessWidget {
  final EventModel event;
  final bool loading;
  final VoidCallback onTap;
  const _RsvpButton(
      {required this.event, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final going = event.currentUserRsvped;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: loading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: going ? AppColors.surface : AppColors.primary,
            foregroundColor: going ? AppColors.error : Colors.white,
            side: going
                ? const BorderSide(color: AppColors.error)
                : BorderSide.none,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: loading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: going ? AppColors.error : Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      going
                          ? Icons.event_busy_rounded
                          : Icons.event_available_rounded,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      going ? 'Cancel RSVP' : 'RSVP — I\'m Going',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── RSVP list (President only) ────────────────────────────────

class _RsvpListSection extends ConsumerWidget {
  final String eventId;
  const _RsvpListSection({required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rsvpAsync = ref.watch(eventRsvpListProvider(eventId));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.people_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Who\'s Going',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                rsvpAsync.whenOrNull(
                  data: (list) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${list.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ) ?? const SizedBox.shrink(),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          rsvpAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2.5),
              ),
            ),
            error: (_, _) => const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Could not load RSVPs.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No one has RSVP\'d yet.',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (_, i) {
                      final r = list[i];
                      final profile =
                          r['profiles'] as Map<String, dynamic>?;
                      final name =
                          profile?['full_name'] as String? ?? 'Unknown';
                      final email = profile?['email'] as String? ?? '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                      )),
                                  if (email.isNotEmpty)
                                    Text(email,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        )),
                                ],
                              ),
                            ),
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.success, size: 18),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
