import 'dart:async';

import 'package:club_os/features/notifications/providers/notifications_providers.dart';
import 'package:club_os/shared/models/notification_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/notifications_test_support.dart';

void main() {
  group('unreadCountProvider', () {
    // Overrides notificationsProvider directly, so authStateChangesProvider and
    // the Supabase-backed repository are never touched.
    Future<int> unreadFor(List<NotificationModel> notifs) async {
      final container = ProviderContainer(
        overrides: [
          notificationsProvider.overrideWith((ref) async => notifs),
        ],
      );
      addTearDown(container.dispose);
      await container.read(notificationsProvider.future);
      return container.read(unreadCountProvider);
    }

    test('counts only unread notifications', () async {
      final count = await unreadFor([
        sampleNotif(id: 'a', read: false),
        sampleNotif(id: 'b', read: true),
        sampleNotif(id: 'c', read: false),
      ]);

      expect(count, 2);
    });

    test('is 0 for an empty list', () async {
      expect(await unreadFor(const []), 0);
    });

    test('is 0 when everything is read', () async {
      final count = await unreadFor([
        sampleNotif(id: 'a', read: true),
        sampleNotif(id: 'b', read: true),
      ]);

      expect(count, 0);
    });

    test('is 0 while notifications are still loading', () {
      final container = ProviderContainer(
        overrides: [
          notificationsProvider.overrideWith(
            (ref) => Completer<List<NotificationModel>>().future,
          ),
        ],
      );
      addTearDown(container.dispose);

      // No await: the future never resolves, so the provider stays loading and
      // unreadCountProvider falls back to `const []` -> 0.
      expect(container.read(unreadCountProvider), 0);
    });
  });
}
