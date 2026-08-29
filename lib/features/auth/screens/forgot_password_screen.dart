import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/verification_code_view.dart';
import '../providers/auth_providers.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String email;
  const ForgotPasswordScreen({super.key, required this.email});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  bool _isLoading = false;
  bool _sent = false;
  String? _errorMessage;

  Future<void> _send() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(widget.email);
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) {
        setState(
            () => _errorMessage = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/login'),
        ),
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: _sent
              ? VerificationCodeView(
                  email: widget.email,
                  title: 'Enter your code',
                  subtitle: 'We sent a 6-digit code to',
                  verifyLabel: 'Verify code',
                  onVerify: (code) async {
                    await ref
                        .read(authRepositoryProvider)
                        .verifyRecoveryCode(email: widget.email, token: code);
                    // The session is live now; the router's
                    // passwordRecovery guard lands us on the new-password
                    // screen.
                    if (context.mounted) context.go('/reset-password');
                  },
                  onResend: () => ref
                      .read(authRepositoryProvider)
                      .sendPasswordResetEmail(widget.email),
                  onBack: () => context.go('/login'),
                  backLabel: 'Back to Login',
                )
              : _SendView(
            email: widget.email,
            isLoading: _isLoading,
            errorMessage: _errorMessage,
            onSend: _send,
            onBack: () => context.go('/login'),
          ),
        ),
      ),
    );
  }
}

class _SendView extends StatelessWidget {
  final String email;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSend;
  final VoidCallback onBack;

  const _SendView({
    required this.email,
    required this.isLoading,
    required this.errorMessage,
    required this.onSend,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.lock_reset_rounded,
              color: AppColors.primary, size: 28),
        ),
        const SizedBox(height: 20),
        Text('Forgot your password?',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'We\'ll send a 6-digit code to:',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.email_outlined,
                  color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  email,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (errorMessage != null) ...[
          _ErrorBanner(message: errorMessage!),
          const SizedBox(height: 16),
        ],
        ElevatedButton(
          onPressed: isLoading ? null : onSend,
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text('Send Reset Code'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: isLoading ? null : onBack,
          child: const Text('Back'),
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
        borderRadius: BorderRadius.circular(10),
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
