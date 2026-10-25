import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import 'glyph_button.dart';
import 'parts.dart';

/// One thing a page can do, as a card: its glyph, its name, and a line on
/// what it does.
class ActionCard {
  final String id;
  final Glyph glyph;
  final String name;
  final String line;
  final VoidCallback onTap;

  /// Faint and deaf while it cannot be chosen (the practice's other ways
  /// while one runs).
  final bool enabled;

  /// A card of another kind than the ones before it (the I Ching's Read,
  /// after its three ways of casting): set apart from them by a rule, and
  /// drawn on a ground of the accent with no outline, its glyph and name
  /// in the accent.
  final bool apart;

  const ActionCard({
    required this.id,
    required this.glyph,
    required this.name,
    this.line = '',
    required this.onTap,
    this.enabled = true,
    this.apart = false,
  });
}

/// What a page can do, as a row of cards in its lower panel, the cards
/// the utilities are chosen from: the glyph large, the name, a line on
/// what it does. Touching one does it. Where the lower panel is tall (a
/// tablet on its side) they run down it instead, each as wide as the
/// column and short. The bar is the house's and never changes, so what a
/// page did from its bar it does from here (owner, 20 October 2026: the
/// bazi's journal, under its Options).
class ActionCards extends StatelessWidget {
  final List<ActionCard> cards;

  /// The card chosen, lit, where the cards are ways to choose between (the
  /// practice's stopwatch, timer and tally); none where each is a deed.
  final String? chosen;

  /// Glyph and name only, the cards sharing the row's width between them:
  /// for a panel with something over the cards.
  final bool compact;

  const ActionCards({
    super.key,
    required this.cards,
    this.chosen,
    this.compact = false,
  });

  static const _cardWidth = 176.0;
  static const _cardHeight = 76.0;

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final tall = FourParts.tallPanel(context);

    Widget face(ActionCard each) => tall
        ? Row(
            children: [
              GlyphMark(glyph: each.glyph, size: 28, color: colors.accent),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _name(theme, each),
                    SizedBox(height: spacing.xs / 2),
                    _line(theme, each, lines: 1),
                  ],
                ),
              ),
            ],
          )
        : Column(
            children: [
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: GlyphMark(
                      glyph: each.glyph,
                      size: 36,
                      color: colors.accent,
                    ),
                  ),
                ),
              ),
              SizedBox(height: spacing.xs),
              _name(theme, each),
              SizedBox(height: spacing.xs / 2),
              _line(theme, each, lines: 2),
            ],
          );

    // Between a card set apart and those before it: a faint rule, with
    // room either side.
    Widget rule() {
      final across = tall ? Axis.vertical : Axis.horizontal;
      final line = Container(
        width: across == Axis.horizontal ? 1 : null,
        height: across == Axis.vertical ? 1 : null,
        margin: across == Axis.horizontal
            ? EdgeInsets.symmetric(vertical: spacing.sm)
            : EdgeInsets.symmetric(horizontal: spacing.sm),
        color: colors.outline,
      );
      final gap = SizedBox(width: spacing.sm, height: spacing.sm);
      return Flex(
        direction: across,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [gap, line, gap],
      );
    }

    Widget card(ActionCard each) {
      // Among ways to choose, the one chosen is lit and the others stand
      // back.
      final lit = chosen == null || chosen == each.id;
      return Opacity(
        opacity: each.enabled ? 1 : 0.3,
        child: IgnorePointer(
          ignoring: !each.enabled,
          child: GestureDetector(
            key: ValueKey(each.id),
            behavior: HitTestBehavior.opaque,
            onTap: each.onTap,
            child: AnimatedContainer(
              duration: theme.motion.medium,
              curve: theme.motion.curve,
              width: tall || compact ? null : _cardWidth,
              height: tall ? _cardHeight : null,
              padding: EdgeInsets.all(spacing.md - spacing.xs),
              decoration: BoxDecoration(
                color: each.apart
                    ? colors.accent.withValues(alpha: 0.14)
                    : lit
                    ? colors.surfaceRaised
                    : colors.surfaceRaised.withValues(alpha: 0),
                border: Border.all(
                  color: each.apart
                      ? colors.accent.withValues(alpha: 0)
                      : lit
                      ? colors.accent
                      : colors.outline,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(theme.radii.md),
              ),
              child: compact ? _small(theme, each, lit) : face(each),
            ),
          ),
        ),
      );
    }

    if (compact) {
      return Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, each) in cards.indexed) ...[
              if (i > 0 && each.apart)
                rule()
              else if (i > 0)
                SizedBox(width: spacing.sm),
              Expanded(child: card(each)),
            ],
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, room) => SingleChildScrollView(
        scrollDirection: tall ? Axis.vertical : Axis.horizontal,
        padding: EdgeInsets.all(spacing.md),
        child: ConstrainedBox(
          // Centred while they fit.
          constraints: tall
              ? BoxConstraints(
                  minHeight: math.max(0, room.maxHeight - 2 * spacing.md),
                )
              : BoxConstraints(
                  minWidth: math.max(0, room.maxWidth - 2 * spacing.md),
                ),
          child: Flex(
            direction: tall ? Axis.vertical : Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, each) in cards.indexed) ...[
                if (i > 0 && each.apart)
                  rule()
                else if (i > 0)
                  SizedBox(width: spacing.sm, height: spacing.sm),
                card(each),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // A card of a compact row: the glyph, and under it the name.
  Widget _small(SmThemeData theme, ActionCard each, bool lit) => Column(
    children: [
      Expanded(
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: GlyphMark(
              glyph: each.glyph,
              size: 28,
              color: lit || each.apart
                  ? theme.colors.accent
                  : theme.colors.textSecondary,
            ),
          ),
        ),
      ),
      SizedBox(height: theme.spacing.xs),
      _name(theme, each),
    ],
  );

  Widget _name(SmThemeData theme, ActionCard each) => Text(
    each.name.toUpperCase(),
    maxLines: 1,
    softWrap: false,
    overflow: TextOverflow.fade,
    style: theme.type.caption.copyWith(
      color: each.apart ? theme.colors.accent : theme.colors.textSecondary,
      letterSpacing: 1.2,
    ),
  );

  // Always [lines] tall, so the glyph stands in the same place on every
  // card.
  Widget _line(SmThemeData theme, ActionCard each, {required int lines}) {
    final style = theme.type.label.copyWith(
      color: theme.colors.textFaint,
      letterSpacing: 0,
    );
    return Stack(
      alignment: lines == 1 ? Alignment.topLeft : Alignment.topCenter,
      children: [
        SizedBox(
          width: double.infinity,
          child: Text('\n' * (lines - 1), maxLines: lines, style: style),
        ),
        Text(
          each.line,
          maxLines: lines,
          overflow: TextOverflow.ellipsis,
          textAlign: lines == 1 ? TextAlign.start : TextAlign.center,
          style: style,
        ),
      ],
    );
  }
}
