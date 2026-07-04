import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../features/auth/providers/auth_providers.dart';
import '../../../shared/models/user_club_role_model.dart';
import '../providers/directory_providers.dart';
import '../widgets/role_pill.dart';

class MemberProfileScreen extends ConsumerStatefulWidget {
  final String roleId;
  const MemberProfileScreen({super.key, required this.roleId});

  @override
  ConsumerState<MemberProfileScreen> createState() =>
      _MemberProfileScreenState();
}

class _MemberProfileScreenState extends ConsumerState<MemberProfileScreen> {
  bool _isRemoving = false;

  Future<void> _confirmRemove(UserClubRoleModel member) async {
    final name = member.profile?.fullName ?? 'this member';
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RemoveSheet(name: name),
    );
    if (confirmed != true) return;

    setState(() => _isRemoving = true);
    try {
      await ref.read(directoryRepositoryProvider).removeMember(member.id);
      if (!mounted) return;
      context.pop();
      ref.invalidate(clubMembersProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text('$name was removed from the club.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRemoving = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not remove member. Try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(clubMembersProvider);
    final viewerRole = ref.watch(activeClubRoleProvider);
    final currentUserId = supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: AppColors.textPrimary,
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Member',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: membersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),
        error: (_, _) => const Center(
          child: Text(
            'Could not load member.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        data: (members) {
          UserClubRoleModel? member;
          for (final m in members) {
            if (m.id == widget.roleId) {
              member = m;
              break;
            }
          }
          if (member == null) return const _NotFound();

          final isSelf = member.userId == currentUserId;
          final canRemove =
              (viewerRole?.isPresident ?? false) &&
              !isSelf &&
              !member.isPresident;

          return _ProfileBody(
            member: member,
            isSelf: isSelf,
            canRemove: canRemove,
            isRemoving: _isRemoving,
            onRemove: () => _confirmRemove(member!),
          );
        },
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final UserClubRoleModel member;
  final bool isSelf;
  final bool canRemove;
  final bool isRemoving;
  final VoidCallback onRemove;

  const _ProfileBody({
    required this.member,
    required this.isSelf,
    required this.canRemove,
    required this.isRemoving,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final name = member.profile?.fullName ?? 'Unknown';
    final email = member.profile?.email ?? '';
    final personalEmail = member.profile?.personalEmail ?? '';
    final color = roleColor(member.role);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Identity card ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 34,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RolePill(label: member.roleDisplayName, color: color),
                  if (isSelf) ...[
                    const SizedBox(width: 8),
                    const MutedTag(label: 'You'),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Info card ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.school_outlined,
                label: 'University Email',
                value: email.isNotEmpty ? email : '—',
              ),
              const Divider(height: 20),
              _InfoRow(
                icon: Icons.alternate_email,
                label: 'Personal Email',
                value: personalEmail.isNotEmpty ? personalEmail : '—',
              ),
              const Divider(height: 20),
              _InfoRow(
                icon: Icons.workspace_premium_outlined,
                label: 'Role',
                value: member.roleDisplayName,
              ),
              const Divider(height: 20),
              _InfoRow(
                icon: Icons.event_outlined,
                label: 'Joined',
                value: DateFormat(
                  'MMMM d, y',
                ).format(member.createdAt.toLocal()),
              ),
            ],
          ),
        ),

        // ── President-only: remove member ─────────────────────
        if (canRemove) ...[
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: isRemoving ? null : onRemove,
              icon: isRemoving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.error,
                      ),
                    )
                  : const Icon(Icons.person_remove_rounded, size: 18),
              label: Text(isRemoving ? 'Removing…' : 'Remove from Club'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'They will lose access to this club and can request to join again later.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],

        const SizedBox(height: 40),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_rounded,
              size: 56,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 12),
            Text(
              'Member not found.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoveSheet extends StatelessWidget {
  final String name;
  const _RemoveSheet({required this.name});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_remove_rounded,
              color: AppColors.error,
              size: 30,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Remove member?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const TextSpan(
                  text:
                      ' will lose access to this club. They can request to join again later.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Remove'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}
