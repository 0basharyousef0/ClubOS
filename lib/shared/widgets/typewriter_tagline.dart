import 'dart:async';

import 'package:flutter/material.dart';

/// Tagline that types out [word] after a static [prefix] with a blinking
/// caret, e.g. "Club management, simpl▍".
///
/// The untyped remainder is laid out transparently and the caret always
/// reserves its slot, so the line never shifts or re-centers mid-animation.
class TypewriterTagline extends StatefulWidget {
  final String prefix;
  final String word;
  final TextStyle style;

  const TypewriterTagline({
    super.key,
    required this.prefix,
    required this.word,
    required this.style,
  });

  @override
  State<TypewriterTagline> createState() => _TypewriterTaglineState();
}

class _TypewriterTaglineState extends State<TypewriterTagline>
    with SingleTickerProviderStateMixin {
  static const _startDelay = Duration(milliseconds: 450);
  static const _charInterval = Duration(milliseconds: 140);
  static const _blinkInterval = Duration(milliseconds: 380);
  static const _caretLinger = Duration(milliseconds: 3000);
  static const _glowHalf = Duration(milliseconds: 250);

  int _typed = 0;
  bool _caretOn = true;
  bool _caretGone = false;
  Timer? _startTimer;
  Timer? _typeTimer;
  Timer? _blinkTimer;
  Timer? _lingerTimer;
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(vsync: this, duration: _glowHalf)
      ..addListener(() => setState(() {}));
    _blinkTimer = Timer.periodic(_blinkInterval, (_) {
      if (!_caretGone) setState(() => _caretOn = !_caretOn);
    });
    _startTimer = Timer(_startDelay, () {
      _typeTimer = Timer.periodic(_charInterval, (t) {
        setState(() => _typed++);
        if (_typed >= widget.word.length) {
          t.cancel();
          // Flash the finished word: glow up, then back down.
          _glow.forward().then((_) => _glow.reverse());
          _lingerTimer = Timer(_caretLinger, () {
            setState(() => _caretGone = true);
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _typeTimer?.cancel();
    _blinkTimer?.cancel();
    _lingerTimer?.cancel();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typed = widget.word.substring(0, _typed);
    final rest = widget.word.substring(_typed);
    final showCaret = !_caretGone && _caretOn;
    final caretColor =
        showCaret ? (widget.style.color ?? Colors.white) : Colors.transparent;

    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: widget.prefix),
          TextSpan(
            text: typed,
            style: TextStyle(
              color: Color.lerp(
                  widget.style.color ?? Colors.white, Colors.white, _glow.value),
              shadows: _glow.value == 0
                  ? null
                  : [
                      Shadow(
                        color: Colors.white
                            .withValues(alpha: 0.85 * _glow.value),
                        blurRadius: 14 * _glow.value,
                      ),
                    ],
            ),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              width: 1.5,
              height: (widget.style.fontSize ?? 14) * 1.05,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              color: caretColor,
            ),
          ),
          TextSpan(
            text: rest,
            style: const TextStyle(color: Colors.transparent),
          ),
        ],
      ),
    );
  }
}
