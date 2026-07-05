import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_providers.dart';
import '../../../shared/models/announcement_model.dart';
import '../../../shared/models/event_model.dart';
import '../../../shared/models/task_model.dart';
import '../../../shared/models/user_club_role_model.dart';
import '../data/dashboard_repository.dart';

final dashboardRepositoryProvider =
    Provider<DashboardRepository>((ref) => DashboardRepository());

final pendingApprovalsProvider =
    FutureProvider<List<UserClubRoleModel>>((ref) async {
  final role = ref.watch(activeClubRoleProvider);
  if (role == null || !role.isPresident) return [];
  return ref
      .read(dashboardRepositoryProvider)
      .getPendingApprovals(role.clubId);
});

final myTasksProvider = FutureProvider<List<TaskModel>>((ref) async {
  final role = ref.watch(activeClubRoleProvider);
  if (role == null) return [];
  final repo = ref.read(dashboardRepositoryProvider);
  // Presidents oversee rather than receive tasks, so their dashboard
  // lists the tasks they handed out (with assignee) instead.
  if (role.isPresident) {
    return repo.getTasksAssignedBy(role.clubId, role.userId);
  }
  return repo.getMyTasks(role.clubId, role.userId);
});

final upcomingEventsProvider = FutureProvider<List<EventModel>>((ref) async {
  final role = ref.watch(activeClubRoleProvider);
  if (role == null) return [];
  return ref
      .read(dashboardRepositoryProvider)
      .getUpcomingEvents(role.clubId);
});

final recentAnnouncementsProvider =
    FutureProvider<List<AnnouncementModel>>((ref) async {
  final role = ref.watch(activeClubRoleProvider);
  if (role == null) return [];
  return ref
      .read(dashboardRepositoryProvider)
      .getRecentAnnouncements(role.clubId);
});
