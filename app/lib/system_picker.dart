import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import 'calendar_system.dart';
import 'inertial_snap.dart';
import 'parts.dart';
import 'strings.dart';
import 'system_glyph.dart';
import 'system_palettes.dart';

/// A strip of system cards, one per calendar system, scrolled sideways.
/// Each card is painted in its own system's palette and shows [date] as
/// that system reads it.
///
/// The card at the centre is the chosen one. The strip opens with the
/// active system there, always comes to rest with a card there, and
/// whichever card that is becomes the active system. Tapping a card brings
/// it to the centre.
///
/// Where the lower panel is tall (a tablet on its side) the cards run
/// down it instead, each as wide as the column and short, and the card
/// at the middle of the panel is the chosen one.
class SystemPicker extends StatefulWidget {
  final CivilDate date;
  final CalendarSystem active;
  final CalendarSystem? locked;

  /// Called with the card at the centre once the strip has come to rest.
  final ValueChanged<CalendarSystem> onPick;

  /// Passed in so a strip fading out keeps its own wording.
  final Strings strings;

  const SystemPicker({
    super.key,
    required this.strings,
    required this.date,
    required this.active,
    required this.locked,
    required this.onPick,
  });

  @override
  State<SystemPicker> createState() => _SystemPickerState();
}

class _SystemPickerState extends State<SystemPicker> {
  static const _cardWidth = 176.0;

  // Down a tall panel: short enough for five or so to be seen at once.
  static const _cardHeight = 76.0;

  ScrollController? _scroll;

  // Whether the strip runs down, as the controller was made for, and the
  // room each card takes along the strip.
  bool? _tall;
  double _slot = 0;

  // Where and when a touch fell on the strip while it moved.
  (Offset, Duration)? _down;

  // Whether the strip is gliding. The touch that stops a glide ends it
  // before the strip hears of the touch, so the end is taken only once
  // that touch has been handled.
  bool _moving = false;

  // The card nearest the centre, for the tick felt as one passes.
  late int _nearest = widget.active.index;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  void _onScroll() {
    final nearest = _cardAt(_scroll!.offset, _slot);
    if (nearest == _nearest) return;
    _nearest = nearest;
    HapticFeedback.selectionClick();
  }

  static int _cardAt(double offset, double slot) =>
      (offset / slot).round().clamp(0, CalendarSystem.values.length - 1);

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final tall = FourParts.tallPanel(context);
    final slot = (tall ? _cardHeight : _cardWidth) + 2 * spacing.xs;
    _slot = slot;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Created on first layout, already centred on the active card, so
        // the strip never appears at one offset and jumps to another.
        // Made again, on the same card, if the tablet is turned and the
        // strip changes direction.
        if (_tall != tall) {
          final old = _scroll;
          if (old != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
          }
          _tall = tall;
          _scroll = ScrollController(
            initialScrollOffset:
                (old == null ? widget.active.index : _nearest) * slot,
          )..addListener(_onScroll);
        }
        final scroll = _scroll!;

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification) _moving = true;
            if (notification is ScrollEndNotification) {
              scheduleMicrotask(() => _moving = false);
            }
            final offset = notification.metrics.pixels;
            final card = _cardAt(offset, slot);
            // Chosen once it is at the centre and all but still. Waiting
            // for the very end of the glide would be waiting on movement
            // too small to see.
            final arrived =
                notification is ScrollEndNotification ||
                (notification is ScrollUpdateNotification &&
                    notification.dragDetails == null &&
                    (notification.scrollDelta ?? 1).abs() < 0.5 &&
                    (offset - card * slot).abs() < 0.5);
            if (arrived) widget.onPick(CalendarSystem.values[card]);
            return false;
          },
          // While the strip glides, a scroll view lets nothing in it be
          // touched, and its own drag takes the touch: a tap on a card
          // would only stop the glide. So the strip watches the touch
          // itself, beneath any gesture: one that falls while it moves
          // and lifts where it fell picks the card under it. When it is
          // still, the card's own tap does that.
          child: Listener(
            onPointerDown: (event) {
              _down = _moving ? (event.localPosition, event.timeStamp) : null;
            },
            onPointerUp: (event) {
              final down = _down;
              _down = null;
              if (down == null) return;
              final (fell, began) = down;
              if ((event.localPosition - fell).distance > kTouchSlop ||
                  event.timeStamp - began > kLongPressTimeout) {
                return;
              }
              final extent = tall
                  ? constraints.maxHeight
                  : constraints.maxWidth;
              final along = tall
                  ? event.localPosition.dy
                  : event.localPosition.dx;
              final before = math.max(0.0, (extent - slot) / 2);
              final at = ((along + scroll.offset - before) / slot).floor();
              if (at < 0 || at >= CalendarSystem.values.length) return;
              // After the touch is done with: lifting the finger hands
              // the strip back to its own settling, which would otherwise
              // take over from this.
              scheduleMicrotask(
                () => scroll.animateTo(
                  at * slot,
                  duration: theme.motion.medium,
                  curve: theme.motion.curve,
                ),
              );
            },
            child: SingleChildScrollView(
              key: ValueKey(tall),
              controller: scroll,
              scrollDirection: tall ? Axis.vertical : Axis.horizontal,
              physics: InertialSnapPhysics((_) => slot),
              // Enough room either side for the first and last cards to
              // reach the centre.
              padding: tall
                  ? EdgeInsets.symmetric(
                      horizontal: spacing.md,
                      vertical: math.max(0, (constraints.maxHeight - slot) / 2),
                    )
                  : EdgeInsets.symmetric(
                      horizontal: math.max(
                        0,
                        (constraints.maxWidth - slot) / 2,
                      ),
                      vertical: spacing.md,
                    ),
              child: Flex(
                direction: tall ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final system in CalendarSystem.values)
                    Padding(
                      padding: tall
                          ? EdgeInsets.symmetric(vertical: spacing.xs)
                          : EdgeInsets.symmetric(horizontal: spacing.xs),
                      child: GestureDetector(
                        key: ValueKey('card-${system.name}'),
                        onTap: () => scroll.animateTo(
                          system.index * slot,
                          duration: theme.motion.medium,
                          curve: theme.motion.curve,
                        ),
                        // How far a card is from the centre decides how it
                        // looks, so the strip changes as it moves, not
                        // after.
                        child: AnimatedBuilder(
                          animation: scroll,
                          builder: (context, card) {
                            final offset = scroll.hasClients
                                ? scroll.offset
                                : widget.active.index * slot;
                            final away = math.min(
                              1.0,
                              (offset / slot - system.index).abs(),
                            );
                            return Transform.scale(
                              scale: 1 - 0.08 * away,
                              child: Opacity(
                                opacity: 1 - 0.28 * away,
                                child: DecoratedBox(
                                  position: DecorationPosition.foreground,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: system.shown.accent.withValues(
                                        alpha: 1 - away,
                                      ),
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      theme.radii.md,
                                    ),
                                  ),
                                  child: card,
                                ),
                              ),
                            );
                          },
                          child: _SystemCard(
                            system: system,
                            strings: widget.strings,
                            width: tall ? null : _cardWidth,
                            height: tall ? _cardHeight : null,
                            date: widget.date,
                            isLocked: system == widget.locked,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SystemCard extends StatelessWidget {
  final CalendarSystem system;
  final Strings strings;

  /// Along a sideways strip the card's width; down a tall panel, its
  /// height, and it is laid out across.
  final double? width;
  final double? height;
  final CivilDate date;
  final bool isLocked;

  /// How large the glyph is drawn when the card has the room.
  static const glyphSize = 56.0;

  const _SystemCard({
    required this.system,
    required this.strings,
    required this.width,
    required this.height,
    required this.date,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    // The card's own palette, whatever system the rest of the app is in.
    final colors = system.shown;

    final across = height != null;

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(theme.spacing.md - theme.spacing.xs),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(theme.radii.md),
      ),
      // The glyph first and largest, at the centre: it is what the card
      // is known by, before a word of it is read.
      child: Stack(
        children: [
          Positioned.fill(
            child: across
                ? _across(theme, colors)
                : Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SystemGlyph(
                              system: system,
                              size: glyphSize,
                              color: colors.accent,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: theme.spacing.xs),
                      Text(
                        strings.systemLabel(system).toUpperCase(),
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: theme.type.caption.copyWith(
                          color: colors.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: theme.spacing.xs / 2),
                      // Always two lines tall, so the glyph stands in the same
                      // place on every card whether the date needs one or two.
                      Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          Text(
                            '\n',
                            maxLines: 2,
                            style: theme.type.label.copyWith(letterSpacing: 0),
                          ),
                          Text(
                            strings.dayText(system, date) ?? '–',
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: theme.type.label.copyWith(
                              color: colors.textPrimary,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          if (isLocked)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Laid across, for a tall panel: the glyph at the left, then the
  /// system's name over the date as it reads it.
  Widget _across(SmThemeData theme, SmColors colors) => Row(
    children: [
      SizedBox(
        width: 52,
        child: Center(
          child: SystemGlyph(system: system, size: 40, color: colors.accent),
        ),
      ),
      SizedBox(width: theme.spacing.sm),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.systemLabel(system).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: theme.type.caption.copyWith(
                color: colors.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: theme.spacing.xs / 2),
            Text(
              strings.dayText(system, date) ?? '–',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.type.label.copyWith(
                color: colors.textPrimary,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
