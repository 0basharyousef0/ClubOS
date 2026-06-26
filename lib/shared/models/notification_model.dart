class NotificationModel {
  final String id;
  final String userId;
  final String? clubId;
  final String type;
  final String message;
  final bool read;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    this.clubId,
    required this.type,
    required this.message,
    required this.read,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        clubId: json['club_id'] as String?,
        type: json['type'] as String,
        message: json['message'] as String,
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
