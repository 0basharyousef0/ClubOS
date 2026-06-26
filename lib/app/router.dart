import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/auth/screens/approvals_screen.dart';
import '../features/auth/screens/auth_redirect_screen.dart';
import '../features/auth/screens/club_select_screen.dart';
import '../features/auth/screens/club_setup_screen.dart';
import '../features/auth/screens/club_switcher_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/pending_approval_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/directory/screens/directory_screen.dart';
import '../features/directory/screens/member_profile_screen.dart';
import '../features/more/screens/more_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/polls/screens/poll_create_screen.dart';
import '../features/tasks/screens/tasks_screen.dart';
import '../features/tasks/screens/task_create_screen.dart';
import '../features/tasks/screens/task_detail_screen.dart';
import '../features/events/screens/events_screen.dart';
import '../features/events/screens/event_create_screen.dart';
import '../features/events/screens/event_detail_screen.dart';
import '../features/polls/screens/poll_detail_screen.dart';
import '../features/polls/screens/polls_screen.dart';
import '../features/announcements/screens/announcements_screen.dart';
import '../features/announcements/screens/announcement_create_screen.dart';
import '../features/resources/screens/resources_screen.dart';
import '../shared/widgets/main_scaffold.dart';
import '../shared/widgets/placeholder_screen.dart';

class _AuthRefreshNotifier extends ChangeNotifier {
  AuthChangeEvent? lastEvent;

  _AuthRefreshNotifier() {
    _sub = supabase.auth.onAuthStateChange.listen((state) {
      lastEvent = state.event;
      notifyListeners();
    });
  }

  late final StreamSubscription _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _authRefreshNotifier = _AuthRefreshNotifier();

/// Fade crossfade — tab switches and top-level destinations.
/// When a _PushPage is pushed on top, this page scales down and dims.
class _TabPage<T> extends Page<T> {
  final Widget child;
  const _TabPage({required this.child, required LocalKey key})
    : super(key: key);

  @override
  Route<T> createRoute(BuildContext context) {
    return PageRouteBuilder<T>(
      settings: this,
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => child,
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        // The purple header is a Hero (see TabHeaderHero), so it stays anchored
        // across tab switches. Only the content beneath it animates: a gentle
        // fade with a small upward slide, so it reads as the content swapping
        // under a fixed header rather than the whole page sliding.
        final slide =
            Tween<Offset>(
              begin: const Offset(0.0, 0.03),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        final fade = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
        );

        // When a push page (detail / create) covers this one, it scales down +
        // dims — this is the "+" transition, kept as-is.
        final coverScale = Tween<double>(begin: 1.0, end: 0.92).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOut),
        );
        final coverDim = Tween<double>(begin: 1.0, end: 0.6).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOut),
        );

        return FadeTransition(
          opacity: coverDim,
          child: ScaleTransition(
            scale: coverScale,
            child: FadeTransition(
              opacity: fade,
              child: SlideTransition(position: slide, child: child),
            ),
          ),
        );
      },
    );
  }
}

/// Slide-up — detail screens and create screens.
/// Enters from the bottom, exits back down on pop.
class _PushPage<T> extends Page<T> {
  final Widget child;
  const _PushPage({required this.child, required LocalKey key})
    : super(key: key);

  @override
  Route<T> createRoute(BuildContext context) {
    return PageRouteBuilder<T>(
      settings: this,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => child,
      transitionsBuilder: (_, animation, _, child) {
        // Slide from bottom to position.
        final slide =
            Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        // Quick fade-in prevents a hard edge appearing at the screen bottom.
        final fade = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
        );
        // Rounded top corners animate in as the page rises.
        final radius = Tween<double>(begin: 24.0, end: 0.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
          ),
        );
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: AnimatedBuilder(
              animation: radius,
              builder: (_, c) => ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(radius.value),
                ),
                child: c,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

// Authenticated users on these routes get bounced to /auth-redirect
const _authRoutes = {'/login', '/register'};

// Accessible by both authenticated and unauthenticated users (onboarding flow)
const _onboardingRoutes = {
  '/club-setup',
  '/club-select',
  '/forgot-password',
  '/reset-password',
};

// President-only routes — non-presidents are bounced to /dashboard
const _presidentRoutes = {'/approvals'};

final appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: _authRefreshNotifier,
  redirect: (context, state) {
    final user = supabase.auth.currentUser;
    final loc = state.matchedLocation;

    // Password recovery deep link — always route to reset screen
    if (_authRefreshNotifier.lastEvent == AuthChangeEvent.passwordRecovery) {
      return loc == '/reset-password' ? null : '/reset-password';
    }

    // Unauthenticated: only allow auth + onboarding routes
    if (user == null) {
      final allowed =
          _authRoutes.contains(loc) || _onboardingRoutes.contains(loc);
      return allowed ? null : '/login';
    }

    // Authenticated user on login/register → redirect away
    if (_authRoutes.contains(loc)) return '/auth-redirect';

    // President-only routes — block everyone else from even reaching them
    if (_presidentRoutes.contains(loc)) {
      final role = ProviderScope.containerOf(context, listen: false)
          .read(activeClubRoleProvider);
      if (role == null || !role.isPresident) return '/dashboard';
    }

    return null;
  },
  routes: [
    // ── Auth (no bottom nav) ──────────────────────────────────
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (_, _) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (_, _) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/auth-redirect',
      name: 'auth-redirect',
      builder: (_, _) => const AuthRedirectScreen(),
    ),
    GoRoute(
      path: '/club-setup',
      name: 'club-setup',
      builder: (_, _) => const ClubSetupScreen(),
    ),
    GoRoute(
      path: '/club-select',
      name: 'club-select',
      builder: (_, _) => const ClubSelectScreen(),
    ),
    GoRoute(
      path: '/pending-approval',
      name: 'pending-approval',
      builder: (_, _) => const PendingApprovalScreen(),
    ),
    GoRoute(
      path: '/club-switcher',
      name: 'club-switcher',
      builder: (_, _) => const ClubSwitcherScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      name: 'forgot-password',
      builder: (_, s) => ForgotPasswordScreen(
        email: s.extra is String ? s.extra as String : '',
      ),
    ),
    GoRoute(
      path: '/reset-password',
      name: 'reset-password',
      builder: (_, _) => const ResetPasswordScreen(),
    ),

    // ── Main app (with bottom nav via ShellRoute) ─────────────
    ShellRoute(
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          name: 'dashboard',
          pageBuilder: (_, s) =>
              _TabPage(key: s.pageKey, child: const DashboardScreen()),
        ),

        // ── Tasks ──────────────────────────────────────────────
        GoRoute(
          path: '/tasks',
          name: 'tasks',
          pageBuilder: (_, s) =>
              _TabPage(key: s.pageKey, child: const TasksScreen()),
          routes: [
            GoRoute(
              path: 'create',
              name: 'task-create',
              pageBuilder: (_, s) =>
                  _PushPage(key: s.pageKey, child: const TaskCreateScreen()),
            ),
            GoRoute(
              path: ':id',
              name: 'task-detail',
              pageBuilder: (_, s) => _PushPage(
                key: s.pageKey,
                child: TaskDetailScreen(taskId: s.pathParameters['id']!),
              ),
            ),
          ],
        ),

        // ── Events ─────────────────────────────────────────────
        GoRoute(
          path: '/events',
          name: 'events',
          pageBuilder: (_, s) =>
              _TabPage(key: s.pageKey, child: const EventsScreen()),
          routes: [
            GoRoute(
              path: 'create',
              name: 'event-create',
              pageBuilder: (_, s) =>
                  _PushPage(key: s.pageKey, child: const EventCreateScreen()),
            ),
            GoRoute(
              path: ':id',
              name: 'event-detail',
              pageBuilder: (_, s) => _PushPage(
                key: s.pageKey,
                child: EventDetailScreen(eventId: s.pathParameters['id']!),
              ),
            ),
          ],
        ),

        // ── More ───────────────────────────────────────────────
        GoRoute(
          path: '/more',
          name: 'more',
          pageBuilder: (_, s) =>
              _TabPage(key: s.pageKey, child: const MoreScreen()),
        ),

        // ── Announcements ──────────────────────────────────────
        GoRoute(
          path: '/announcements',
          name: 'announcements',
          pageBuilder: (_, s) =>
              _TabPage(key: s.pageKey, child: const AnnouncementsScreen()),
          routes: [
            GoRoute(
              path: 'create',
              name: 'announcement-create',
              pageBuilder: (_, s) => _PushPage(
                key: s.pageKey,
                child: const AnnouncementCreateScreen(),
              ),
            ),
          ],
        ),

        // ── Directory ──────────────────────────────────────────
        GoRoute(
          path: '/directory',
          name: 'directory',
          pageBuilder: (_, s) =>
              _TabPage(key: s.pageKey, child: const DirectoryScreen()),
          routes: [
            GoRoute(
              path: ':id',
              name: 'member-profile',
              pageBuilder: (_, s) => _PushPage(
                key: s.pageKey,
                child: MemberProfileScreen(roleId: s.pathParameters['id']!),
              ),
            ),
          ],
        ),

        // ── Polls ──────────────────────────────────────────────
        GoRoute(
          path: '/polls',
          name: 'polls',
          pageBuilder: (_, s) =>
              _TabPage(key: s.pageKey, child: const PollsScreen()),
          routes: [
            GoRoute(
              path: 'create',
              name: 'poll-create',
              pageBuilder: (_, s) =>
                  _PushPage(key: s.pageKey, child: const PollCreateScreen()),
            ),
            GoRoute(
              path: ':id',
              name: 'poll-detail',
              pageBuilder: (_, s) => _PushPage(
                key: s.pageKey,
                child: PollDetailScreen(pollId: s.pathParameters['id']!),
              ),
            ),
          ],
        ),

        // ── Other destinations ─────────────────────────────────
        GoRoute(
          path: '/activity-log',
          name: 'activity-log',
          pageBuilder: (_, s) => _TabPage(
            key: s.pageKey,
            child: const PlaceholderScreen(title: 'Activity Log'),
          ),
        ),
        GoRoute(
          path: '/resources',
          name: 'resources',
          pageBuilder: (_, s) =>
              _TabPage(key: s.pageKey, child: const ResourcesScreen()),
        ),
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          pageBuilder: (_, s) =>
              _TabPage(key: s.pageKey, child: const NotificationsScreen()),
        ),
        GoRoute(
          path: '/approvals',
          name: 'approvals',
          pageBuilder: (_, s) =>
              _TabPage(key: s.pageKey, child: const ApprovalsScreen()),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          pageBuilder: (_, s) =>
              _TabPage(key: s.pageKey, child: const SettingsScreen()),
        ),
      ],
    ),
  ],
);
