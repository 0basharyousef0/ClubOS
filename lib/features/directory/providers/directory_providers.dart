import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_providers.dart';
import '../../../shared/models/user_club_role_model.dart';
import '../data/directory_repository.dart';

final directoryRepositoryProvider = Provider<DirectoryRepository>(
  (ref) => DirectoryRepository(),
);

/// Approved members of the active club, sorted by role then name.
final clubMembersProvider = FutureProvider<List<UserClubRoleModel>>((
  ref,
) async {
  final role = ref.watch(activeClubRoleProvider);
  if (role == null) return const [];
  return ref.read(directoryRepositoryProvider).getApprovedMembers(role.clubId);
});
