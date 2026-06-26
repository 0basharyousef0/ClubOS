import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/activity_log_model.dart';
import '../../../shared/models/user_club_role_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/activity_log_repository.dart';

final activityLogRepositoryProvider =
    Provider<ActivityLogRepository>((ref) => ActivityLogRepository());

/// The active filters for the activity feed. Each dimension is independent and
/// any may be null (meaning "don't filter on this dimension").
class ActivityFilter {
  final String? actorId;
  final String? actionType;
  final DateTimeRange? range;

  const ActivityFilter({this.actorId, this.actionType, this.range});

  bool get isActive => actorId != null || actionType != null || range != null;
}

final activityFilterProvider =
    StateProvider<ActivityFilter>((ref) => const ActivityFilter());

/// The filtered activity feed for the active club. Returns empty for anyone who
/// isn't the club president — the screen is route-guarded and RLS enforces this
/// server-side too, so this is just a fast client-side short-circuit.
final activityLogProvider = FutureProvider<List<ActivityLogModel>>((ref) async {
  final role = ref.watch(activeClubRoleProvider);
  if (role == null || !role.isPresident) return const [];

  final filter = ref.watch(activityFilterProvider);
  final range = filter.range;
  return ref.read(activityLogRepositoryProvider).getClubActivity(
        clubId: role.clubId,
        actorId: filter.actorId,
        actionType: filter.actionType,
        from: range?.start,
        // Make the end day inclusive by querying up to the start of the next day.
        toExclusive: range == null
            ? null
            : DateTime(range.end.year, range.end.month, range.end.day)
                .add(const Duration(days: 1)),
      );
});

/// Approved members of the active club, for the "filter by member" picker.
final activityMembersProvider =
    FutureProvider<List<UserClubRoleModel>>((ref) async {
  final role = ref.watch(activeClubRoleProvider);
  if (role == null || !role.isPresident) return const [];
  return ref.read(activityLogRepositoryProvider).getClubMembers(role.clubId);
});
