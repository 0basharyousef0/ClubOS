import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';

/// Shared 6-digit code panel for the email verification flows (signup
/// confirmation, password recovery, email change).
///
/// Every auth email template renders `{{ .Token }}` rather than a link,
/// so the app never has to host a callback page or handle a deep link —
/// the user just types the code they were sent.
class VerificationCodeView extends StatefulWidget {
  final String email;
  final String title;

  /// Shown under the title; the email is appended automatically.
  final String subtitle;

  /// Throws to surface an error; returning normally means verified.
  final Future<void> Function(String code) onVerify;

  /// Omit to hide the resend button.
  final Future<void> Function()? onResend;

  final String verifyLabel;
  final VoidCallback? onBack;
  final String backLabel;

  const VerificationCodeView({
    super.key,
    required this.email,
    required this.title,
    required this.subtitle,
    required this.onVerify,
    this.onResend,
    this.verifyLabel = 'Verify',
    this.onBack,
    this.backLabel = 'Back',
  });

  @override
  State<VerificationCodeView> createState() => _VerificationCodeViewState();
}

class _VerificationCodeViewState extends State<VerificationCodeView> {
  final _controller = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  String? _error;

  /// Supabase rate-limits auth emails; a cooldown keeps users from
  /// burning through the allowance and locking themselves out.
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {});
      // Six digits in — verify without making them hunt for the button.
      if (_controller.text.trim().length == 6 && !_isVerifying) {
        _verify();
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 45);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendCooldown--);
      if (_resendCooldown <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    final code = _controller.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() {
      _isVerifying = true;
      _error = null;
    });
    try {
      await widget.onVerify(code);
    } catch (e) {
      if (mounted) {
        setState(() => _error = _friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    final onResend = widget.onResend;
    if (onResend == null) return;
    setState(() {
      _isResending = true;
      _error = null;
    });
    try {
      await onResend();
      _startCooldown();
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  /// Supabase's raw messages ("Token has expired or is invalid") are
  /// accurate but blunt; soften the ones users actually hit.
  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('expired') || msg.contains('invalid')) {
      return 'That code is incorrect or has expired. Request a new one.';
    }
    if (msg.contains('rate') || msg.contains('too many')) {
      return 'Too many attempts. Wait a minute and try again.';
    }
    return 'Could not verify the code. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final canVerify = _controller.text.trim().length == 6 && !_isVerifying;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.mark_email_read_rounded,
              color: AppColors.primary, size: 28),
        ),
        const SizedBox(height: 20),
        Text(widget.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          '${widget.subtitle}\n${widget.email}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          maxLength: 6,
          enabled: !_isVerifying,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          // iOS surfaces the code from the email as a keyboard suggestion.
          autofillHints: const [AutofillHints.oneTimeCode],
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 12,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 12,
              color: AppColors.textSecondary.withValues(alpha: 0.35),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
                    color: AppColors.error, size: 18),
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
            onPressed: canVerify ? _verify : null,
            child: _isVerifying
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : Text(widget.verifyLabel),
          ),
        ),
        if (widget.onResend != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed:
                (_isResending || _resendCooldown > 0 || _isVerifying)
                    ? null
                    : _resend,
            child: Text(
              _isResending
                  ? 'Sending…'
                  : _resendCooldown > 0
                      ? 'Resend code in ${_resendCooldown}s'
                      : 'Resend code',
            ),
          ),
        ],
        if (widget.onBack != null) ...[
          const SizedBox(height: 4),
          TextButton(onPressed: widget.onBack, child: Text(widget.backLabel)),
        ],
      ],
    );
  }
}
