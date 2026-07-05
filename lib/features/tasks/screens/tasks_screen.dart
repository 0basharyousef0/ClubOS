import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/tab_header_hero.dart';
import '../../../features/auth/providers/auth_providers.dart';
import '../../../shared/models/task_model.dart';
import '../providers/tasks_providers.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String _filter = 'all';
  // VP-only view switch: their own tasks vs tasks they handed out.
  bool _showAssignedByMe = false;

  List<TaskModel> _applyFilter(List<TaskModel> tasks) {
    if (_filter == 'all') return tasks;
    return tasks.where((t) => t.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(activeClubRoleProvider);
    final canAssign = role?.canAssignTasks ?? false;
    // Presidents only hand out tasks, so they get just the assigned-by-me
    // view. VPs receive AND hand out, so they can toggle between their
    // own tasks and the ones they assigned (never other VPs' tasks —
    // the query and RLS both scope to assigned_by = them).
    final isPresident = role?.isPresident ?? false;
    final isVp = role?.isVicePresident ?? false;
    final showingAssigned = isPresident || (isVp && _showAssignedByMe);

    final tasksAsync = showingAssigned
        ? ref.watch(assignedByMeTasksProvider)
        : ref.watch(myAssignedTasksProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: RefreshIndicator(
          color: AppColors.primary,
          edgeOffset: 100,
          onRefresh: () async {
            if (showingAssigned) {
              ref.invalidate(assignedByMeTasksProvider);
            } else {
              ref.invalidate(myAssignedTasksProvider);
            }
          },
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              TabHeaderHero(
                child: _TasksHeader(
                  isPresident: showingAssigned,
                  clubName: role?.club?.name,
                  tasksAsync: tasksAsync,
                ),
              ),
              const SizedBox(height: 16),
              if (isVp) ...[
                _VpViewToggle(
                  showAssignedByMe: _showAssignedByMe,
                  onChanged: (v) => setState(() => _showAssignedByMe = v),
                ),
                const SizedBox(height: 14),
              ],
              // Filter chips
              _FilterRow(
                selected: _filter,
                onSelect: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: 16),
              tasksAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
                error: (_, _) => const _EmptyState(
                  icon: Icons.error_outline_rounded,
                  message: 'Could not load tasks.',
                ),
                data: (tasks) {
                  final filtered = _applyFilter(tasks);
                  if (filtered.isEmpty) {
                    return _EmptyState(
                      icon: Icons.task_alt_rounded,
                      message: _filter == 'all'
                          ? 'No tasks yet.'
                          : 'No ${_filterLabel(_filter).toLowerCase()} tasks.',
                      sub: showingAssigned
                          ? 'Tap + to assign a task to a member.'
                          : 'Tasks assigned to you will appear here.',
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        ...filtered.map((t) => _TaskCard(
                              task: t,
                              showAssignee: showingAssigned,
                              onTap: () => context.go('/tasks/${t.id}'),
                            )),
                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        floatingActionButton: canAssign
            ? FloatingActionButton.extended(
                onPressed: () => context.go('/tasks/create'),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Assign'),
              )
            : null,
      ),
    );
  }

  String _filterLabel(String f) => switch (f) {
        'not_started' => 'Not Started',
        'in_progress' => 'In Progress',
        'complete' => 'Complete',
        _ => 'All',
      };
}

// ── Header ────────────────────────────────────────────────────

class _TasksHeader extends StatelessWidget {
  final bool isPresident;
  final String? clubName;
  final AsyncValue tasksAsync;

  const _TasksHeader({
    required this.isPresident,
    required this.clubName,
    required this.tasksAsync,
  });

  @override
  Widget build(BuildContext context) {
    final count = tasksAsync.whenOrNull<int>(data: (tasks) => (tasks as List).length);

    return Container(
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tasks',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.checklist_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        count != null
                            ? '$count ${isPresident ? 'task${count == 1 ? '' : 's'} assigned' : 'assigned task${count == 1 ? '' : 's'}'}'
                            : isPresident ? 'Tasks you assigned' : 'My tasks',
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
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter chips ──────────────────────────────────────────────

// ── VP view toggle ────────────────────────────────────────────

class _VpViewToggle extends StatelessWidget {
  final bool showAssignedByMe;
  final ValueChanged<bool> onChanged;

  const _VpViewToggle({
    required this.showAssignedByMe,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _segment('My Tasks', !showAssignedByMe, () => onChanged(false)),
            _segment('Assigned by Me', showAssignedByMe,
                () => onChanged(true)),
          ],
        ),
      ),
    );
  }

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _FilterRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final filters = [
      ('all', 'All'),
      ('not_started', 'Not Started'),
      ('in_progress', 'In Progress'),
      ('complete', 'Complete'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: filters
            .map((f) => _FilterChip(
                  value: f.$1,
                  label: f.$2,
                  isSelected: selected == f.$1,
                  onTap: () => onSelect(f.$1),
                ))
            .toList(),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String value;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.value,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Task card ─────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final bool showAssignee;
  final VoidCallback onTap;

  const _TaskCard({
    required this.task,
    required this.showAssignee,
    required this.onTap,
  });

  Color get _urgencyColor => switch (task.urgency) {
        'high' => AppColors.error,
        'low' => AppColors.success,
        _ => AppColors.warning,
      };

  Color get _statusColor => switch (task.status) {
        'in_progress' => const Color(0xFF3B82F6),
        'complete' => AppColors.success,
        _ => AppColors.textSecondary,
      };

  String get _statusLabel => switch (task.status) {
        'in_progress' => 'In Progress',
        'complete' => 'Complete',
        _ => 'Not Started',
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: _urgencyColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: _statusColor.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (showAssignee &&
                                task.assignedToProfile != null) ...[
                              const Icon(Icons.person_outline_rounded,
                                  size: 12,
                                  color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                task.assignedToProfile!['full_name']
                                        as String? ??
                                    'Unknown',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 10),
                            ],
                            if (task.dueDate != null) ...[
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: task.isOverdue
                                    ? AppColors.error
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Due ${DateFormat('MMM d').format(task.dueDate!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: task.isOverdue
                                      ? AppColors.error
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? sub;
  const _EmptyState({required this.icon, required this.message, this.sub});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 26),
              ),
              const SizedBox(height: 14),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              if (sub != null) ...[
                const SizedBox(height: 5),
                Text(
                  sub!,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
}
