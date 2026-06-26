import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/club_model.dart';
import '../providers/auth_providers.dart';

final _clubsProvider = FutureProvider<List<ClubModel>>((ref) async {
  return ref.watch(authRepositoryProvider).getClubs();
});

class ClubSelectScreen extends ConsumerStatefulWidget {
  const ClubSelectScreen({super.key});

  @override
  ConsumerState<ClubSelectScreen> createState() => _ClubSelectScreenState();
}

class _ClubSelectScreenState extends ConsumerState<ClubSelectScreen> {
  ClubModel? _selectedClub;
  final _roleTitleController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _roleTitleController.dispose();
    super.dispose();
  }

  Future<void> _joinClub() async {
    if (_selectedClub == null) return;

    final role = supabase.auth.currentUser?.userMetadata?['intended_role'] as String?
        ?? AppConstants.roleVicePresident;
    final isPresidentRole = role == AppConstants.rolePresident;
    final roleTitle = _roleTitleController.text.trim();

    if (!isPresidentRole && roleTitle.isEmpty) {
      setState(() => _errorMessage = 'Please enter your specific role title.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).joinClub(
            clubId: _selectedClub!.id,
            role: role,
            roleTitle: isPresidentRole ? null : roleTitle,
          );
      ref.invalidate(userClubRolesProvider);
      if (mounted) context.go('/pending-approval');
    } on AuthApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clubsAsync = ref.watch(_clubsProvider);
    final role = supabase.auth.currentUser?.userMetadata?['intended_role'] as String?
        ?? AppConstants.roleVicePresident;
    final needsTitle = role != AppConstants.rolePresident;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () async {
            final roles = ref.read(userClubRolesProvider).valueOrNull ?? [];
            final hasApproved = roles.any((r) => r.isApproved);
            if (hasApproved) {
              if (context.mounted) context.go('/club-switcher');
            } else {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/register');
            }
          },
        ),
        title: const Text('Join a Club'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              _buildHeader(context),
              const SizedBox(height: 16),
              Expanded(
                child: clubsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 40),
                        const SizedBox(height: 8),
                        Text('Could not load clubs'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(_clubsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (clubs) {
                    // Filter out clubs the user already belongs to (approved or pending)
                    final existingRoles = ref.read(userClubRolesProvider).valueOrNull ?? [];
                    final existingClubIds = existingRoles
                        .where((r) => r.isApproved || r.isPending)
                        .map((r) => r.clubId)
                        .toSet();
                    final available = clubs
                        .where((c) => !existingClubIds.contains(c.id))
                        .toList();

                    return available.isEmpty
                        ? _EmptyClubs(
                            onBecomePresident: () => context.go('/club-setup'))
                        : _ClubList(
                            clubs: available,
                            selected: _selectedClub,
                            onSelect: (c) => setState(() {
                              _selectedClub = c;
                              _roleTitleController.clear();
                            }),
                          );
                  },
                ),
              ),
              if (needsTitle && _selectedClub != null) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _roleTitleController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() => _errorMessage = null),
                  decoration: InputDecoration(
                    labelText: 'Your Specific Role',
                    hintText: role == AppConstants.roleVicePresident
                        ? 'e.g. VP Finance, VP Marketing'
                        : 'e.g. Director of Events, Director of Finance',
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: _errorMessage!),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed:
                    (_selectedClub == null || _isLoading) ? null : _joinClub,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Request to Join'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.search_rounded,
              color: AppColors.primary, size: 30),
        ),
        const SizedBox(height: 16),
        Text('Join a club',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          'Select your club. The President will approve your request.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _ClubList extends StatelessWidget {
  final List<ClubModel> clubs;
  final ClubModel? selected;
  final ValueChanged<ClubModel> onSelect;

  const _ClubList(
      {required this.clubs, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: clubs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final club = clubs[i];
        final isSelected = selected?.id == club.id;
        return GestureDetector(
          onTap: () => onSelect(club),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.06)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.groups_rounded,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    club.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary, size: 22),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyClubs extends StatelessWidget {
  final VoidCallback onBecomePresident;
  const _EmptyClubs({required this.onBecomePresident});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.search_off_rounded,
            size: 56, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Text('No clubs yet',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Be the first to create one!',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: onBecomePresident,
          child: const Text('Create a Club Instead'),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
