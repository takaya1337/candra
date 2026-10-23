import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import 'calendar_system.dart';
import 'glyph_button.dart';
import 'parts.dart';
import 'strings.dart';
import 'system_palettes.dart';

/// Something a calendar system can do beyond naming the day: a chart, a
/// wheel, a reckoning of its own. A system may have several, or none.
enum Utility {
  /// The four pillars of an instant.
  bazi(CalendarSystem.chinese, Glyph.bazi),

  /// The Javanese year of the seasons.
  mangsa(CalendarSystem.javanese, Glyph.mangsa),

  /// The Javanese sky: the stars the seasons were read by.
  lintang(CalendarSystem.javanese, Glyph.lintang),

  /// The five prayers on a day's clock.
  salat(CalendarSystem.hijri, Glyph.salat),

  /// The young crescent after the new moon, and what the criteria make
  /// of it.
  hilal(CalendarSystem.hijri, Glyph.hilal),

  /// Where the sun and the moon stand: the ephemeris.
  sky(CalendarSystem.gregorian, Glyph.sky),

  /// The planets: where they stand, their hours, their lore.
  planets(CalendarSystem.gregorian, Glyph.planets),

  /// The fixed stars as they stand.
  stars(CalendarSystem.gregorian, Glyph.stars),

  /// The sun and the moon for photographs.
  light(CalendarSystem.gregorian, Glyph.light);

  final CalendarSystem system;
  final Glyph glyph;

  const Utility(this.system, this.glyph);

  /// The utilities of [system], in the order they are shown.
  static List<Utility> of(CalendarSystem system) => [
    for (final utility in values)
      if (utility.system == system) utility,
  ];
}

/// A strip of cards, one for each utility of [system], scrolled sideways:
/// the same strip the systems are chosen from. Each card has the
/// utility's glyph, its name, and a line on what it is. Touching a card
/// opens it.
///
/// Where the lower panel is tall (a tablet on its side) the cards run
/// down it instead, each as wide as the column and short: the glyph at
/// the left, the name and the line on what it is beside it.
class UtilityPicker extends StatefulWidget {
  final CalendarSystem system;
  final ValueChanged<Utility> onOpen;

  /// Passed in so a strip fading out keeps its own wording.
  final Strings strings;

  const UtilityPicker({
    super.key,
    required this.system,
    required this.strings,
    required this.onOpen,
  });

  @override
  State<UtilityPicker> createState() => _UtilityPickerState();
}

class _UtilityPickerState extends State<UtilityPicker> {
  static const _cardWidth = 176.0;

  // Down a tall panel: short enough for five or so to be seen at once.
  static const _cardHeight = 76.0;

  final _scroll = ScrollController();
  int _nearest = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = widget.system.shown;
    final tall = FourParts.tallPanel(context);
    final slot = (tall ? _cardHeight : _cardWidth) + 2 * spacing.xs;
    final utilities = Utility.of(widget.system);

    return LayoutBuilder(
      builder: (context, constraints) =>
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              final nearest = (notification.metrics.pixels / slot)
                  .round()
                  .clamp(0, utilities.length - 1);
              if (nearest != _nearest) {
                _nearest = nearest;
                HapticFeedback.selectionClick();
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: tall ? Axis.vertical : Axis.horizontal,
              physics: const BouncingScrollPhysics(),
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
                  for (final utility in utilities)
                    Padding(
                      padding: tall
                          ? EdgeInsets.symmetric(vertical: spacing.xs)
                          : EdgeInsets.symmetric(horizontal: spacing.xs),
                      child: GestureDetector(
                        key: ValueKey('utility-${utility.name}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onOpen(utility),
                        child: Container(
                          width: tall ? null : _cardWidth,
                          height: tall ? _cardHeight : null,
                          padding: EdgeInsets.all(spacing.md - spacing.xs),
                          decoration: BoxDecoration(
                            color: colors.surfaceRaised,
                            border: Border.all(
                              color: colors.accent,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(theme.radii.md),
                          ),
                          child: tall
                              ? _across(theme, colors, utility)
                              : Column(
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: GlyphMark(
                                            glyph: utility.glyph,
                                            size: 44,
                                            color: colors.accent,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: spacing.xs),
                                    Text(
                                      widget.strings
                                          .utilityName(utility)
                                          .toUpperCase(),
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      style: theme.type.caption.copyWith(
                                        color: colors.textSecondary,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    SizedBox(height: spacing.xs / 2),
                                    // Always two lines tall, so the glyph stands in
                                    // the same place on every card.
                                    Stack(
                                      alignment: Alignment.topCenter,
                                      children: [
                                        Text(
                                          '\n',
                                          maxLines: 2,
                                          style: theme.type.label.copyWith(
                                            letterSpacing: 0,
                                          ),
                                        ),
                                        Text(
                                          widget.strings.utilitySummary(
                                            utility,
                                          ),
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
                      ),
                    ),
                ],
              ),
            ),
          ),
    );
  }

  /// A card laid across, for a tall panel: the glyph at the left, then
  /// the name over the line on what it is.
  Widget _across(SmThemeData theme, SmColors colors, Utility utility) {
    final spacing = theme.spacing;
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Center(
            child: GlyphMark(
              glyph: utility.glyph,
              size: 36,
              color: colors.accent,
            ),
          ),
        ),
        SizedBox(width: spacing.sm),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.strings.utilityName(utility).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: theme.type.caption.copyWith(
                  color: colors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: spacing.xs / 2),
              Text(
                widget.strings.utilitySummary(utility),
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
}
