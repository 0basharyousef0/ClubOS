class PollOptionModel {
  final String id;
  final String pollId;
  final String text;
  final int voteCount;

  const PollOptionModel({
    required this.id,
    required this.pollId,
    required this.text,
    this.voteCount = 0,
  });

  factory PollOptionModel.fromJson(Map<String, dynamic> json) =>
      PollOptionModel(
        id: json['id'] as String,
        pollId: json['poll_id'] as String,
        text: json['text'] as String,
        voteCount: json['vote_count'] as int? ?? 0,
      );
}

class PollModel {
  final String id;
  final String clubId;
  final String title;
  final String? description;
  final String createdBy;
  final String audience;
  final DateTime? closesAt;
  final DateTime createdAt;
  final List<PollOptionModel> options;
  final String? myVoteOptionId;
  final int totalVotes;

  const PollModel({
    required this.id,
    required this.clubId,
    required this.title,
    this.description,
    required this.createdBy,
    required this.audience,
    this.closesAt,
    required this.createdAt,
    this.options = const [],
    this.myVoteOptionId,
    this.totalVotes = 0,
  });

  bool get isOpen => closesAt == null || closesAt!.isAfter(DateTime.now());
  bool get hasVoted => myVoteOptionId != null;

  String get audienceDisplayName => switch (audience) {
        'all' => 'All Members',
        'vps_only' => 'VPs & President',
        'directors_only' => 'Directors Only',
        _ => audience,
      };

  factory PollModel.fromJson(Map<String, dynamic> json) => PollModel(
        id: json['id'] as String,
        clubId: json['club_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        createdBy: json['created_by'] as String,
        audience: json['audience'] as String,
        closesAt: json['closes_at'] != null
            ? DateTime.parse(json['closes_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        options: (json['poll_options'] as List<dynamic>? ?? [])
            .map((o) => PollOptionModel.fromJson(o as Map<String, dynamic>))
            .toList(),
        myVoteOptionId: json['my_vote_option_id'] as String?,
        totalVotes: json['total_votes'] as int? ?? 0,
      );
}
