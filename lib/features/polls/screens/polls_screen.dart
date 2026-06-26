import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/gradient_header.dart';
import '../../../features/auth/providers/auth_providers.dart';
import '../../../shared/models/poll_model.dart';
import '../providers/polls_providers.dart';

class PollsScreen extends ConsumerWidget {
  const PollsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(activeClubRoleProvider);
    final canCreate =
        role?.isPresident == true || role?.isVicePresident == true;

    return DefaultTabController(
      length: 2,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButton: canCreate
              ? FloatingActionButton(
                  onPressed: () => context.go('/polls/create'),
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : null,
          body: Column(
            children: [
              const GradientHeader(title: 'Polls'),
              Material(
                color: AppColors.background,
                child: const TabBar(
                  tabs: [Tab(text: 'Active'), Tab(text: 'Closed')],
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                ),
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    _PollsList(active: true),
                    _PollsList(active: false),
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

class _PollsList extends ConsumerWidget {
  final bool active;
  const _PollsList({required this.active});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pollsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (all) {
        final now = DateTime.now();
        final polls = all.where((p) {
          if (active) return p.closesAt == null || p.closesAt!.isAfter(now);
          return p.closesAt != null && p.closesAt!.isBefore(now);
        }).toList();

        if (polls.isEmpty) {
          return Center(
            child: Text(
              active ? 'No active polls.' : 'No closed polls.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(pollsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: polls.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _PollCard(poll: polls[i]),
          ),
        );
      },
    );
  }
}

class _PollCard extends StatelessWidget {
  final PollModel poll;
  const _PollCard({required this.poll});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/polls/${poll.id}'),
      child: Container(
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
              children: [
                Expanded(
                  child: Text(
                    poll.title,
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
                    poll.audienceDisplayName,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary),
                  ),
                ),
              ],
            ),
            if (poll.description != null && poll.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                poll.description!,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.how_to_vote_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${poll.totalVotes} vote${poll.totalVotes == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                if (poll.closesAt != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.schedule_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Closes ${DateFormat('MMM d').format(poll.closesAt!)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
                const Spacer(),
                if (poll.hasVoted)
                  const Icon(Icons.check_circle_rounded,
                      size: 16, color: AppColors.success),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
