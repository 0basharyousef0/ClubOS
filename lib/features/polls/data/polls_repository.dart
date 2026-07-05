import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/poll_model.dart';

class PollsRepository {
  /// Poll ids (of the given ones) where the current user may vote.
  Future<Set<String>> _myEligiblePollIds(List<String> pollIds) async {
    if (pollIds.isEmpty) return {};
    final userId = supabase.auth.currentUser!.id;
    final rows = await supabase
        .from('poll_eligible_voters')
        .select('poll_id')
        .eq('user_id', userId)
        .inFilter('poll_id', pollIds);
    return (rows as List)
        .map((r) => (r as Map<String, dynamic>)['poll_id'] as String)
        .toSet();
  }

  Future<List<PollModel>> getPolls(String clubId) async {
    final userId = supabase.auth.currentUser!.id;

    final response = await supabase
        .from(AppConstants.tablePolls)
        .select('*, poll_options(*)')
        .eq('club_id', clubId)
        .order('created_at', ascending: false);

    final eligibleIds = await _myEligiblePollIds([
      for (final row in response as List) (row as Map)['id'] as String,
    ]);

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
        'can_vote': eligibleIds.contains(pollId),
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

    final eligibleIds = await _myEligiblePollIds([pollId]);

    return PollModel.fromJson({
      ...row,
      'poll_options': options,
      'my_vote_option_id': myVote?['option_id'],
      'total_votes': totalVotes,
      'can_vote': eligibleIds.contains(pollId),
    });
  }

  /// Resolves an audience choice to concrete voter user-ids. Custom
  /// audiences pass their hand-picked list through untouched.
  Future<List<String>> resolveAudience({
    required String clubId,
    required String audience,
    List<String> customUserIds = const [],
  }) async {
    if (audience == AppConstants.audienceCustom) return customUserIds;

    final userId = supabase.auth.currentUser!.id;
    final rows = await supabase
        .from(AppConstants.tableUserClubRoles)
        .select('user_id, role, reports_to')
        .eq('club_id', clubId)
        .eq('status', AppConstants.statusApproved);

    return [
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        if (switch (audience) {
          AppConstants.audienceAll => true,
          AppConstants.audienceVpsOnly => r['role'] == 'president' ||
              r['role'] == 'vice_president',
          AppConstants.audienceMyDirectors =>
            r['role'] == 'director' && r['reports_to'] == userId,
          _ => false,
        })
          r['user_id'] as String,
    ];
  }

  Future<void> createPoll({
    required String clubId,
    required String title,
    String? description,
    required String audience,
    required List<String> options,
    required List<String> eligibleUserIds,
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

    // Snapshot who can see/vote this poll; visibility, voting and
    // auto-close all key off this list.
    await supabase.from('poll_eligible_voters').insert([
      for (final id in eligibleUserIds.toSet())
        {'poll_id': pollId, 'user_id': id},
    ]);
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

  /// Ends voting now. RLS (`polls_update`) restricts this to the creator.
  Future<void> closePoll(String id) async {
    await supabase
        .from(AppConstants.tablePolls)
        .update({'closes_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}
