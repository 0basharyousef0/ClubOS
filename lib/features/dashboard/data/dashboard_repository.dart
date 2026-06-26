import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/announcement_model.dart';
import '../../../shared/models/event_model.dart';
import '../../../shared/models/task_model.dart';
import '../../../shared/models/user_club_role_model.dart';

class DashboardRepository {
  Future<List<UserClubRoleModel>> getPendingApprovals(String clubId) async {
    final response = await supabase
        .from(AppConstants.tableUserClubRoles)
        // Disambiguate: user_club_roles has two FKs to profiles
        // (user_id, approved_by), so a bare `profiles(*)` embed fails.
        .select('*, profiles!user_id(*)')
        .eq('club_id', clubId)
        .eq('status', AppConstants.statusPending)
        .order('created_at');
    return (response as List)
        .map((e) => UserClubRoleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TaskModel>> getMyTasks(String clubId, String userId) async {
    final response = await supabase
        .from(AppConstants.tableTasks)
        .select()
        .eq('club_id', clubId)
        .eq('assigned_to', userId)
        .neq('status', AppConstants.taskComplete)
        .order('due_date', ascending: true, nullsFirst: false)
        .limit(3);
    return (response as List)
        .map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EventModel>> getUpcomingEvents(String clubId) async {
    final now = DateTime.now().toIso8601String();
    final response = await supabase
        .from(AppConstants.tableEvents)
        .select()
        .eq('club_id', clubId)
        .gte('event_date', now)
        .order('event_date', ascending: true)
        .limit(3);
    return (response as List)
        .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AnnouncementModel>> getRecentAnnouncements(String clubId) async {
    final response = await supabase
        .from(AppConstants.tableAnnouncements)
        .select('*, profiles(full_name)')
        .eq('club_id', clubId)
        .order('created_at', ascending: false)
        .limit(3);
    final items = (response as List)
        .map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>))
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }
}
