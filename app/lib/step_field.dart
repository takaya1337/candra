import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

/// A value with a step down and a step up either side of it.
///
/// If [hold] is set, keeping a finger on a step goes on stepping, and
/// faster the longer it is held: ten steps at a time after a second, a
/// hundred after three.
class StepField extends StatelessWidget {
  final String name;
  final String label;
  final String value;
  final ValueChanged<int> onStep;
  final bool hold;

  const StepField({
    super.key,
    required this.name,
    required this.label,
    required this.value,
    required this.onStep,
    this.hold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          style: theme.type.caption.copyWith(
            color: colors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Step(name: name, up: false, hold: hold, onStep: onStep),
            Flexible(
              child: Text(
                value,
                key: ValueKey('$name-value'),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: theme.type.body.copyWith(color: colors.textPrimary),
              ),
            ),
            _Step(name: name, up: true, hold: hold, onStep: onStep),
          ],
        ),
      ],
    );
  }
}

class _Step extends StatefulWidget {
  final String name;
  final bool up;
  final bool hold;
  final ValueChanged<int> onStep;

  const _Step({
    required this.name,
    required this.up,
    required this.hold,
    required this.onStep,
  });

  @override
  State<_Step> createState() => _StepState();
}

class _StepState extends State<_Step> {
  Timer? _repeat;
  int _ticks = 0;

  int get _sign => widget.up ? 1 : -1;

  void _start() {
    _ticks = 0;
    _repeat?.cancel();
    _repeat = Timer.periodic(const Duration(milliseconds: 90), (_) {
      _ticks++;
      final size = _ticks > 33 ? 100 : (_ticks > 11 ? 10 : 1);
      if (_ticks % 4 == 0) HapticFeedback.selectionClick();
      widget.onStep(_sign * size);
    });
  }

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    return GestureDetector(
      key: ValueKey('${widget.name}-${widget.up ? 'up' : 'down'}'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onStep(_sign);
      },
      onLongPressStart: widget.hold ? (_) => _start() : null,
      onLongPressEnd: widget.hold ? (_) => _stop() : null,
      onLongPressCancel: widget.hold ? _stop : null,
      child: SizedBox(
        width: 24,
        height: 40,
        child: Center(
          child: Text(
            widget.up ? '+' : '−',
            style: theme.type.title.copyWith(color: theme.colors.accent),
          ),
        ),
      ),
    );
  }
}
