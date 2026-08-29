import 'package:intl/intl.dart';

import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/task_comment_model.dart';
import '../../../shared/models/task_model.dart';
import '../../../shared/models/user_club_role_model.dart';

class TasksRepository {
  // Tasks a user handed out (with assignee) — President oversight view
  Future<List<TaskModel>> getTasksAssignedBy(
      String clubId, String userId) async {
    final response = await supabase
        .from(AppConstants.tableTasks)
        .select('*, profiles!assigned_to(id, full_name, email)')
        .eq('club_id', clubId)
        .eq('assigned_by', userId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Tasks assigned to a specific user
  Future<List<TaskModel>> getMyTasks(String clubId, String userId) async {
    final response = await supabase
        .from(AppConstants.tableTasks)
        .select()
        .eq('club_id', clubId)
        .eq('assigned_to', userId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Single task with profile join
  Future<TaskModel> getTask(String taskId) async {
    final response = await supabase
        .from(AppConstants.tableTasks)
        .select('*, profiles!assigned_to(id, full_name, email)')
        .eq('id', taskId)
        .single();
    return TaskModel.fromJson(response);
  }

  Future<void> createTask({
    required String clubId,
    required String title,
    String? description,
    required String assignedTo,
    DateTime? dueDate,
    required String urgency,
  }) async {
    final user = supabase.auth.currentUser!;
    await supabase.from(AppConstants.tableTasks).insert({
      'club_id': clubId,
      'title': title.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      'assigned_to': assignedTo,
      'assigned_by': user.id,
      if (dueDate != null)
        'due_date': DateFormat('yyyy-MM-dd').format(dueDate),
      'urgency': urgency,
      'status': AppConstants.taskNotStarted,
    });
  }

  Future<void> updateStatus(String taskId, String status) async {
    await supabase
        .from(AppConstants.tableTasks)
        .update({'status': status}).eq('id', taskId);
  }

  // Comments, chat-style: oldest first so the latest sits at the
  // bottom next to the input (.order() defaults to DESCENDING).
  Future<List<TaskCommentModel>> getComments(String taskId) async {
    final response = await supabase
        .from(AppConstants.tableTaskComments)
        .select('*, profiles(id, full_name)')
        .eq('task_id', taskId)
        .order('created_at', ascending: true);
    return (response as List)
        .map((e) => TaskCommentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addComment(String taskId, String content) async {
    final user = supabase.auth.currentUser!;
    await supabase.from(AppConstants.tableTaskComments).insert({
      'task_id': taskId,
      'user_id': user.id,
      'content': content.trim(),
    });
  }

  // Approved club members for assignment picker
  Future<List<UserClubRoleModel>> getApprovedMembers(String clubId) async {
    final response = await supabase
        .from(AppConstants.tableUserClubRoles)
        // `profiles!user_id` disambiguates: user_club_roles has two FKs
        // to profiles (user_id, approved_by), so a bare embed fails.
        .select('*, profiles!user_id(id, full_name, email)')
        .eq('club_id', clubId)
        .eq('status', AppConstants.statusApproved)
        .order('role');
    return (response as List)
        .map((e) => UserClubRoleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteTask(String id) async {
    await supabase.from(AppConstants.tableTasks).delete().eq('id', id);
  }
}
