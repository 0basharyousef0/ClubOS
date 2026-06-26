import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_providers.dart';
import '../../../shared/models/announcement_model.dart';
import '../data/announcements_repository.dart';

final announcementsRepositoryProvider =
    Provider<AnnouncementsRepository>((ref) => AnnouncementsRepository());

final clubAnnouncementsProvider =
    FutureProvider<List<AnnouncementModel>>((ref) async {
  final role = ref.watch(activeClubRoleProvider);
  if (role == null) return [];
  return ref
      .read(announcementsRepositoryProvider)
      .getAnnouncements(role.clubId);
});
