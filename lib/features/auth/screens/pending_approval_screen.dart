import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/logout_sheet.dart';
import '../providers/auth_providers.dart';

class PendingApprovalScreen extends ConsumerStatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  ConsumerState<PendingApprovalScreen> createState() =>
      _PendingApprovalScreenState();
}

class _PendingApprovalScreenState
    extends ConsumerState<PendingApprovalScreen> {
  bool _isRefreshing = false;

  Future<void> _checkStatus() async {
    setState(() => _isRefreshing = true);
    try {
      ref.invalidate(userClubRolesProvider);
      // Wait for the provider to refresh
      await ref.read(userClubRolesProvider.future);

      if (!mounted) return;
      final roles = ref.read(userClubRolesProvider).valueOrNull ?? [];
      final approved = roles.where((r) => r.isApproved).toList();
      final rejected = roles.where((r) => r.isRejected).toList();

      if (approved.isNotEmpty) {
        context.go('/club-switcher');
      } else if (rejected.isNotEmpty) {
        _showRejectedDialog(rejected.first.club?.name ?? 'your club');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Still pending — check back later.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _showRejectedDialog(String clubName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Request Rejected'),
        content: Text(
            'Your request to join $clubName was rejected by the President.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/club-select');
            },
            child: const Text('Try Another Club'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showLogoutConfirmation(context);
    if (confirmed && mounted) {
      await ref.read(authRepositoryProvider).signOut();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(userClubRolesProvider);
    final pendingRole = rolesAsync.valueOrNull
        ?.where((r) => r.isPending)
        .firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              _buildIllustration(),
              const SizedBox(height: 28),
              Text('Waiting for approval',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                pendingRole != null
                    ? 'Your request to join ${pendingRole.club?.name ?? 'the club'} as ${pendingRole.roleDisplayName} is pending.\n\nThe President will review your request shortly.'
                    : 'Your membership request is under review.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isRefreshing ? null : _checkStatus,
                child: _isRefreshing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Check Status'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _signOut,
                child: const Text('Sign Out'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIllustration() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.hourglass_top_rounded,
        color: AppColors.warning,
        size: 52,
      ),
    );
  }
}
