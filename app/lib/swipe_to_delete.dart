import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import 'glyph_button.dart';

/// A row that can be drawn to the left to show a delete button beside
/// it: an entry, a reminder, a category.
///
/// The row does not move. Its left edge stays where it is and its right
/// edge is drawn in, so the row grows narrower and the button stands in
/// the room that makes, never outside the row's own place.
///
/// Only a drag to the left takes hold of it, so a drag the other way
/// still reaches whatever is behind (a strip of pages, say). Let go past
/// half way and it stays open. A touch anywhere but on the button closes
/// it: on the row, beside it, anywhere on the screen. The red button
/// does the deleting; what that means is the caller's business.
class SwipeToDelete extends StatefulWidget {
  /// Names the delete button for tests: `swipe-delete-<name>`.
  final String name;
  final Widget child;
  final VoidCallback onDelete;

  const SwipeToDelete({
    super.key,
    required this.name,
    required this.child,
    required this.onDelete,
  });

  /// How far the row moves aside.
  static const reveal = 60.0;

  @override
  State<SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<SwipeToDelete>
    with SingleTickerProviderStateMixin {
  // The one row that is open, if any: opening another closes it.
  static _SwipeToDeleteState? _opened;

  late final AnimationController _slide = AnimationController(vsync: this);
  final _button = GlobalKey();
  bool _listening = false;

  bool get _isOpen => _slide.value > 0;

  @override
  void dispose() {
    if (_opened == this) _opened = null;
    _listen(false);
    _slide.dispose();
    super.dispose();
  }

  // While it is open, every touch on the screen is heard: one that is
  // not on the button closes it.
  void _listen(bool on) {
    if (on == _listening) return;
    _listening = on;
    final router = GestureBinding.instance.pointerRouter;
    on ? router.addGlobalRoute(_onTouch) : router.removeGlobalRoute(_onTouch);
  }

  void _onTouch(PointerEvent event) {
    if (event is! PointerDownEvent || !mounted) return;
    final box = _button.currentContext?.findRenderObject();
    if (box is RenderBox &&
        (box.localToGlobal(Offset.zero) & box.size).contains(event.position)) {
      return;
    }
    _settle(false);
  }

  void _settle(bool open) {
    _listen(open);
    final motion = SmTheme.of(context).motion;
    if (open) {
      if (_opened != this) _opened?._settle(false);
      _opened = this;
    } else if (_opened == this) {
      _opened = null;
    }
    _slide.animateTo(
      open ? 1 : 0,
      duration: motion.medium,
      curve: motion.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        _LeftwardDrag: GestureRecognizerFactoryWithHandlers<_LeftwardDrag>(
          () => _LeftwardDrag(isOpen: () => _isOpen),
          // With the phone's own measure of how far a finger must go
          // before it is a drag, as every other drag on the screen
          // has: without it this one waited for longer than the strip
          // of pages or the stack of cards behind it, on phones that
          // set a shorter measure, and never took hold.
          (drag) => drag
            ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context)
            ..onUpdate = (details) {
              _slide.value -= details.primaryDelta! / SwipeToDelete.reveal;
            }
            ..onEnd = (details) {
              final speed = details.primaryVelocity ?? 0;
              _settle(speed.abs() > 300 ? speed < 0 : _slide.value > 0.5);
            }
            ..onCancel = () => _settle(_slide.value > 0.5),
        ),
      },
      child: AnimatedBuilder(
        animation: _slide,
        builder: (context, child) => Stack(
          children: [
            // Behind the row, at its right: only there once the row has
            // begun to move.
            if (_slide.value > 0)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Opacity(
                    opacity: _slide.value.clamp(0, 1),
                    child: KeyedSubtree(
                      key: _button,
                      child: GlyphButton(
                        key: ValueKey('swipe-delete-${widget.name}'),
                        glyph: Glyph.delete,
                        square: true,
                        tint: DeleteCardButton.red,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          _settle(false);
                          widget.onDelete();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            // The row itself, its right edge drawn in to make room.
            Padding(
              padding: EdgeInsets.only(
                right: SwipeToDelete.reveal * _slide.value.clamp(0, 1),
              ),
              // Open, a tap on the row only closes it.
              child: _slide.value > 0
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _settle(false),
                      child: IgnorePointer(child: child),
                    )
                  : child,
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

/// A sideways drag that only takes hold when it goes left, or when the
/// row is already open and is being put back.
class _LeftwardDrag extends HorizontalDragGestureRecognizer {
  final bool Function() isOpen;

  _LeftwardDrag({required this.isOpen});

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    final slop = computeHitSlop(pointerDeviceKind, gestureSettings);
    return isOpen()
        ? globalDistanceMoved.abs() > slop
        : globalDistanceMoved < -slop;
  }
}
