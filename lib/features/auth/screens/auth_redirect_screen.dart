import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase_client.dart';
import '../providers/auth_providers.dart';

/// Shown after login/signup to route the user to the correct screen
/// based on their club membership state.
class AuthRedirectScreen extends ConsumerWidget {
  const AuthRedirectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(userClubRolesProvider);

    return rolesAsync.when(
      loading: () => const _LoadingScaffold(),
      error: (e, _) => _ErrorScaffold(message: e.toString()),
      data: (roles) {
        final approved = roles.where((r) => r.isApproved).toList();
        final pending = roles.where((r) => r.isPending).toList();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;

          if (approved.isNotEmpty) {
            context.go('/club-switcher');
            return;
          }

          if (pending.isNotEmpty) {
            context.go('/pending-approval');
            return;
          }

          // No memberships — check intended role from signup metadata
          final user = supabase.auth.currentUser;
          final intendedRole =
              user?.userMetadata?['intended_role'] as String? ?? '';

          if (intendedRole == 'president') {
            context.go('/club-setup');
          } else {
            context.go('/club-select');
          }
        });

        return const _LoadingScaffold();
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Back to Login'),
            ),
          ],
        ),
      ),
    );
  }
}
