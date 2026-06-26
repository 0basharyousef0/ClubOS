class EventModel {
  final String id;
  final String clubId;
  final String title;
  final String? description;
  final DateTime eventDate;
  final String createdBy;
  final DateTime createdAt;
  final Map<String, dynamic>? createdByProfile;
  final int rsvpCount;
  final bool currentUserRsvped;

  const EventModel({
    required this.id,
    required this.clubId,
    required this.title,
    this.description,
    required this.eventDate,
    required this.createdBy,
    required this.createdAt,
    this.createdByProfile,
    this.rsvpCount = 0,
    this.currentUserRsvped = false,
  });

  bool get isUpcoming => eventDate.isAfter(DateTime.now());
  String? get createdByName => createdByProfile?['full_name'] as String?;

  factory EventModel.fromJson(Map<String, dynamic> json) => EventModel(
        id: json['id'] as String,
        clubId: json['club_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        eventDate: DateTime.parse(json['event_date'] as String),
        createdBy: json['created_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        createdByProfile: json['profiles'] as Map<String, dynamic>?,
        rsvpCount: json['rsvp_count'] as int? ?? 0,
        currentUserRsvped: json['current_user_rsvped'] as bool? ?? false,
      );
}
