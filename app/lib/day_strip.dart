import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import 'inertial_snap.dart';
import 'parts.dart';
import 'strings.dart';

/// The day strip: the days in a row, one page each and numbered by the
/// day itself, five in view, swiped to the day before or after. The day
/// at the centre is the chosen one.
///
/// [controller] must be a [stripAt] controller.
class DayStrip extends StatelessWidget {
  final PageController controller;
  final Strings strings;

  /// The colours of the dots under a day, at most four.
  final List<Color> Function(CivilDate date) dotsOf;

  /// Whether the dots are drawn as rings: things to come, not things
  /// written.
  final bool rings;

  /// Called once the strip has come to rest on a day, and all but still:
  /// not on every day that goes by.
  final ValueChanged<CivilDate> onArrived;

  const DayStrip({
    super.key,
    required this.controller,
    required this.strings,
    required this.dotsOf,
    required this.onArrived,
    this.rings = false,
  });

  /// A controller for a strip that starts on [date].
  static PageController stripAt(CivilDate date) =>
      PageController(viewportFraction: 1 / 5, initialPage: date.dayNumber);

  @override
  Widget build(BuildContext context) {
    final motion = SmTheme.of(context).motion;
    final tall = FourParts.tallPanel(context);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final page = controller.page;
        if (page == null) return false;
        final arrived =
            notification is ScrollEndNotification ||
            (notification is ScrollUpdateNotification &&
                notification.dragDetails == null &&
                (notification.scrollDelta ?? 1).abs() < 0.5 &&
                (page - page.round()).abs() < 0.01);
        if (arrived) onArrived(CivilDate.fromDayNumber(page.round()));
        return false;
      },
      child: PageView.builder(
        key: const ValueKey('day-strip'),
        controller: controller,
        scrollDirection: tall ? Axis.vertical : Axis.horizontal,
        // A flick carries the strip on over several days, and it always
        // comes to rest with one at the centre.
        pageSnapping: false,
        physics: InertialSnapPhysics(
          (position) => position.viewportDimension / 5,
        ),
        onPageChanged: (_) => HapticFeedback.selectionClick(),
        itemBuilder: (context, day) => _DayChip(
          date: CivilDate.fromDayNumber(day),
          strip: controller,
          strings: strings,
          dots: dotsOf(CivilDate.fromDayNumber(day)),
          rings: rings,
          across: tall,
          onTap: () => controller.animateToPage(
            day,
            duration: motion.transition,
            curve: motion.transitionCurve,
          ),
        ),
      ),
    );
  }
}

/// One day on the day strip: its weekday, its number, its pasaran, and a
/// dot for each category written in that day. The day at the centre stands
/// out, and the others fall back the further off they are, as the strip
/// moves.
class _DayChip extends StatelessWidget {
  final CivilDate date;
  final PageController strip;
  final Strings strings;
  final List<Color> dots;
  final bool rings;

  /// Whether the chip is laid out across, in one line, for a strip that
  /// runs down a tall panel.
  final bool across;
  final VoidCallback onTap;

  const _DayChip({
    required this.date,
    required this.strip,
    required this.strings,
    required this.dots,
    required this.rings,
    required this.across,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final weton = Weton.of(date);

    // Across, down a tall panel, everything on the chip at twice its
    // size: the slot is several times the line's height there.
    final scale = across ? 2.0 : 1.0;
    final caption = theme.type.caption.copyWith(
      fontSize: theme.type.caption.fontSize! * scale,
    );
    final weekday = Text(
      strings.weekdayName(weton.weekday).substring(0, 3).toUpperCase(),
      style: caption.copyWith(
        color: colors.textSecondary,
        letterSpacing: 1.2 * scale,
      ),
    );
    final number = Text(
      '${date.day}',
      style: theme.type.title.copyWith(
        color: colors.textPrimary,
        fontSize: theme.type.title.fontSize! * scale,
      ),
    );
    final pasaran = Text(
      weton.pasaran.label,
      style: caption.copyWith(color: colors.textSecondary),
    );
    final marks = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final color in dots)
          Container(
            width: 4 * scale,
            height: 4 * scale,
            margin: EdgeInsets.symmetric(horizontal: 1.5 * scale),
            decoration: BoxDecoration(
              color: rings ? null : color,
              border: rings ? Border.all(color: color) : null,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );

    final chip = GestureDetector(
      key: ValueKey('day-${date.dayNumber}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedBuilder(
        animation: strip,
        builder: (context, child) {
          final page = strip.hasClients && strip.position.haveDimensions
              ? strip.page!
              : strip.initialPage.toDouble();
          final away = math.min(2.0, (page - date.dayNumber).abs());
          return Opacity(
            opacity: 1 - 0.32 * away,
            child: Transform.scale(
              scale: 1 - 0.11 * away,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceRaised.withValues(
                    alpha: math.max(0, 1 - away),
                  ),
                  border: Border.all(
                    color: colors.accent.withValues(
                      alpha: math.max(0, 1 - away),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(theme.radii.md),
                ),
                child: child,
              ),
            ),
          );
        },
        child: across
            ? Row(
                children: [
                  // The number on the strip's middle line, as it is on
                  // the upright chip: the weekday right up to it, the
                  // pasaran and the dots after it.
                  // Either side shrinks to its room rather than run
                  // over, should a face be wider than this one.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(fit: BoxFit.scaleDown, child: weekday),
                    ),
                  ),
                  SizedBox(
                    width: 56 * scale,
                    child: Center(child: number),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            pasaran,
                            SizedBox(width: theme.spacing.sm * scale),
                            marks,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    weekday,
                    number,
                    pasaran,
                    SizedBox(height: 10, child: marks),
                  ],
                ),
              ),
      ),
    );
    // Upright, as far from the row over the strip (the search, the
    // categories' capsule and the buttons) as from the bar under the
    // panel, and a little narrower than its slot; what is on it stays at
    // its centre (owner, 20 October 2026).
    if (!across) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.xs,
          vertical: theme.spacing.md,
        ),
        child: chip,
      );
    }
    // Across, a little room round each chip, so that the one at the
    // centre does not run into the column's edges.
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.md,
        vertical: theme.spacing.xs,
      ),
      child: chip,
    );
  }
}
