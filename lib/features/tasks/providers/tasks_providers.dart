import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_providers.dart';
import '../../../shared/models/task_comment_model.dart';
import '../../../shared/models/task_model.dart';
import '../../../shared/models/user_club_role_model.dart';
import '../data/tasks_repository.dart';

final tasksRepositoryProvider =
    Provider<TasksRepository>((ref) => TasksRepository());

// Tasks the current user assigned to others (President oversight view)
final assignedByMeTasksProvider =
    FutureProvider<List<TaskModel>>((ref) async {
  final role = ref.watch(activeClubRoleProvider);
  if (role == null) return [];
  return ref
      .read(tasksRepositoryProvider)
      .getTasksAssignedBy(role.clubId, role.userId);
});

// Tasks assigned to the current user (everyone's own list)
final myAssignedTasksProvider = FutureProvider<List<TaskModel>>((ref) async {
  final role = ref.watch(activeClubRoleProvider);
  if (role == null) return [];
  return ref
      .read(tasksRepositoryProvider)
      .getMyTasks(role.clubId, role.userId);
});

// Single task detail
final taskDetailProvider =
    FutureProvider.family<TaskModel, String>((ref, taskId) async {
  return ref.read(tasksRepositoryProvider).getTask(taskId);
});

// Comments for a task
final taskCommentsProvider =
    FutureProvider.family<List<TaskCommentModel>, String>((ref, taskId) async {
  return ref.read(tasksRepositoryProvider).getComments(taskId);
});

// Attachments for a task
final taskAttachmentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, taskId) async {
  return ref.read(tasksRepositoryProvider).getAttachments(taskId);
});

// Approved club members for the assignment picker: presidents assign
// to VPs; VPs to their OWN directors (reports_to link captured at
// signup) and to fellow VPs.
final clubMembersProvider =
    FutureProvider<List<UserClubRoleModel>>((ref) async {
  final role = ref.watch(activeClubRoleProvider);
  if (role == null) return [];
  final members =
      await ref.read(tasksRepositoryProvider).getApprovedMembers(role.clubId);
  if (role.isPresident) {
    return members.where((m) => m.isVicePresident).toList();
  }
  if (role.isVicePresident) {
    return members
        .where((m) =>
            (m.isDirector && m.reportsTo == role.userId) ||
            (m.isVicePresident && m.userId != role.userId))
        .toList();
  }
  return [];
});
