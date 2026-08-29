import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';

/// Opens a URL outside the app. Returns false if it could not be opened,
/// so callers can surface a fallback rather than appearing to do nothing.
Future<bool> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Opens the device mail client with the support address pre-filled.
Future<bool> openSupportEmail({String subject = 'ClubOS support'}) {
  return openExternalUrl(
    'mailto:${AppConstants.supportEmail}'
    '?subject=${Uri.encodeComponent(subject)}',
  );
}

/// The "by creating an account you agree to…" line shown under the signup
/// button. App Store guideline 1.2 expects an app carrying user-generated
/// content to put its content rules in front of people before they join.
///
/// Stateful because the tap recognizers behind the two links have to be
/// disposed with the widget.
class LegalConsentLine extends StatefulWidget {
  const LegalConsentLine({super.key});

  @override
  State<LegalConsentLine> createState() => _LegalConsentLineState();
}

class _LegalConsentLineState extends State<LegalConsentLine> {
  late final TapGestureRecognizer _terms;
  late final TapGestureRecognizer _privacy;

  @override
  void initState() {
    super.initState();
    _terms = TapGestureRecognizer()
      ..onTap = () => openExternalUrl(AppConstants.urlTermsOfService);
    _privacy = TapGestureRecognizer()
      ..onTap = () => openExternalUrl(AppConstants.urlPrivacyPolicy);
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
      fontSize: 12,
      height: 1.4,
      color: AppColors.textSecondary,
    );
    final link = base.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.primary,
    );

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'By creating an account you agree to our '),
          TextSpan(
            text: 'Terms of Service',
            style: link,
            recognizer: _terms,
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: link,
            recognizer: _privacy,
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
