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

    // Upsert, not insert: someone who previously left this club still
    // has their row (status 'left'), and UNIQUE (user_id, club_id)
    // would reject a fresh insert. The ucr_rejoin policy allows the
    // 'left' -> 'pending' flip and nothing else.
    await supabase.from(AppConstants.tableUserClubRoles).upsert({
      'user_id': user.id,
      'club_id': clubId,
      'role': role,
      'status': AppConstants.statusPending,
      'role_title': (roleTitle != null && roleTitle.trim().isNotEmpty)
          ? roleTitle.trim()
          : null,
      // Directors record which VP they work under (drives the
      // "My Directors" poll audience).
      'reports_to': reportsTo,
    }, onConflict: 'user_id,club_id');

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

  /// Hands the active club to another approved member; the caller
  /// becomes a Vice President. Validation (caller is president, target
  /// is an approved member) is enforced server-side by the RPC.
  Future<void> transferPresidency({
    required String clubId,
    required String newPresidentId,
  }) async {
    await supabase.rpc(
      'transfer_presidency',
      params: {
        'p_club_id': clubId,
        'p_new_president_id': newPresidentId,
      },
    );
  }

  /// Wipes a club's operational content so a new board starts clean:
  /// tasks, events, announcements, polls, meetings, the activity log
  /// and the club's notifications. The club, its name, its constitution
  /// and the president survive; [clearRoster] additionally drops every
  /// other membership for a full board handover. President-only,
  /// enforced by the RPC.
  ///
  Future<void> resetClubTerm({
    required String clubId,
    required bool clearRoster,
  }) async {
    await supabase.rpc('reset_club_term', params: {
      'p_club_id': clubId,
      'p_clear_roster': clearRoster,
    });
  }

  /// Leaves a single club without touching the account or the caller's
  /// other memberships. The RPC notifies the president (and any
  /// directors orphaned by a departing VP), drops future RSVPs,
  /// meeting invites and open-poll eligibility, and keeps the
  /// membership row as a 'left' tombstone so the work they authored
  /// still renders their name. Presidents are rejected server-side.
  Future<void> leaveClub(String clubId) async {
    await supabase.rpc('leave_club', params: {'p_club_id': clubId});
  }

  /// Permanently deletes the caller's account (App Store 5.1.1(v)).
  ///
  /// Server-side the RPC removes memberships, notifications and device
  /// tokens, anonymizes the profile tombstone ("Former member") so past
  /// work survives, notifies affected teams, and deletes the auth user.
  /// Presidents of clubs with other members are rejected by the RPC and
  /// must transfer presidency or delete the club first.
  Future<void> deleteAccount() async {
    await supabase.rpc('delete_account');
    // The server session died with the account; this clears the local
    // one. removeToken() inside is a no-op — tokens are already gone.
    await signOut();
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
