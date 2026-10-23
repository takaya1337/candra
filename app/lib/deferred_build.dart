import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Shows [child] straight away when [eager]; otherwise leaves an empty box
/// and puts [child] in once nothing is moving: no animation is running and
/// [busy], if given, reads false.
///
/// For content that is expensive to lay out and not yet on screen, so the
/// cost never lands in the middle of a scroll.
class DeferredBuild extends StatefulWidget {
  final bool eager;

  /// True while something is in motion that this should wait out, such as
  /// a scroll position's `isScrollingNotifier`.
  final ValueListenable<bool>? busy;

  final Widget child;

  const DeferredBuild({
    super.key,
    required this.eager,
    required this.child,
    this.busy,
  });

  @override
  State<DeferredBuild> createState() => _DeferredBuildState();
}

class _DeferredBuildState extends State<DeferredBuild> {
  late bool _ready = widget.eager;

  @override
  void initState() {
    super.initState();
    if (!_ready) {
      widget.busy?.addListener(_checkAfterFrame);
      _checkAfterFrame();
    }
  }

  @override
  void didUpdateWidget(DeferredBuild oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy) {
      oldWidget.busy?.removeListener(_checkAfterFrame);
      if (!_ready) widget.busy?.addListener(_checkAfterFrame);
    }
    if (widget.eager && !_ready) {
      _ready = true;
      widget.busy?.removeListener(_checkAfterFrame);
    }
  }

  @override
  void dispose() {
    widget.busy?.removeListener(_checkAfterFrame);
    super.dispose();
  }

  // Looks again once the current frame (if any) is done. While something
  // is animating, frames keep coming, so this polls once per frame without
  // spinning; once [busy] clears, its listener calls back in.
  void _checkAfterFrame() {
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.idle) {
      _check();
    } else {
      scheduler.addPostFrameCallback((_) => _check());
    }
  }

  void _check() {
    if (!mounted || _ready) return;
    if (widget.busy?.value ?? false) return;
    if (SchedulerBinding.instance.transientCallbackCount > 0) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _check());
      return;
    }
    widget.busy?.removeListener(_checkAfterFrame);
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) =>
      _ready ? widget.child : const SizedBox.expand();
}
