import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import 'scroll_bars.dart';

/// One dot of a [DotPicker].
typedef PickerDot = ({String id, Color color});

/// A row of small coloured dots, one per thing to choose from, with the
/// chosen one ringed. Tapping a dot chooses it.
///
/// The row is never wider than twelve dots; with more, it scrolls sideways.
/// A dot is small, but the area that takes the tap is a comfortable size.
class DotPicker extends StatefulWidget {
  final List<PickerDot> dots;
  final String? selected;
  final ValueChanged<String> onPick;

  /// Dots drawn as empty rings: there to be chosen, but with nothing
  /// behind them yet.
  final Set<String> hollow;

  /// Drawn in a capsule as wide as it is given, its outline plain to
  /// see: the dots centred in it while they fit, scrolled sideways inside
  /// it when they do not, the scroll's bar kept within the outline (the
  /// journal's and the reminders' panels, owner, 20 October 2026). As
  /// tall as a bar button.
  final bool capsule;

  const DotPicker({
    super.key,
    required this.dots,
    required this.selected,
    required this.onPick,
    this.hollow = const {},
    this.capsule = false,
  });

  /// A capsule's height: a bar button's.
  static const capsuleHeight = 40.0;

  /// Dots shown before the row starts to scroll.
  static const limit = 12;

  /// The width one dot takes, including the space that catches the tap.
  static const slot = 22.0;
  static const height = 36.0;

  @override
  State<DotPicker> createState() => _DotPickerState();
}

class _DotPickerState extends State<DotPicker> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(DotPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) _reveal();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // Brings the chosen dot into view when it was chosen some other way.
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final index = widget.dots.indexWhere((d) => d.id == widget.selected);
      if (index < 0) return;
      final start = index * DotPicker.slot;
      final position = _scroll.position;
      if (start < position.pixels ||
          start + DotPicker.slot >
              position.pixels + position.viewportDimension) {
        _scroll.animateTo(
          (start - position.viewportDimension / 2 + DotPicker.slot / 2).clamp(
            0.0,
            position.maxScrollExtent,
          ),
          duration: SmTheme.of(context).motion.medium,
          curve: SmTheme.of(context).motion.curve,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [for (final dot in widget.dots) _dot(theme, dot)],
    );
    if (widget.capsule) {
      const height = DotPicker.capsuleHeight;
      const end = height / 2;
      return Container(
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: theme.colors.textFaint),
          borderRadius: BorderRadius.circular(end),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(end),
          child: LayoutBuilder(
            builder: (context, room) => ScrollHintStyle(
              // Along the foot, clear of the rounded ends and the line.
              inset: const EdgeInsets.fromLTRB(end, 0, end, 2),
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: end / 2),
                child: ConstrainedBox(
                  // Centred while they fit.
                  constraints: BoxConstraints(minWidth: room.maxWidth - end),
                  child: Center(child: row),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: DotPicker.limit * DotPicker.slot,
      ),
      child: SizedBox(
        height: DotPicker.height,
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          child: row,
        ),
      ),
    );
  }

  Widget _dot(SmThemeData theme, PickerDot dot) => GestureDetector(
    key: ValueKey('pick-${dot.id}'),
    behavior: HitTestBehavior.opaque,
    onTap: () {
      if (dot.id == widget.selected) return;
      HapticFeedback.selectionClick();
      widget.onPick(dot.id);
    },
    child: SizedBox(
      width: DotPicker.slot,
      height: DotPicker.height,
      child: Center(
        child: AnimatedContainer(
          duration: theme.motion.medium,
          curve: theme.motion.curve,
          width: dot.id == widget.selected ? 14 : 8,
          height: dot.id == widget.selected ? 14 : 8,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // The chosen dot wears a ring of its own colour.
            border: dot.id == widget.selected
                ? Border.all(color: dot.color, width: 1.2)
                : null,
            color: dot.id == widget.selected || widget.hollow.contains(dot.id)
                ? null
                : dot.color.withValues(alpha: 0.75),
          ),
          foregroundDecoration:
              dot.id != widget.selected && widget.hollow.contains(dot.id)
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: dot.color.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                )
              : null,
          child: dot.id == widget.selected
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    // The chosen one's heart is empty too
                    // while there is nothing behind it.
                    color: widget.hollow.contains(dot.id)
                        ? dot.color.withValues(alpha: 0)
                        : dot.color,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
        ),
      ),
    ),
  );
}
