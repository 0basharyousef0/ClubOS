class TaskCommentModel {
  final String id;
  final String taskId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final Map<String, dynamic>? profile;

  const TaskCommentModel({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.profile,
  });

  String? get authorName => profile?['full_name'] as String?;

  factory TaskCommentModel.fromJson(Map<String, dynamic> json) =>
      TaskCommentModel(
        id: json['id'] as String,
        taskId: json['task_id'] as String,
        userId: json['user_id'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        profile: json['profiles'] as Map<String, dynamic>?,
      );
}
