import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/poll_model.dart';

class PollsRepository {
  Future<List<PollModel>> getPolls(String clubId) async {
    final userId = supabase.auth.currentUser!.id;

    final response = await supabase
        .from(AppConstants.tablePolls)
        .select('*, poll_options(*)')
        .eq('club_id', clubId)
        .order('created_at', ascending: false);

    final polls = <PollModel>[];
    for (final row in response as List) {
      final map = row as Map<String, dynamic>;
      final pollId = map['id'] as String;

      // Get total votes and user's vote
      final votesResp = await supabase
          .from(AppConstants.tablePollVotes)
          .select('option_id, user_id')
          .eq('poll_id', pollId);

      final votes = votesResp as List;
      final totalVotes = votes.length;
      final myVote = votes
          .cast<Map<String, dynamic>>()
          .where((v) => v['user_id'] == userId)
          .firstOrNull;

      // Attach vote counts to options
      final options = (map['poll_options'] as List<dynamic>)
          .map((o) {
            final opt = o as Map<String, dynamic>;
            final count =
                votes.where((v) => v['option_id'] == opt['id']).length;
            return PollOptionModel.fromJson({...opt, 'vote_count': count});
          })
          .toList();

      polls.add(PollModel.fromJson({
        ...map,
        'poll_options': options.map((o) => {
          'id': o.id,
          'poll_id': o.pollId,
          'text': o.text,
          'vote_count': o.voteCount,
        }).toList(),
        'my_vote_option_id': myVote?['option_id'],
        'total_votes': totalVotes,
      }));
    }
    return polls;
  }

  Future<PollModel> getPollWithResults(String pollId) async {
    final userId = supabase.auth.currentUser!.id;

    final row = await supabase
        .from(AppConstants.tablePolls)
        .select('*, poll_options(*)')
        .eq('id', pollId)
        .single();

    final votesResp = await supabase
        .from(AppConstants.tablePollVotes)
        .select('option_id, user_id')
        .eq('poll_id', pollId);

    final votes = votesResp as List;
    final totalVotes = votes.length;
    final myVote = votes
        .cast<Map<String, dynamic>>()
        .where((v) => v['user_id'] == userId)
        .firstOrNull;

    final options = ((row)['poll_options'] as List)
        .map((o) {
          final opt = o as Map<String, dynamic>;
          final count = votes.where((v) => v['option_id'] == opt['id']).length;
          return {'id': opt['id'], 'poll_id': opt['poll_id'], 'text': opt['text'], 'vote_count': count};
        })
        .toList();

    return PollModel.fromJson({
      ...row,
      'poll_options': options,
      'my_vote_option_id': myVote?['option_id'],
      'total_votes': totalVotes,
    });
  }

  Future<void> createPoll({
    required String clubId,
    required String title,
    String? description,
    required String audience,
    required List<String> options,
    DateTime? closesAt,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    final poll = await supabase
        .from(AppConstants.tablePolls)
        .insert({
          'club_id': clubId,
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          'created_by': userId,
          'audience': audience,
          if (closesAt != null) 'closes_at': closesAt.toIso8601String(),
        })
        .select()
        .single();

    final pollId = poll['id'] as String;
    await supabase.from(AppConstants.tablePollOptions).insert(
          options.map((text) => {'poll_id': pollId, 'text': text}).toList(),
        );
  }

  Future<void> vote(String pollId, String optionId) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from(AppConstants.tablePollVotes).insert({
      'poll_id': pollId,
      'option_id': optionId,
      'user_id': userId,
    });
  }

  Future<void> deletePoll(String id) async {
    await supabase.from(AppConstants.tablePolls).delete().eq('id', id);
  }
}
