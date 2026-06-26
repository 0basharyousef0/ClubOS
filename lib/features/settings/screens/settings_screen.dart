import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../features/auth/providers/auth_providers.dart';
import '../../../shared/widgets/gradient_header.dart';
import '../../../shared/widgets/logout_sheet.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authStateChangesProvider);
    final user = supabase.auth.currentUser;
    final name = user?.userMetadata?['full_name'] as String? ?? '';
    final email = user?.email ?? '';

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

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    ));
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
    if (widget.type == _ChangeType.password && v.length < 6) {
      return 'Password must be at least 6 characters';
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
