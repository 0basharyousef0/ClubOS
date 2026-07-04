import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/activity_log_model.dart';
import '../../../shared/models/user_club_role_model.dart';

class ActivityLogRepository {
  /// A club's activity, newest first. The `activity_log_select` RLS policy
  /// already restricts reads to the club's (approved) president, so callers
  /// don't need to re-check the role server-side.
  ///
  /// [from] is inclusive and [toExclusive] is exclusive — pass the day *after*
  /// the last day you want so the whole final day is covered.
  Future<List<ActivityLogModel>> getClubActivity({
    required String clubId,
    String? actorId,
    String? actionType,
    DateTime? from,
    DateTime? toExclusive,
  }) async {
    var query = supabase
        .from(AppConstants.tableActivityLog)
        .select('*, profiles!user_id(id, full_name)')
        .eq('club_id', clubId);

    if (actorId != null) query = query.eq('user_id', actorId);
    if (actionType != null) query = query.eq('action_type', actionType);
    if (from != null) {
      query = query.gte('created_at', from.toUtc().toIso8601String());
    }
    if (toExclusive != null) {
      query = query.lt('created_at', toExclusive.toUtc().toIso8601String());
    }

    final response =
        await query.order('created_at', ascending: false).limit(200);
    return (response as List)
        .map((e) => ActivityLogModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Approved members of the club — powers the "filter by member" picker.
  Future<List<UserClubRoleModel>> getClubMembers(String clubId) async {
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
}
