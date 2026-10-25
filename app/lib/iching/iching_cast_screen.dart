import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import '../action_cards.dart';
import '../bar_button.dart';
import '../glyph_button.dart';
import '../house.dart';
import '../journal/entry.dart';
import '../journal/entry_screen.dart';
import '../journal/journal_store.dart';
import '../panel_tabs.dart';
import '../parts.dart';
import '../routes.dart';
import '../strings.dart';
import '../toast.dart';
import 'iching_art.dart';
import 'iching_pack.dart';
import 'iching_reading_screen.dart';
import 'iching_record.dart';

/// A hexagram cast, line by line from the bottom, by the coins, by the
/// stalks, or by hand; and once it stands, read, or saved to the journal.
///
///  * Top bar: the way of casting, and which line is being cast; once all
///    six stand, the hexagram's number and names.
///  * Main body: the six places of the hexagram filling from the bottom,
///    and under them, at the centre, the coins or the stalks at work; the
///    cast just above the foot, as the practice has its start. Once the
///    hexagram stands, casting afresh is at the bottom left, in red. By
///    hand, the six
///    lines instead, the top one highest as in the figure, each with its
///    four numbers to choose from; the lines set drawn as they are set,
///    so the hexagram builds down the page from the bottom.
///  * Lower panel: the cast to and from the journal, as cards (as the
///    bazi's Options), and the hexagram, to read; the reading turns to
///    the one it becomes.
///  * Bottom bar: the house's.
///
/// Nothing is kept unless the user saves it: the cast lasts as long as
/// the page.
class IchingCastScreen extends StatefulWidget {
  final CastMethod method;

  /// The text pack; loaded from the app's assets when not given.
  final IchingPack? pack;

  /// Where the chance comes from; the phone's own secure source when not
  /// given.
  final math.Random? random;

  /// A cast opened from a journal entry: what it was saved as, and the
  /// entry, which saving here changes and returns to.
  final IchingRecord? record;
  final Entry? source;

  const IchingCastScreen({
    super.key,
    required this.method,
    this.pack,
    this.random,
    this.record,
    this.source,
  });

  @override
  State<IchingCastScreen> createState() => _IchingCastScreenState();
}

class _IchingCastScreenState extends State<IchingCastScreen>
    with SingleTickerProviderStateMixin {
  late final math.Random _random = widget.random ?? math.Random.secure();
  late final AnimationController _throw = AnimationController(vsync: this);
  late IchingPack? _pack = widget.pack ?? IchingPack.ready;
  late CastMethod _method = widget.method;

  // The lines cast so far, from the bottom up.
  final _lines = <LineValue>[];

  // The throw now being shown: one or the other.
  CoinThrow? _coins;
  StalkLine? _stalks;

  // The moment the cast began, by the phone's clock: what an entry made
  // of it is dated by.
  CivilDate? _date;
  int _minute = 0;
  Duration _offset = Duration.zero;

  // What the lower panel is doing with the journal, or null when it shows
  // the cards.
  _JournalSide? _side;

  // The entry the cast came from: saving asks whether to change it.
  Entry? _source;

  // Saving, the user chose a new entry: the categories show.
  bool _anew = false;

  String? _toast;
  Timer? _toastTimer;

  static const _coinTime = Duration(milliseconds: 1300);
  static const _stalkTime = Duration(milliseconds: 3600);

  bool get _done => _lines.length == 6 && !_throw.isAnimating;

  @override
  void initState() {
    super.initState();
    if (_pack == null) {
      IchingPack.load().then((pack) {
        if (mounted) setState(() => _pack = pack);
      });
    }
    if (widget.record case final record?) {
      _apply(record, widget.source);
      final title = widget.source?.title;
      if (title != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _say(Strings.of(context).ichingLoaded(title));
        });
      }
    }
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _throw.dispose();
    super.dispose();
  }

  void _say(String message) {
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
    setState(() => _toast = message);
  }

  Future<void> _cast() async {
    if (_throw.isAnimating || _lines.length == 6) return;
    HapticFeedback.selectionClick();
    if (_lines.isEmpty) {
      final now = DateTime.now();
      _date = CivilDate(now.year, now.month, now.day);
      _minute = now.hour * 60 + now.minute;
      _offset = now.timeZoneOffset;
    }
    setState(() {
      if (_method == CastMethod.coins) {
        _coins = Yijing.throwCoins(_random);
        _stalks = null;
      } else {
        _stalks = Yijing.countStalks(_random);
        _coins = null;
      }
    });
    final value = _coins?.value ?? _stalks!.value;
    final cast = _lines.length;
    _throw.duration = _method == CastMethod.coins ? _coinTime : _stalkTime;
    await _throw.forward(from: 0);
    // Loaded or begun again meanwhile: this throw counts for nothing.
    if (!mounted || _lines.length != cast) return;
    HapticFeedback.lightImpact();
    setState(() => _lines.add(value));
  }

  // By hand: line [place] (0 the bottom) set to [value]. A line already
  // set may be set again; the next one up is the only new one that can
  // be.
  void _set(int place, LineValue value) {
    if (place > _lines.length || place > 5) return;
    HapticFeedback.selectionClick();
    if (_lines.isEmpty) {
      final now = DateTime.now();
      _date = CivilDate(now.year, now.month, now.day);
      _minute = now.hour * 60 + now.minute;
      _offset = now.timeZoneOffset;
    }
    setState(() {
      if (place == _lines.length) {
        _lines.add(value);
      } else {
        _lines[place] = value;
      }
    });
  }

  // Afresh: the six places empty again. A cast loaded from an entry is
  // still that entry's, so a new one can be saved in its place.
  void _again() {
    HapticFeedback.selectionClick();
    setState(() {
      _lines.clear();
      _coins = null;
      _stalks = null;
      _date = null;
      _throw.value = 0;
    });
  }

  // What the cast on the screen is, as its line in an entry; null until
  // all six lines stand.
  IchingRecord? get _record => !_done || _date == null
      ? null
      : IchingRecord(
          method: _method,
          lines: List.of(_lines),
          date: _date!,
          minute: _minute,
          offset: _offset,
        );

  // Sets the cast to [record]'s, standing whole, with [entry] as its own.
  void _apply(IchingRecord record, Entry? entry) {
    _throw.stop();
    _throw.value = 0;
    _lines
      ..clear()
      ..addAll(record.lines);
    _coins = null;
    _stalks = null;
    _method = record.method;
    _date = record.date;
    _minute = record.minute;
    _offset = record.offset;
    _source = entry;
  }

  // [entry] as the journal now has it, or null if it is gone.
  Entry? _stillThere(Entry? entry) => entry == null
      ? null
      : JournalScope.of(context)
            .entriesFor(entry.date, utcOffset: entry.utcOffset)
            .where((e) => e.id == entry.id)
            .firstOrNull;

  // The newest entry that holds this very cast, if the journal has one.
  Entry? _sameCast() {
    final value = _record?.value;
    if (value == null) return null;
    final found = JournalScope.of(context)
        .allEntries()
        .where((e) => e.iching == value)
        .toList();
    if (found.isEmpty) return null;
    found.sort(_newestFirst);
    return found.first;
  }

  static int _newestFirst(Entry a, Entry b) {
    final day = b.date.dayNumber.compareTo(a.date.dayNumber);
    return day != 0 ? day : b.secondOfDay.compareTo(a.secondOfDay);
  }

  // The title a cast's entry is given: the hexagram, and the one it
  // becomes where lines change.
  static String _autoTitle(IchingPack pack, IchingRecord record) {
    final cast = record.cast;
    final primary = pack.of(cast.primary);
    if (cast.changing.isEmpty) return '${primary.number} ${primary.name}';
    final relating = pack.of(cast.relating);
    return '${primary.number} ${primary.name} → '
        '${relating.number} ${relating.name}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final strings = Strings.of(context);
    final pack = _pack;
    final editing = _stillThere(_source);
    final primary = _done && pack != null
        ? pack.of(YijingCast(_lines).primary)
        : null;
    final english = primary?.readIn(strings.language)?.reading.name;

    return PopScope(
      // Back, while the panel asks something or lists the journal, closes
      // that first, as Cancel does.
      canPop: _side == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSide();
      },
      child: ColoredBox(
        color: colors.background,
        child: SafeArea(
          child: FourParts(
            top: TopBar(
              key: const ValueKey('iching-cast-top-bar'),
              leading: TopBarTitle(label: strings.ichingMethod(_method)),
              // Casting into an entry's place: its title, so it is plain
              // that this is that entry's cast and not a new one.
              trailing: editing != null
                  ? _EntryCapsule(title: editing.title)
                  : null,
              subtitle: primary == null
                  ? strings.ichingLineOf(math.min(6, _lines.length + 1))
                  : '${primary.number} · ${primary.name}'
                        '${english == null ? '' : ' · $english'}',
            ),
            body: _body(theme, strings),
            panel: switch (_side) {
              _JournalSide.save => _savePanel(theme, strings),
              _JournalSide.load => _loadPanel(theme, strings),
              _JournalSide.discard => _discardPanel(theme, strings),
              null => _cards(strings, pack, editing),
            },
            bar: const RoomBar(),
          ),
        ),
      ),
    );
  }

  Widget _body(SmThemeData theme, Strings strings) {
    if (_method == CastMethod.manual) return _byHand(theme, strings);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final waiting = _lines.isEmpty && !_throw.isAnimating;
    return LayoutBuilder(
      builder: (context, room) {
        final height = room.maxHeight;
        const hint = 64.0;
        // The throw at the centre of the body; the hexagram above it, in
        // what is left under the hint.
        final throwHeight = height * 0.38;
        final throwTop = (height - throwHeight) / 2 - height * 0.02;
        final figureRoom = math.max(0.0, throwTop - hint - spacing.sm);
        final figureWidth = math.min(
          150.0,
          math.min(room.maxWidth * 0.5, figureRoom / 0.86),
        );
        return Stack(
          children: [
            // Before the first line, what to do and what the way is.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: hint,
              child: AnimatedOpacity(
                opacity: waiting ? 1 : 0,
                duration: theme.motion.medium,
                child: Column(
                  key: const ValueKey('iching-hint'),
                  children: [
                    Text(
                      strings.ichingAsk,
                      textAlign: TextAlign.center,
                      style: theme.type.label.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    // Where the ask takes two lines (a narrow body, a
                    // longer language), the note takes what is left and
                    // fades out at its foot.
                    Flexible(
                      child: Text(
                        _method == CastMethod.coins
                            ? strings.ichingCoinsNote
                            : strings.ichingStalksNote,
                        key: const ValueKey('iching-method-note'),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.fade,
                        style: theme.type.caption.copyWith(
                          color: colors.textFaint,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // The hexagram as far as it has been cast: six places, filled
            // from the bottom.
            Positioned(
              top: hint,
              left: 0,
              right: 0,
              height: figureRoom,
              child: Center(
                child: HexagramFigure(
                  key: const ValueKey('iching-building'),
                  lines: _lines,
                  width: figureWidth,
                  color: colors.textPrimary,
                  faint: colors.outline,
                  mark: colors.accent,
                ),
              ),
            ),
            Positioned(
              top: throwTop,
              left: 0,
              right: 0,
              height: throwHeight,
              child: AnimatedBuilder(
                animation: _throw,
                builder: (context, _) => CustomPaint(
                  key: const ValueKey('iching-throw'),
                  painter: _method == CastMethod.coins
                      ? CoinsPainter(
                          thrown: _coins,
                          t: _throw.value,
                          ink: colors.textPrimary,
                          metal: colors.accent,
                          ground: colors.background,
                        )
                      : StalksPainter(
                          line: _stalks,
                          t: _throw.value,
                          ink: colors.textPrimary,
                          aside: colors.accent,
                        ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            // What the last throw came to, once it has landed.
            Positioned(
              top: throwTop + throwHeight,
              left: 0,
              right: 0,
              height: 28,
              child: Center(
                child: Text(
                  _throw.isAnimating || _lines.isEmpty
                      ? ''
                      : strings.ichingLineValue(_lines.last),
                  key: const ValueKey('iching-value'),
                  style: theme.type.label.copyWith(color: colors.textSecondary),
                ),
              ),
            ),
            // The cast, a little above the foot of the body, until the
            // hexagram stands; then casting afresh, at the left.
            ..._foot(
              theme,
              button: _done
                  ? null
                  : GlyphButton(
                      key: const ValueKey('iching-cast'),
                      glyph: Glyph.start,
                      lit: true,
                      filled: true,
                      onTap: _cast,
                    ),
              again: _done,
            ),
          ],
        );
      },
    );
  }

  // The foot of the body: at the centre the cast while it goes on; at
  // the left, in the red of what destroys, casting afresh once the
  // hexagram stands (by hand, once a line is set), so it is not touched
  // by accident (owner, 25 October 2026); and the toast over them.
  List<Widget> _foot(
    SmThemeData theme, {
    required Widget? button,
    required bool again,
  }) {
    final spacing = theme.spacing;
    return [
      Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(bottom: spacing.md + spacing.md),
          child: SizedBox(height: 56, child: Center(child: button)),
        ),
      ),
      if (again)
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.only(
              left: spacing.md,
              bottom: spacing.md + spacing.md,
            ),
            child: SizedBox(
              height: 56,
              child: Center(
                widthFactor: 1,
                child: GlyphButton(
                  key: const ValueKey('iching-again'),
                  glyph: Glyph.reset,
                  tint: dangerColor,
                  onTap: _again,
                ),
              ),
            ),
          ),
        ),
      Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(bottom: 56 + 2 * spacing.md),
          child: Toast(message: _toast),
        ),
      ),
    ];
  }

  /// The body when the lines are set by hand: what the numbers are, then
  /// the six lines, the top one highest, each its place's name, the line
  /// as it is set (a place waiting until it is) and its four numbers. The
  /// line to set next has its name in the accent; those above it wait,
  /// faint, until it is set.
  Widget _byHand(SmThemeData theme, Strings strings) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    const places = ['初', '二', '三', '四', '五', '上'];
    return Stack(
      children: [
        Column(
          children: [
            AnimatedOpacity(
              opacity: _lines.length < 6 ? 1 : 0,
              duration: theme.motion.medium,
              child: Column(
                key: const ValueKey('iching-hint'),
                children: [
                  Text(
                    strings.ichingManualAsk,
                    textAlign: TextAlign.center,
                    style: theme.type.label.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    strings.ichingManualNote,
                    key: const ValueKey('iching-method-note'),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.fade,
                    style: theme.type.caption.copyWith(
                      color: colors.textFaint,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing.sm),
            Expanded(
              child: LayoutBuilder(
                builder: (context, room) {
                  final row = math.min(
                    56.0,
                    math.max(0.0, room.maxHeight - 56 - 2 * spacing.md) / 6,
                  );
                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Column(
                        key: const ValueKey('iching-manual-rows'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var place = 5; place >= 0; place--)
                            SizedBox(
                              height: row,
                              child: _HandLine(
                                key: ValueKey('iching-manual-$place'),
                                place: places[place],
                                index: place,
                                value: place < _lines.length
                                    ? _lines[place]
                                    : null,
                                next: place == _lines.length,
                                open: place <= _lines.length,
                                onSet: (value) => _set(place, value),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        ..._foot(theme, button: null, again: _lines.isNotEmpty),
      ],
    );
  }

  void _toggle(_JournalSide side) {
    HapticFeedback.selectionClick();
    setState(() {
      _side = _side == side ? null : side;
      _anew = false;
    });
  }

  void _closeSide() {
    HapticFeedback.selectionClick();
    setState(() {
      _side = null;
      _anew = false;
    });
  }

  // The panel's cards: to and from the journal on the left (as the
  // bazi's Options have them), and the reading on the right, where the
  // hexagram it becomes is turned to. All three always stand, so nothing
  // moves as the hexagram comes to stand; what cannot be done yet is
  // faint.
  Widget _cards(Strings strings, IchingPack? pack, Entry? editing) {
    final cast = YijingCast(List.of(_lines));
    final primary = _done && pack != null ? pack.of(cast.primary) : null;
    return ActionCards(
      key: const ValueKey('iching-cast-cards'),
      compact: true,
      cards: [
        if (editing == null) ...[
          ActionCard(
            id: 'iching-load',
            glyph: Glyph.import,
            name: strings.ichingLoad,
            onTap: () => _toggle(_JournalSide.load),
          ),
          ActionCard(
            id: 'iching-save',
            glyph: Glyph.journal,
            name: strings.ichingSave,
            enabled: primary != null,
            onTap: () => _toggle(_JournalSide.save),
          ),
        ] else ...[
          ActionCard(
            id: 'iching-discard',
            glyph: Glyph.close,
            name: strings.ichingDiscard,
            onTap: () => _toggle(_JournalSide.discard),
          ),
          ActionCard(
            id: 'iching-save',
            glyph: Glyph.save,
            name: strings.ichingSaveHere,
            enabled: primary != null,
            onTap: () => _toggle(_JournalSide.save),
          ),
        ],
        ActionCard(
          id: 'iching-reading',
          glyph: Glyph.book,
          name: primary == null
              ? strings.ichingRead
              : '${primary.number} ${primary.name}',
          enabled: primary != null,
          onTap: () {
            HapticFeedback.selectionClick();
            pushIchingCastReading(context, cast: cast, pack: pack);
          },
        ),
      ],
    );
  }

  // Back to the cast, the panel's question unanswered: the same as the
  // back gesture.
  Widget _cancel(Strings strings) => BarButton(
    key: const ValueKey('iching-cancel'),
    label: strings.cancel,
    compact: true,
    onTap: _closeSide,
  );

  Widget _question(
    SmThemeData theme,
    String key,
    String question,
    List<Widget> answers,
  ) {
    final spacing = theme.spacing;
    return SingleChildScrollView(
      key: ValueKey(key),
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            question,
            style: theme.type.label.copyWith(
              color: theme.colors.textSecondary,
              height: 1.4,
            ),
          ),
          SizedBox(height: spacing.md),
          Row(
            children: [
              for (final (i, answer) in answers.indexed) ...[
                if (i > 0) SizedBox(width: spacing.sm),
                Expanded(child: answer),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// The lower panel while saving: for a cast that is an entry's (loaded
  /// from it), whether to change that entry or add another; for one the
  /// journal already holds, whether to add it again; then, for a new
  /// entry, which category it goes into.
  Widget _savePanel(SmThemeData theme, Strings strings) {
    final pack = _pack;
    final record = _record;
    if (pack == null || record == null) return const SizedBox.expand();
    final editing = _stillThere(_source);
    final source = editing ?? _sameCast();
    if (source == null || _anew) return _categories(theme, strings);
    final anew = BarButton(
      key: const ValueKey('iching-save-new'),
      label: strings.ichingSaveNew,
      compact: true,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _anew = true);
      },
    );
    if (editing == null) {
      return _question(
        theme,
        'iching-save-ask',
        strings.ichingSavedAsk(source.title),
        [anew, _cancel(strings)],
      );
    }
    return SingleChildScrollView(
      key: const ValueKey('iching-save-ask'),
      padding: EdgeInsets.all(theme.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.ichingSaveAsk(source.title),
            style: theme.type.label.copyWith(
              color: theme.colors.textSecondary,
              height: 1.4,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          Row(
            children: [
              Expanded(
                child: BarButton(
                  key: const ValueKey('iching-save-here'),
                  label: strings.ichingSaveHere,
                  compact: true,
                  onTap: () => _overwrite(source, strings, pack, record),
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(child: anew),
            ],
          ),
          SizedBox(height: theme.spacing.sm),
          _cancel(strings),
        ],
      ),
    );
  }

  /// Which of the journal's categories the cast goes into. Touching one
  /// opens the new entry, holding the cast, to be written in; it is in
  /// the journal only once its tick is touched.
  Widget _categories(SmThemeData theme, Strings strings) {
    final spacing = theme.spacing;
    final journal = JournalScope.of(context);
    return Padding(
      key: const ValueKey('iching-save-categories'),
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.ichingSaveTo,
            style: theme.type.caption.copyWith(
              color: theme.colors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: spacing.sm),
          PillRow(
            listKey: const ValueKey('iching-save-list'),
            inset: 0,
            children: [
              for (final category in journal.categories)
                _Category(
                  key: ValueKey('iching-save-${category.id}'),
                  category: category,
                  onTap: () => _save(category),
                ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(width: 140, child: _cancel(strings)),
          ),
        ],
      ),
    );
  }

  Future<void> _save(JournalCategory category) async {
    final pack = _pack;
    final record = _record;
    if (pack == null || record == null) return;
    HapticFeedback.selectionClick();
    // Dated by the moment it was cast, not the moment it was saved.
    final draft = Entry(
      id: '',
      date: record.date,
      minuteOfDay: record.minute,
      utcOffset: record.offset,
      categoryId: category.id,
      title: _autoTitle(pack, record),
      content: '',
      iching: record.value,
    );
    // Saved, the cast is no longer an entry's being changed.
    setState(() {
      _side = null;
      _anew = false;
      _source = null;
    });
    await Navigator.of(context).push(
      fadeRoute<void>(
        context,
        (context) => EntryScreen(
          date: draft.date,
          utcOffset: draft.utcOffset,
          minuteOfDay: draft.minuteOfDay,
          draft: draft,
        ),
      ),
    );
  }

  // Writes the cast over [source], keeping its day, category, writing and
  // tags; its title too, unless it is still the one the cast gave it.
  Future<void> _overwrite(
    Entry source,
    Strings strings,
    IchingPack pack,
    IchingRecord record,
  ) async {
    HapticFeedback.mediumImpact();
    final journal = JournalScope.of(context);
    final old = IchingRecord.parse(source.iching);
    final named = old == null || source.title != _autoTitle(pack, old);
    final entry = journal.save(
      source.copyWith(
        title: named ? null : _autoTitle(pack, record),
        iching: record.value,
      ),
    );
    setState(() {
      _side = null;
      _source = null;
    });
    // Opened from that very entry: back to it, which says what was done.
    if (widget.source?.id == entry.id) {
      Navigator.of(context).pop(strings.ichingRewritten);
      return;
    }
    await Navigator.of(context).push(
      fadeRoute<void>(
        context,
        (context) => EntryScreen(
          date: entry.date,
          utcOffset: entry.utcOffset,
          entry: entry,
          notice: strings.ichingRewritten,
        ),
      ),
    );
  }

  /// The lower panel asking whether to let go of the new cast and go back
  /// to the entry's.
  Widget _discardPanel(SmThemeData theme, Strings strings) {
    final entry = _stillThere(_source);
    return _question(
      theme,
      'iching-discard-ask',
      strings.ichingDiscardAsk(entry?.title ?? ''),
      [
        BarButton(
          key: const ValueKey('iching-discard-yes'),
          label: strings.ichingDiscard,
          compact: true,
          tint: dangerColor,
          primary: true,
          onTap: _discard,
        ),
        _cancel(strings),
      ],
    );
  }

  // Ends being the entry's cast, the cast back as the entry has it. Opened
  // from that entry, back to it, nothing changed.
  void _discard() {
    HapticFeedback.mediumImpact();
    final entry = _stillThere(_source);
    if (entry == null) return;
    if (widget.source?.id == entry.id) {
      Navigator.of(context).pop();
      return;
    }
    final record = IchingRecord.parse(entry.iching);
    setState(() {
      if (record != null) _apply(record, null);
      _source = null;
      _side = null;
      _anew = false;
    });
    _say(Strings.of(context).ichingDiscarded);
  }

  /// The lower panel while loading: every cast saved to the journal,
  /// newest first. One whose line is whole is loaded by a touch; one that
  /// is not is shown faint and cannot be.
  Widget _loadPanel(SmThemeData theme, Strings strings) {
    final spacing = theme.spacing;
    final colors = theme.colors;
    final journal = JournalScope.of(context);
    final casts = journal.allEntries().where((e) => e.iching != null).toList()
      ..sort(_newestFirst);
    if (casts.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Text(
            strings.ichingLoadNone,
            key: const ValueKey('iching-load-none'),
            textAlign: TextAlign.center,
            style: theme.type.label.copyWith(color: colors.textFaint),
          ),
        ),
      );
    }
    return ListView(
      key: const ValueKey('iching-load-list'),
      padding: EdgeInsets.symmetric(vertical: spacing.xs),
      children: [
        for (final entry in casts)
          Builder(
            builder: (context) {
              final record = IchingRecord.parse(entry.iching);
              final category = journal.category(entry.categoryId);
              return GestureDetector(
                key: ValueKey('iching-load-${entry.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: record == null ? null : () => _load(entry, record),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.md,
                    vertical: spacing.xs + 2,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: category?.color ?? colors.textFaint,
                        ),
                      ),
                      SizedBox(width: spacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.type.body.copyWith(
                                color: record == null
                                    ? colors.textFaint
                                    : entry.id == _source?.id
                                    ? colors.accent
                                    : colors.textPrimary,
                              ),
                            ),
                            Text(
                              record == null
                                  ? strings.ichingLoadUnusable
                                  : strings.ichingLoadCast(
                                      strings.gregorian(entry.date),
                                    ),
                              style: theme.type.caption.copyWith(
                                color: colors.textFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // The cast as [record] has it, and [entry] remembered as its own.
  void _load(Entry entry, IchingRecord record) {
    HapticFeedback.selectionClick();
    setState(() {
      _apply(record, entry);
      _side = null;
    });
    _say(Strings.of(context).ichingLoaded(entry.title));
  }
}

enum _JournalSide { save, load, discard }

/// One of the journal's categories, offered to take the cast: its dot and
/// its name.
class _Category extends StatelessWidget {
  final JournalCategory category;
  final VoidCallback onTap;

  const _Category({super.key, required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    return SmPressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: spacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: category.color),
          borderRadius: BorderRadius.circular(theme.radii.lg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: category.color,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: spacing.sm),
            Text(
              category.name,
              style: theme.type.label.copyWith(color: theme.colors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

/// The title of the entry whose cast this is, in a capsule of fixed width
/// in the bar: long titles are cut.
class _EntryCapsule extends StatelessWidget {
  final String title;

  const _EntryCapsule({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    return Container(
      key: const ValueKey('iching-entry-capsule'),
      width: 150,
      height: 44,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(color: colors.accent.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(theme.radii.lg),
      ),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.type.label.copyWith(color: colors.textPrimary),
      ),
    );
  }
}

/// One line set by hand: its place's name, the line as it is set, and the
/// four numbers it can be, the one chosen lit (in the accent where it is
/// a line that changes).
class _HandLine extends StatelessWidget {
  final String place;
  final int index;
  final LineValue? value;

  /// Whether this is the line to set next, and whether it can be set
  /// at all (it, and every line under it).
  final bool next;
  final bool open;
  final ValueChanged<LineValue> onSet;

  const _HandLine({
    super.key,
    required this.place,
    required this.index,
    required this.value,
    required this.next,
    required this.open,
    required this.onSet,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    return AnimatedOpacity(
      opacity: open ? 1 : 0.3,
      duration: theme.motion.medium,
      child: IgnorePointer(
        ignoring: !open,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.xs / 2),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  place,
                  textAlign: TextAlign.center,
                  style: theme.type.label.copyWith(
                    color: next ? colors.accent : colors.textFaint,
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              HexagramFigure(
                lines: [?value],
                places: 1,
                width: 76,
                color: colors.textPrimary,
                faint: colors.outline,
                mark: colors.accent,
              ),
              SizedBox(width: spacing.md),
              for (final (i, each) in LineValue.values.indexed) ...[
                if (i > 0) SizedBox(width: spacing.xs),
                Expanded(child: _choice(theme, each)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _choice(SmThemeData theme, LineValue each) {
    final colors = theme.colors;
    final chosen = value == each;
    final ink = chosen
        ? (each.changes ? colors.accent : colors.textPrimary)
        : colors.textSecondary;
    return GestureDetector(
      key: ValueKey('iching-manual-$index-${each.number}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onSet(each),
      child: AnimatedContainer(
        duration: theme.motion.fast,
        curve: theme.motion.curve,
        decoration: BoxDecoration(
          color: chosen
              ? colors.surfaceRaised
              : colors.surfaceRaised.withValues(alpha: 0),
          border: Border.all(
            color: chosen
                ? (each.changes ? colors.accent : colors.textSecondary)
                : colors.outline,
          ),
          borderRadius: BorderRadius.circular(theme.radii.md),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${each.number}',
                style: theme.type.body.copyWith(color: ink),
              ),
              SizedBox(width: theme.spacing.xs),
              HexagramFigure(
                lines: [each],
                places: 1,
                width: 18,
                color: ink,
                faint: ink,
                mark: each.changes ? colors.accent : ink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
