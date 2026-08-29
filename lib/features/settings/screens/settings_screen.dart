import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/legal_links.dart';
import '../../../shared/widgets/verification_code_view.dart';
import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../features/auth/providers/auth_providers.dart';
import '../../../features/directory/providers/directory_providers.dart';
import '../../../shared/models/user_club_role_model.dart';
import '../../../shared/widgets/gradient_header.dart';
import '../../../shared/widgets/logout_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authStateChangesProvider);
    final user = supabase.auth.currentUser;
    final name = user?.userMetadata?['full_name'] as String? ?? '';
    final email = user?.email ?? '';
    final activeRole = ref.watch(activeClubRoleProvider);
    final isPresident = activeRole?.isPresident ?? false;
    final clubName = activeRole?.club?.name ?? '';
    final allRoles = ref.watch(userClubRolesProvider).valueOrNull ?? [];
    final hasMultipleClubs =
        allRoles.where((r) => r.isApproved).length > 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            title: 'Settings',
            badge: name.isNotEmpty
                ? GradientHeaderBadge(
                    icon: Icons.person_rounded, label: name)
                : null,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                const SizedBox(height: 24),

                // Profile card
                Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isNotEmpty ? name : 'No name set',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const _SectionLabel(label: 'Account'),
            const SizedBox(height: 8),

            _SettingsTile(
              icon: Icons.person_outline_rounded,
              title: 'Change Name',
              subtitle: name.isNotEmpty ? name : 'Not set',
              onTap: () => _showChangeSheet(
                context,
                ref,
                type: _ChangeType.name,
                currentEmail: email,
                currentValue: name,
              ),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.email_outlined,
              title: 'Change Email',
              subtitle: email,
              onTap: () => _showChangeSheet(
                context,
                ref,
                type: _ChangeType.email,
                currentEmail: email,
                currentValue: email,
              ),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.lock_outline_rounded,
              title: 'Change Password',
              subtitle: '••••••••',
              onTap: () => _showChangeSheet(
                context,
                ref,
                type: _ChangeType.password,
                currentEmail: email,
                currentValue: '',
              ),
            ),

            if (hasMultipleClubs) ...[
              const SizedBox(height: 24),
              const _SectionLabel(label: 'Club'),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.swap_horiz_rounded,
                title: 'Switch Club',
                subtitle: clubName.isNotEmpty ? clubName : 'Active club',
                onTap: () => context.go('/club-switcher'),
              ),
            ],

            const SizedBox(height: 24),
            const _SectionLabel(label: 'Session'),
            const SizedBox(height: 8),

            _SettingsTile(
              icon: Icons.logout_rounded,
              title: 'Log Out',
              subtitle: 'Sign out of your account',
              iconColor: AppColors.error,
              titleColor: AppColors.error,
              onTap: () async {
                final confirmed = await showLogoutConfirmation(context);
                if (confirmed && context.mounted) {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go('/login');
                }
              },
            ),

            const SizedBox(height: 24),
            const _SectionLabel(label: 'About'),
            const SizedBox(height: 8),

            _SettingsTile(
              icon: Icons.shield_outlined,
              title: 'Privacy Policy',
              subtitle: 'What we collect and how to delete your data',
              onTap: () => _openUrl(context, AppConstants.urlPrivacyPolicy),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              subtitle: 'Community rules and acceptable use',
              onTap: () => _openUrl(context, AppConstants.urlTermsOfService),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.support_agent_rounded,
              title: 'Contact Support',
              subtitle: AppConstants.supportEmail,
              onTap: () async {
                final ok = await openSupportEmail();
                if (!ok && context.mounted) {
                  _showCopyableFallback(
                    context,
                    'No mail app is set up. Email us at '
                    '${AppConstants.supportEmail}',
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.balance_rounded,
              title: 'Open Source Licenses',
              subtitle: 'Software ClubOS is built on',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'ClubOS',
                applicationVersion: _appVersion,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'ClubOS $_appVersion',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),

            const SizedBox(height: 24),
            const _SectionLabel(label: 'Danger Zone'),
            const SizedBox(height: 8),
            if (isPresident) ...[
              _SettingsTile(
                icon: Icons.workspace_premium_outlined,
                title: 'Transfer Presidency',
                subtitle: 'Hand $clubName over to another member',
                onTap: () => _showTransferSheet(context, ref),
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.auto_awesome_rounded,
                title: 'Start a New Term',
                subtitle: 'Clear last term\'s work and start fresh',
                onTap: () => _showResetTermSheet(
                  context,
                  ref,
                  clubName.isNotEmpty ? clubName : 'this club',
                ),
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.delete_forever_rounded,
                title: 'Delete Club',
                subtitle: 'Permanently delete $clubName and all its data',
                iconColor: AppColors.error,
                titleColor: AppColors.error,
                onTap: () => _showDeleteClubSheet(context, ref, clubName),
              ),
              const SizedBox(height: 8),
            ],
            // Presidents can't walk away from a club — they transfer or
            // delete it (the tiles above). Everyone else can leave.
            if (!isPresident && activeRole != null) ...[
              _SettingsTile(
                icon: Icons.exit_to_app_rounded,
                title: 'Leave Club',
                subtitle: clubName.isNotEmpty
                    ? 'Leave $clubName but keep your account'
                    : 'Leave this club but keep your account',
                onTap: () => _showLeaveClubSheet(
                  context,
                  ref,
                  clubName.isNotEmpty ? clubName : 'this club',
                ),
              ),
              const SizedBox(height: 8),
            ],
            _SettingsTile(
              icon: Icons.person_off_rounded,
              title: 'Delete Account',
              subtitle: 'Permanently delete your account and personal data',
              iconColor: AppColors.error,
              titleColor: AppColors.error,
              onTap: () => _showDeleteAccountSheet(context, ref),
            ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  void _showDeleteClubSheet(
    BuildContext context,
    WidgetRef ref,
    String clubName,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeleteClubSheet(
        clubName: clubName,
        onConfirm: () async {
          final role = ref.read(activeClubRoleProvider);
          if (role == null) return;

          final allRoles = ref.read(userClubRolesProvider).valueOrNull ?? [];
          await ref.read(authRepositoryProvider).deleteClub(role.clubId);

          ref.read(selectedClubRoleProvider.notifier).state = null;
          ref.invalidate(userClubRolesProvider);

          final otherApproved = allRoles
              .where((r) => r.isApproved && r.clubId != role.clubId)
              .toList();

          if (context.mounted) {
            if (otherApproved.isNotEmpty) {
              context.go('/club-switcher');
            } else {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/login');
            }
          }
        },
      ),
    );
  }

  void _showTransferSheet(BuildContext context, WidgetRef ref) {
    final role = ref.read(activeClubRoleProvider);
    if (role == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransferPresidencySheet(
        clubName: role.club?.name ?? 'this club',
        loadMembers: () async {
          final members = await ref
              .read(directoryRepositoryProvider)
              .getApprovedMembers(role.clubId);
          return members.where((m) => m.userId != role.userId).toList();
        },
        onConfirm: (member) async {
          await ref.read(authRepositoryProvider).transferPresidency(
                clubId: role.clubId,
                newPresidentId: member.userId,
              );
          // The caller is a Vice President now — drop the stale selection
          // and re-fetch roles so the whole app picks up the demotion.
          ref.read(selectedClubRoleProvider.notifier).state = null;
          ref.invalidate(userClubRolesProvider);
        },
      ),
    );
  }

  /// Kept in step with `version:` in pubspec.yaml. Hardcoded rather than
  /// read via package_info_plus — one string is not worth another
  /// platform plugin in the iOS build.
  static const String _appVersion = '1.0.0';

  Future<void> _openUrl(BuildContext context, String url) async {
    final ok = await openExternalUrl(url);
    if (!ok && context.mounted) {
      _showCopyableFallback(context, 'Could not open the page. Visit $url');
    }
  }

  /// A launch can fail on a device with no browser or mail client set up;
  /// show the address rather than silently doing nothing.
  void _showCopyableFallback(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Wiping a term is permanent, so this carries the same
  /// type-the-club-name ceremony as club deletion.
  void _showResetTermSheet(
    BuildContext context,
    WidgetRef ref,
    String clubName,
  ) {
    final role = ref.read(activeClubRoleProvider);
    if (role == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResetTermSheet(
        clubName: clubName,
        onConfirm: (clearRoster) async {
          await ref.read(authRepositoryProvider).resetClubTerm(
                clubId: role.clubId,
                clearRoster: clearRoster,
              );
          // Every list in the app is now stale.
          ref.invalidate(userClubRolesProvider);
        },
      ),
    );
  }

  /// Leaving is recoverable (the member can request to rejoin), so this
  /// is a single confirmation — deliberately lighter than the
  /// type-to-confirm ceremony guarding account and club deletion.
  void _showLeaveClubSheet(
    BuildContext context,
    WidgetRef ref,
    String clubName,
  ) {
    final role = ref.read(activeClubRoleProvider);
    if (role == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LeaveClubSheet(
        clubName: clubName,
        onConfirm: () async {
          await ref.read(authRepositoryProvider).leaveClub(role.clubId);
          // The active selection is stale now; re-fetch roles so the
          // app routes to a remaining club (or the join flow).
          ref.read(selectedClubRoleProvider.notifier).state = null;
          ref.invalidate(userClubRolesProvider);
        },
        onLeft: () {
          if (context.mounted) context.go('/');
        },
      ),
    );
  }

  void _showDeleteAccountSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeleteAccountSheet(
        loadStatus: () => _loadDeletionStatus(ref),
        onTransferInstead: () => _showTransferSheet(context, ref),
        onDelete: () async {
          await ref.read(authRepositoryProvider).deleteAccount();
          ref.read(selectedClubRoleProvider.notifier).state = null;
        },
        onDeleted: () {
          if (context.mounted) context.go('/login');
        },
      ),
    );
  }

  /// Presidents of clubs with other approved members cannot delete their
  /// account until they transfer presidency (or delete the club); clubs
  /// where they are the only member dissolve with the account. The RPC
  /// enforces the same rules server-side — this precheck is for UX.
  Future<_DeletionStatus> _loadDeletionStatus(WidgetRef ref) async {
    final roles = await ref.read(authRepositoryProvider).getUserClubRoles();
    final dirRepo = ref.read(directoryRepositoryProvider);
    final activeRole = ref.read(activeClubRoleProvider);

    final blocking = <String>[];
    final dissolving = <String>[];
    var activeClubBlocks = false;

    for (final r in roles.where((r) => r.isApproved && r.isPresident)) {
      final members = await dirRepo.getApprovedMembers(r.clubId);
      final hasOthers = members.any((m) => m.userId != r.userId);
      final name = r.club?.name ?? 'Unnamed club';
      if (hasOthers) {
        blocking.add(name);
        if (r.clubId == activeRole?.clubId) activeClubBlocks = true;
      } else {
        dissolving.add(name);
      }
    }

    return _DeletionStatus(
      blockingClubs: blocking,
      dissolvingClubs: dissolving,
      activeClubBlocks: activeClubBlocks,
    );
  }

  void _showChangeSheet(
    BuildContext context,
    WidgetRef ref, {
    required _ChangeType type,
    required String currentEmail,
    required String currentValue,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangeSheet(
        type: type,
        currentEmail: currentEmail,
        currentValue: currentValue,
        onSuccess: () => ref.invalidate(authStateChangesProvider),
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
      );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color iconColor;
  final Color titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = AppColors.primary,
    this.titleColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
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
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (titleColor == AppColors.textPrimary)
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Change sheet ──────────────────────────────────────────────

enum _ChangeType { name, email, password }

class _ChangeSheet extends StatefulWidget {
  final _ChangeType type;
  final String currentEmail;
  final String currentValue;
  final VoidCallback onSuccess;

  const _ChangeSheet({
    required this.type,
    required this.currentEmail,
    required this.currentValue,
    required this.onSuccess,
  });

  @override
  State<_ChangeSheet> createState() => _ChangeSheetState();
}

class _ChangeSheetState extends State<_ChangeSheet> {
  final _newValueController = TextEditingController();
  final _confirmController = TextEditingController(); // for password confirm
  final _otpController = TextEditingController();

  bool _otpSent = false;

  /// Set once the change has been requested and Supabase has emailed a
  /// confirmation code to the new address; the sheet then collects that
  /// second code. Only ever used for [_ChangeType.email].
  String? _pendingNewEmail;
  bool _isSending = false;
  bool _isConfirming = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _newValueController.dispose();
    _confirmController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String get _title => switch (widget.type) {
        _ChangeType.name => 'Change Name',
        _ChangeType.email => 'Change Email',
        _ChangeType.password => 'Change Password',
      };

  String get _fieldLabel => switch (widget.type) {
        _ChangeType.name => 'New Name',
        _ChangeType.email => 'New Email',
        _ChangeType.password => 'New Password',
      };

  String get _hint => switch (widget.type) {
        _ChangeType.name => 'Enter your new full name',
        _ChangeType.email => 'Enter your new email address',
        _ChangeType.password => 'Enter your new password',
      };

  String? _validateNewValue() {
    final v = _newValueController.text.trim();
    if (v.isEmpty) return '$_fieldLabel is required';
    if (widget.type == _ChangeType.email && !v.contains('@')) {
      return 'Enter a valid email';
    }
    if (widget.type == _ChangeType.password && v.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (widget.type == _ChangeType.password &&
        _confirmController.text != _newValueController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _sendCode() async {
    final validationError = _validateNewValue();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      await supabase.auth.signInWithOtp(
        email: widget.currentEmail,
        shouldCreateUser: false,
      );
      if (mounted) setState(() => _otpSent = true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send code. Try again.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _confirm() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() {
      _isConfirming = true;
      _error = null;
    });
    try {
      // Verify OTP
      await supabase.auth.verifyOTP(
        email: widget.currentEmail,
        token: code,
        type: OtpType.email,
      );

      // Apply the change
      final newValue = _newValueController.text.trim();
      switch (widget.type) {
        case _ChangeType.name:
          await supabase.auth.updateUser(
            UserAttributes(data: {'full_name': newValue}),
          );
          await supabase
              .from('profiles')
              .update({'full_name': newValue})
              .eq('id', supabase.auth.currentUser!.id);
        case _ChangeType.email:
          await supabase.auth.updateUser(
            UserAttributes(email: newValue),
          );
          // Supabase now emails a second code, this time to the NEW
          // address — proving they can receive mail there. Stay in the
          // sheet to collect it rather than closing on a half-done
          // change.
          if (mounted) {
            setState(() {
              _pendingNewEmail = newValue;
              _isConfirming = false;
            });
          }
          return;
        case _ChangeType.password:
          await supabase.auth.updateUser(
            UserAttributes(password: newValue),
          );
      }

      widget.onSuccess();
      if (mounted) {
        Navigator.pop(context);
        _showSuccess(context);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  void _showSuccess(BuildContext context) {
    final msg = switch (widget.type) {
      _ChangeType.name => 'Name updated successfully.',
      _ChangeType.email =>
        'Confirmation sent to your new email. Click the link to complete the change.',
      _ChangeType.password => 'Password updated successfully.',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    // Final leg of an email change: confirm the code sent to the new
    // address. Reuses the shared panel the signup and recovery flows use.
    final pendingNewEmail = _pendingNewEmail;
    if (pendingNewEmail != null) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding + 24),
        child: SingleChildScrollView(
          child: VerificationCodeView(
            email: pendingNewEmail,
            title: 'Confirm your new email',
            subtitle: 'We sent a 6-digit code to',
            verifyLabel: 'Confirm new email',
            onVerify: (code) async {
              await supabase.auth.verifyOTP(
                email: pendingNewEmail,
                token: code,
                type: OtpType.emailChange,
              );
              widget.onSuccess();
              if (context.mounted) {
                Navigator.pop(context);
                _showSuccess(context);
              }
            },
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding + 24),
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
          Text(_title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(
            _otpSent
                ? 'Enter the 6-digit code sent to ${widget.currentEmail}.'
                : 'A confirmation code will be sent to ${widget.currentEmail}.',
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),

          if (!_otpSent) ...[
            // New value field
            TextField(
              controller: _newValueController,
              obscureText: widget.type == _ChangeType.password && _obscureNew,
              keyboardType: widget.type == _ChangeType.email
                  ? TextInputType.emailAddress
                  : TextInputType.text,
              textCapitalization: widget.type == _ChangeType.name
                  ? TextCapitalization.words
                  : TextCapitalization.none,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: _fieldLabel,
                hintText: _hint,
                prefixIcon: Icon(widget.type == _ChangeType.name
                    ? Icons.person_outline
                    : widget.type == _ChangeType.email
                        ? Icons.email_outlined
                        : Icons.lock_outline),
                suffixIcon: widget.type == _ChangeType.password
                    ? IconButton(
                        icon: Icon(_obscureNew
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (widget.type == _ChangeType.password) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
            ],
          ] else ...[
            // OTP field
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 12,
              ),
              decoration: const InputDecoration(
                hintText: '000000',
                counterText: '',
                prefixIcon: Icon(Icons.pin_outlined),
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isSending ? null : _sendCode,
                child: const Text('Resend code'),
              ),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: (_isSending || _isConfirming)
                  ? null
                  : (_otpSent ? _confirm : _sendCode),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: (_isSending || _isConfirming)
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(_otpSent ? 'Confirm Change' : 'Send Confirmation Code'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Delete club sheet ─────────────────────────────────────────

class _DeleteClubSheet extends StatefulWidget {
  final String clubName;
  final Future<void> Function() onConfirm;

  const _DeleteClubSheet({
    required this.clubName,
    required this.onConfirm,
  });

  @override
  State<_DeleteClubSheet> createState() => _DeleteClubSheetState();
}

class _DeleteClubSheetState extends State<_DeleteClubSheet> {
  int _step = 0; // 0 = warning, 1 = confirm
  final _nameController = TextEditingController();
  bool _understood = false;
  bool _isDeleting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _nameMatches =>
      _nameController.text.trim() == widget.clubName.trim();

  bool get _canDelete => _nameMatches && _understood && !_isDeleting;

  Future<void> _delete() async {
    setState(() {
      _isDeleting = true;
      _error = null;
    });
    try {
      Navigator.pop(context);
      await widget.onConfirm();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _error = 'Could not delete club. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding + 24),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: _step == 0 ? _buildWarningStep() : _buildConfirmStep(),
      ),
    );
  }

  Widget _buildWarningStep() {
    return Column(
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
        const SizedBox(height: 28),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delete_forever_rounded,
              color: AppColors.error,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Delete Club?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This will permanently delete "${widget.clubName}" and cannot be undone. The following will be removed:',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        _ConsequenceRow(icon: Icons.people_alt_outlined, label: 'All members and roles'),
        const SizedBox(height: 8),
        _ConsequenceRow(icon: Icons.checklist_rounded, label: 'All tasks and comments'),
        const SizedBox(height: 8),
        _ConsequenceRow(icon: Icons.event_outlined, label: 'All events and RSVPs'),
        const SizedBox(height: 8),
        _ConsequenceRow(icon: Icons.campaign_outlined, label: 'All announcements'),
        const SizedBox(height: 8),
        _ConsequenceRow(icon: Icons.how_to_vote_outlined, label: 'All polls and votes'),
        const SizedBox(height: 28),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () => setState(() => _step = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    return Column(
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
        const SizedBox(height: 24),
        const Text(
          'Confirm deletion',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            children: [
              const TextSpan(text: 'Type '),
              TextSpan(
                text: widget.clubName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const TextSpan(text: ' to confirm.'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          autofocus: true,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: widget.clubName,
            errorText: _nameController.text.isNotEmpty && !_nameMatches
                ? 'Name does not match'
                : null,
          ),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => setState(() => _understood = !_understood),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _understood,
                  onChanged: (v) => setState(() => _understood = v ?? false),
                  activeColor: AppColors.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'I understand this action is permanent and cannot be undone.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _canDelete ? _delete : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.error.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isDeleting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Permanently Delete Club',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: () => setState(() => _step = 0),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Back',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Transfer presidency sheet ─────────────────────────────────

class _TransferPresidencySheet extends StatefulWidget {
  final String clubName;
  final Future<List<UserClubRoleModel>> Function() loadMembers;
  final Future<void> Function(UserClubRoleModel member) onConfirm;

  const _TransferPresidencySheet({
    required this.clubName,
    required this.loadMembers,
    required this.onConfirm,
  });

  @override
  State<_TransferPresidencySheet> createState() =>
      _TransferPresidencySheetState();
}

class _TransferPresidencySheetState extends State<_TransferPresidencySheet> {
  List<UserClubRoleModel>? _members;
  UserClubRoleModel? _selected;
  int _step = 0; // 0 = pick member, 1 = confirm
  final _nameController = TextEditingController();
  bool _isTransferring = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.loadMembers().then((members) {
      if (mounted) setState(() => _members = members);
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _members = const [];
          _error = 'Could not load members. Try again.';
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _selectedName => _selected?.profile?.fullName.trim() ?? '';

  bool get _nameMatches =>
      _selectedName.isNotEmpty &&
      _nameController.text.trim().toLowerCase() ==
          _selectedName.toLowerCase();

  Future<void> _transfer() async {
    final member = _selected;
    if (member == null) return;
    setState(() {
      _isTransferring = true;
      _error = null;
    });
    try {
      await widget.onConfirm(member);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '$_selectedName is now the president of ${widget.clubName}. '
                'You are a Vice President.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _isTransferring = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isTransferring = false;
          _error = 'Could not transfer presidency. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding + 24),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: _step == 0 ? _buildPickStep() : _buildConfirmStep(),
      ),
    );
  }

  Widget _buildPickStep() {
    final members = _members;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        const SizedBox(height: 20),
        const Text(
          'Transfer Presidency',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose the member who will become the new president of '
          '${widget.clubName}. You will become a Vice President.',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        if (members == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (members.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              _error ??
                  'No other approved members yet. Approve a member first — '
                      'or delete the club instead.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: members.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final m = members[index];
                final selected = _selected?.id == m.id;
                return GestureDetector(
                  onTap: () => setState(() => _selected = m),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.06)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            selected ? AppColors.primary : AppColors.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.12),
                          child: Text(
                            (m.profile?.fullName.isNotEmpty ?? false)
                                ? m.profile!.fullName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.profile?.fullName ?? 'Unknown member',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                m.roleDisplayName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
              },
            ),
          ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed:
                _selected == null ? null : () => setState(() => _step = 1),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    final m = _selected!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        const SizedBox(height: 20),
        const Text(
          'Confirm transfer',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // The successor's details, so the president knows exactly who
        // is receiving the club.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.profile?.fullName ?? 'Unknown member',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                m.roleDisplayName,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              if ((m.profile?.email ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  m.profile!.email,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            children: [
              const TextSpan(text: 'Type '),
              TextSpan(
                text: _selectedName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const TextSpan(text: ' to confirm.'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          autofocus: true,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: _selectedName,
            errorText: _nameController.text.isNotEmpty && !_nameMatches
                ? 'Name does not match'
                : null,
          ),
          onChanged: (_) => setState(() => _error = null),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _SheetError(message: _error!),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: (_nameMatches && !_isTransferring) ? _transfer : null,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isTransferring
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Transfer Presidency',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed:
                _isTransferring ? null : () => setState(() => _step = 0),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Back',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Delete account sheet ──────────────────────────────────────

class _DeletionStatus {
  /// Clubs the user presides over that still have other approved members —
  /// each blocks deletion until presidency is transferred (or the club
  /// deleted).
  final List<String> blockingClubs;

  /// Clubs where the user is president and the only approved member —
  /// these are deleted together with the account.
  final List<String> dissolvingClubs;

  final bool activeClubBlocks;

  const _DeletionStatus({
    required this.blockingClubs,
    required this.dissolvingClubs,
    required this.activeClubBlocks,
  });
}

class _DeleteAccountSheet extends StatefulWidget {
  final Future<_DeletionStatus> Function() loadStatus;
  final VoidCallback onTransferInstead;
  final Future<void> Function() onDelete;
  final VoidCallback onDeleted;

  const _DeleteAccountSheet({
    required this.loadStatus,
    required this.onTransferInstead,
    required this.onDelete,
    required this.onDeleted,
  });

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  static const _confirmWord = 'DELETE';

  _DeletionStatus? _status;
  int _step = 0; // 0 = warning (or blocked), 1 = confirm
  final _confirmController = TextEditingController();
  bool _understood = false;
  bool _isDeleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.loadStatus().then((status) {
      if (mounted) setState(() => _status = status);
    }).catchError((_) {
      if (mounted) {
        // Fail open on the precheck: the RPC re-validates server-side
        // and rejects a blocked president with a readable message.
        setState(() {
          _status = const _DeletionStatus(
            blockingClubs: [],
            dissolvingClubs: [],
            activeClubBlocks: false,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  bool get _wordMatches =>
      _confirmController.text.trim().toUpperCase() == _confirmWord;

  Future<void> _delete() async {
    setState(() {
      _isDeleting = true;
      _error = null;
    });
    try {
      await widget.onDelete();
      if (mounted) {
        Navigator.pop(context);
        widget.onDeleted();
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _error = 'Could not delete your account. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    final status = _status;
    final Widget body;
    if (status == null) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (status.blockingClubs.isNotEmpty) {
      body = _buildBlockedStep(status);
    } else {
      body = _step == 0 ? _buildWarningStep(status) : _buildConfirmStep();
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding + 24),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: body,
      ),
    );
  }

  Widget _buildBlockedStep(_DeletionStatus status) {
    final clubs = status.blockingClubs.map((c) => '"$c"').join(', ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        const SizedBox(height: 28),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              color: AppColors.warning,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Transfer your presidency first',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You are the president of $clubs. A club can\'t be left without '
          'a president — transfer the presidency to another member (or '
          'delete the club), then delete your account.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        if (status.blockingClubs.length > 1 ||
            !status.activeClubBlocks) ...[
          const SizedBox(height: 8),
          const Text(
            'Use the club switcher to open each club and transfer or '
            'delete it from Settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 28),
        if (status.activeClubBlocks) ...[
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onTransferInstead();
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Transfer Presidency',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarningStep(_DeletionStatus status) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        const SizedBox(height: 28),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_off_rounded,
              color: AppColors.error,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Delete Account?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'This permanently deletes your account and cannot be undone. '
          'The following is removed:',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        const _ConsequenceRow(
            icon: Icons.badge_outlined,
            label: 'Your name, emails and login'),
        const SizedBox(height: 8),
        const _ConsequenceRow(
            icon: Icons.people_alt_outlined,
            label: 'Your club memberships and directory listing'),
        const SizedBox(height: 8),
        const _ConsequenceRow(
            icon: Icons.notifications_off_outlined,
            label: 'Your notifications and registered devices'),
        for (final club in status.dissolvingClubs) ...[
          const SizedBox(height: 8),
          _ConsequenceRow(
            icon: Icons.delete_forever_rounded,
            label: '"$club" — you are its only member, so it is deleted',
          ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.history_rounded,
                  size: 16, color: AppColors.textSecondary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tasks, comments, files and posts you contributed stay '
                  'with your clubs, shown as "Former member".',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () => setState(() => _step = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        const SizedBox(height: 24),
        const Text(
          'Confirm deletion',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            children: [
              const TextSpan(text: 'Type '),
              TextSpan(
                text: _confirmWord,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const TextSpan(text: ' to confirm.'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmController,
          autofocus: true,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: _confirmWord,
            errorText: _confirmController.text.isNotEmpty && !_wordMatches
                ? 'Type $_confirmWord to continue'
                : null,
          ),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => setState(() => _understood = !_understood),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _understood,
                  onChanged: (v) => setState(() => _understood = v ?? false),
                  activeColor: AppColors.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'I understand my account and personal data are '
                  'permanently deleted and cannot be recovered.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _SheetError(message: _error!),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed:
                (_wordMatches && _understood && !_isDeleting) ? _delete : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.error.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isDeleting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Permanently Delete Account',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: _isDeleting ? null : () => setState(() => _step = 0),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Back',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Small shared sheet pieces ─────────────────────────────────

/// Two-step reset: review what goes and choose whether the roster goes
/// with it, then type the club name to confirm. Permanent, so it wears
/// the same ceremony as club deletion.
class _ResetTermSheet extends StatefulWidget {
  final String clubName;
  final Future<void> Function(bool clearRoster) onConfirm;

  const _ResetTermSheet({required this.clubName, required this.onConfirm});

  @override
  State<_ResetTermSheet> createState() => _ResetTermSheetState();
}

class _ResetTermSheetState extends State<_ResetTermSheet> {
  final _confirmController = TextEditingController();
  int _step = 0; // 0 = review, 1 = type-to-confirm
  bool _clearRoster = false;
  bool _isResetting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _confirmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canConfirm =>
      _confirmController.text.trim().toLowerCase() ==
      widget.clubName.trim().toLowerCase();

  Future<void> _reset() async {
    setState(() {
      _isResetting = true;
      _error = null;
    });
    try {
      await widget.onConfirm(_clearRoster);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.clubName} is ready for a new term.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _isResetting = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isResetting = false;
          _error = 'Could not start a new term. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding + 24),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: _step == 0 ? _buildReviewStep() : _buildConfirmStep(),
      ),
    );
  }

  Widget _buildReviewStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        const SizedBox(height: 28),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Color(0xFF8B5CF6), size: 30),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Start a new term',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Clears last term\'s work from ${widget.clubName} so your new '
          'board starts on a clean slate. This cannot be undone.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ConsequenceRow(
                icon: Icons.delete_sweep_outlined,
                label: 'Erased: tasks, comments and attachments, events '
                    'and RSVPs, announcements, polls and votes, meetings, '
                    'and the activity log',
              ),
              SizedBox(height: 10),
              _ConsequenceRow(
                icon: Icons.shield_outlined,
                label: 'Kept: the club and its name, the constitution '
                    'and resources, and you as president',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Full board turnover is common but not universal — a director
        // often stays on as a VP, so this is opt-in.
        GestureDetector(
          onTap: () => setState(() => _clearRoster = !_clearRoster),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _clearRoster
                  ? AppColors.error.withValues(alpha: 0.06)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _clearRoster ? AppColors.error : AppColors.border,
                width: _clearRoster ? 2 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _clearRoster
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 22,
                  color:
                      _clearRoster ? AppColors.error : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Also remove all other members',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _clearRoster
                            ? 'Everyone but you leaves the club. Their '
                                'accounts are untouched and they can request '
                                'to join again.'
                            : 'Leave unchecked to keep your current VPs and '
                                'directors.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () => setState(() => _step = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHandle(),
        const SizedBox(height: 28),
        const Text(
          'Type the club name to confirm',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _clearRoster
              ? 'This erases last term\'s work AND removes every other '
                  'member from ${widget.clubName}.'
              : 'This erases last term\'s work from ${widget.clubName}.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _confirmController,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          decoration: InputDecoration(
            hintText: widget.clubName,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _SheetError(message: _error!),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: (!_canConfirm || _isResetting) ? null : _reset,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.border,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isResetting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Start New Term',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: _isResetting ? null : () => setState(() => _step = 0),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Back',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

/// Single-step confirmation for leaving one club. Lighter than the
/// account/club deletion sheets on purpose: leaving is recoverable, and
/// matching their type-to-confirm weight would train people to click
/// through the irreversible ones too.
class _LeaveClubSheet extends StatefulWidget {
  final String clubName;
  final Future<void> Function() onConfirm;
  final VoidCallback onLeft;

  const _LeaveClubSheet({
    required this.clubName,
    required this.onConfirm,
    required this.onLeft,
  });

  @override
  State<_LeaveClubSheet> createState() => _LeaveClubSheetState();
}

class _LeaveClubSheetState extends State<_LeaveClubSheet> {
  bool _isLeaving = false;
  String? _error;

  Future<void> _leave() async {
    setState(() {
      _isLeaving = true;
      _error = null;
    });
    try {
      await widget.onConfirm();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You left ${widget.clubName}.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        widget.onLeft();
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _isLeaving = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLeaving = false;
          _error = 'Could not leave the club. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 28),
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.exit_to_app_rounded,
                  color: AppColors.warning, size: 30),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Leave ${widget.clubName}?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your account and any other clubs you belong to are not '
            'affected. You can request to join again later.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ConsequenceRow(
                  icon: Icons.visibility_off_outlined,
                  label: 'You lose access to this club\'s tasks, events, '
                      'polls and announcements',
                ),
                SizedBox(height: 10),
                _ConsequenceRow(
                  icon: Icons.event_busy_outlined,
                  label: 'Upcoming RSVPs, meeting invites and open polls '
                      'drop you from their lists',
                ),
                SizedBox(height: 10),
                _ConsequenceRow(
                  icon: Icons.groups_outlined,
                  label: 'Your president is notified, and any directors '
                      'reporting to you are unassigned',
                ),
                SizedBox(height: 10),
                _ConsequenceRow(
                  icon: Icons.history_rounded,
                  label: 'Work you already created stays in the club, '
                      'still under your name',
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            _SheetError(message: _error!),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLeaving ? null : _leave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLeaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Leave Club',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: _isLeaving ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

class _SheetError extends StatelessWidget {
  final String message;
  const _SheetError({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          ],
        ),
      );
}

class _ConsequenceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ConsequenceRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.error),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
