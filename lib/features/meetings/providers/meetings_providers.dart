import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_providers.dart';
import '../../../shared/models/meeting_model.dart';
import '../../../shared/models/user_club_role_model.dart';
import '../data/meetings_repository.dart';

final meetingsRepositoryProvider =
    Provider<MeetingsRepository>((ref) => MeetingsRepository());

final meetingsProvider = FutureProvider<List<MeetingModel>>((ref) async {
  final role = ref.watch(activeClubRoleProvider);
  if (role == null) return [];
  return ref.read(meetingsRepositoryProvider).getMeetings(role.clubId);
});

/// Members the current user may invite — for the custom picker.
final meetingInviteePickerProvider =
    FutureProvider<List<UserClubRoleModel>>((ref) async {
  final role = ref.watch(activeClubRoleProvider);
  if (role == null) return [];
  return ref.read(meetingsRepositoryProvider).getInvitableMembers(
        clubId: role.clubId,
        isPresident: role.isPresident,
      );
});
