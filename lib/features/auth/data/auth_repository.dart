import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
import '../../../core/fcm_service.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/club_model.dart';
import '../../../shared/models/user_club_role_model.dart';

class AuthRepository {
  Future<bool> checkEmailExists(String email) async {
    final result = await supabase.rpc(
      'check_email_exists',
      params: {'p_email': email.trim().toLowerCase()},
    );
    return result as bool;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await supabase.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'io.clubos://reset-password',
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String personalEmail,
    required String intendedRole,
    String? roleTitle,
  }) async {
    return supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'personal_email': personalEmail,
        'intended_role': intendedRole,
        if (roleTitle != null && roleTitle.trim().isNotEmpty)
          'role_title': roleTitle.trim(),
      },
    );
  }

  /// Approved VPs of a club (name + title), for the director join flow.
  /// Uses a SECURITY DEFINER RPC because the joining user is not a member
  /// yet, so RLS hides other members' roles.
  Future<List<Map<String, dynamic>>> getClubVps(String clubId) async {
    final response =
        await supabase.rpc('list_club_vps', params: {'p_club_id': clubId});
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<void> signIn({required String email, required String password}) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    // Deregister this device first (needs the session's RLS scope);
    // no-ops if Firebase isn't configured and never blocks sign-out.
    await FcmService.removeToken();
    await supabase.auth.signOut();
  }

  Future<List<ClubModel>> getClubs() async {
    final response = await supabase.rpc('list_clubs_for_dropdown');
    return (response as List)
        .map((e) => ClubModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> isClubNameAvailable(String name) async {
    final result = await supabase.rpc(
      'check_club_name_available',
      params: {'p_name': name.trim()},
    );
    return result as bool;
  }

  Future<void> createClub(String name) async {
    await supabase.rpc(
      'create_club_with_president',
      params: {'p_name': name.trim()},
    );
  }

  Future<void> joinClub({
    required String clubId,
    required String role,
    String? roleTitle,
    String? reportsTo,
  }) async {
    final user = supabase.auth.currentUser!;

    await supabase.from(AppConstants.tableUserClubRoles).insert({
      'user_id': user.id,
      'club_id': clubId,
      'role': role,
      'status': AppConstants.statusPending,
      if (roleTitle != null && roleTitle.trim().isNotEmpty)
        'role_title': roleTitle.trim(),
      // Directors record which VP they work under (drives the
      // "My Directors" poll audience).
      'reports_to': ?reportsTo,
    });

    // Notify the president via a SECURITY DEFINER RPC — a pending user
    // cannot read other members' roles through RLS, so the RPC handles
    // the president lookup and notification insert server-side.
    final displayRole = (roleTitle != null && roleTitle.trim().isNotEmpty)
        ? roleTitle.trim()
        : (role == AppConstants.roleVicePresident
              ? 'Vice President'
              : 'Director');

    await supabase.rpc(
      'notify_club_president_of_join',
      params: {'p_club_id': clubId, 'p_role_name': displayRole},
    );
  }

  Future<List<UserClubRoleModel>> getUserClubRoles() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final response = await supabase
        .from(AppConstants.tableUserClubRoles)
        .select('*, clubs(*)')
        .eq('user_id', user.id);

    return (response as List)
        .map((e) => UserClubRoleModel.fromJson(e))
        .toList();
  }

  Future<void> deleteClub(String clubId) async {
    await supabase
        .from(AppConstants.tableClubs)
        .delete()
        .eq('id', clubId);
  }

  Future<void> approveRole(String roleId) async {
    final user = supabase.auth.currentUser!;
    await supabase
        .from(AppConstants.tableUserClubRoles)
        .update({'status': AppConstants.statusApproved, 'approved_by': user.id})
        .eq('id', roleId);
  }

  Future<void> rejectRole(String roleId) async {
    await supabase
        .from(AppConstants.tableUserClubRoles)
        .update({'status': AppConstants.statusRejected})
        .eq('id', roleId);
  }

  Future<List<UserClubRoleModel>> getPendingRolesForClub(String clubId) async {
    final response = await supabase
        .from(AppConstants.tableUserClubRoles)
        // Disambiguate: user_club_roles has two FKs to profiles
        // (user_id, approved_by), so a bare `profiles(*)` embed fails.
        .select('*, profiles!user_id(*)')
        .eq('club_id', clubId)
        .eq('status', AppConstants.statusPending);

    return (response as List)
        .map((e) => UserClubRoleModel.fromJson(e))
        .toList();
  }
}
