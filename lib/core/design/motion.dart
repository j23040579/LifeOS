import 'package:flutter/material.dart';

Duration motionDuration(BuildContext context, {int milliseconds = 260}) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

/// One transition per destination. Data updates retain state and keyboard focus.
class DestinationMotion extends StatelessWidget {
  const DestinationMotion({
    super.key,
    required this.destination,
    required this.child,
  });
  final int destination;
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: motionDuration(context),
    reverseDuration: motionDuration(context, milliseconds: 160),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .025),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: KeyedSubtree(key: ValueKey(destination), child: child),
  );
}
