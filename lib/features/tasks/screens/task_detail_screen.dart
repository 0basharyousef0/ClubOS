import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../features/dashboard/providers/dashboard_providers.dart';
import '../../../shared/models/task_comment_model.dart';
import '../../../shared/models/task_model.dart';
import '../providers/tasks_providers.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final _commentController = TextEditingController();
  bool _isPosting = false;
  bool _isUpdatingStatus = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String get _currentUserId => supabase.auth.currentUser!.id;

  Future<void> _confirmDelete(TaskModel task) async {
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
                'Delete Task?',
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
                      text: task.title,
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
      await ref.read(tasksRepositoryProvider).deleteTask(task.id);
      ref.invalidate(assignedByMeTasksProvider);
      ref.invalidate(myAssignedTasksProvider);
      ref.invalidate(myTasksProvider);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete task. Try again.')),
        );
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdatingStatus = true);
    try {
      await ref
          .read(tasksRepositoryProvider)
          .updateStatus(widget.taskId, newStatus);
      ref.invalidate(taskDetailProvider(widget.taskId));
      ref.invalidate(assignedByMeTasksProvider);
      ref.invalidate(myAssignedTasksProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update status.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isPosting = true);
    try {
      await ref
          .read(tasksRepositoryProvider)
          .addComment(widget.taskId, text);
      _commentController.clear();
      ref.invalidate(taskCommentsProvider(widget.taskId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to post comment.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskDetailProvider(widget.taskId));

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
        title: taskAsync.maybeWhen(
          data: (t) => Text(
            t.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          orElse: () => const Text('Task'),
        ),
        centerTitle: true,
        actions: [
          if (taskAsync.whenOrNull(
                data: (t) => t.assignedBy == _currentUserId,
              ) ==
              true)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 22),
              color: AppColors.error,
              onPressed: () => _confirmDelete(taskAsync.value!),
            ),
        ],
      ),
      body: taskAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2.5),
        ),
        error: (_, _) => const Center(
          child: Text('Could not load task.',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        data: (task) => _TaskBody(
          task: task,
          taskId: widget.taskId,
          currentUserId: _currentUserId,
          commentController: _commentController,
          isPosting: _isPosting,
          isUpdatingStatus: _isUpdatingStatus,
          onUpdateStatus: _updateStatus,
          onPostComment: _postComment,
        ),
      ),
    );
  }
}

class _TaskBody extends ConsumerWidget {
  final TaskModel task;
  final String taskId;
  final String currentUserId;
  final TextEditingController commentController;
  final bool isPosting;
  final bool isUpdatingStatus;
  final Future<void> Function(String) onUpdateStatus;
  final Future<void> Function() onPostComment;

  const _TaskBody({
    required this.task,
    required this.taskId,
    required this.currentUserId,
    required this.commentController,
    required this.isPosting,
    required this.isUpdatingStatus,
    required this.onUpdateStatus,
    required this.onPostComment,
  });

  bool get _isAssignedToMe => task.assignedTo == currentUserId;

  Color get _urgencyColor => switch (task.urgency) {
        'high' => AppColors.error,
        'low' => AppColors.success,
        _ => AppColors.warning,
      };

  Color get _statusColor => switch (task.status) {
        'in_progress' => const Color(0xFF3B82F6),
        'complete' => AppColors.success,
        _ => const Color(0xFF9CA3AF),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(taskCommentsProvider(taskId));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Status card ───────────────────────────────────────
        _StatusCard(
          task: task,
          statusColor: _statusColor,
          isAssignedToMe: _isAssignedToMe,
          isUpdating: isUpdatingStatus,
          onUpdate: onUpdateStatus,
        ),

        const SizedBox(height: 16),

        // ── Details card ──────────────────────────────────────
        _DetailCard(task: task, urgencyColor: _urgencyColor),

        // ── Description ───────────────────────────────────────
        if (task.description != null && task.description!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Description',
            icon: Icons.notes_rounded,
            child: Text(
              task.description!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // ── Comments ──────────────────────────────────────────
        _SectionCard(
          title: 'Comments',
          icon: Icons.chat_bubble_outline_rounded,
          child: commentsAsync.when(
            loading: () => const SizedBox(
                height: 24,
                child: Center(
                    child: LinearProgressIndicator(
                        color: AppColors.primary))),
            error: (_, _) => const Text('Could not load comments.',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            data: (comments) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (comments.isEmpty)
                  const Text(
                    'No comments yet. Be the first!',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  )
                else
                  ...comments
                      .map((c) => _CommentBubble(
                          comment: c, isMe: c.userId == currentUserId)),
                const SizedBox(height: 14),
                // Comment input
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization:
                            TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Write a comment...',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: isPosting ? null : onPostComment,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: isPosting
                            ? const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2),
                                ),
                              )
                            : const Icon(Icons.send_rounded,
                                color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }
}

// ── Status card ───────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final TaskModel task;
  final Color statusColor;
  final bool isAssignedToMe;
  final bool isUpdating;
  final Future<void> Function(String) onUpdate;

  const _StatusCard({
    required this.task,
    required this.statusColor,
    required this.isAssignedToMe,
    required this.isUpdating,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    String? nextStatus;
    String? nextLabel;
    IconData? nextIcon;

    if (isAssignedToMe) {
      if (task.isNotStarted) {
        nextStatus = AppConstants.taskInProgress;
        nextLabel = 'Start Task';
        nextIcon = Icons.play_arrow_rounded;
      } else if (task.isInProgress) {
        nextStatus = AppConstants.taskComplete;
        nextLabel = 'Mark Complete';
        nextIcon = Icons.check_rounded;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              task.isComplete
                  ? Icons.check_circle_rounded
                  : task.isInProgress
                      ? Icons.timelapse_rounded
                      : Icons.radio_button_unchecked_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.statusDisplayName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                if (task.isComplete)
                  const Text('This task is done.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary))
                else if (!isAssignedToMe)
                  const Text('Only the assignee can update status.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (nextStatus != null)
            GestureDetector(
              onTap: isUpdating ? null : () => onUpdate(nextStatus!),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: isUpdating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(nextIcon!, color: Colors.white, size: 16),
                          const SizedBox(width: 5),
                          Text(
                            nextLabel!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Detail card ───────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final TaskModel task;
  final Color urgencyColor;
  const _DetailCard({required this.task, required this.urgencyColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.flag_rounded,
            iconColor: urgencyColor,
            label: 'Urgency',
            value: task.urgencyDisplayName,
            valueColor: urgencyColor,
          ),
          if (task.dueDate != null) ...[
            const Divider(height: 20),
            _DetailRow(
              icon: Icons.calendar_today_rounded,
              iconColor: task.isOverdue
                  ? AppColors.error
                  : AppColors.textSecondary,
              label: 'Due Date',
              value: DateFormat('MMMM d, y').format(task.dueDate!),
              valueColor:
                  task.isOverdue ? AppColors.error : AppColors.textPrimary,
              suffix: task.isOverdue
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Overdue',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
          if (task.assignedToProfile != null) ...[
            const Divider(height: 20),
            _DetailRow(
              icon: Icons.person_outline_rounded,
              label: 'Assigned To',
              value:
                  task.assignedToProfile!['full_name'] as String? ?? 'Unknown',
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;
  final Widget? suffix;

  const _DetailRow({
    required this.icon,
    this.iconColor = AppColors.textSecondary,
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
              fontSize: 13, color: AppColors.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
        if (suffix != null) ...[
          const SizedBox(width: 6),
          suffix!,
        ],
      ],
    );
  }
}

// ── Section card ──────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Comment bubble ────────────────────────────────────────────

class _CommentBubble extends StatelessWidget {
  final TaskCommentModel comment;
  final bool isMe;
  const _CommentBubble({required this.comment, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final name = comment.authorName ?? 'Unknown';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isMe
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.background,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isMe ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isMe ? 'You' : name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('MMM d, h:mm a')
                          .format(comment.createdAt.toLocal()),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppColors.primary.withValues(alpha: 0.07)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    comment.content,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
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

