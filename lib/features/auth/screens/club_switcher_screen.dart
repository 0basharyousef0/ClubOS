import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/user_club_role_model.dart';
import '../../../shared/widgets/logout_sheet.dart';
import '../providers/auth_providers.dart';

class ClubSwitcherScreen extends ConsumerWidget {
  const ClubSwitcherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(userClubRolesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Your Clubs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () async {
              final confirmed = await showLogoutConfirmation(context);
              if (confirmed && context.mounted) {
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
      body: rolesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 40),
              const SizedBox(height: 8),
              Text(e.toString()),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(userClubRolesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (roles) => _ClubListBody(roles: roles),
      ),
    );
  }
}

class _ClubListBody extends ConsumerStatefulWidget {
  final List<UserClubRoleModel> roles;
  const _ClubListBody({required this.roles});

  @override
  ConsumerState<_ClubListBody> createState() => _ClubListBodyState();
}

class _ClubListBodyState extends ConsumerState<_ClubListBody> {
  bool _isUpdatingRole = false;

  void _selectClub(UserClubRoleModel role) {
    ref.read(selectedClubRoleProvider.notifier).state = role;
    context.go('/dashboard');
  }

  Future<void> _showAddClubSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddClubSheet(onRoleSelected: _handleAddClub),
    );
  }

  Future<void> _handleAddClub(String role) async {
    Navigator.pop(context);
    setState(() => _isUpdatingRole = true);
    try {
      await supabase.auth.updateUser(
        UserAttributes(data: {'intended_role': role}),
      );
      if (!mounted) return;
      if (role == 'president') {
        context.go('/club-setup');
      } else {
        context.go('/club-select');
      }
    } finally {
      if (mounted) setState(() => _isUpdatingRole = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final approved = widget.roles.where((r) => r.isApproved).toList();
    final pending = widget.roles.where((r) => r.isPending).toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              children: [
                Text(
                  'Select a club to continue',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ...approved.map(
                  (r) => _ClubCard(role: r, enabled: true, onTap: () => _selectClub(r)),
                ),
                if (pending.isNotEmpty) ...[
                  if (approved.isNotEmpty) const SizedBox(height: 4),
                  ...pending.map(
                    (r) => _ClubCard(role: r, enabled: false, onTap: null),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: OutlinedButton.icon(
              onPressed: _isUpdatingRole ? null : _showAddClubSheet,
              icon: _isUpdatingRole
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: const Text('Add Another Club'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubCard extends StatelessWidget {
  final UserClubRoleModel role;
  final bool enabled;
  final VoidCallback? onTap;

  const _ClubCard({
    required this.role,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: enabled ? AppColors.surface : AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: enabled
                      ? AppColors.primary.withValues(alpha: 0.10)
                      : AppColors.textSecondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.groups_rounded,
                  color: enabled ? AppColors.primary : AppColors.textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.club?.name ?? 'Unknown Club',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: enabled
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role.roleDisplayName,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (!enabled)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.warning,
                    ),
                  ),
                )
              else
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddClubSheet extends StatefulWidget {
  final void Function(String role) onRoleSelected;
  const _AddClubSheet({required this.onRoleSelected});

  @override
  State<_AddClubSheet> createState() => _AddClubSheetState();
}

class _AddClubSheetState extends State<_AddClubSheet> {
  String? _selectedRole;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Add a Club', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'What is your role in the new club?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          _RoleTile(
            icon: Icons.star_rounded,
            title: 'President',
            subtitle: 'Create and lead a new club',
            selected: _selectedRole == 'president',
            onTap: () => setState(() => _selectedRole = 'president'),
          ),
          const SizedBox(height: 10),
          _RoleTile(
            icon: Icons.person_rounded,
            title: 'Vice President',
            subtitle: 'Join an existing club as VP',
            selected: _selectedRole == 'vice_president',
            onTap: () => setState(() => _selectedRole = 'vice_president'),
          ),
          const SizedBox(height: 10),
          _RoleTile(
            icon: Icons.badge_rounded,
            title: 'Director',
            subtitle: 'Join an existing club as Director',
            selected: _selectedRole == 'director',
            onTap: () => setState(() => _selectedRole = 'director'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _selectedRole == null
                ? null
                : () => widget.onRoleSelected(_selectedRole!),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _RoleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
