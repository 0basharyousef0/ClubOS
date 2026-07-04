import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';

/// Small tap target that copies [text] to the clipboard and confirms
/// with a snackbar.
class CopyIconButton extends StatelessWidget {
  final String text;
  final double size;

  const CopyIconButton({super.key, required this.text, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Copied $text'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(milliseconds: 1400),
            ),
          );
      },
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(
          Icons.copy_rounded,
          size: size,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
