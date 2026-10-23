import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import '../bar_button.dart';
import '../bazi/two_wheels.dart';
import '../glyph_button.dart';
import '../house.dart';
import '../journal/entry.dart';
import '../journal/entry_screen.dart';
import '../journal/journal_store.dart';
import '../parts.dart';
import '../reminders/reminder.dart';
import '../reminders/reminder_screen.dart';
import '../reminders/reminder_store.dart';
import '../routes.dart';
import '../sky_place.dart';
import '../strings.dart';
import 'query.dart';
import 'tags_ui.dart';

/// Opens the search from the journal or the reminders, on [date]. It
/// looks first in what it was opened from.
Future<void> pushSearch(
  BuildContext context, {
  required CivilDate date,
  required Duration utcOffset,
  required bool fromReminders,
}) => Navigator.of(context).push(
  fadeRoute<void>(
    context,
    (context) => SearchScreen(
      date: date,
      utcOffset: utcOffset,
      fromReminders: fromReminders,
    ),
  ),
);

/// The fields of a query, chosen on the strip in the lower panel.
enum SearchField { lookIn, category, tags, day, evening, when, words }

/// How what is found is shown: a list, or laid on a month or a year.
enum SearchView { list, month, year }

/// The search: the journal and the reminders asked by category, tag,
/// words, and by any cycle of the calendars ("every entry on Kliwon",
/// "the garden notes at full moon"), with the evening counted as the day
/// before or the day after as the asker reckons.
///
///  * Top bar: the name, how many were found, and the query in a line.
///  * Main body: what was found. A list by default, newest first (the
///    reminders soonest first, at the first of their days that fits); or
///    laid on a month or a year, where the days that fit the cycles are
///    shaded and the days with something found carry its colours, so a
///    pattern shows.
///  * Lower panel: the fields of the query as a strip, and the instrument
///    for the one chosen.
///  * Top bar, at the right: how many were found, and the view.
///  * Clearing the query: at the body's bottom right, only while there is
///    something to clear.
///  * Bottom bar: the house's; while the words are typed, theirs. The
///    search is opened in the journal or the reminders and stays in that
///    room.
class SearchScreen extends StatefulWidget {
  final CivilDate date;
  final Duration utcOffset;
  final bool fromReminders;

  /// Today; the clock's unless a test says.
  final CivilDate? today;

  const SearchScreen({
    super.key,
    required this.date,
    required this.utcOffset,
    this.fromReminders = false,
    this.today,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late SearchQuery _query = SearchQuery(
    entries: !widget.fromReminders,
    reminders: widget.fromReminders,
  );
  SearchField _field = SearchField.day;
  SearchView _view = SearchView.list;

  // The month or the year shown: the one this day is in.
  late CivilDate _anchor = widget.date;

  // A day touched on the month or the year: the list is narrowed to it.
  CivilDate? _onlyDay;

  // The day wheels: the cycle, and the value under it.
  int _kind = CycleKind.pasaran.index;
  final _values = <int, int>{};

  // The words, being typed in the bar.
  bool _wording = false;
  final _words = TextEditingController();
  final _wordsFocus = FocusNode();

  late final CivilDate _today =
      widget.today ?? CivilDate.fromDateTime(DateTime.now());

  // What was found, and what it was found for.
  Object? _asked;
  var _entryHits = <SearchHit>[];
  var _reminderHits = <SearchHit>[];

  // Sunsets worked out so far, by day number.
  final _sunsets = <int, int?>{};

  @override
  void dispose() {
    _words.dispose();
    _wordsFocus.dispose();
    super.dispose();
  }

  int? Function(CivilDate date)? get _sunset {
    final place = SkyPlace.current.value;
    if (place == null) return null;
    return (date) => _sunsets.putIfAbsent(
      date.dayNumber,
      () => Sky.sun(
        date,
        latitude: place.latitude,
        longitude: place.longitude,
        utcOffset: widget.utcOffset,
      ).set,
    );
  }

  void _set(SearchQuery query) {
    HapticFeedback.selectionClick();
    setState(() {
      _query = query;
      _onlyDay = null;
    });
  }

  void _choose(SearchField field) {
    HapticFeedback.selectionClick();
    // Look in has nothing under it: its own button goes round entries,
    // reminders and both.
    if (field == SearchField.lookIn) {
      final (entries, reminders) = switch ((_query.entries, _query.reminders)) {
        (true, false) => (false, true),
        (false, true) => (true, true),
        _ => (true, false),
      };
      _query = _query.copyWith(entries: entries, reminders: reminders);
      _onlyDay = null;
    }
    // Moving off the words puts the keyboard away, keeping what was
    // typed.
    if (_wording && field != SearchField.words) _doneWording();
    setState(() => _field = field);
    if (field == SearchField.words) _startWording();
  }

  void _startWording() {
    setState(() => _wording = true);
    _words.text = _query.words;
    _wordsFocus.requestFocus();
  }

  void _doneWording() {
    _wordsFocus.unfocus();
    setState(() {
      _wording = false;
      _query = _query.copyWith(words: _words.text.trim());
    });
  }

  void _nextView() {
    HapticFeedback.selectionClick();
    setState(() {
      _view = SearchView.values[(_view.index + 1) % 3];
      _onlyDay = null;
    });
  }

  // Today, on the month or the year.
  void _anchorToday() => setState(() {
    _anchor = _today;
    _onlyDay = null;
  });

  void _clear() {
    HapticFeedback.selectionClick();
    setState(() {
      _query = SearchQuery(
        entries: _query.entries,
        reminders: _query.reminders,
      );
      _onlyDay = null;
      _words.clear();
    });
  }

  Future<void> _openEntry(Entry entry) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      fadeRoute<String>(
        context,
        (context) => EntryScreen(
          date: entry.date,
          utcOffset: entry.utcOffset,
          entry: entry,
          categoryId: entry.categoryId,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openReminder(Reminder reminder, CivilDate day) async {
    HapticFeedback.selectionClick();
    await pushReminder(context, reminder: reminder, day: day);
    if (mounted) setState(() {});
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final strings = Strings.of(context);
    final journal = JournalScope.of(context);
    final reminders = ReminderScope.of(context);
    final sunset = _query.evening == Evening.sunset ? _sunset : null;

    // Asked again only when the query or what it is asked of changes.
    final asked = (
      _query,
      journal.revision,
      reminders.revision,
      SkyPlace.current.value,
    );
    if (asked != _asked) {
      _asked = asked;
      _entryHits = _query.searchEntries(
        journal,
        sunset: sunset,
        place: SkyPlace.current.value,
      );
      _reminderHits = _query.searchReminders(
        reminders,
        from: _today,
        sunset: sunset,
      );
    }
    final entryHits = _entryHits;
    final reminderHits = _reminderHits;
    final only = _onlyDay;
    final shownEntries = only == null
        ? entryHits
        : [
            for (final hit in entryHits)
              if (hit.day == only) hit,
          ];
    final shownReminders = only == null
        ? reminderHits
        : [
            for (final reminder in _query.remindersOn(
              reminders,
              only,
              sunset: sunset,
            ))
              SearchHit.reminder(reminder, only, only),
          ];
    final count = shownEntries.length + shownReminders.length;

    return PopScope(
      canPop: !_wording && only == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_wording) {
          _doneWording();
        } else {
          setState(() => _onlyDay = null);
        }
      },
      child: ColoredBox(
        color: colors.background,
        child: SafeArea(
          child: Recentre(
            enabled: _view != SearchView.list,
            onToday: _anchorToday,
            atToday: _view == SearchView.year
                ? _anchor.year == _today.year
                : _anchor.year == _today.year && _anchor.month == _today.month,
            child: FourParts(
              top: TopBar(
                key: const ValueKey('search-top-bar'),
                leading: TopBarTitle(label: strings.searchTitle),
                // How many were found, left of the view: the view at the
                // top right, as on the calendar.
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.searchFound(count),
                      key: const ValueKey('search-count'),
                      style: theme.type.caption.copyWith(
                        color: colors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(width: spacing.md),
                    // Its glyph is the view a touch goes to.
                    GlyphButton(
                      key: const ValueKey('search-view'),
                      glyph: switch (_view) {
                        SearchView.list => Glyph.monthView,
                        SearchView.month => Glyph.yearView,
                        SearchView.year => Glyph.list,
                      },
                      square: true,
                      onTap: _nextView,
                    ),
                  ],
                ),
                subtitle: only != null
                    ? strings.gregorian(only)
                    : _summary(strings, journal),
              ),
              body: Stack(
                children: [
                  Positioned.fill(
                    child: switch (_view) {
                      SearchView.list => _list(
                        theme,
                        strings,
                        journal,
                        reminders,
                        shownEntries,
                        shownReminders,
                      ),
                      SearchView.month => _month(
                        theme,
                        strings,
                        journal,
                        reminders,
                        entryHits,
                        sunset,
                      ),
                      SearchView.year => _year(
                        theme,
                        strings,
                        journal,
                        reminders,
                        entryHits,
                        sunset,
                      ),
                    },
                  ),
                  // Clearing the query: at the body's bottom right, and only
                  // while there is something to clear.
                  Positioned(
                    right: 0,
                    bottom: spacing.md,
                    child: AnimatedSwitcher(
                      duration: theme.motion.medium,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween(begin: 0.8, end: 1.0).animate(animation),
                          child: child,
                        ),
                      ),
                      child: _query.isOpen && only == null
                          ? const SizedBox.shrink()
                          : GlyphButton(
                              key: const ValueKey('search-clear'),
                              glyph: Glyph.close,
                              square: true,
                              onTap: _clear,
                            ),
                    ),
                  ),
                ],
              ),
              // The query is made in the panel, so it has more room than
              // elsewhere: 9 against 13, where most screens have 4. As the
              // keyboard rises for the words the panel gives way to it, as
              // much as it rises, down to the fields and the hint; so the
              // list holds still, and only gives way once the panel cannot.
              // Leaving, the same in reverse.
              panelFlex: 9,
              panelSize: (share, keyboard) =>
                  math.max(_fieldsHeight + 56, share - keyboard),
              panel: _panel(theme, strings, journal),
              // The house's bar; while the words are typed, theirs. Only the
              // bar hears the keyboard move.
              bar: RoomBar(
                typing: _wording
                    ? Builder(
                        builder: (context) => BottomBar(
                          padding: EdgeInsets.all(spacing.md).copyWith(
                            bottom:
                                spacing.md +
                                MediaQuery.viewInsetsOf(context).bottom,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            border: Border(
                              top: BorderSide(color: colors.outline),
                            ),
                          ),
                          child: _wordsBar(theme, strings),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The query in a line: the cycles, then the categories and the tags.
  String _summary(Strings strings, JournalStore journal) {
    final parts = <String>[
      for (final MapEntry(key: kind, value: values) in _query.cycles.entries)
        [for (final v in values) strings.cycleValue(kind, v)].join(' / '),
      for (final id in _query.categories) ?journal.category(id)?.name,
      for (final id in _query.tags)
        if (journal.tag(id) case final tag?) '#${tag.name}',
      if (_query.words.isNotEmpty) '"${_query.words}"',
      if (_query.byMoment && _query.hasCycles)
        strings.searchWhenName(byMoment: true).toLowerCase(),
    ];
    return parts.isEmpty ? strings.searchAnyDay : parts.join(' · ');
  }

  Widget _wordsBar(SmThemeData theme, Strings strings) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    return Row(
      key: const ValueKey('search-words-bar'),
      children: [
        GlyphButton(
          key: const ValueKey('search-words-clear'),
          glyph: Glyph.close,
          square: true,
          onTap: () => _words.clear(),
        ),
        SizedBox(width: spacing.sm),
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.md,
              vertical: spacing.sm + 1,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: colors.outline),
              borderRadius: BorderRadius.circular(theme.radii.md),
            ),
            child: SmTextField(
              key: const ValueKey('search-words'),
              controller: _words,
              focusNode: _wordsFocus,
              labels: strings.textToolbar,
              placeholder: strings.searchWordsPlaceholder,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _doneWording(),
              style: theme.type.body.copyWith(color: colors.textPrimary),
            ),
          ),
        ),
        SizedBox(width: spacing.sm),
        GlyphButton(
          key: const ValueKey('search-words-done'),
          glyph: Glyph.save,
          square: true,
          lit: true,
          onTap: _doneWording,
        ),
      ],
    );
  }

  // The list: the reminders found, soonest first, then the entries,
  // newest first.
  Widget _list(
    SmThemeData theme,
    Strings strings,
    JournalStore journal,
    ReminderStore reminders,
    List<SearchHit> entries,
    List<SearchHit> found,
  ) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    if (entries.isEmpty && found.isEmpty) {
      return Center(
        child: Text(
          strings.searchNothing,
          key: const ValueKey('search-nothing'),
          style: theme.type.body.copyWith(color: colors.textSecondary),
        ),
      );
    }
    Widget heading(String text) => Padding(
      padding: EdgeInsets.fromLTRB(spacing.xs, spacing.sm, 0, spacing.xs),
      child: Text(
        text.toUpperCase(),
        style: theme.type.caption.copyWith(
          color: colors.textFaint,
          letterSpacing: 1.2,
        ),
      ),
    );
    final both = entries.isNotEmpty && found.isNotEmpty;
    return ListView(
      key: const ValueKey('search-list'),
      padding: EdgeInsets.only(bottom: spacing.md),
      children: [
        if (both) heading(strings.searchReminders),
        for (final hit in found)
          _ResultTile(
            key: ValueKey('search-reminder-${hit.reminder!.id}'),
            hue:
                journal.category(hit.reminder!.categoryId)?.color ??
                colors.accent,
            when:
                '${strings.searchNextOn(strings.gregorian(hit.date))}'
                ' · ${hit.reminder!.time}',
            counted: hit.day == hit.date ? null : '${Weton.of(hit.day)}',
            title: hit.reminder!.title,
            detail: strings.repeatLabel(
              hit.reminder!.repeat,
              hit.reminder!.start,
              reminders.utcOffset,
            ),
            tags: _tagNames(journal, hit.reminder!.tags),
            bell: true,
            onTap: () => _openReminder(hit.reminder!, hit.date),
          ),
        if (both) heading(strings.searchEntries),
        for (final hit in entries)
          _ResultTile(
            key: ValueKey('search-entry-${hit.entry!.id}'),
            hue:
                journal.category(hit.entry!.categoryId)?.color ?? colors.accent,
            when:
                '${strings.gregorian(hit.date)} · ${Weton.of(hit.date)}'
                ' · ${_two(hit.entry!.minuteOfDay ~/ 60)}:'
                '${_two(hit.entry!.minuteOfDay % 60)}',
            counted: hit.day == hit.date ? null : '${Weton.of(hit.day)}',
            title: hit.entry!.title.isEmpty
                ? hit.entry!.content.split('\n').first
                : hit.entry!.title,
            detail: hit.entry!.title.isEmpty
                ? ''
                : hit.entry!.content.split('\n').first,
            tags: _tagNames(journal, hit.entry!.tags),
            onTap: () => _openEntry(hit.entry!),
          ),
      ],
    );
  }

  static List<String> _tagNames(JournalStore journal, List<String> ids) => [
    for (final id in ids) ?journal.tag(id)?.name,
  ];

  // The colours of what was found on [date]: a category's once, the
  // earliest first, up to four.
  List<Color> _colorsOn(
    CivilDate date,
    Map<int, List<Color>> entryColors,
    JournalStore journal,
    ReminderStore reminders,
    int? Function(CivilDate)? sunset,
  ) {
    final colors = <Color>[...?entryColors[date.dayNumber]];
    for (final reminder in _query.remindersOn(
      reminders,
      date,
      sunset: sunset,
    )) {
      final hue = journal.category(reminder.categoryId)?.color;
      if (hue != null && !colors.contains(hue)) colors.add(hue);
    }
    return colors.take(4).toList();
  }

  Map<int, List<Color>> _entryColors(
    List<SearchHit> hits,
    JournalStore journal,
  ) {
    final byDay = <int, List<Color>>{};
    for (final hit in hits.reversed) {
      final hue = journal.category(hit.entry!.categoryId)?.color;
      if (hue == null) continue;
      // On the day it was counted as: under an evening rule, Wednesday
      // night's entry stands on Thursday, inside the pattern asked for.
      final day = byDay.putIfAbsent(hit.day.dayNumber, () => []);
      if (!day.contains(hue)) day.add(hue);
    }
    return byDay;
  }

  void _showDay(CivilDate date) {
    HapticFeedback.selectionClick();
    setState(() {
      _onlyDay = date;
      _view = SearchView.list;
    });
  }

  Widget _month(
    SmThemeData theme,
    Strings strings,
    JournalStore journal,
    ReminderStore reminders,
    List<SearchHit> hits,
    int? Function(CivilDate)? sunset,
  ) {
    final entryColors = _entryColors(hits, journal);
    return _Paged(
      key: const ValueKey('search-month'),
      page: _anchor.year * 12 + _anchor.month - 1,
      onPage: (page) =>
          setState(() => _anchor = CivilDate(page ~/ 12, page % 12 + 1, 1)),
      title: (page) => '${strings.monthNames[page % 12]} ${page ~/ 12}',
      builder: (page) => _SearchMonth(
        year: page ~/ 12,
        month: page % 12 + 1,
        today: _today,
        weekdays: strings.weekdayInitials,
        fits: (date) =>
            _query.hasCycles &&
            _query.dayMatches(date, utcOffset: widget.utcOffset),
        colorsOf: (date) =>
            _colorsOn(date, entryColors, journal, reminders, sunset),
        onTap: _showDay,
      ),
    );
  }

  Widget _year(
    SmThemeData theme,
    Strings strings,
    JournalStore journal,
    ReminderStore reminders,
    List<SearchHit> hits,
    int? Function(CivilDate)? sunset,
  ) {
    final entryColors = _entryColors(hits, journal);
    return _Paged(
      key: const ValueKey('search-year'),
      page: _anchor.year,
      onPage: (page) => setState(() => _anchor = CivilDate(page, 1, 1)),
      title: (page) => '$page',
      builder: (page) => _SearchYear(
        year: page,
        today: _today,
        months: [for (final name in strings.monthNames) name.substring(0, 3)],
        describe: (date) => '${strings.gregorian(date)} · ${Weton.of(date)}',
        fits: (date) =>
            _query.hasCycles &&
            _query.dayMatches(date, utcOffset: widget.utcOffset),
        colorsOf: (date) =>
            _colorsOn(date, entryColors, journal, reminders, sunset),
        onTap: _showDay,
      ),
    );
  }

  // The lower panel: the fields as a strip, and the chosen one's
  // instrument under it.
  Widget _panel(SmThemeData theme, Strings strings, JournalStore journal) {
    final spacing = theme.spacing;
    final labels = {
      SearchField.lookIn: switch ((_query.entries, _query.reminders)) {
        (true, false) => strings.searchEntries,
        (false, true) => strings.searchReminders,
        _ => strings.searchBoth,
      },
      SearchField.category: strings.searchCategory,
      SearchField.tags: strings.searchTags,
      SearchField.day: strings.searchDay,
      SearchField.evening: strings.searchEvening,
      SearchField.when: strings.searchWhen,
      SearchField.words: strings.searchWords,
    };
    bool active(SearchField field) => switch (field) {
      SearchField.lookIn => false,
      SearchField.category => _query.categories.isNotEmpty,
      SearchField.tags => _query.tags.isNotEmpty,
      SearchField.day => _query.cycles.isNotEmpty,
      SearchField.evening => _query.evening != Evening.midnight,
      SearchField.when => _query.byMoment,
      SearchField.words => _query.words.isNotEmpty,
    };
    return Column(
      key: const ValueKey('search-panel'),
      children: [
        SizedBox(height: spacing.sm),
        // Under the row, room for its bar: it runs on past the edge.
        SizedBox(
          height: 40 + _barRoom,
          child: ListView(
            key: const ValueKey('search-fields'),
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(spacing.md, 0, spacing.md, _barRoom),
            children: [
              for (final field in SearchField.values)
                Padding(
                  padding: EdgeInsets.only(right: spacing.sm),
                  child: BarButton(
                    key: ValueKey('search-field-${field.name}'),
                    label: labels[field]!,
                    compact: true,
                    filled: field == _field,
                    marked: active(field),
                    onTap: () => _choose(field),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ClipRect(
            child: AnimatedSwitcher(
              duration: theme.motion.medium,
              child: KeyedSubtree(
                key: ValueKey(_field),
                child: _instrument(theme, strings, journal),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _instrument(SmThemeData theme, Strings strings, JournalStore journal) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    Widget note(String text) => Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.md),
      child: Text(
        text,
        style: theme.type.caption.copyWith(
          color: colors.textFaint,
          height: 1.4,
        ),
      ),
    );
    // What stands where a field has nothing to show: a solid block, as
    // if the bar had risen to meet the fields.
    final cover = DecoratedBox(
      key: const ValueKey('search-cover'),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outline)),
      ),
      child: const SizedBox.expand(),
    );
    Widget chips(List<Widget> children) => SingleChildScrollView(
      padding: EdgeInsets.all(spacing.md),
      child: Wrap(
        spacing: spacing.sm,
        runSpacing: spacing.sm,
        children: children,
      ),
    );

    switch (_field) {
      case SearchField.lookIn:
        return cover;
      case SearchField.category:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: chips([
                for (final category in journal.categories)
                  SearchChip(
                    key: ValueKey('search-category-${category.id}'),
                    label: category.name,
                    hue: category.color,
                    on: _query.categories.contains(category.id),
                    onTap: () => _set(
                      _query.copyWith(
                        categories: _toggled(_query.categories, category.id),
                      ),
                    ),
                  ),
              ]),
            ),
            note(strings.searchCategoryNote),
            SizedBox(height: spacing.sm),
          ],
        );
      case SearchField.tags:
        if (journal.tags.isEmpty) {
          return Center(child: note(strings.searchNoTags));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: chips([
                for (final tag in journal.tags)
                  SearchChip(
                    key: ValueKey('search-tag-${tag.id}'),
                    label: '#${tag.name}',
                    hue: colors.accent,
                    on: _query.tags.contains(tag.id),
                    onTap: () => _set(
                      _query.copyWith(tags: _toggled(_query.tags, tag.id)),
                    ),
                  ),
              ]),
            ),
            note(strings.searchTagsNote),
            SizedBox(height: spacing.sm),
          ],
        );
      case SearchField.day:
        final kinds = CycleKind.values;
        return Column(
          children: [
            // What is asked so far: touched, one comes off.
            SizedBox(
              height: 40 + _barRoom,
              child: ListView(
                key: const ValueKey('search-cycles'),
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.fromLTRB(
                  spacing.md,
                  spacing.xs,
                  spacing.md,
                  _barRoom,
                ),
                children: [
                  if (_query.cycles.isEmpty)
                    Center(child: note(strings.searchDayHint)),
                  for (final MapEntry(key: kind, value: values)
                      in _query.cycles.entries)
                    for (final value in values)
                      Padding(
                        padding: EdgeInsets.only(right: spacing.sm),
                        child: SearchChip(
                          key: ValueKey('search-cycle-${kind.name}-$value'),
                          label: '${strings.cycleValue(kind, value)}  ×',
                          hue: colors.accent,
                          on: true,
                          onTap: () => _set(_query.toggleCycle(kind, value)),
                        ),
                      ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: TwoWheels(
                      name: 'search-day',
                      headings: [
                        for (final kind in kinds) strings.cycleName(kind),
                      ],
                      under: (kind) => [
                        for (var v = 0; v < kinds[kind].count; v++)
                          kinds[kind].label(v, strings),
                      ],
                      heading: _kind,
                      chosen: (kind) => _values[kind] ?? 0,
                      onChanged: (kind, value) {
                        _kind = kind;
                        _values[kind] = value;
                      },
                      firstFlex: 5,
                      secondFlex: 5,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: spacing.md),
                    child: GlyphButton(
                      key: const ValueKey('search-day-add'),
                      glyph: Glyph.add,
                      square: true,
                      lit: true,
                      onTap: () {
                        final kind = kinds[_kind];
                        final value = _values[_kind] ?? 0;
                        if (_query.cycles[kind]?.contains(value) ?? false) {
                          return;
                        }
                        _set(_query.toggleCycle(kind, value));
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case SearchField.evening:
        final place = SkyPlace.current.value;
        // Only the top half is used, as the evening needs; the rest is
        // covered.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: spacing.sm),
                children: [
                  SizedBox(height: spacing.md),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: spacing.sm,
                    children: [
                      for (final evening in Evening.values)
                        Opacity(
                          opacity: evening == Evening.sunset && place == null
                              ? 0.35
                              : 1,
                          child: IgnorePointer(
                            ignoring:
                                evening == Evening.sunset && place == null,
                            child: BarButton(
                              key: ValueKey('search-evening-${evening.name}'),
                              label: strings.eveningName(evening),
                              compact: true,
                              filled: _query.evening == evening,
                              onTap: () =>
                                  _set(_query.copyWith(evening: evening)),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: spacing.md),
                  note(strings.eveningNote(_query.evening)),
                  if (place == null) ...[
                    SizedBox(height: spacing.xs),
                    note(strings.eveningNeedsPlace),
                  ],
                ],
              ),
            ),
            Expanded(child: cover),
          ],
        );
      case SearchField.when:
        // Counted by the day it is about, or by when it was first saved
        // (its moment record).
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: spacing.sm),
                children: [
                  SizedBox(height: spacing.md),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: spacing.sm,
                    children: [
                      for (final byMoment in const [false, true])
                        BarButton(
                          key: ValueKey(
                            byMoment ? 'search-when-saved' : 'search-when-day',
                          ),
                          label: strings.searchWhenName(byMoment: byMoment),
                          compact: true,
                          filled: _query.byMoment == byMoment,
                          onTap: () =>
                              _set(_query.copyWith(byMoment: byMoment)),
                        ),
                    ],
                  ),
                  SizedBox(height: spacing.md),
                  note(strings.searchWhenNote(byMoment: _query.byMoment)),
                ],
              ),
            ),
            Expanded(child: cover),
          ],
        );
      case SearchField.words:
        return Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _startWording,
            child: note(
              _query.words.isEmpty
                  ? strings.searchWordsNote
                  : '"${_query.words}" · ${strings.searchWordsNote}',
            ),
          ),
        );
    }
  }

  // Under a row that runs sideways, the height its scroll bar is drawn
  // in, clear of what is in the row.
  static const _barRoom = 7.0;

  // The head of the panel: the gap over the fields, and their row.
  static const _fieldsHeight = 8 + 40 + _barRoom;

  static Set<String> _toggled(Set<String> set, String id) {
    final next = {...set};
    if (!next.remove(id)) next.add(id);
    return next;
  }
}

/// One thing found: a coloured edge for its category, when it is (and,
/// under an evening rule, the weton it was counted as), its title, a line
/// of what it says, and its tags.
class _ResultTile extends StatelessWidget {
  final Color hue;
  final String when;
  final String? counted;
  final String title;
  final String detail;
  final List<String> tags;
  final bool bell;
  final VoidCallback onTap;

  const _ResultTile({
    super.key,
    required this.hue,
    required this.when,
    required this.counted,
    required this.title,
    required this.detail,
    required this.tags,
    required this.onTap,
    this.bell = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: spacing.sm),
        padding: EdgeInsets.fromLTRB(
          spacing.md,
          spacing.sm,
          spacing.md,
          spacing.sm,
        ),
        decoration: BoxDecoration(
          color: Color.alphaBlend(hue.withValues(alpha: 0.08), colors.surface),
          border: Border(left: BorderSide(color: hue, width: 3)),
          borderRadius: BorderRadius.circular(theme.radii.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (bell) ...[
                  GlyphMark(glyph: Glyph.reminder, size: 11, color: hue),
                  SizedBox(width: spacing.xs),
                ],
                Expanded(
                  child: Text(
                    counted == null ? when : '$when → $counted',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.type.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            // Room between the lines, about twice what the text leaves.
            SizedBox(height: spacing.xs),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.type.body.copyWith(color: colors.textPrimary),
            ),
            if (detail.isNotEmpty) ...[
              SizedBox(height: spacing.xs),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.type.label.copyWith(color: colors.textSecondary),
              ),
            ],
            if (tags.isNotEmpty) ...[
              SizedBox(height: spacing.xs),
              Text(
                tags.map((t) => '#$t').join('  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.type.caption.copyWith(color: colors.accent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Months or years leafed up and down, as on the calendar, with what is
/// shown named over it.
class _Paged extends StatefulWidget {
  final int page;
  final ValueChanged<int> onPage;
  final String Function(int page) title;
  final Widget Function(int page) builder;

  const _Paged({
    super.key,
    required this.page,
    required this.onPage,
    required this.title,
    required this.builder,
  });

  @override
  State<_Paged> createState() => _PagedState();
}

class _PagedState extends State<_Paged> {
  late final _pages = PageController(initialPage: widget.page);

  // Told of a page from outside (today): it glides there.
  @override
  void didUpdateWidget(_Paged oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_pages.hasClients) return;
    final at = _pages.page?.round();
    if (at == null || at == widget.page) return;
    final motion = SmTheme.of(context).motion;
    if ((at - widget.page).abs() <= 3) {
      _pages.animateToPage(
        widget.page,
        duration: motion.medium,
        curve: motion.curve,
      );
    } else {
      _pages.jumpToPage(widget.page);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    return Column(
      children: [
        Text(
          widget.title(widget.page),
          key: const ValueKey('search-period'),
          style: theme.type.label.copyWith(color: theme.colors.textSecondary),
        ),
        SizedBox(height: theme.spacing.xs),
        Expanded(
          child: PageView.builder(
            controller: _pages,
            scrollDirection: Axis.vertical,
            onPageChanged: (page) {
              HapticFeedback.selectionClick();
              widget.onPage(page);
            },
            itemBuilder: (context, page) => widget.builder(page),
          ),
        ),
      ],
    );
  }
}

/// A month for the search: six Monday-first weeks. A day that fits the
/// cycles asked for is shaded; a day with something found has a dot for
/// each colour of it. Touching a day lists what was found on it.
class _SearchMonth extends StatelessWidget {
  final int year;
  final int month;
  final CivilDate today;
  final List<String> weekdays;
  final bool Function(CivilDate date) fits;
  final List<Color> Function(CivilDate date) colorsOf;
  final ValueChanged<CivilDate> onTap;

  const _SearchMonth({
    required this.year,
    required this.month,
    required this.today,
    required this.weekdays,
    required this.fits,
    required this.colorsOf,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final first = CivilDate(year, month, 1);
    final start = first.addDays(-(Weekday.of(first).index));
    return Column(
      children: [
        Row(
          children: [
            for (final initial in weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    initial,
                    style: theme.type.label.copyWith(color: colors.textFaint),
                  ),
                ),
              ),
          ],
        ),
        Expanded(
          child: Column(
            children: [
              for (var week = 0; week < 6; week++)
                Expanded(
                  child: Row(
                    children: [
                      for (var d = 0; d < 7; d++)
                        Expanded(
                          child: _cell(theme, start.addDays(week * 7 + d)),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cell(SmThemeData theme, CivilDate date) {
    final colors = theme.colors;
    final inMonth = date.month == month;
    final hues = inMonth ? colorsOf(date) : const <Color>[];
    final shaded = inMonth && fits(date);
    return GestureDetector(
      key: ValueKey('search-day-${date.dayNumber}'),
      behavior: HitTestBehavior.opaque,
      onTap: inMonth ? () => onTap(date) : null,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: shaded ? colors.accent.withValues(alpha: 0.16) : null,
          border: date == today ? Border.all(color: colors.accent) : null,
          borderRadius: BorderRadius.circular(theme.radii.sm),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: theme.type.body.copyWith(
                color: inMonth
                    ? (shaded ? colors.textPrimary : colors.textSecondary)
                    : colors.textFaint.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final hue in hues)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: hue,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A year for the search, made for seeing patterns: twelve rows, one per
/// month, and a column for each day of the month, so a cycle shows as
/// lines (five-day pasaran as diagonals, the moon drifting a day or two
/// a month). Days that fit the cycles are shaded; days with something
/// found are filled in its colour.
///
/// The days are too small for a fingertip, so a day is picked through a
/// magnifying glass. A touch puts the glass down over the day touched,
/// showing it large with its date; touching the glass lists that day.
/// Held, the glass follows the finger from day to day, and letting go
/// lists the day it is on. A quick swipe up or down still leafs the
/// years.
class _SearchYear extends StatefulWidget {
  final int year;
  final CivilDate today;
  final List<String> months;
  final bool Function(CivilDate date) fits;
  final List<Color> Function(CivilDate date) colorsOf;
  final String Function(CivilDate date) describe;
  final ValueChanged<CivilDate> onTap;

  const _SearchYear({
    required this.year,
    required this.today,
    required this.months,
    required this.fits,
    required this.colorsOf,
    required this.describe,
    required this.onTap,
  });

  static const _label = 30.0;

  @override
  State<_SearchYear> createState() => _SearchYearState();
}

class _SearchYearState extends State<_SearchYear> {
  // Where the finger is, and the day under it, while the glass is out.
  Offset? _finger;
  CivilDate? _focus;

  // Hold this long and the glass follows the finger; move sooner and it
  // is a swipe through the years.
  static const _hold = Duration(milliseconds: 200);

  int get _year => widget.year;

  CivilDate _dayAt(Offset p, double cell, double rowHeight) {
    final month = ((p.dy / rowHeight).floor() + 1).clamp(1, 12);
    final last = CivilDate.daysInMonth(_year, month);
    final day = (((p.dx - _SearchYear._label) / cell).floor() + 1).clamp(
      1,
      last,
    );
    return CivilDate(_year, month, day);
  }

  void _move(Offset p, double cell, double rowHeight) {
    final day = _dayAt(p, cell, rowHeight);
    if (day != _focus) HapticFeedback.selectionClick();
    setState(() {
      _finger = p;
      _focus = day;
    });
  }

  void _pick() {
    final day = _focus;
    setState(() {
      _finger = null;
      _focus = null;
    });
    if (day != null) widget.onTap(day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    // Worked out once for the year, not for every frame.
    final cells = <(CivilDate, bool, Color?)>[];
    for (var month = 1; month <= 12; month++) {
      final last = CivilDate.daysInMonth(_year, month);
      for (var day = 1; day <= last; day++) {
        final date = CivilDate(_year, month, day);
        final hues = widget.colorsOf(date);
        cells.add((date, widget.fits(date), hues.firstOrNull));
      }
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final cell = (size.width - _SearchYear._label) / 31;
        final rowHeight = size.height / 12;
        final grid = _YearPainter(
          cells: cells,
          cell: cell,
          rowHeight: rowHeight,
          today: widget.today,
          months: widget.months,
          shade: colors.accent,
          empty: colors.surfaceRaised,
          ink: colors.textPrimary,
          faint: colors.textFaint,
          label: theme.type.caption,
        );
        final glass = _Glass.place(_finger, size);
        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  TapGestureRecognizer.new,
                  (tap) => tap.onTapUp = (details) {
                    final p = details.localPosition;
                    // A touch on the glass takes the day under it.
                    if (glass != null &&
                        (p - glass).distance <= _Glass.radius) {
                      HapticFeedback.selectionClick();
                      _pick();
                    } else {
                      _move(p, cell, rowHeight);
                    }
                  },
                ),
            LongPressGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  LongPressGestureRecognizer
                >(() => LongPressGestureRecognizer(duration: _hold), (hold) {
                  hold.onLongPressStart = (details) =>
                      _move(details.localPosition, cell, rowHeight);
                  hold.onLongPressMoveUpdate = (details) =>
                      _move(details.localPosition, cell, rowHeight);
                  hold.onLongPressEnd = (_) => _pick();
                }),
          },
          child: Stack(
            children: [
              CustomPaint(
                key: const ValueKey('search-year-grid'),
                size: Size.infinite,
                painter: grid,
              ),
              if (glass != null && _focus != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      key: const ValueKey('search-year-glass'),
                      painter: _Glass(
                        grid: grid,
                        centre: glass,
                        focus: _focus!,
                        date: widget.describe(_focus!),
                        surface: colors.surface,
                        outline: colors.outline,
                        ink: colors.textPrimary,
                        style: theme.type.label,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _YearPainter extends CustomPainter {
  final List<(CivilDate, bool, Color?)> cells;
  final double cell;
  final double rowHeight;
  final CivilDate today;
  final List<String> months;
  final Color shade;
  final Color empty;
  final Color ink;
  final Color faint;
  final TextStyle label;

  const _YearPainter({
    required this.cells,
    required this.cell,
    required this.rowHeight,
    required this.today,
    required this.months,
    required this.shade,
    required this.empty,
    required this.ink,
    required this.faint,
    required this.label,
  });

  /// Where [date]'s square stands.
  Offset centreOf(CivilDate date) => Offset(
    _SearchYear._label + (date.day - 0.5) * cell,
    (date.month - 0.5) * rowHeight,
  );

  double get side => (cell < rowHeight ? cell : rowHeight) - 2;

  @override
  void paint(Canvas canvas, Size size) {
    for (var month = 0; month < 12; month++) {
      final text = TextPainter(
        text: TextSpan(
          text: months[month],
          style: label.copyWith(color: faint),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(0, month * rowHeight + (rowHeight - text.height) / 2),
      );
    }
    final paint = Paint();
    for (final (date, fits, hue) in cells) {
      final rect = Rect.fromCenter(
        center: centreOf(date),
        width: side,
        height: side,
      );
      final shape = RRect.fromRectAndRadius(rect, const Radius.circular(2));
      paint.color = hue ?? (fits ? shade.withValues(alpha: 0.35) : empty);
      canvas.drawRRect(shape, paint);
      if (date == today) {
        canvas.drawRRect(
          shape.inflate(1.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = ink,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_YearPainter old) =>
      old.cells != cells || old.cell != cell || old.rowHeight != rowHeight;
}

/// The magnifying glass over the year: the grid drawn [zoom] times over
/// in a circle, centred on the day it is on, that day ringed, and its
/// date on a tab at the glass's foot.
class _Glass extends CustomPainter {
  final _YearPainter grid;
  final Offset centre;
  final CivilDate focus;
  final String date;
  final Color surface;
  final Color outline;
  final Color ink;
  final TextStyle style;

  const _Glass({
    required this.grid,
    required this.centre,
    required this.focus,
    required this.date,
    required this.surface,
    required this.outline,
    required this.ink,
    required this.style,
  });

  static const radius = 58.0;
  static const zoom = 3.2;

  // How far above the finger the glass stands, so the finger does not
  // hide it.
  static const _lift = radius + 34;

  /// Where the glass stands for a finger at [finger], in a grid of
  /// [size]: above the finger, or under it near the top, and always
  /// whole on the grid. None with no finger.
  static Offset? place(Offset? finger, Size size) {
    if (finger == null) return null;
    var y = finger.dy - _lift;
    if (y - radius < 0) y = finger.dy + _lift;
    final x = finger.dx.clamp(radius, size.width - radius);
    return Offset(x, y.clamp(radius, size.height - radius));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final circle = Rect.fromCircle(center: centre, radius: radius);
    final day = grid.centreOf(focus);
    canvas
      ..drawCircle(
        centre + const Offset(0, 3),
        radius + 1,
        Paint()
          ..color = const Color(0x66000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      )
      ..save()
      ..clipPath(Path()..addOval(circle))
      ..drawRect(circle, Paint()..color = surface)
      ..translate(centre.dx, centre.dy)
      ..scale(zoom)
      ..translate(-day.dx, -day.dy);
    grid.paint(canvas, size);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: day,
            width: grid.side + 3,
            height: grid.side + 3,
          ),
          const Radius.circular(2.5),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 / zoom * 2
          ..color = ink,
      )
      ..restore()
      ..drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = outline,
      );

    // The date, on a tab across the foot of the glass.
    final text = TextPainter(
      text: TextSpan(
        text: date,
        style: style.copyWith(color: ink),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    final tab = Rect.fromCenter(
      center: Offset(centre.dx, centre.dy + radius),
      width: text.width + 16,
      height: text.height + 8,
    );
    // Kept on the grid when the glass is at an edge.
    final shift = tab.left < 0
        ? -tab.left
        : (tab.right > size.width ? size.width - tab.right : 0.0);
    final placed = tab.shift(Offset(shift, 0));
    final shape = RRect.fromRectAndRadius(
      placed,
      Radius.circular(tab.height / 2),
    );
    canvas
      ..drawRRect(shape, Paint()..color = surface)
      ..drawRRect(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = outline,
      );
    text.paint(canvas, placed.topLeft + const Offset(8, 4));
  }

  @override
  bool shouldRepaint(_Glass old) =>
      old.centre != centre || old.focus != focus || old.grid != grid;
}
