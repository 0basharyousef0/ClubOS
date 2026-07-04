import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../features/auth/providers/auth_providers.dart';
import '../../../shared/models/user_club_role_model.dart';
import '../../../shared/widgets/copy_icon_button.dart';
import '../../../shared/widgets/gradient_header.dart';
import '../providers/directory_providers.dart';
import '../widgets/role_pill.dart';

class DirectoryScreen extends ConsumerStatefulWidget {
  const DirectoryScreen({super.key});

  @override
  ConsumerState<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends ConsumerState<DirectoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clubName = ref.watch(activeClubRoleProvider)?.club?.name;
    final membersAsync = ref.watch(clubMembersProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            GradientHeader(
              title: 'Directory',
              badge: clubName != null
                  ? GradientHeaderBadge(
                      icon: Icons.groups_rounded,
                      label: clubName,
                    )
                  : null,
            ),
            Expanded(
              child: membersAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2.5,
                  ),
                ),
                error: (_, _) => _ErrorState(
                  onRetry: () => ref.invalidate(clubMembersProvider),
                ),
                data: (members) => _DirectoryBody(
                  members: members,
                  query: _query,
                  searchController: _searchController,
                  onQueryChanged: (v) => setState(() => _query = v),
                  onRefresh: () async => ref.invalidate(clubMembersProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectoryBody extends StatelessWidget {
  final List<UserClubRoleModel> members;
  final String query;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final Future<void> Function() onRefresh;

  const _DirectoryBody({
    required this.members,
    required this.query,
    required this.searchController,
    required this.onQueryChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = supabase.auth.currentUser?.id;
    final q = query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? members
        : members.where((m) {
            final name = (m.profile?.fullName ?? '').toLowerCase();
            final email = (m.profile?.email ?? '').toLowerCase();
            final personal = (m.profile?.personalEmail ?? '').toLowerCase();
            return name.contains(q) ||
                email.contains(q) ||
                personal.contains(q);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: TextField(
            controller: searchController,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search members',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        searchController.clear();
                        onQueryChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _countLabel(members.length, filtered.length, q.isNotEmpty),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _EmptyState(hasQuery: q.isNotEmpty)
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: onRefresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _MemberCard(
                      member: filtered[i],
                      isCurrentUser: filtered[i].userId == currentUserId,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  String _countLabel(int total, int shown, bool searching) {
    final noun = total == 1 ? 'member' : 'members';
    return searching ? '$shown of $total $noun' : '$total $noun';
  }
}

/// Email line on a member card: wraps fully instead of truncating,
/// with a copy button alongside.
class _EmailLine extends StatelessWidget {
  final String email;
  const _EmailLine({required this.email});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            email,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 2),
        CopyIconButton(text: email),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  final UserClubRoleModel member;
  final bool isCurrentUser;
  const _MemberCard({required this.member, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    final name = member.profile?.fullName ?? 'Unknown';
    final email = member.profile?.email ?? '';
    final personalEmail = member.profile?.personalEmail ?? '';
    final color = roleColor(member.role);

    return GestureDetector(
      onTap: () => context.go('/directory/${member.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        const MutedTag(label: 'You'),
                      ],
                    ],
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    _EmailLine(email: email),
                  ],
                  if (personalEmail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    _EmailLine(email: personalEmail),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            RolePill(label: member.roleDisplayName, color: color),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              "Couldn't load the directory",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  const _EmptyState({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    // Wrapped in a scroll view so pull-to-refresh still works when empty.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasQuery ? Icons.search_off_rounded : Icons.groups_outlined,
                    size: 56,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hasQuery
                        ? 'No members match your search.'
                        : 'No members yet.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
