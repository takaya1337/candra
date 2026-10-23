import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import '../confirm_bar.dart';
import '../date_picker.dart';
import '../day_strip.dart';
import '../dot_picker.dart';
import '../glyph_button.dart';
import '../journal/categories_screen.dart';
import '../journal/entry.dart';
import '../house.dart';
import '../journal/journal_store.dart';
import '../month_grid.dart';
import '../app_shell.dart';
import '../parts.dart';
import '../scroll_bars.dart';
import '../search/search_screen.dart';
import '../strings.dart';
import '../system_months.dart';
import '../swipe_to_delete.dart';
import '../toast.dart';
import 'reminder.dart';
import 'reminder_screen.dart';
import 'reminder_store.dart';

/// Every reminder there is. It shares the journal's frame (the same top
/// bar, lower panel and bottom bar, the same categories) and none of its
/// main body, so the two are never mistaken for each other.
///
///  * Top bar: the day stood on, as a button that raises the date picker,
///    and at the right, deleting the reminders of the category in front.
///    Under them its weton, and across from it how many reminders there
///    are in all.
///  * Main body: the reminder rail. One category at a time, swiped
///    sideways to the next: the category's name, then its reminders
///    strung down a line, a ring on the line for each. A reminder that
///    falls on the day stood on has its ring filled and its tile lit.
///    All of a category's reminders are listed, not one day's.
///  * Lower panel: as in the journal, the search at the top left and the
///    categories and a new reminder at the top right, the category picker
///    between them, over the day strip. The date picker takes its place
///    when called for, and the delete question is answered at its foot.
///  * Bottom bar: the house's. The reminders are a room of the house
///    (`House`), between the practice and the journal.
///
/// A new reminder goes into the category on screen and starts on the day
/// stood on. The day is the house's, as in the journal.
class RemindersScreen extends StatefulWidget {
  final CivilDate day;

  /// For the journal, when switched to; the reminder store's if not given.
  final Duration? utcOffset;

  /// Today, for the today button; the clock's, unless a test says.
  final CivilDate? today;

  const RemindersScreen({
    super.key,
    required this.day,
    this.utcOffset,
    this.today,
  });

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with RoomDay<RemindersScreen> {
  late CivilDate _date = widget.day;
  late PageController _days = DayStrip.stripAt(widget.day);

  late final CivilDate _today =
      widget.today ?? CivilDate.fromDateTime(DateTime.now());

  // The rail: one page per category. Made once the categories are known.
  PageController? _pages;

  // The category on screen, and the categories as they were when the rail
  // was last put in step with it.
  String? _front;
  String _known = '';

  // True while the date picker has the lower panel.
  bool _picking = false;

  // True while the question "delete all of these?" is up.
  bool _confirming = false;

  // A reminder drawn aside and its delete touched: asked about first, in
  // the lower panel, as every delete is (owner, 20 October 2026).
  Reminder? _doomed;

  String? _toast;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _days.dispose();
    _pages?.dispose();
    super.dispose();
  }

  void _say(String message, {int seconds = 3}) {
    if (!mounted) return;
    _toastTimer?.cancel();
    _toastTimer = Timer(
      Duration(seconds: seconds),
      () => setState(() => _toast = null),
    );
    setState(() => _toast = message);
  }

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
      _date = date;
      _confirming = false;
    });
    if (byStrip) return;
    if (_days.hasClients) {
      _days.jumpToPage(date.dayNumber);
    } else {
      // The strip is out of the panel (the date picker has it): have it
      // come back on this day.
      _days.dispose();
      _days = DayStrip.stripAt(date);
    }
  }

  void _setPicking(bool picking) {
    HapticFeedback.selectionClick();
    // The strip comes back on the day stood on, wherever it was before.
    if (!picking && !_days.hasClients) {
      _days.dispose();
      _days = DayStrip.stripAt(_date);
    }
    setState(() {
      _picking = picking;
      _confirming = false;
    });
  }

  void _setConfirming(bool confirming) {
    HapticFeedback.selectionClick();
    setState(() => _confirming = confirming);
  }

  // Turns the rail to category [id], gliding if [glide].
  void _show(String id, {bool glide = true}) {
    final index = JournalScope.of(context).categories
        .indexWhere((c) => c.id == id);
    final pages = _pages;
    if (index < 0 || pages == null || !pages.hasClients) return;
    if (glide) {
      final motion = SmTheme.of(context).motion;
      pages.animateToPage(
        index,
        duration: motion.transition,
        curve: motion.transitionCurve,
      );
    } else {
      pages.jumpToPage(index);
    }
  }

  // Opens [reminder] for changes, or with none a new one in [categoryId].
  Future<void> _open(Reminder? reminder, {String? categoryId}) async {
    HapticFeedback.selectionClick();
    final strings = Strings.of(context);
    final store = ReminderScope.of(context);
    final saved = await pushReminder(
      context,
      reminder: reminder,
      day: _date,
      categoryId: categoryId,
    );
    if (saved == null || !mounted) return;
    // Come back to the category it was saved in.
    final home = saved.categoryId;
    if (home != null && home != _front) {
      setState(() => _front = home);
      _show(home, glide: false);
    }
    // The phone may need asking, the first time.
    if (!await store.askAllowed()) _say(strings.notificationsOff, seconds: 6);
  }

  // The categories screen: the journal's, and the same categories.
  Future<void> _manageCategories() async {
    HapticFeedback.selectionClick();
    await pushCategories(context);
  }

  void _toggle(Reminder reminder) {
    HapticFeedback.selectionClick();
    ReminderScope.of(context)
        .save(reminder.copyWith(enabled: !reminder.enabled));
  }

  void _deleteAll(List<Reminder> reminders) {
    HapticFeedback.mediumImpact();
    ReminderScope.of(context).deleteAll({for (final r in reminders) r.id});
    setState(() => _confirming = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final strings = Strings.of(context);
    final store = ReminderScope.of(context);
    final categories = JournalScope.of(context).categories;

    // Each reminder under its category. One whose category is not here
    // (made before reminders had them, or brought in from elsewhere) is
    // shown under the first, until it is given another.
    final byCategory = {
      for (final category in categories) category.id: <Reminder>[],
    };
    if (categories.isNotEmpty) {
      for (final reminder in store.reminders) {
        (byCategory[reminder.categoryId] ?? byCategory[categories.first.id]!)
            .add(reminder);
      }
    }
    for (final list in byCategory.values) {
      list.sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay));
    }
    final filled = [
      for (final category in categories)
        if (byCategory[category.id]!.isNotEmpty) category.id,
    ];
    // The category on screen: the one last shown if it still exists, else
    // the first with reminders, else the first.
    final front = categories.any((c) => c.id == _front)
        ? _front
        : (filled.firstOrNull ?? categories.firstOrNull?.id);
    _front = front;
    final frontIndex = categories.indexWhere((c) => c.id == front);
    final frontCategory = frontIndex < 0 ? null : categories[frontIndex];
    final inFront = byCategory[front] ?? const <Reminder>[];
    final canDelete = inFront.isNotEmpty;
    final confirming = _confirming && canDelete;
    // Either question up: the category's, or one reminder's.
    final asking = confirming || _doomed != null;
    final ringing = {for (final reminder in store.on(_date)) reminder.id};

    // The rail starts on the front category, and is put back on it when
    // categories are added or deleted underneath.
    final known = categories.map((c) => c.id).join(' ');
    if (_pages == null && frontIndex >= 0) {
      _pages = PageController(initialPage: frontIndex);
    } else if (known != _known && front != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _show(front, glide: false);
      });
    }
    _known = known;

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
                  key: const ValueKey('reminders-date'),
                  label: strings.gregorian(_date),
                  open: _picking,
                  onTap: () => _setPicking(!_picking),
                ),
                // Deleting every reminder of the category in front: at the
                // top right, in red, as in the journal.
                trailing: DeleteCardButton(
                  enabled: canDelete && !_picking,
                  onTap: () => _setConfirming(true),
                ),
                subtitle: '${Weton.of(_date)}',
                // How many there are in all, across from the weton, over
                // the category's own count.
                detail: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${strings.remindersTitle.toUpperCase()}'
                    ' · ${store.reminders.length}',
                    key: const ValueKey('reminder-count'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: theme.type.caption.copyWith(
                      color: colors.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              body: AnimatedOpacity(
                opacity: asking ? 0.04 : 1,
                duration: asking ? theme.motion.medium : Toast.makeWay,
                child: IgnorePointer(
                  ignoring: asking,
                  // With the date picker up, the body is the month, as in
                  // the journal: each day with a dot for every category
                  // with a reminder that day. Tapping a day goes to it.
                  child: _picking
                      ? _calendar(theme, strings, store, categories)
                      : categories.isEmpty
                      ? Center(
                          child: Text(
                            strings.noReminders,
                            style: theme.type.body.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        )
                      : PageView.builder(
                          key: const ValueKey('reminder-rail'),
                          controller: _pages,
                          itemCount: categories.length,
                          onPageChanged: (index) {
                            HapticFeedback.selectionClick();
                            setState(() => _front = categories[index].id);
                          },
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            return _RailPage(
                              key: ValueKey('rail-${category.id}'),
                              category: category,
                              emptyText: strings.noReminders,
                              tiles: [
                                for (final reminder in byCategory[category.id]!)
                                  _ReminderTile(
                                    reminder: reminder,
                                    hue: category.color,
                                    ringing: ringing.contains(reminder.id),
                                    repeat: strings.repeatLabel(
                                      reminder.repeat,
                                      reminder.start,
                                      store.utcOffset,
                                    ),
                                    next: _nextLine(strings, store, reminder),
                                    onTap: () => _open(reminder),
                                    onToggle: () => _toggle(reminder),
                                    // Drawn to the left, its own delete
                                    // button: this one reminder only.
                                    onDelete: () {
                                      HapticFeedback.selectionClick();
                                      setState(() => _doomed = reminder);
                                    },
                                  ),
                              ],
                            );
                          },
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
                                  key: const ValueKey('reminders-picker'),
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
                              : Column(
                                  key: const ValueKey('reminders-instrument'),
                                  children: [
                                    SizedBox(height: spacing.xs),
                                    // As in the journal: the search at the
                                    // top left, the categories and a new
                                    // reminder at the top right.
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: spacing.md,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: DotPicker(
                                              capsule: true,
                                              key: const ValueKey(
                                                'category-picker',
                                              ),
                                              dots: [
                                                for (final category
                                                    in categories)
                                                  (
                                                    id: category.id,
                                                    color: category.color,
                                                  ),
                                              ],
                                              hollow: {
                                                for (final category
                                                    in categories)
                                                  if (!filled.contains(
                                                    category.id,
                                                  ))
                                                    category.id,
                                              },
                                              selected: front,
                                              onPick: _show,
                                            ),
                                          ),
                                          SizedBox(width: spacing.sm),
                                          _searchButton(),
                                          SizedBox(width: spacing.sm),
                                          GlyphButton(
                                            key: const ValueKey('categories'),
                                            glyph: Glyph.categories,
                                            square: true,
                                            onTap: _manageCategories,
                                          ),
                                          SizedBox(width: spacing.sm),
                                          GlyphButton(
                                            key: const ValueKey('reminder-add'),
                                            glyph: Glyph.add,
                                            square: true,
                                            lit: true,
                                            onTap: front == null
                                                ? _manageCategories
                                                : () => _open(
                                                    null,
                                                    categoryId: front,
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: DayStrip(
                                        controller: _days,
                                        strings: strings,
                                        rings: true,
                                        dotsOf: (date) =>
                                            _ringsOn(store, categories, date),
                                        onArrived: (date) =>
                                            _setDate(date, byStrip: true),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: PanelFoot(
                      toast: Toast(
                        hurried: asking || _toast == null,
                        message: confirming
                            ? strings.deleteRemindersQuestion(
                                inFront.length,
                                frontCategory!.name,
                              )
                            : _doomed != null
                            ? strings.deleteReminderQuestion(_doomed!.title)
                            : _toast,
                      ),
                      answer: confirming
                          ? ConfirmBar(
                              key: const ValueKey('confirm-bar'),
                              label: strings.delete,
                              onConfirm: () => _deleteAll(inFront),
                              onCancel: () => _setConfirming(false),
                            )
                          : _doomed != null
                          ? ConfirmBar(
                              key: const ValueKey('confirm-bar'),
                              label: strings.delete,
                              onConfirm: () {
                                HapticFeedback.mediumImpact();
                                store.delete(_doomed!.id);
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

  /// The reminders' calendar: the month the date picker is on, each day
  /// with a dot for every category with a reminder on it, up to four.
  Widget _calendar(
    SmThemeData theme,
    Strings strings,
    ReminderStore store,
    List<JournalCategory> categories,
  ) => Column(
    key: const ValueKey('reminders-calendar'),
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
          span: SystemCalendar.of(SystemScope.of(context).value).monthOf(_date),
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
              store.marksOn(date, categories).take(MonthGrid.maxDots),
            ))
              category.color,
          ],
        ),
      ),
    ],
  );

  // The search, from here: what it looks in first is this screen's.
  Widget _searchButton() => GlyphButton(
    key: const ValueKey('reminders-search'),
    glyph: Glyph.search,
    square: true,
    onTap: () {
      HapticFeedback.selectionClick();
      pushSearch(
        context,
        date: _date,
        utcOffset: ReminderScope.of(context).utcOffset,
        fromReminders: true,
      );
    },
  );

  // The colours of the categories with a reminder on [date], each once.
  List<Color> _ringsOn(
    ReminderStore store,
    List<JournalCategory> categories,
    CivilDate date,
  ) {
    if (categories.isEmpty) return const [];
    final found = <JournalCategory>{};
    for (final reminder in store.on(date)) {
      found.add(
        categories.where((c) => c.id == reminder.categoryId).firstOrNull ??
            categories.first,
      );
    }
    return [for (final category in found.take(4)) category.color];
  }

  String _nextLine(Strings strings, ReminderStore store, Reminder reminder) {
    if (!reminder.enabled) return strings.reminderOff;
    final next = store.nextOf(reminder);
    return next == null
        ? strings.reminderOver
        : strings.reminderNext(strings.gregorian(next));
  }
}

/// One category on the reminder rail: its name beside a ring, how many
/// reminders it has, and then the reminders down a line, each hung from a
/// ring of its own.
class _RailPage extends StatelessWidget {
  final JournalCategory category;
  final List<_ReminderTile> tiles;
  final String emptyText;

  const _RailPage({
    super.key,
    required this.category,
    required this.tiles,
    required this.emptyText,
  });

  /// The width kept for the line and its rings.
  static const gutter = 22.0;

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final hue = category.color;

    Widget ring({required bool filled, double size = 9}) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? hue : colors.background,
        border: Border.all(color: hue, width: 1.4),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            // Its count over the tiles' right edge.
            padding: EdgeInsets.only(bottom: spacing.sm, right: spacing.sm),
            child: Row(
              children: [
                SizedBox(
                  width: gutter,
                  child: Center(child: ring(filled: false, size: 12)),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Text(
                    category.name.toUpperCase(),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: theme.type.label.copyWith(
                      color: hue,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                Text(
                  '${tiles.length}',
                  style: theme.type.label.copyWith(color: hue),
                ),
              ],
            ),
          ),
          Expanded(
            child: tiles.isEmpty
                ? Center(
                    child: Text(
                      emptyText,
                      style: theme.type.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  )
                : // The bar out in the page's margin, clear of the tiles
                  // (owner, 20 October 2026).
                  ScrollHintStyle(
                    // In the category's colour, as the journal's folders.
                    color: hue.withValues(alpha: 0.75),
                    inset: const EdgeInsets.only(right: -4),
                    child: SingleChildScrollView(
                      // The tiles end short of the bar, so it stands
                      // clear of them (owner, 20 October 2026).
                      padding: EdgeInsets.only(
                        bottom: spacing.md,
                        right: spacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final tile in tiles)
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // The line, and this reminder's ring on it.
                                  SizedBox(
                                    width: gutter,
                                    child: Stack(
                                      alignment: Alignment.topCenter,
                                      children: [
                                        Positioned(
                                          top: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 1.2,
                                            color: hue.withValues(alpha: 0.4),
                                          ),
                                        ),
                                        Positioned(
                                          top: spacing.md + 2,
                                          child: ring(filled: tile.ringing),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: spacing.sm),
                                  Expanded(child: tile),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// One reminder on the rail: its name, its repeat label and the next day
/// it falls on; on the right its time, and under that the bell that
/// switches it on and off, as wide as the time and standing on the same
/// line as the last of the words. Lit while it falls on the day stood on.
class _ReminderTile extends StatelessWidget {
  final Reminder reminder;
  final Color hue;
  final bool ringing;
  final String repeat;
  final String next;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ReminderTile({
    required this.reminder,
    required this.hue,
    required this.ringing,
    required this.repeat,
    required this.next,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: SwipeToDelete(
        name: reminder.id,
        onDelete: onDelete,
        child: GestureDetector(
          key: ValueKey('reminder-${reminder.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: theme.motion.medium,
            curve: theme.motion.curve,
            padding: EdgeInsets.all(spacing.md - spacing.xs),
            decoration: BoxDecoration(
              color: hue.withValues(alpha: ringing ? 0.2 : 0.05),
              border: Border.all(
                color: hue.withValues(alpha: ringing ? 0.95 : 0.28),
              ),
              borderRadius: BorderRadius.circular(theme.radii.sm + 2),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Opacity(
                      opacity: reminder.enabled ? 1 : 0.45,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reminder.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.type.body.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: spacing.xs),
                          Text(
                            repeat,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.type.label.copyWith(
                              color: colors.textPrimary.withValues(alpha: 0.8),
                            ),
                          ),
                          SizedBox(height: spacing.xs / 2),
                          Text(
                            next,
                            style: theme.type.caption.copyWith(
                              color: colors.textFaint,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: spacing.md),
                  // As wide as the time, whatever that is.
                  IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Opacity(
                          opacity: reminder.enabled ? 1 : 0.45,
                          child: Text(
                            reminder.time,
                            key: ValueKey('reminder-time-${reminder.id}'),
                            textAlign: TextAlign.center,
                            style: theme.type.label.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Switches it on and off: in the category's colour
                        // while on.
                        GlyphButton(
                          key: ValueKey('reminder-toggle-${reminder.id}'),
                          glyph: Glyph.reminder,
                          compact: true,
                          lit: reminder.enabled,
                          tint: reminder.enabled ? hue : null,
                          onTap: onToggle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
