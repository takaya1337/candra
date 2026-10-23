import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Starts the keyboard's height down the moment the keyboard is sent away.
///
/// While the keyboard slides, the system reports its height every frame,
/// and a layout that follows those reports keeps pace with it or runs a
/// frame or two ahead. Rising, that is what is wanted. Leaving, the first
/// report comes some thirty milliseconds after the focus has left the
/// text, and for that long everything would sit still above a keyboard
/// already told to go.
///
/// So this replaces the height in [MediaQuery]: it follows the reports,
/// except that when the focus leaves the text it starts down at once. The
/// keyboard then uncovers a layout that is already out of its way.
///
/// Once the reports have been still for a moment the last one is taken as
/// it is, in case the keyboard stayed after all.
class KeyboardLift extends StatefulWidget {
  final Widget child;

  const KeyboardLift({super.key, required this.child});

  @override
  State<KeyboardLift> createState() => _KeyboardLiftState();
}

class _KeyboardLiftState extends State<KeyboardLift>
    with TickerProviderStateMixin {
  static const _still = Duration(milliseconds: 150);

  // The keyboard takes about this long to go once it has started.
  static const _fall = Duration(milliseconds: 150);

  // Runs from 1 to 0 as the height drops ahead of a leaving keyboard.
  late final _leave = AnimationController(
    vsync: this,
    duration: _fall,
    value: 0,
  )..addListener(() => setState(() {}));

  // Runs out when the reported height has stopped changing.
  late final _quiet = AnimationController(vsync: this)
    ..addStatusListener(_onQuiet);

  // The height as last reported, and the height handed down unless the
  // keyboard is leaving.
  double? _raw;
  double _ahead = 0;

  // While leaving: the height it started down from.
  bool _leaving = false;
  double _leftFrom = 0;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final raw = MediaQuery.viewInsetsOf(context).bottom;
    if (_raw == null) {
      _raw = raw;
      _ahead = raw;
    } else if (raw != _raw) {
      final step = raw - _raw!;
      _ahead = raw;
      _raw = raw;
      if (step > 0) _stopLeaving();
      _quiet
        ..duration = _still
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocus);
    _leave.dispose();
    _quiet.dispose();
    super.dispose();
  }

  double get _inset => _leaving
      ? math.min(_ahead, _leftFrom * Curves.easeIn.transform(_leave.value))
      : _ahead;

  void _onFocus() {
    final focused = FocusManager.instance.primaryFocus?.context;
    final typing =
        focused != null &&
        focused.findAncestorWidgetOfExactType<EditableText>() != null;
    if (typing || _leaving || _ahead == 0) return;
    _leftFrom = _ahead;
    _leaving = true;
    _leave.reverse(from: 1);
    // In case the keyboard stays after all.
    _quiet
      ..duration = _still * 5
      ..forward(from: 0);
    setState(() {});
  }

  void _stopLeaving() {
    _leaving = false;
    _leave.stop();
  }

  void _onQuiet(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final raw = _raw!;
    setState(() {
      _stopLeaving();
      _ahead = raw;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    final inset = math.max(0.0, _inset);

    return MediaQuery(
      data: data.copyWith(
        viewInsets: data.viewInsets.copyWith(bottom: inset),
        // What the keyboard does not cover of the system's bottom edge.
        padding: data.padding.copyWith(
          bottom: math.max(0.0, data.viewPadding.bottom - inset),
        ),
      ),
      child: widget.child,
    );
  }
}
