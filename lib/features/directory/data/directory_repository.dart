import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/user_club_role_model.dart';

class DirectoryRepository {
  /// All approved members of [clubId], each with their profile joined,
  /// ordered by role (President → Vice President → Director) then name.
  ///
  /// RLS (`ucr_select`) lets any approved member read co-members, and
  /// `profiles_select` exposes the joined profile, so this works for every
  /// role — President, VP and Director can all view the directory.
  Future<List<UserClubRoleModel>> getApprovedMembers(String clubId) async {
    final response = await supabase
        .from(AppConstants.tableUserClubRoles)
        // `profiles!user_id` disambiguates the embed: user_club_roles has two
        // FKs to profiles (user_id and approved_by), so a bare `profiles(*)`
        // is ambiguous and PostgREST rejects it.
        .select('*, profiles!user_id(*)')
        .eq('club_id', clubId)
        .eq('status', AppConstants.statusApproved);

    final members = (response as List)
        .map((e) => UserClubRoleModel.fromJson(e as Map<String, dynamic>))
        .toList();

    members.sort((a, b) {
      final byRole = _roleRank(a.role).compareTo(_roleRank(b.role));
      if (byRole != 0) return byRole;
      final aName = (a.profile?.fullName ?? '').toLowerCase();
      final bName = (b.profile?.fullName ?? '').toLowerCase();
      return aName.compareTo(bName);
    });
    return members;
  }

  /// Removes a member from the club by deleting their role row.
  /// Server-side this is permitted only for the club's president (`ucr_delete`).
  Future<void> removeMember(String roleId) async {
    await supabase
        .from(AppConstants.tableUserClubRoles)
        .delete()
        .eq('id', roleId);
  }

  static int _roleRank(String role) => switch (role) {
    AppConstants.rolePresident => 0,
    AppConstants.roleVicePresident => 1,
    AppConstants.roleDirector => 2,
    _ => 3,
  };
}
