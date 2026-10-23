import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import '../glyph_button.dart';
import '../scroll_bars.dart';
import '../strings.dart';
import '../swipe_to_delete.dart';
import 'entry.dart';
import 'markdown.dart';

/// A day's journal as a stack of folders, one per category, the way they
/// stand in a filing drawer: every folder the same size and in the same
/// place, each with a tab along the top edge, the tabs set step by step
/// across the row and just overlapping.
///
/// Four folders stand in the drawer at any time, the one in front and the
/// three behind it, so there are never more than four tabs in the row.
/// With more categories than that the rest wait out of sight: each deal
/// sends the front folder to the back of the line and brings the next one
/// waiting into the row, the tabs gliding along to make room.
///
/// A tab carries its category's name and, under it, a dot per entry: up
/// to four, then a count of the rest. The folder in front shows all of
/// its category's entries for the day, and scrolls up and down.
///
/// Tapping a tab brings its folder to the front. A swipe to either side
/// deals the front folder away: it travels out that way, the one behind
/// it leads, and it comes back in at the rear.
class CardStack extends StatefulWidget {
  final List<JournalPlane> planes;

  /// The category that should be at the front. Changing it reshuffles the
  /// stack so that folder leads and the others follow in their usual
  /// order.
  final String? front;

  /// Called with the category of the folder brought to the front, by a
  /// deal or by a tap on its tab.
  final ValueChanged<String>? onFront;

  /// Called when an entry in a folder is tapped.
  final ValueChanged<Entry>? onOpenEntry;

  /// Called when an entry's own delete button, shown by drawing the
  /// entry to the left, is pressed.
  final ValueChanged<Entry>? onDeleteEntry;

  /// What a folder with no entries says.
  final String emptyText;

  const CardStack({
    super.key,
    required this.planes,
    this.front,
    this.onFront,
    this.onOpenEntry,
    this.onDeleteEntry,
    this.emptyText = '',
  });

  /// How tall the row of tabs is.
  static const tabHeight = 44.0;

  /// How far a tab's sides lean.
  static const lean = 12.0;

  /// Folders standing in the drawer at any time: the front one and three
  /// behind. No more tabs than this are ever in the row.
  static const shown = 4;

  /// How many characters a folder's label has room for.
  static const labelLength = 12;

  /// A category's name as its folder's label: in capitals, whole up to
  /// twelve characters; a longer one is cut to eight and three dots.
  static String labelOf(String name) {
    final label = name.toUpperCase();
    return label.length <= labelLength
        ? label
        : '${label.substring(0, labelLength - 4).trimRight()}...';
  }

  /// Dots on a tab before the rest become a count.
  static const maxDots = 4;

  /// Where the tab of folder [index] of [count] sits along a row [width]
  /// wide: its left edge and its width. With few folders the tabs stand
  /// side by side, just overlapping; with many they close up.
  static ({double left, double width}) tabOf(
    int index,
    int count,
    double width,
  ) {
    // The row stops short of the sheet's rounded corner.
    final row = width - lean;
    // Wide enough that each overlaps the next by its lean and no more,
    // while there is room for that.
    final tab = ((row - lean) / math.max(count, 1) + lean)
        .clamp(72.0, math.min(150.0, row))
        .toDouble();
    final step = count < 2
        ? 0.0
        : math.min(tab - lean, (row - tab) / (count - 1));
    return (left: index * step, width: tab);
  }

  @override
  State<CardStack> createState() => _CardStackState();
}

class _CardStackState extends State<CardStack> with TickerProviderStateMixin {
  static const _dealTime = Duration(milliseconds: 520);

  // Front to back.
  late List<JournalPlane> _order = _startingAt(widget.front);

  // 0 = at rest. Up to 0.5 the front folder is leaving; from 0.5 to 1 it
  // is arriving at the rear. A drag moves this directly, up to the halfway
  // point, and letting go finishes or undoes it.
  late final AnimationController _deal = AnimationController(vsync: this);

  // Runs once each time a folder is brought to the front by its tab or
  // from outside: what is in it rises into place.
  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  // Which way the front folder is leaving: -1 left, 1 right.
  double _way = -1;
  double _dragged = 0;

  int get _count => _order.length;

  /// The planes in their usual order, turned so [front] leads. A deal is
  /// the same turn by one place, so the order is always a turn of this.
  List<JournalPlane> _startingAt(String? front) {
    final planes = widget.planes;
    final index = planes.indexWhere((p) => p.category.id == front);
    if (index <= 0) return [...planes];
    return [...planes.skip(index), ...planes.take(index)];
  }

  @override
  void didUpdateWidget(CardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The planes are regrouped whenever an entry changes, and the front can
    // be chosen from outside. Either way: keep whichever folder is asked
    // for at the front, or failing that the one already there.
    final current = _order.isEmpty ? null : _order.first.category.id;
    final wanted = widget.front != oldWidget.front ? widget.front : current;
    final next = _startingAt(wanted);
    final same =
        next.length == _order.length &&
        Iterable.generate(next.length)
            .every((i) => next[i].category.id == _order[i].category.id);
    if (!same) {
      _deal.value = 0;
      if (next.isNotEmpty && next.first.category.id != current) {
        _rise.forward(from: 0);
      }
    }
    _order = next;
  }

  @override
  void dispose() {
    _deal.dispose();
    _rise.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double width) {
    if (_count < 2 || _deal.isAnimating) return;
    _dragged += details.primaryDelta!;
    if (_dragged != 0) _way = _dragged.sign;
    _deal.value = math.min(_dragged.abs() / width, 0.45);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_count < 2 || _deal.isAnimating) return;
    _dragged = 0;
    final flung = details.primaryVelocity!.abs() > 500;
    if (_deal.value < 0.12 && !flung) {
      _deal.animateBack(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    _deal.animateTo(1, duration: _dealTime * (1 - _deal.value)).whenComplete(
      () {
        if (!mounted || _deal.value != 1) return;
        HapticFeedback.lightImpact();
        setState(() {
          _order = [..._order.skip(1), _order.first];
          _deal.value = 0;
        });
        widget.onFront?.call(_order.first.category.id);
      },
    );
  }

  // A tap on a tab: that folder leads.
  void _bringForward(String id) {
    if (_deal.value != 0 || _order.first.category.id == id) return;
    HapticFeedback.selectionClick();
    setState(() => _order = _startingAt(id));
    _rise.forward(from: 0);
    widget.onFront?.call(id);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = constraints.biggest;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: (details) =>
              _onDragUpdate(details, area.width),
          onHorizontalDragEnd: _onDragEnd,
          child: AnimatedBuilder(
            animation: _deal,
            builder: (context, _) {
              final v = _deal.value;

              // Once the front folder is half way out, the one behind it
              // leads.
              final leaving = v < 0.5;

              // Four folders stand in the drawer at any time: the one in
              // front and the three behind it. With more, the rest wait
              // out of sight; as the front one is dealt away the next in
              // line takes the place it leaves.
              final crowded = _count > CardStack.shown;
              final standing = crowded && !leaving
                  ? _order.skip(1).take(CardStack.shown).toList()
                  : _order.take(CardStack.shown).toList();
              // Their tabs keep the order the categories have, left to
              // right, whichever of them is in front.
              int placeOf(JournalPlane plane) => widget.planes.indexWhere(
                (p) => p.category.id == plane.category.id,
              );
              final row = [...standing]
                ..sort((a, b) => placeOf(a).compareTo(placeOf(b)));

              Widget placed(
                JournalPlane plane, {
                required bool leads,
                double left = 0,
                double opacity = 1,
              }) {
                final tab = CardStack.tabOf(
                  row.indexOf(plane),
                  row.length,
                  area.width,
                );
                return Positioned(
                  key: ValueKey(plane.category.id),
                  left: left,
                  top: 0,
                  width: area.width,
                  height: area.height,
                  // One that joins the four comes in softly.
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 260),
                    builder: (context, arrived, child) => Opacity(
                      opacity: (opacity * arrived).clamp(0.0, 1.0),
                      child: child,
                    ),
                    child: RepaintBoundary(
                      child: _Folder(
                        plane: plane,
                        tabLeft: tab.left,
                        tabWidth: tab.width,
                        leads: leads,
                        rise: _rise,
                        emptyText: widget.emptyText,
                        onOpenEntry: widget.onOpenEntry,
                        onDeleteEntry: widget.onDeleteEntry,
                        onTab: () => _bringForward(plane.category.id),
                      ),
                    ),
                  ),
                );
              }

              final rest = [
                for (var i = _count - 1; i >= 1; i--)
                  if (standing.contains(_order[i]))
                    placed(_order[i], leads: i == 1 && v > 0),
              ];

              // The front folder: out to the side it was swiped, then in
              // at the rear from the other side, as if it had gone round.
              // In a crowded drawer it does not come back in: it waits
              // its turn out of sight.
              Widget? front;
              if (leaving) {
                final out = Curves.easeIn.transform(v / 0.5);
                front = placed(
                  _order.first,
                  leads: true,
                  left: _way * area.width * 1.1 * out,
                );
              } else if (!crowded) {
                final arrive = Curves.easeOutCubic.transform((v - 0.5) / 0.5);
                front = placed(
                  _order.first,
                  leads: false,
                  left: -_way * area.width * 0.6 * (1 - arrive),
                  opacity: arrive,
                );
              }

              return Stack(
                clipBehavior: Clip.none,
                children: leaving ? [...rest, ?front] : [?front, ...rest],
              );
            },
          ),
        );
      },
    );
  }
}

/// One category's folder: its tab, standing up from the top edge at its
/// own place along the row, and under it the sheet with all of that day's
/// entries in the category, each cut to a one-line title and three lines
/// of text. The sheet scrolls up and down.
class _Folder extends StatelessWidget {
  final JournalPlane plane;
  final double tabLeft;
  final double tabWidth;

  /// Whether this folder is the one in front, or about to be.
  final bool leads;
  final Animation<double> rise;
  final String emptyText;
  final ValueChanged<Entry>? onOpenEntry;

  /// Called when an entry's own delete button, shown by drawing the
  /// entry to the left, is pressed.
  final ValueChanged<Entry>? onDeleteEntry;
  final VoidCallback onTab;

  const _Folder({
    required this.plane,
    required this.tabLeft,
    required this.tabWidth,
    required this.leads,
    required this.rise,
    required this.emptyText,
    required this.onTab,
    this.onOpenEntry,
    this.onDeleteEntry,
  });

  // Where an entry was written, if geotagged: one quiet line under its
  // title, the name alone, or the coordinates of a place with none. Cut
  // short when long; the whole of it is on the entry itself.
  static Widget? _placeLine(SmThemeData theme, Color hue, Entry entry) {
    final place = entry.place;
    if (place == null) return null;
    final tone = hue.withValues(alpha: 0.85);
    return Padding(
      key: ValueKey('place-${entry.id}'),
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          GlyphMark(glyph: Glyph.place, size: 9, color: tone),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              place.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.type.caption.copyWith(color: tone),
            ),
          ),
        ],
      ),
    );
  }

  // An entry's tile, which can be drawn to the left for its delete
  // button where deleting is allowed.
  Widget _swipeable(Entry entry, Widget tile) => onDeleteEntry == null
      ? tile
      : SwipeToDelete(
          name: entry.id,
          onDelete: () => onDeleteEntry!(entry),
          child: tile,
        );

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final hue = plane.category.color;
    final count = plane.entries.length;

    // The tab glides to its place when the row is rearranged.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: tabLeft),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, tabLeft, _) =>
          _build(context, theme, colors, spacing, hue, count, tabLeft),
    );
  }

  Widget _build(
    BuildContext context,
    SmThemeData theme,
    SmColors colors,
    SmSpacing spacing,
    Color hue,
    int count,
    double tabLeft,
  ) {
    return CustomPaint(
      painter: _FolderPainter(
        tabLeft: tabLeft,
        tabWidth: tabWidth,
        radius: theme.radii.md,
        // Opaque, so a folder fully hides the ones behind it.
        fill: Color.alphaBlend(hue.withValues(alpha: 0.13), colors.surface),
        edge: hue.withValues(alpha: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The tab: the name, and under it a dot per entry.
          SizedBox(
            height: CardStack.tabHeight,
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.only(left: tabLeft),
                child: GestureDetector(
                  key: ValueKey('tab-${plane.category.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onTab,
                  child: SizedBox(
                    width: tabWidth,
                    height: CardStack.tabHeight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        CardStack.lean + 4,
                        8,
                        CardStack.lean + 2,
                        0,
                      ),
                      child: _TabLabel(
                        id: plane.category.id,
                        name: plane.category.name,
                        hue: hue,
                        count: count,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: !leads
                // Behind the front folder: nothing of the sheet shows.
                ? const SizedBox.expand()
                // The sheet takes every touch on it, so none falls
                // through to a folder behind.
                : ColoredBox(
                    color: const Color(0x00000000),
                    child: FadeTransition(
                      opacity: rise,
                      child: SlideTransition(
                        position:
                            Tween(
                              begin: const Offset(0, 0.03),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: rise,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: plane.entries.isEmpty
                            // A category chosen to write in, with nothing
                            // in it yet today.
                            ? Center(
                                child: Text(
                                  emptyText,
                                  style: theme.type.body.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              )
                            : // The bar in the category's colour, to be seen, and kept off
                              // the folder's rounded corners and inside its
                              // line (owner, 20 October 2026).
                              ScrollHintStyle(
                                color: hue.withValues(alpha: 0.75),
                                inset: EdgeInsets.fromLTRB(
                                  0,
                                  theme.radii.md,
                                  3,
                                  theme.radii.md,
                                ),
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.fromLTRB(
                                    spacing.md,
                                    spacing.md,
                                    spacing.md,
                                    spacing.md,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (final entry in plane.entries)
                                        // Each entry is a tile of its own, set apart
                                        // from the next: plainly a thing to be tapped.
                                        Padding(
                                          padding: EdgeInsets.only(
                                            bottom: spacing.sm,
                                          ),
                                          child: _swipeable(
                                            entry,
                                            GestureDetector(
                                              key: ValueKey(
                                                'entry-${entry.id}',
                                              ),
                                              behavior: HitTestBehavior.opaque,
                                              onTap: onOpenEntry == null
                                                  ? null
                                                  : () => onOpenEntry!(entry),
                                              child: Container(
                                                padding: EdgeInsets.all(
                                                  spacing.md - spacing.xs,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: hue.withValues(
                                                    alpha: 0.08,
                                                  ),
                                                  border: Border.all(
                                                    color: hue.withValues(
                                                      alpha: 0.28,
                                                    ),
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        theme.radii.sm + 2,
                                                      ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .baseline,
                                                      textBaseline: TextBaseline
                                                          .alphabetic,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            entry.title,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: theme
                                                                .type
                                                                .body
                                                                .copyWith(
                                                                  color: colors
                                                                      .textPrimary,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          width: spacing.sm,
                                                        ),
                                                        Text(
                                                          entry.duration == null
                                                              ? entry.time
                                                              : '${entry.time} · '
                                                                    '${Strings.of(context).practiceLength(entry.duration!)}',
                                                          style: theme
                                                              .type
                                                              .caption
                                                              .copyWith(
                                                                color: colors
                                                                    .textSecondary,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                    ?_placeLine(
                                                      theme,
                                                      hue,
                                                      entry,
                                                    ),
                                                    if (entry
                                                        .content
                                                        .isNotEmpty) ...[
                                                      SizedBox(
                                                        height: spacing.xs,
                                                      ),
                                                      // The content as Markdown, its marks
                                                      // hidden.
                                                      Text.rich(
                                                        Markdown.span(
                                                          entry.content,
                                                          theme.type.label
                                                              .copyWith(
                                                                color: colors
                                                                    .textPrimary
                                                                    .withValues(
                                                                      alpha:
                                                                          0.8,
                                                                    ),
                                                                height: 1.45,
                                                              ),
                                                          colors: colors,
                                                          showMarks: false,
                                                          flat: true,
                                                        ),
                                                        maxLines: 3,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// What a folder's tab carries: the name, and under it a dot per entry.
class _TabLabel extends StatelessWidget {
  final String id;
  final String name;
  final Color hue;
  final int count;

  const _TabLabel({
    required this.id,
    required this.name,
    required this.hue,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Every label is set as though it were twelve characters long,
        // and shrunk as one to fit the tab: so all are the same size, and
        // a name of twelve always fits whole.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Stack(
            children: [
              Opacity(
                opacity: 0,
                child: Text(
                  'M' * CardStack.labelLength,
                  maxLines: 1,
                  softWrap: false,
                  style: theme.type.caption.copyWith(letterSpacing: 1.2),
                ),
              ),
              Text(
                CardStack.labelOf(name),
                maxLines: 1,
                softWrap: false,
                style: theme.type.caption.copyWith(
                  color: hue,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < math.min(count, CardStack.maxDots); i++)
              Container(
                key: ValueKey('dot-$id-$i'),
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(color: hue, shape: BoxShape.circle),
              ),
            if (count > CardStack.maxDots)
              Flexible(
                child: Text(
                  '+${count - CardStack.maxDots}',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: theme.type.caption.copyWith(
                    color: hue,
                    fontSize: 9,
                    height: 0.6,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// A category's folder as the journal draws it, for showing one before
/// it is kept: its tab at the left with the name in [hue], over a strip
/// of the sheet [sheet] high. Nothing in it can be touched.
class FolderPreview extends StatelessWidget {
  final String name;
  final Color hue;
  final double sheet;

  const FolderPreview({
    super.key,
    required this.name,
    required this.hue,
    this.sheet = 36,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // As wide as the first tab is with four folders in the drawer.
        final tab = CardStack.tabOf(0, CardStack.shown, constraints.maxWidth);
        return CustomPaint(
          painter: _FolderPainter(
            tabLeft: tab.left,
            tabWidth: tab.width,
            radius: theme.radii.md,
            fill: Color.alphaBlend(
              hue.withValues(alpha: 0.13),
              theme.colors.surface,
            ),
            edge: hue.withValues(alpha: 0.9),
          ),
          child: SizedBox(
            height: CardStack.tabHeight + sheet,
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.only(left: tab.left),
                child: SizedBox(
                  width: tab.width,
                  height: CardStack.tabHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      CardStack.lean + 4,
                      8,
                      CardStack.lean + 2,
                      0,
                    ),
                    child: _TabLabel(
                      id: 'preview',
                      name: name,
                      hue: hue,
                      count: 0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A folder's outline: the sheet, a rounded rectangle under the row of
/// tabs, and its tab rising out of the top edge with leaning sides.
class _FolderPainter extends CustomPainter {
  final double tabLeft;
  final double tabWidth;
  final double radius;
  final Color fill;
  final Color edge;

  const _FolderPainter({
    required this.tabLeft,
    required this.tabWidth,
    required this.radius,
    required this.fill,
    required this.edge,
  });

  Path _outline(Size size) {
    const top = CardStack.tabHeight;
    const lean = CardStack.lean;
    final r = radius;
    final w = size.width - 0.6;
    final h = size.height - 0.6;
    final left = tabLeft;
    final right = math.min(tabLeft + tabWidth, w);
    final corner = Radius.circular(r);
    final path = Path();

    // Up the left side to where the tab begins.
    if (left < 1) {
      // The tab is flush with the left side: one straight edge.
      path
        ..moveTo(0.6, top + r)
        ..lineTo(0.6, r)
        ..arcToPoint(Offset(r, 0.6), radius: corner);
    } else {
      path
        ..moveTo(0.6, top + r)
        ..arcToPoint(Offset(r, top), radius: corner)
        ..lineTo(left, top)
        ..cubicTo(left + lean / 2, top, left + lean / 2, 0.6, left + lean, 0.6);
    }
    // Along the top of the tab and down its right side.
    if (right > w - 1) {
      path
        ..lineTo(w - r, 0.6)
        ..arcToPoint(Offset(w, r), radius: corner);
    } else {
      path
        ..lineTo(right - lean, 0.6)
        ..cubicTo(right - lean / 2, 0.6, right - lean / 2, top, right, top)
        ..lineTo(w - r, top)
        ..arcToPoint(Offset(w, top + r), radius: corner);
    }
    // Round the sheet.
    return path
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: corner)
      ..lineTo(r, h)
      ..arcToPoint(Offset(0.6, h - r), radius: corner)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _outline(size);
    canvas
      ..drawPath(path, Paint()..color = fill)
      ..drawPath(
        path,
        Paint()
          ..color = edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
  }

  // The tab and the sheet take touches themselves; the row beside the
  // tab lets them through to the tabs of the folders behind.
  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_FolderPainter old) =>
      old.tabLeft != tabLeft ||
      old.tabWidth != tabWidth ||
      old.radius != radius ||
      old.fill != fill ||
      old.edge != edge;
}
