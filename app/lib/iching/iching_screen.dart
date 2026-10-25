import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import '../action_cards.dart';
import '../glyph_button.dart';
import '../house.dart';
import '../journal/entry.dart';
import '../parts.dart';
import '../routes.dart';
import '../strings.dart';
import 'iching_cast_screen.dart';
import 'iching_library.dart';
import 'iching_pack.dart';
import 'iching_reading_screen.dart' show IchingDrafts;
import 'iching_record.dart';

/// Opens the I Ching.
Future<void> pushIching(BuildContext context) =>
    Navigator.of(context)
        .push(fadeRoute<void>(context, (context) => const IchingScreen()));

/// Opens the cast a journal entry holds, standing whole, to read it or
/// cast afresh in its place. Returns what was done to the entry, if
/// anything, for the entry to say.
Future<String?> pushIchingOf(
  BuildContext context, {
  required Entry entry,
  required IchingRecord record,
}) => Navigator.of(context).push<String>(
  fadeRoute<String>(
    context,
    (context) =>
        IchingCastScreen(method: record.method, record: record, source: entry),
  ),
);

/// The I Ching: the door to its four ways in. Opened from the Chinese
/// calendar's utilities, inside the house.
///
///  * Top bar: its name, and what it is for.
///  * Main body: the character 易, large and faint: nothing to work.
///  * Lower panel: four cards, left to right the three ways of casting
///    (the stalks, the coins, and by hand), and set apart from them, on a
///    ground of the accent, the book. Each opens its page in the same
///    room; back is the swipe.
///  * Bottom bar: the house's.
///
/// Nothing here is kept: neither the question, which is never asked for,
/// nor what was cast, unless the user saves the cast to the journal.
class IchingScreen extends StatefulWidget {
  /// The text pack; loaded from the app's assets when not given.
  final IchingPack? pack;

  /// Where the chance comes from; the phone's own secure source when not
  /// given.
  final math.Random? random;

  const IchingScreen({super.key, this.pack, this.random});

  @override
  State<IchingScreen> createState() => _IchingScreenState();
}

class _IchingScreenState extends State<IchingScreen> {
  // The hold on the faint 易 that shows or hides our notes
  // (IchingDrafts): nothing on screen tells of it.
  Timer? _hold;
  Offset? _holdFrom;

  void _holdStart(PointerDownEvent event) {
    _hold?.cancel();
    _holdFrom = event.position;
    _hold = Timer(IchingDrafts.hold, IchingDrafts.toggle);
  }

  void _holdMove(PointerMoveEvent event) {
    // A finger that wanders is not holding.
    final from = _holdFrom;
    if (from != null && (event.position - from).distance > 24) _holdEnd();
  }

  void _holdEnd([PointerEvent? _]) {
    _hold?.cancel();
    _hold = null;
    _holdFrom = null;
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Read now, so the pages opened from here have it from their first
    // frame.
    if (widget.pack == null) IchingPack.load();
  }

  void _open(Widget page) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(fadeRoute<void>(context, (context) => page));
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final strings = Strings.of(context);

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: FourParts(
          top: TopBar(
            key: const ValueKey('iching-top-bar'),
            leading: TopBarTitle(label: strings.ichingTitle),
            subtitle: strings.ichingSubtitle,
          ),
          // The book's own word for change, faint at the centre: the body
          // has nothing to work until a way is chosen.
          body: LayoutBuilder(
            builder: (context, room) => Center(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _holdStart,
                onPointerMove: _holdMove,
                onPointerUp: _holdEnd,
                onPointerCancel: _holdEnd,
                child: Text(
                  '易',
                  key: const ValueKey('iching-yi'),
                  style: theme.type.display.copyWith(
                    fontSize: math.min(room.maxWidth, room.maxHeight) * 0.42,
                    height: 1,
                    color: colors.textFaint.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          ),
          panel: ActionCards(
            key: const ValueKey('iching-ways'),
            compact: true,
            cards: [
              for (final (method, glyph, name) in [
                (CastMethod.stalks, Glyph.stalks, strings.ichingStalks),
                (CastMethod.coins, Glyph.coins, strings.ichingCoins),
                (CastMethod.manual, Glyph.byHand, strings.ichingManual),
              ])
                ActionCard(
                  id: 'iching-${method.name}',
                  glyph: glyph,
                  name: name,
                  onTap: () => _open(
                    IchingCastScreen(
                      method: method,
                      pack: widget.pack,
                      random: widget.random,
                    ),
                  ),
                ),
              // The book, which is not a way of casting: set apart.
              ActionCard(
                id: 'iching-read',
                glyph: Glyph.book,
                name: strings.ichingRead,
                apart: true,
                onTap: () => _open(IchingLibrary(pack: widget.pack)),
              ),
            ],
          ),
          bar: const RoomBar(),
        ),
      ),
    );
  }
}
