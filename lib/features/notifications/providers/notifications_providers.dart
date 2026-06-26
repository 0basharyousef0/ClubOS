import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_providers.dart';
import '../../../shared/models/notification_model.dart';
import '../data/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(),
);

/// The current user's notifications (refetched whenever auth state changes).
final notificationsProvider = FutureProvider<List<NotificationModel>>((
  ref,
) async {
  ref.watch(authStateChangesProvider);
  return ref.read(notificationsRepositoryProvider).getMyNotifications();
});

/// Unread count, derived from [notificationsProvider] so there's a single
/// source of truth (also powers the dashboard bell badge).
final unreadCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsProvider).valueOrNull ?? const [];
  return notifs.where((n) => !n.read).length;
});
