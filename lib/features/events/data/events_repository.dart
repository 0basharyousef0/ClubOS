import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/event_model.dart';

class EventsRepository {
  Future<List<EventModel>> getClubEvents(String clubId) async {
    final userId = supabase.auth.currentUser!.id;
    final plain = await supabase
        .from(AppConstants.tableEvents)
        .select('*, profiles(id, full_name)')
        .eq('club_id', clubId)
        .order('event_date');

    final rsvpCounts = await supabase
        .from(AppConstants.tableEventRsvps)
        .select('event_id')
        .inFilter('event_id', (plain as List).map((e) => e['id'] as String).toList());

    final userRsvps = await supabase
        .from(AppConstants.tableEventRsvps)
        .select('event_id')
        .eq('user_id', userId)
        .inFilter('event_id', plain.map((e) => e['id'] as String).toList());

    final countMap = <String, int>{};
    for (final r in rsvpCounts as List) {
      final eid = r['event_id'] as String;
      countMap[eid] = (countMap[eid] ?? 0) + 1;
    }

    final userRsvpSet = <String>{
      for (final r in userRsvps as List) r['event_id'] as String,
    };

    return plain
        .map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          return EventModel.fromJson({
            ...map,
            'rsvp_count': countMap[map['id']] ?? 0,
            'current_user_rsvped': userRsvpSet.contains(map['id']),
          });
        })
        .toList();
  }

  Future<EventModel> getEvent(String eventId) async {
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase
        .from(AppConstants.tableEvents)
        .select('*, profiles(id, full_name)')
        .eq('id', eventId)
        .single();

    final rsvpCountRes = await supabase
        .from(AppConstants.tableEventRsvps)
        .select('id')
        .eq('event_id', eventId);

    final userRsvpRes = await supabase
        .from(AppConstants.tableEventRsvps)
        .select('id')
        .eq('event_id', eventId)
        .eq('user_id', userId);

    return EventModel.fromJson({
      ...data,
      'rsvp_count': (rsvpCountRes as List).length,
      'current_user_rsvped': (userRsvpRes as List).isNotEmpty,
    });
  }

  Future<void> createEvent({
    required String clubId,
    required String title,
    String? description,
    required DateTime eventDate,
  }) async {
    final user = supabase.auth.currentUser!;
    await supabase.from(AppConstants.tableEvents).insert({
      'club_id': clubId,
      'title': title.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      'event_date': eventDate.toIso8601String(),
      'created_by': user.id,
    });
  }

  Future<void> rsvp(String eventId) async {
    final user = supabase.auth.currentUser!;
    await supabase.from(AppConstants.tableEventRsvps).insert({
      'event_id': eventId,
      'user_id': user.id,
    });
  }

  Future<void> cancelRsvp(String eventId) async {
    final user = supabase.auth.currentUser!;
    await supabase
        .from(AppConstants.tableEventRsvps)
        .delete()
        .eq('event_id', eventId)
        .eq('user_id', user.id);
  }

  Future<List<Map<String, dynamic>>> getRsvpList(String eventId) async {
    final response = await supabase
        .from(AppConstants.tableEventRsvps)
        .select('user_id, profiles(id, full_name, email), created_at')
        .eq('event_id', eventId)
        .order('created_at');
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<void> deleteEvent(String id) async {
    await supabase.from(AppConstants.tableEvents).delete().eq('id', id);
  }
}
