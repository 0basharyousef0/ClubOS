/// A single entry in a club's activity log (a President-only audit feed).
///
/// Rows are written by database triggers when members act — completing or
/// starting tasks, RSVPing to events, posting announcements, or voting in
/// polls — and the acting member's name is joined in via `profiles`.
class ActivityLogModel {
  final String id;
  final String clubId;
  final String userId;
  final String actionType;
  final Map<String, dynamic>? details;
  final DateTime createdAt;

  /// Display name of the member who performed the action (joined from
  /// `profiles`); null if the join wasn't requested or the profile is missing.
  final String? actorName;

  const ActivityLogModel({
    required this.id,
    required this.clubId,
    required this.userId,
    required this.actionType,
    required this.createdAt,
    this.details,
    this.actorName,
  });

  /// Title of the thing the action was about (task / event / poll /
  /// announcement), when the trigger recorded one in `details`.
  String? get subjectTitle {
    final title = details?['title'];
    return (title is String && title.trim().isNotEmpty) ? title.trim() : null;
  }

  factory ActivityLogModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return ActivityLogModel(
      id: json['id'] as String,
      clubId: json['club_id'] as String,
      userId: json['user_id'] as String,
      actionType: json['action_type'] as String,
      details: json['details'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      actorName: profile?['full_name'] as String?,
    );
  }
}
