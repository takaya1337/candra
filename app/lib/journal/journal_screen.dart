import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import '../confirm_bar.dart';
import '../date_picker.dart';
import '../day_strip.dart';
import '../dot_picker.dart';
import '../app_shell.dart';
import '../glyph_button.dart';
import '../month_grid.dart';
import '../parts.dart';
import '../house.dart';
import '../routes.dart';
import '../search/search_screen.dart';
import '../strings.dart';
import '../system_months.dart';
import '../toast.dart';
import 'card_stack.dart';
import 'categories_screen.dart';
import 'entry.dart';
import 'entry_screen.dart';
import 'journal_store.dart';

/// The journal, a day at a time, laid out as the month screen is.
///
///  * Top bar: the day, as a button that raises the date picker, and its
///    weton; at the right, deleting the card in front.
///  * Main body: the day's entries as a card stack, one card per category.
///  * Lower panel: at its top the search on the left, the category picker,
///    a dot for every category, and the categories and a new entry on the
///    right; under them the day strip, which is swiped to the day before
///    or after. The date picker takes its place when called for, and the
///    delete question is answered at its foot.
///  * Bottom bar: the house's. The journal is a room of the house
///    (`House`), the last on the right.
///
/// A new entry is always written in the category at the front, so that is
/// chosen here first: the picker has a dot for every category, hollow for
/// those with nothing on this day, and choosing one of those brings an
/// empty card to the front to be written in.
///
/// The day it is on is the house's: taken up as the room is entered, and
/// handed on as it is left.
class JournalScreen extends StatefulWidget {
  final CivilDate date;
  final Duration utcOffset;

  /// Today, for the today button; the clock's, unless a test says.
  final CivilDate? today;

  const JournalScreen({
    super.key,
    required this.date,
    required this.utcOffset,
    this.today,
  });

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen>
    with RoomDay<JournalScreen> {
  late CivilDate _date = widget.date;

  // The day strip: one page per day, numbered by the day itself. A new
  // one is made each time the strip comes back into the lower panel, so
  // that it always starts on the journal's day and never on the day it
  // was first opened with.
  late PageController _days = _stripAt(widget.date);

  PageController _stripAt(CivilDate date) => DayStrip.stripAt(date);

  // Which way the day last changed: 1 forward, -1 back. The cards come in
  // from that side.
  double _way = 1;

  // The category of the card at the front; null means the first.
  String? _front;

  // True while the date picker has the lower panel.
  bool _picking = false;

  // True while the question "delete this whole card?" is up.
  bool _confirming = false;

  // An entry drawn aside and its delete touched: asked about first, in
  // the lower panel, as every delete is (owner, 20 October 2026).
  Entry? _doomed;

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  late final CivilDate _today =
      widget.today ?? CivilDate.fromDateTime(DateTime.now());

  @override
  CivilDate get roomDay => _date;

  @override
  void enterDay(CivilDate day) => _setDate(day);

  // Straight to today, the strip gliding there if it is in the panel.
  void _goToToday() {
    if (_date == _today) return;
    if (_days.hasClients && (_date.dayNumber - _today.dayNumber).abs() <= 30) {
      final motion = SmTheme.of(context).motion;
      _days.animateToPage(
        _today.dayNumber,
        duration: motion.transition,
        curve: motion.transitionCurve,
      );
    } else {
      _setDate(_today);
    }
  }

  // Moves to another day. [byStrip] when the day strip did it, and so is
  // already there.
  void _setDate(CivilDate date, {bool byStrip = false}) {
    if (date == _date) return;
    setState(() {
      _way = date.dayNumber > _date.dayNumber ? 1 : -1;
      _date = date;
      _front = null;
      _confirming = false;
      _doomed = null;
    });
    if (byStrip) return;
    if (_days.hasClients) {
      _days.jumpToPage(date.dayNumber);
    } else {
      // The strip is out of the panel (the date picker has it): have it
      // come back on this day.
      _days.dispose();
      _days = _stripAt(date);
    }
  }

  void _setPicking(bool picking) {
    HapticFeedback.selectionClick();
    // The strip comes back on the journal's day, wherever it was before.
    if (!picking && !_days.hasClients) {
      _days.dispose();
      _days = _stripAt(_date);
    }
    setState(() {
      _picking = picking;
      _confirming = false;
    });
  }

  Future<void> _open(Entry? entry, {String? categoryId}) async {
    HapticFeedback.selectionClick();
    final shown = await Navigator.of(context).push(
      fadeRoute<String>(
        context,
        (context) => EntryScreen(
          date: _date,
          utcOffset: widget.utcOffset,
          entry: entry,
          categoryId: categoryId,
        ),
      ),
    );
    // Come back to the card of whatever was last read or written.
    if (shown == null || !mounted) return;
    // Unless its last entry was deleted there: then the card has gone,
    // and the first one leads again.
    final stillThere = JournalScope.of(context)
        .planesFor(_date, utcOffset: widget.utcOffset)
        .any((p) => p.category.id == shown);
    setState(() => _front = stillThere ? shown : null);
  }

  // A new entry goes into the category at the front. With no categories
  // at all, one has to be made first.
  Future<void> _addEntry(String? front) async {
    if (front == null) return _manageCategories();
    return _open(null, categoryId: front);
  }

  // The categories screen, for managing them only.
  Future<void> _manageCategories() async {
    HapticFeedback.selectionClick();
    await pushCategories(context);
  }

  void _setConfirming(bool confirming) {
    HapticFeedback.selectionClick();
    setState(() => _confirming = confirming);
  }

  void _deleteCard(String categoryId) {
    HapticFeedback.mediumImpact();
    JournalScope.of(context)
        .deleteCard(_date, categoryId, utcOffset: widget.utcOffset);
    // The card is gone; the first one left leads.
    setState(() {
      _confirming = false;
      _front = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final strings = Strings.of(context);
    final store = JournalScope.of(context);
    final written = store.planesFor(_date, utcOffset: widget.utcOffset);
    final categories = store.categories;

    // The front: what was asked for if it still exists, else the first
    // card, else the first category.
    final front = categories.any((c) => c.id == _front)
        ? _front
        : (written.isNotEmpty
              ? written.first.category.id
              : categories.firstOrNull?.id);
    // The cards: one per category with entries today, and an empty one
    // for the front category if it has none.
    final planes = [
      for (final category in categories)
        ?written.where((p) => p.category.id == category.id).firstOrNull ??
            (category.id == front
                ? JournalPlane(category: category, entries: const [])
                : null),
    ];
    final frontPlane = planes.where((p) => p.category.id == front).firstOrNull;
    final canDelete = frontPlane != null && frontPlane.entries.isNotEmpty;
    final confirming = _confirming && canDelete;
    // Either question up: the card's, or one entry's.
    final asking = confirming || _doomed != null;

    tellDay();
    return PopScope(
      // Back takes back the question, then the picker; then the house's
      // own back has it.
      canPop: !asking && !_picking,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_doomed != null) {
          setState(() => _doomed = null);
        } else if (confirming) {
          _setConfirming(false);
        } else if (_picking) {
          _setPicking(false);
        }
      },
      child: Recentre(
        onToday: _goToToday,
        atToday: _date == _today,
        child: ColoredBox(
          color: colors.background,
          child: SafeArea(
            child: FourParts(
              top: TopBar(
                leading: TopBarButton(
                  key: const ValueKey('journal-date'),
                  label: strings.gregorian(_date),
                  open: _picking,
                  onTap: () => _setPicking(!_picking),
                ),
                subtitle: '${Weton.of(_date)}',
                // Deleting the card in front: at the top right, in red.
                // Nothing to delete where the front card is empty.
                trailing: DeleteCardButton(
                  enabled: canDelete && !_picking,
                  onTap: () => _setConfirming(true),
                ),
              ),
              body: Padding(
                padding: EdgeInsets.fromLTRB(
                  spacing.sm,
                  0,
                  spacing.sm,
                  spacing.md,
                ),
                child: AnimatedOpacity(
                  opacity: asking ? 0.04 : 1,
                  duration: asking ? theme.motion.medium : Toast.makeWay,
                  child: IgnorePointer(
                    ignoring: asking,
                    // With the date picker up, the body is the
                    // journal's own calendar: the month, with a
                    // dot for every category written in that
                    // day. This is where the journal is seen on
                    // a calendar; the calendar itself shows
                    // reminders.
                    child: _picking
                        ? _calendar(theme, strings, store)
                        : AnimatedSwitcher(
                            duration: theme.motion.transition,
                            switchInCurve: theme.motion.transitionCurve,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) {
                              final incoming =
                                  child.key == ValueKey(_date.dayNumber);
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween(
                                    begin: Offset(
                                      (incoming ? _way : -_way) * 0.35,
                                      0,
                                    ),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: KeyedSubtree(
                              key: ValueKey(_date.dayNumber),
                              child: planes.isEmpty
                                  ? Center(
                                      child: Text(
                                        strings.nothingLogged,
                                        style: theme.type.body.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    )
                                  : CardStack(
                                      planes: planes,
                                      front: front,
                                      emptyText: strings.nothingLogged,
                                      onFront: (id) =>
                                          setState(() => _front = id),
                                      onOpenEntry: _open,
                                      // Drawn to the left, an entry shows its own
                                      // delete button: that one entry only.
                                      onDeleteEntry: (entry) {
                                        HapticFeedback.selectionClick();
                                        setState(() => _doomed = entry);
                                      },
                                    ),
                            ),
                          ),
                  ),
                ),
              ),
              panel: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: asking ? 0.04 : 1,
                      duration: confirming
                          ? theme.motion.medium
                          : Toast.makeWay,
                      child: IgnorePointer(
                        ignoring: asking,
                        child: AnimatedSwitcher(
                          duration: theme.motion.medium,
                          child: _picking
                              ? Stack(
                                  key: const ValueKey('journal-picker'),
                                  children: [
                                    Positioned.fill(
                                      child: Center(
                                        child: DatePicker(
                                          date: _date,
                                          strings: strings,
                                          onChanged: _setDate,
                                        ),
                                      ),
                                    ),
                                    // The search stays where it was, left of the
                                    // categories and the new one (owner, 15 and 20
                                    // October 2026).
                                    Positioned(
                                      right: spacing.md + 2 * (40 + spacing.sm),
                                      top: spacing.xs,
                                      child: _searchButton(),
                                    ),
                                  ],
                                )
                              : _instrument(
                                  theme,
                                  strings,
                                  store,
                                  front,
                                  canDelete,
                                  {
                                    for (final category in categories)
                                      if (!written.any(
                                        (p) => p.category.id == category.id,
                                      ))
                                        category.id,
                                  },
                                ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: PanelFoot(
                      toast: Toast(
                        hurried: true,
                        message: confirming
                            ? strings.deleteCardQuestion(
                                frontPlane.entries.length,
                                frontPlane.category.name,
                                strings.gregorian(_date),
                              )
                            : _doomed != null
                            ? strings.deleteEntryQuestion
                            : null,
                      ),
                      answer: confirming
                          ? ConfirmBar(
                              key: const ValueKey('confirm-bar'),
                              label: strings.delete,
                              onConfirm: () =>
                                  _deleteCard(frontPlane.category.id),
                              onCancel: () => _setConfirming(false),
                            )
                          : _doomed != null
                          ? ConfirmBar(
                              key: const ValueKey('confirm-bar'),
                              label: strings.delete,
                              onConfirm: () {
                                HapticFeedback.mediumImpact();
                                store.delete(_doomed!);
                                setState(() => _doomed = null);
                              },
                              onCancel: () {
                                HapticFeedback.selectionClick();
                                setState(() => _doomed = null);
                              },
                            )
                          : null,
                    ),
                  ),
                ],
              ),
              bar: const RoomBar(),
            ),
          ),
        ),
      ),
    );
  }

  /// The journal's calendar: the month the date picker is on, each day
  /// with a dot for every category written in that day, up to four.
  /// Tapping a day goes to it.
  Widget _calendar(SmThemeData theme, Strings strings, JournalStore store) =>
      Column(
        key: const ValueKey('journal-calendar'),
        children: [
          Row(
            children: [
              for (final initial in strings.weekdayInitials)
                Expanded(
                  child: Center(
                    child: Text(
                      initial,
                      style: theme.type.label.copyWith(
                        color: theme.colors.textFaint,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          Expanded(
            child: MonthGrid(
              // The month of the system the calendar is in, as the calendar
              // counts it.
              span: SystemCalendar.of(SystemScope.of(context).value)
                  .monthOf(_date),
              shifted: SystemCalendar.of(SystemScope.of(context).value).shifts,
              system: SystemScope.of(context).value,
              today: _today,
              selected: _date,
              onSelect: (date) {
                HapticFeedback.selectionClick();
                _setDate(date);
              },
              dotsOf: (date) => [
                for (final category in byHue(
                  store
                      .marksOn(date, utcOffset: widget.utcOffset)
                      .take(MonthGrid.maxDots),
                ))
                  category.color,
              ],
            ),
          ),
        ],
      );

  /// What the lower panel holds when nothing else has it: the category
  /// picker over the day strip.
  Widget _instrument(
    SmThemeData theme,
    Strings strings,
    JournalStore store,
    String? front,
    bool canDelete,
    Set<String> empty,
  ) => Column(
    key: const ValueKey('journal-instrument'),
    children: [
      SizedBox(height: theme.spacing.xs),
      // The search at the top left; the categories and a new entry at the
      // top right; the category picker between them.
      Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.spacing.md),
        child: Row(
          children: [
            Expanded(
              child: DotPicker(
                capsule: true,
                key: const ValueKey('category-picker'),
                dots: [
                  for (final category in store.categories)
                    (id: category.id, color: category.color),
                ],
                hollow: empty,
                selected: front,
                onPick: (id) => setState(() => _front = id),
              ),
            ),
            SizedBox(width: theme.spacing.sm),
            _searchButton(),
            SizedBox(width: theme.spacing.sm),
            GlyphButton(
              key: const ValueKey('categories'),
              glyph: Glyph.categories,
              square: true,
              onTap: _manageCategories,
            ),
            SizedBox(width: theme.spacing.sm),
            GlyphButton(
              key: const ValueKey('new-entry'),
              glyph: Glyph.add,
              square: true,
              lit: true,
              onTap: () => _addEntry(front),
            ),
          ],
        ),
      ),
      Expanded(
        child: DayStrip(
          controller: _days,
          strings: strings,
          dotsOf: (date) => [
            for (final category
                in store.marksOn(date, utcOffset: widget.utcOffset).take(4))
              category.color,
          ],
          onArrived: (date) => _setDate(date, byStrip: true),
        ),
      ),
    ],
  );

  // The search, from here: what it looks in first is this screen's.
  Widget _searchButton() => GlyphButton(
    key: const ValueKey('journal-search'),
    glyph: Glyph.search,
    square: true,
    onTap: () {
      HapticFeedback.selectionClick();
      pushSearch(
        context,
        date: _date,
        utcOffset: widget.utcOffset,
        fromReminders: false,
      );
    },
  );
}
