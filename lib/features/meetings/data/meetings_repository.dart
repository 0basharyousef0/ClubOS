import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/meeting_model.dart';
import '../../../shared/models/user_club_role_model.dart';

class MeetingsRepository {
  Future<List<MeetingModel>> getMeetings(String clubId) async {
    final response = await supabase
        .from(AppConstants.tableMeetings)
        .select('*, meeting_attendees(user_id, profiles(full_name))')
        .eq('club_id', clubId)
        .order('scheduled_at', ascending: true);
    return (response as List)
        .map((e) => MeetingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Members the current user is allowed to invite. Presidents can
  /// invite anyone approved; VPs only the president, fellow VPs,
  /// their own directors, and themselves (mirrors the
  /// can_add_meeting_attendee RLS check).
  Future<List<UserClubRoleModel>> getInvitableMembers({
    required String clubId,
    required bool isPresident,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    final response = await supabase
        .from(AppConstants.tableUserClubRoles)
        // `profiles!user_id` disambiguates the two FKs to profiles.
        .select('*, profiles!user_id(id, full_name, email)')
        .eq('club_id', clubId)
        .eq('status', AppConstants.statusApproved)
        .order('role');
    final members = (response as List)
        .map((e) => UserClubRoleModel.fromJson(e as Map<String, dynamic>))
        .toList();
    if (isPresident) return members;
    return [
      for (final m in members)
        if (m.userId == userId ||
            m.isPresident ||
            m.isVicePresident ||
            (m.isDirector && m.reportsTo == userId))
          m,
    ];
  }

  /// Resolves an audience choice to concrete attendee user-ids.
  /// The scheduler is always included.
  Future<List<String>> resolveAudience({
    required String clubId,
    required String audience,
    List<String> customUserIds = const [],
  }) async {
    final userId = supabase.auth.currentUser!.id;
    if (audience == AppConstants.meetingAudienceCustom) {
      return {...customUserIds, userId}.toList();
    }

    final rows = await supabase
        .from(AppConstants.tableUserClubRoles)
        .select('user_id, role, reports_to')
        .eq('club_id', clubId)
        .eq('status', AppConstants.statusApproved);

    final ids = {
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        if (switch (audience) {
          AppConstants.meetingAudienceVps => r['role'] == 'president' ||
              r['role'] == 'vice_president',
          AppConstants.meetingAudienceVpsDirectors => true,
          AppConstants.meetingAudienceMyDirectors =>
            r['role'] == 'director' && r['reports_to'] == userId,
          _ => false,
        })
          r['user_id'] as String,
      userId,
    };
    return ids.toList();
  }

  Future<void> createMeeting({
    required String clubId,
    required String title,
    String? notes,
    required String audience,
    required DateTime scheduledAt,
    required String recurrence,
    int? reminderOffsetMinutes,
    required List<String> attendeeUserIds,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    final meeting = await supabase
        .from(AppConstants.tableMeetings)
        .insert({
          'club_id': clubId,
          'title': title,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          'created_by': userId,
          'audience': audience,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'recurrence': recurrence,
          'reminder_offset_minutes': ?reminderOffsetMinutes,
        })
        .select()
        .single();

    // Snapshot who's invited; visibility, the instant "you were
    // invited" notification and the pre-meeting reminder all key
    // off this list.
    await supabase.from(AppConstants.tableMeetingAttendees).insert([
      for (final id in attendeeUserIds.toSet())
        {'meeting_id': meeting['id'], 'user_id': id},
    ]);
  }

  /// Cancels a meeting. RLS restricts this to the creator; attendees
  /// of a future meeting are notified by a DB trigger.
  Future<void> deleteMeeting(String id) async {
    await supabase.from(AppConstants.tableMeetings).delete().eq('id', id);
  }
}
