class AnnouncementModel {
  final String id;
  final String clubId;
  final String title;
  final String content;
  final String postedBy;
  final DateTime createdAt;
  final Map<String, dynamic>? postedByProfile;

  const AnnouncementModel({
    required this.id,
    required this.clubId,
    required this.title,
    required this.content,
    required this.postedBy,
    required this.createdAt,
    this.postedByProfile,
  });

  String? get postedByName =>
      postedByProfile?['full_name'] as String?;

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) =>
      AnnouncementModel(
        id: json['id'] as String,
        clubId: json['club_id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        postedBy: json['posted_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        postedByProfile: json['profiles'] as Map<String, dynamic>?,
      );
}
