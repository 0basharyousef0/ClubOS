import 'package:club_os/core/constants.dart';
import 'package:club_os/features/notifications/data/notifications_repository.dart';
import 'package:club_os/shared/models/notification_model.dart';

/// Builds a [NotificationModel] with sensible defaults so each test only spells
/// out the fields it cares about. Types use the [AppConstants.notif*] constants.
NotificationModel sampleNotif({
  String id = 'n1',
  String userId = 'u1',
  String? clubId = 'c1',
  String type = AppConstants.notifTaskAssigned,
  String message = 'You were assigned a task',
  bool read = false,
  DateTime? createdAt,
}) {
  return NotificationModel(
    id: id,
    userId: userId,
    clubId: clubId,
    type: type,
    message: message,
    read: read,
    createdAt: createdAt ?? DateTime.now(),
  );
}

/// In-memory stand-in for [NotificationsRepository] so provider/widget tests run
/// without Supabase. It subclasses the real repository (whose methods aren't
/// `final`) rather than pulling in a mocking package.
///
/// Marking notifications read mutates the backing list, so a following
/// `ref.invalidate(notificationsProvider)` refetch reflects the change — exactly
/// how the screen refreshes after "Mark all read" or tapping a tile.
class FakeNotificationsRepository extends NotificationsRepository {
  FakeNotificationsRepository(
    List<NotificationModel> items, {
    this.throwOnLoad = false,
  }) : _items = List.of(items);

  List<NotificationModel> _items;

  /// When true, [getMyNotifications] throws — drives the screen's error state.
  final bool throwOnLoad;

  /// How many times [markAllAsRead] was called.
  int markAllCalls = 0;

  /// Ids passed to [markAsRead], in call order.
  final List<String> markedRead = [];

  @override
  Future<List<NotificationModel>> getMyNotifications() async {
    if (throwOnLoad) throw Exception('failed to load notifications');
    return List.of(_items);
  }

  @override
  Future<void> markAsRead(String id) async {
    markedRead.add(id);
    _items = [
      for (final n in _items) n.id == id ? _asRead(n) : n,
    ];
  }

  @override
  Future<void> markAllAsRead() async {
    markAllCalls++;
    _items = [for (final n in _items) _asRead(n)];
  }
}

NotificationModel _asRead(NotificationModel n) => NotificationModel(
      id: n.id,
      userId: n.userId,
      clubId: n.clubId,
      type: n.type,
      message: n.message,
      read: true,
      createdAt: n.createdAt,
    );
