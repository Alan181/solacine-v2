import 'package:flutter/widgets.dart';

/// An [InheritedWidget] providing the active branch index of a [StatefulShellRoute].
/// This allows tabs like Reels to immediately detect when they are no longer the active
/// tab and pause/dispose background playback instantly.
class ActiveShellBranchScope extends InheritedWidget {
  const ActiveShellBranchScope({
    super.key,
    required this.currentIndex,
    required super.child,
  });

  final int currentIndex;

  static int of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ActiveShellBranchScope>()?.currentIndex ?? -1;
  }

  static int? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ActiveShellBranchScope>()?.currentIndex;
  }

  @override
  bool updateShouldNotify(ActiveShellBranchScope oldWidget) {
    return currentIndex != oldWidget.currentIndex;
  }
}
