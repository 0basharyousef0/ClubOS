class TaskModel {
  final String id;
  final String clubId;
  final String title;
  final String? description;
  final String? assignedTo;
  final String? assignedBy;
  final DateTime? dueDate;
  final String urgency;
  final String status;
  final DateTime createdAt;
  final Map<String, dynamic>? assignedToProfile;

  const TaskModel({
    required this.id,
    required this.clubId,
    required this.title,
    this.description,
    this.assignedTo,
    this.assignedBy,
    this.dueDate,
    required this.urgency,
    required this.status,
    required this.createdAt,
    this.assignedToProfile,
  });

  bool get isComplete => status == 'complete';
  bool get isInProgress => status == 'in_progress';
  bool get isNotStarted => status == 'not_started';
  bool get isHighUrgency => urgency == 'high';
  bool get isOverdue =>
      dueDate != null && dueDate!.isBefore(DateTime.now()) && !isComplete;

  String get statusDisplayName => switch (status) {
        'not_started' => 'Not Started',
        'in_progress' => 'In Progress',
        'complete' => 'Complete',
        _ => status,
      };

  String get urgencyDisplayName => switch (urgency) {
        'low' => 'Low',
        'normal' => 'Normal',
        'high' => 'High',
        _ => urgency,
      };

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
        id: json['id'] as String,
        clubId: json['club_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        assignedTo: json['assigned_to'] as String?,
        assignedBy: json['assigned_by'] as String?,
        dueDate: json['due_date'] != null
            ? DateTime.parse(json['due_date'] as String)
            : null,
        urgency: json['urgency'] as String? ?? 'normal',
        status: json['status'] as String? ?? 'not_started',
        createdAt: DateTime.parse(json['created_at'] as String),
        assignedToProfile: json['profiles'] as Map<String, dynamic>?,
      );
}
