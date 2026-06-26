import 'dart:async';

import 'package:club_os/app/theme.dart';
import 'package:club_os/core/constants.dart';
import 'package:club_os/features/auth/providers/auth_providers.dart';
import 'package:club_os/features/notifications/providers/notifications_providers.dart';
import 'package:club_os/features/notifications/screens/notifications_screen.dart';
import 'package:club_os/shared/models/notification_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/notifications_test_support.dart';

void main() {
  // Keep the real notificationsProvider / unreadCountProvider running, but feed
  // them a fake repository and a no-op auth stream so nothing reaches the
  // uninitialized global Supabase client.
  List<Override> baseOverrides(FakeNotificationsRepository fake) => [
        authStateChangesProvider.overrideWith((ref) => Stream<AuthState>.empty()),
        notificationsRepositoryProvider.overrideWithValue(fake),
      ];

  Future<void> pumpScreen(WidgetTester tester, List<Override> overrides) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const NotificationsScreen(),
        ),
      ),
    );
  }

  testWidgets('renders notifications and the mark-all button', (tester) async {
    final fake = FakeNotificationsRepository([
      sampleNotif(
          id: 'a',
          read: false,
          type: AppConstants.notifTaskAssigned,
          message: 'Task assigned to you'),
      sampleNotif(
          id: 'b',
          read: false,
          type: AppConstants.notifEventPosted,
          message: 'New event posted'),
      sampleNotif(
          id: 'c',
          read: true,
          type: AppConstants.notifAnnouncement,
          message: 'Announcement posted'),
    ]);

    await pumpScreen(tester, baseOverrides(fake));
    await tester.pumpAndSettle();

    expect(find.text('Task assigned to you'), findsOneWidget);
    expect(find.text('New event posted'), findsOneWidget);
    expect(find.text('Announcement posted'), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no notifications',
      (tester) async {
    final fake = FakeNotificationsRepository([]);

    await pumpScreen(tester, baseOverrides(fake));
    await tester.pumpAndSettle();

    expect(find.text("You're all caught up"), findsOneWidget);
    expect(find.text('No notifications yet.'), findsOneWidget);
    expect(find.text('Mark all read'), findsNothing);
  });

  testWidgets('shows the error state when loading fails', (tester) async {
    final fake = FakeNotificationsRepository([], throwOnLoad: true);

    await pumpScreen(tester, baseOverrides(fake));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load notifications"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('shows a spinner while loading', (tester) async {
    // A never-completing future keeps the provider in its loading state.
    await pumpScreen(tester, [
      notificationsProvider.overrideWith(
        (ref) => Completer<List<NotificationModel>>().future,
      ),
    ]);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('mark-all-read marks notifications and hides the button',
      (tester) async {
    final fake = FakeNotificationsRepository([
      sampleNotif(id: 'a', read: false, message: 'Unread one'),
      sampleNotif(id: 'b', read: false, message: 'Unread two'),
      sampleNotif(id: 'c', read: true, message: 'Already read'),
    ]);

    await pumpScreen(tester, baseOverrides(fake));
    await tester.pumpAndSettle();

    expect(find.text('Mark all read'), findsOneWidget);

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(fake.markAllCalls, 1);
    expect(find.text('Mark all read'), findsNothing);
  });

  testWidgets('tapping an unread notification marks it read', (tester) async {
    // membership_approved has no route (_routeForType -> null), so the tap marks
    // it read without navigating — no GoRouter needed in the harness.
    final fake = FakeNotificationsRepository([
      sampleNotif(
        id: 'm1',
        read: false,
        type: AppConstants.notifMembershipApproved,
        message: 'Your membership was approved',
      ),
    ]);

    await pumpScreen(tester, baseOverrides(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Your membership was approved'));
    await tester.pumpAndSettle();

    expect(fake.markedRead, contains('m1'));
  });
}
