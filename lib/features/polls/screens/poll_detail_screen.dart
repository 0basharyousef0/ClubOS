import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/poll_model.dart';
import '../providers/polls_providers.dart';

class PollDetailScreen extends ConsumerStatefulWidget {
  final String pollId;
  const PollDetailScreen({super.key, required this.pollId});

  @override
  ConsumerState<PollDetailScreen> createState() => _PollDetailScreenState();
}

class _PollDetailScreenState extends ConsumerState<PollDetailScreen> {
  String? _selectedOptionId;
  bool _isVoting = false;

  Future<void> _confirmDelete(PollModel poll) async {
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
                'Delete Poll?',
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
                      text: poll.title,
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
      await ref.read(pollsRepositoryProvider).deletePoll(poll.id);
      ref.invalidate(pollsProvider);
      if (mounted) context.go('/polls');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete poll. Try again.')),
        );
      }
    }
  }

  Future<void> _confirmClose(PollModel poll) async {
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
                  color: AppColors.warning.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.timer_off_rounded,
                  color: AppColors.warning,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Close Poll Early?',
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
                      text: poll.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const TextSpan(
                        text: '" will stop accepting votes immediately. '
                            'Results stay visible. This cannot be undone.'),
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
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Close Poll'),
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
                  child: const Text('Keep Open'),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true) return;
    try {
      await ref.read(pollsRepositoryProvider).closePoll(poll.id);
      ref.invalidate(pollDetailProvider(widget.pollId));
      ref.invalidate(pollsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poll closed.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not close poll. Try again.')),
        );
      }
    }
  }

  Future<void> _vote() async {
    if (_selectedOptionId == null) return;
    setState(() => _isVoting = true);
    try {
      await ref
          .read(pollsRepositoryProvider)
          .vote(widget.pollId, _selectedOptionId!);
      ref.invalidate(pollDetailProvider(widget.pollId));
      ref.invalidate(pollsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit vote: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pollDetailProvider(widget.pollId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/polls'),
        ),
        title: const Text('Poll'),
        actions: [
          if (async.whenOrNull(
                data: (p) => p.createdBy == supabase.auth.currentUser?.id,
              ) ==
              true)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 22),
              color: AppColors.error,
              onPressed: () => _confirmDelete(async.value!),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (poll) => _PollBody(
          poll: poll,
          selectedOptionId: _selectedOptionId,
          isVoting: _isVoting,
          isCreator: poll.createdBy == supabase.auth.currentUser?.id,
          onSelect: (id) => setState(() => _selectedOptionId = id),
          onVote: _vote,
          onClose: () => _confirmClose(poll),
        ),
      ),
    );
  }
}

class _PollBody extends StatelessWidget {
  final PollModel poll;
  final String? selectedOptionId;
  final bool isVoting;
  final bool isCreator;
  final ValueChanged<String> onSelect;
  final VoidCallback onVote;
  final VoidCallback onClose;

  const _PollBody({
    required this.poll,
    required this.selectedOptionId,
    required this.isVoting,
    required this.isCreator,
    required this.onSelect,
    required this.onVote,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final showResults = poll.hasVoted || !poll.isOpen;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Header
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                poll.audienceDisplayName,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary),
              ),
            ),
            const Spacer(),
            if (!poll.isOpen)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Closed',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(poll.title, style: Theme.of(context).textTheme.headlineMedium),
        if (poll.description != null && poll.description!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(poll.description!,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
        ],
        if (poll.closesAt != null) ...[
          const SizedBox(height: 8),
          Text(
            '${poll.isOpen ? 'Closes' : 'Closed'} ${DateFormat('MMM d, y').format(poll.closesAt!)}',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 28),
        Text(
          showResults
              ? '${poll.totalVotes} vote${poll.totalVotes == 1 ? '' : 's'}'
              : 'Choose an option',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 14),
        ...poll.options.map((opt) => showResults
            ? _ResultBar(
                option: opt,
                total: poll.totalVotes,
                isMyVote: poll.myVoteOptionId == opt.id,
              )
            : _VoteOption(
                option: opt,
                selected: selectedOptionId == opt.id,
                onTap: () => onSelect(opt.id),
              )),
        const SizedBox(height: 24),
        if (!showResults && poll.isOpen)
          ElevatedButton(
            onPressed:
                (selectedOptionId == null || isVoting) ? null : onVote,
            child: isVoting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Submit Vote'),
          ),
        // Creator-only: end voting before the scheduled close date
        if (isCreator && poll.isOpen) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onClose,
            icon: const Icon(Icons.timer_off_rounded, size: 18),
            label: const Text('Close Poll Early'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.warning,
              side: BorderSide(
                  color: AppColors.warning.withValues(alpha: 0.45)),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _VoteOption extends StatelessWidget {
  final PollOptionModel option;
  final bool selected;
  final VoidCallback onTap;

  const _VoteOption(
      {required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option.text,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ResultBar extends StatelessWidget {
  final PollOptionModel option;
  final int total;
  final bool isMyVote;

  const _ResultBar(
      {required this.option, required this.total, required this.isMyVote});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : option.voteCount / total;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isMyVote)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.primary, size: 16),
              if (isMyVote) const SizedBox(width: 6),
              Expanded(
                child: Text(
                  option.text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isMyVote
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${(pct * 100).round()}%',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                isMyVote
                    ? AppColors.primary
                    : AppColors.secondary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${option.voteCount} vote${option.voteCount == 1 ? '' : 's'}',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
