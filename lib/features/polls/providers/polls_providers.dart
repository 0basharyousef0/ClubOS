import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_providers.dart';
import '../../../shared/models/poll_model.dart';
import '../data/polls_repository.dart';

final pollsRepositoryProvider =
    Provider<PollsRepository>((ref) => PollsRepository());

final pollsProvider = FutureProvider<List<PollModel>>((ref) async {
  final role = ref.watch(activeClubRoleProvider);
  if (role == null) return [];
  return ref.read(pollsRepositoryProvider).getPolls(role.clubId);
});

final pollDetailProvider =
    FutureProvider.family<PollModel, String>((ref, pollId) async {
  return ref.read(pollsRepositoryProvider).getPollWithResults(pollId);
});
