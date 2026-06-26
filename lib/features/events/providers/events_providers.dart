import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_providers.dart';
import '../../../shared/models/event_model.dart';
import '../data/events_repository.dart';

final eventsRepositoryProvider = Provider<EventsRepository>(
  (_) => EventsRepository(),
);

final clubEventsProvider = FutureProvider<List<EventModel>>((ref) {
  final role = ref.watch(activeClubRoleProvider);
  if (role == null) return Future.value([]);
  return ref.read(eventsRepositoryProvider).getClubEvents(role.clubId);
});

final eventDetailProvider =
    FutureProvider.family<EventModel, String>((ref, eventId) {
  return ref.read(eventsRepositoryProvider).getEvent(eventId);
});

final eventRsvpListProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, eventId) {
  return ref.read(eventsRepositoryProvider).getRsvpList(eventId);
});
