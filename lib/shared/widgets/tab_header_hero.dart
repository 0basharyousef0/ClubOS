import 'package:flutter/material.dart';

/// Shared hero tag for the purple gradient header at the top of every primary
/// tab. Because each tab paints the same gradient, flying this header between
/// tabs keeps the purple chrome anchored in place while the title and content
/// cross-fade — i.e. a shared-element / hero transition rather than the whole
/// page sliding.
const String kTabHeaderHeroTag = 'tab-header';

/// Wraps a tab screen's gradient header so it takes part in the shared-element
/// transition. Drop this around the header that each tab adds to its scroll
/// view; on a tab switch the header animates from its old rect to its new one.
class TabHeaderHero extends StatelessWidget {
  const TabHeaderHero({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: kTabHeaderHeroTag,
      flightShuttleBuilder: _flightShuttleBuilder,
      child: child,
    );
  }
}

/// Cross-fades the outgoing header over the incoming one. The destination
/// header is the fully-opaque base, so the (identical) purple gradient never
/// dips in opacity and reads as staying perfectly still — only the title and
/// badge dissolve from the old tab to the new one.
Widget _flightShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final Widget fromHeader = (fromHeroContext.widget as Hero).child;
  final Widget toHeader = (toHeroContext.widget as Hero).child;

  return Material(
    type: MaterialType.transparency,
    child: Stack(
      fit: StackFit.expand,
      children: [
        _ShuttleLayer(
          opacity: const AlwaysStoppedAnimation<double>(1),
          child: toHeader,
        ),
        _ShuttleLayer(
          opacity: Tween<double>(begin: 1, end: 0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          ),
          child: fromHeader,
        ),
      ],
    ),
  );
}

class _ShuttleLayer extends StatelessWidget {
  const _ShuttleLayer({required this.opacity, required this.child});

  final Animation<double> opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Let the header keep its natural height while the hero rect resizes
    // between tabs (the dashboard header is taller than the rest), so a resize
    // never trips a layout overflow mid-flight.
    return FadeTransition(
      opacity: opacity,
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minHeight: 0,
        maxHeight: double.infinity,
        child: child,
      ),
    );
  }
}
