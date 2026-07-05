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

// Approved VPs of the selected club — directors pick who they work under.
final _clubVpsProvider = FutureProvider.family<List<Map<String, dynamic>>,
    String>((ref, clubId) async {
  return ref.watch(authRepositoryProvider).getClubVps(clubId);
});

class ClubSelectScreen extends ConsumerStatefulWidget {
  const ClubSelectScreen({super.key});

  @override
  ConsumerState<ClubSelectScreen> createState() => _ClubSelectScreenState();
}

class _ClubSelectScreenState extends ConsumerState<ClubSelectScreen> {
  ClubModel? _selectedClub;
  Map<String, dynamic>? _selectedVp;
  final _roleTitleController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // VPs typed their title at signup — prefill it here (still editable).
    final meta = supabase.auth.currentUser?.userMetadata;
    if ((meta?['intended_role'] as String?) ==
        AppConstants.roleVicePresident) {
      _roleTitleController.text = (meta?['role_title'] as String?) ?? '';
    }
  }

  @override
  void dispose() {
    _roleTitleController.dispose();
    super.dispose();
  }

  /// "VP Finance" / "VP of Finance" / "Vice President Finance" -> "Finance
  /// Director". Falls back to plain "Director" if the VP has no title.
  static String directorTitleFor(Map<String, dynamic> vp) {
    final title = ((vp['role_title'] as String?) ?? '').trim();
    if (title.isEmpty) return 'Director';
    final base = title
        .replaceFirst(
            RegExp(r'^vice\s+president\s+(of\s+)?', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^vp\s+(of\s+)?', caseSensitive: false), '')
        .trim();
    return base.isEmpty ? 'Director' : '$base Director';
  }

  /// Directors can't join a club that has no approved VPs.
  bool _directorJoinBlocked(String role) {
    if (role != AppConstants.roleDirector || _selectedClub == null) {
      return false;
    }
    return ref.watch(_clubVpsProvider(_selectedClub!.id)).maybeWhen(
          data: (vps) => vps.isEmpty,
          orElse: () => false,
        );
  }

  Future<void> _joinClub() async {
    if (_selectedClub == null) return;

    final role = supabase.auth.currentUser?.userMetadata?['intended_role'] as String?
        ?? AppConstants.roleVicePresident;

    String? roleTitle;
    if (role == AppConstants.roleVicePresident) {
      final raw = _roleTitleController.text.trim();
      if (raw.isEmpty) {
        setState(() =>
            _errorMessage = 'Please enter your VP title (e.g. VP Finance).');
        return;
      }
      roleTitle = RegExp(r'^vp\b', caseSensitive: false).hasMatch(raw)
          ? raw
          : 'VP $raw';
    } else if (role == AppConstants.roleDirector) {
      final vps =
          ref.read(_clubVpsProvider(_selectedClub!.id)).valueOrNull ?? [];
      // Directors always work under a VP — no VPs means no director joins.
      if (vps.isEmpty) {
        setState(() => _errorMessage =
            'This club has no VPs yet, so directors can\'t join it.');
        return;
      }
      if (_selectedVp == null) {
        setState(() =>
            _errorMessage = 'Please select the VP you work under.');
        return;
      }
      roleTitle = directorTitleFor(_selectedVp!);
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).joinClub(
            clubId: _selectedClub!.id,
            role: role,
            roleTitle: roleTitle,
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
                              _selectedVp = null;
                            }),
                          );
                  },
                ),
              ),
              if (_selectedClub != null &&
                  role == AppConstants.roleVicePresident) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _roleTitleController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() => _errorMessage = null),
                  decoration: const InputDecoration(
                    labelText: 'Your VP Title',
                    hintText: 'e.g. VP Finance, VP Marketing',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
              ],
              if (_selectedClub != null &&
                  role == AppConstants.roleDirector) ...[
                const SizedBox(height: 16),
                _VpPicker(
                  vpsAsync: ref.watch(_clubVpsProvider(_selectedClub!.id)),
                  selected: _selectedVp,
                  onSelect: (vp) => setState(() {
                    _selectedVp = vp;
                    _errorMessage = null;
                  }),
                  onRetry: () =>
                      ref.invalidate(_clubVpsProvider(_selectedClub!.id)),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: _errorMessage!),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: (_selectedClub == null ||
                        _isLoading ||
                        _directorJoinBlocked(role))
                    ? null
                    : _joinClub,
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

class _VpPicker extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> vpsAsync;
  final Map<String, dynamic>? selected;
  final ValueChanged<Map<String, dynamic>> onSelect;
  final VoidCallback onRetry;

  const _VpPicker({
    required this.vpsAsync,
    required this.selected,
    required this.onSelect,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return vpsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Couldn\'t load this club\'s VPs',
                style: TextStyle(fontSize: 13, color: AppColors.error)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
      data: (vps) {
        if (vps.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This club has no VPs yet. Directors work under a VP, '
                    'so you can\'t join until a VP has been approved.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selected?['user_id'] as String?,
              decoration: const InputDecoration(
                labelText: 'VP you work under',
                prefixIcon: Icon(Icons.supervisor_account_outlined),
              ),
              items: [
                for (final vp in vps)
                  DropdownMenuItem(
                    value: vp['user_id'] as String,
                    child: Text(
                      (vp['role_title'] as String?)?.trim().isNotEmpty == true
                          ? '${vp['full_name']} · ${vp['role_title']}'
                          : vp['full_name'] as String,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) {
                final vp = vps.firstWhere((v) => v['user_id'] == id);
                onSelect(vp);
              },
            ),
            if (selected != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.badge_outlined,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Your title: '
                    '${_ClubSelectScreenState.directorTitleFor(selected!)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
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
