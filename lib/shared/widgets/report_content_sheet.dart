import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/supabase_client.dart';
import '../../features/auth/providers/auth_providers.dart';
import 'legal_links.dart';

/// Reporting flow for user-generated content, required by App Store
/// guideline 1.2. A report notifies the club president, who already has
/// the tools to act on it — delete the content, remove the member.
///
/// Call [showReportContentSheet] from a long-press or menu on any
/// reportable item.
Future<void> showReportContentSheet(
  BuildContext context,
  WidgetRef ref, {
  required String contentType,
  required String contentId,
  required String excerpt,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReportContentSheet(
      contentType: contentType,
      contentId: contentId,
      excerpt: excerpt,
      ref: ref,
    ),
  );
}

const _reasons = [
  'Harassment or bullying',
  'Hate speech or discrimination',
  'Sexually explicit content',
  'Violence or self-harm',
  'Spam or impersonation',
  'Something else',
];

class _ReportContentSheet extends StatefulWidget {
  final String contentType;
  final String contentId;
  final String excerpt;
  final WidgetRef ref;

  const _ReportContentSheet({
    required this.contentType,
    required this.contentId,
    required this.excerpt,
    required this.ref,
  });

  @override
  State<_ReportContentSheet> createState() => _ReportContentSheetState();
}

class _ReportContentSheetState extends State<_ReportContentSheet> {
  String? _reason;
  bool _isSending = false;
  bool _sent = false;
  String? _error;

  Future<void> _submit() async {
    final role = widget.ref.read(activeClubRoleProvider);
    final userId = supabase.auth.currentUser?.id;
    if (role == null || userId == null) return;

    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      await supabase.from(AppConstants.tableContentReports).insert({
        'club_id': role.clubId,
        'reporter_id': userId,
        'content_type': widget.contentType,
        'content_id': widget.contentId,
        // Stored so the president still knows what was reported after
        // the original is deleted.
        'content_excerpt':
            widget.excerpt.length > 300
                ? widget.excerpt.substring(0, 300)
                : widget.excerpt,
        'reason': _reason,
      });
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not send the report. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
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
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        child: _sent ? _buildSent() : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Handle(),
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.flag_outlined,
                color: AppColors.error, size: 28),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Report this content',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your club president will be notified and can remove the content '
          'or the member who posted it. Your name is not shown in the alert.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 18),
        const Text(
          "What's wrong with it?",
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        for (final r in _reasons)
          GestureDetector(
            onTap: () => setState(() => _reason = r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _reason == r
                    ? AppColors.error.withValues(alpha: 0.06)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _reason == r ? AppColors.error : AppColors.border,
                  width: _reason == r ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _reason == r
                            ? AppColors.error
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (_reason == r)
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.error, size: 20),
                ],
              ),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(_error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13)),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: (_reason == null || _isSending) ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.border,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSending
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Submit report',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: TextButton(
            onPressed: _isSending ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }

  Widget _buildSent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Handle(),
        const SizedBox(height: 28),
        Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: AppColors.success, size: 30),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Report sent',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your club president has been notified and will review it.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 20),
        // Guideline 1.2 also expects a route to the developer, not only
        // to a club officer who might be the problem.
        TextButton(
          onPressed: () => openSupportEmail(
              subject: 'ClubOS — reporting objectionable content'),
          child: const Text('Also email the ClubOS team'),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Done',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

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
