class MeetingAttendeeModel {
  final String userId;
  final String? fullName;

  const MeetingAttendeeModel({required this.userId, this.fullName});

  factory MeetingAttendeeModel.fromJson(Map<String, dynamic> json) =>
      MeetingAttendeeModel(
        userId: json['user_id'] as String,
        fullName: (json['profiles'] as Map<String, dynamic>?)?['full_name']
            as String?,
      );
}

class MeetingModel {
  final String id;
  final String clubId;
  final String title;
  final String? notes;
  final String createdBy;
  final String audience;

  /// Next (or only) occurrence. The backend rolls recurring meetings
  /// forward automatically once an occurrence has passed.
  final DateTime scheduledAt;
  final String recurrence;
  final int? reminderOffsetMinutes;
  final DateTime createdAt;
  final List<MeetingAttendeeModel> attendees;

  const MeetingModel({
    required this.id,
    required this.clubId,
    required this.title,
    this.notes,
    required this.createdBy,
    required this.audience,
    required this.scheduledAt,
    required this.recurrence,
    this.reminderOffsetMinutes,
    required this.createdAt,
    this.attendees = const [],
  });

  bool get isRecurring => recurrence != 'once';
  bool get isPast => !isRecurring && scheduledAt.isBefore(DateTime.now());

  String get audienceDisplayName => switch (audience) {
        'vps' => 'VPs & President',
        'vps_directors' => 'VPs & Directors',
        'my_directors' => 'My Directors',
        'custom' => 'Selected Members',
        _ => audience,
      };

  String get recurrenceDisplayName => switch (recurrence) {
        'once' => 'One-time',
        'daily' => 'Daily',
        'weekly' => 'Weekly',
        'biweekly' => 'Bi-weekly',
        'monthly' => 'Monthly',
        _ => recurrence,
      };

  String? get reminderDisplayName {
    final m = reminderOffsetMinutes;
    if (m == null) return null;
    if (m % 1440 == 0) {
      final d = m ~/ 1440;
      return '$d day${d == 1 ? '' : 's'} before';
    }
    if (m % 60 == 0) {
      final h = m ~/ 60;
      return '$h hour${h == 1 ? '' : 's'} before';
    }
    return '$m min before';
  }

  factory MeetingModel.fromJson(Map<String, dynamic> json) => MeetingModel(
        id: json['id'] as String,
        clubId: json['club_id'] as String,
        title: json['title'] as String,
        notes: json['notes'] as String?,
        createdBy: json['created_by'] as String,
        audience: json['audience'] as String,
        scheduledAt: DateTime.parse(json['scheduled_at'] as String).toLocal(),
        recurrence: json['recurrence'] as String,
        reminderOffsetMinutes: json['reminder_offset_minutes'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
        attendees: (json['meeting_attendees'] as List<dynamic>? ?? [])
            .map((a) => MeetingAttendeeModel.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
}
