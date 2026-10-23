import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import '../bar_button.dart';
import '../panel_tabs.dart';
import '../toast.dart';
import 'bazi_record.dart';
import '../date_picker.dart';
import '../day_reading.dart';
import '../action_cards.dart';
import '../glyph_button.dart';
import '../house.dart';
import '../journal/entry.dart';
import '../journal/entry_screen.dart';
import '../journal/geo.dart';
import '../journal/journal_store.dart';
import '../parts.dart';
import '../routes.dart';
import '../strings.dart';
import '../time_picker.dart';
import '../sky_place.dart';
import '../step_field.dart';
import 'bazi_places.dart';
import 'bazi_tables.dart';
import 'place_picker.dart';
import 'two_wheels.dart';

/// Opens the bazi chart on [date].
Future<void> pushBazi(
  BuildContext context, {
  required CivilDate date,
  required Duration utcOffset,
}) => Navigator.of(context).push(
  fadeRoute<void>(
    context,
    (context) => BaziScreen(date: date, utcOffset: utcOffset),
  ),
);

/// Opens the chart of a journal entry, as it was written, to look at or
/// correct. Returns what was done to the entry, if anything, for the
/// entry to say.
Future<String?> pushBaziOf(
  BuildContext context, {
  required Entry entry,
  required BaziRecord record,
}) => Navigator.of(context).push<String>(
  fadeRoute<String>(
    context,
    (context) => BaziScreen(
      date: record.date,
      utcOffset: record.offset,
      minuteOfDay: record.minute,
      record: record,
      source: entry,
    ),
  ),
);

/// What a chart is worked out from. Each has its instrument in the lower
/// panel.
enum BaziField { date, time, place, sex, rules, options }

/// The bazi chart: the four pillars of any instant at any place, for
/// roaming through or for working out a chart from a person's own birth.
///
/// Nothing here is kept. The date, time, place and sex put in last only
/// as long as the screen is open.
///
///  * Top bar: the name of the screen, and the instant being read.
///  * Main body: the four pillars, each with its stem, its branch and the
///    stems the branch hides, and what each is to the day master; then
///    what the chart rests on: the time it was read from, the solar terms
///    either side, the relations among the branches, the luck pillars,
///    and whose tables were used.
///  * Lower panel: a strip of the five things the chart is worked out
///    from, and the instrument for the one chosen.
///  * Bottom bar: back.
class BaziScreen extends StatefulWidget {
  final CivilDate date;
  final Duration utcOffset;

  /// The time of day the chart opens on, in minutes; the clock's, unless
  /// a test says.
  final int? minuteOfDay;

  /// The tables to use, and no others; for tests.
  final BaziTables? tables;

  /// Every table to choose among; read from the app's data files when
  /// neither this nor [tables] is given.
  final BaziLibrary? library;

  /// The time zones to choose among; read from the app's data files when
  /// not given.
  final BaziPlaces? places;

  /// The zone the chart opens in; the phone's own, unless a test says.
  final String? zone;

  /// A chart opened from a journal entry: what it was written from, and
  /// the entry, which writing back changes and returns to.
  final BaziRecord? record;
  final Entry? source;

  const BaziScreen({
    super.key,
    required this.date,
    required this.utcOffset,
    this.minuteOfDay,
    this.tables,
    this.library,
    this.places,
    this.zone,
    this.record,
    this.source,
  });

  @override
  State<BaziScreen> createState() => _BaziScreenState();
}

class _BaziScreenState extends State<BaziScreen> {
  late CivilDate _date = widget.date;
  late int _minute =
      widget.minuteOfDay ?? DateTime.now().hour * 60 + DateTime.now().minute;

  // The zone whose clocks the chart is read by, or null when a plain
  // offset is given in its place.
  String? _zone;
  late Duration _plainOffset = widget.utcOffset;
  BaziPlaces? _places;
  // Counts the times the place was set from outside its wheels, so they
  // are made again where it now is.
  int _placed = 0;

  /// What the clock at the place stood ahead of Greenwich then: by the
  /// zone's own history, not by today's rule.
  Duration get _offset => _zone == null
      ? _plainOffset
      : BaziPlaces.offsetAt(_zone!, _date, _minute);

  // Degrees east, or null when no place has been given.
  double? _longitude;
  bool? _male;
  BaziConfig _config = const BaziConfig();

  BaziField _field = BaziField.time;
  // The rule the rules' wheels stand on, and a count of the times a rule
  // was changed from outside them, so they are made again to match.
  int _rule = 0;
  int _ruled = 0;
  BaziLibrary? _library;
  // Which hidden-stem table, and which of punishments and harms.
  int _hiddenTable = 0;
  int _relationTable = 0;

  BaziTables? get _tables =>
      widget.tables ?? _library?.tables(_hiddenTable, _relationTable);
  bool _finding = false;

  // What the lower panel is doing with the journal: writing the chart to
  // it, or reading one back from it; null when neither.
  _JournalSide? _side;

  // The entry the chart came from or was last written to: writing again
  // asks whether to change it or add another.
  Entry? _source;

  // Writing again, the user chose a new entry: the categories show.
  bool _anew = false;

  // A message rising over the chart for a few seconds.
  String? _toast;
  Timer? _toastTimer;

  void _say(String message) {
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
    setState(() => _toast = message);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _library = widget.library;
    if (widget.tables == null && _library == null) {
      BaziLibrary.load().then((library) {
        if (mounted) setState(() => _library = library);
      });
    }
    _findPlaces();
    if (widget.record case final record?) {
      _apply(record, widget.source);
      final title = widget.source?.title;
      if (title != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _say(Strings.of(context).baziLoaded(title));
        });
      }
    }
  }

  Future<void> _findPlaces() async {
    final places = widget.places ?? await BaziPlaces.load();
    if (!mounted) return;
    setState(() {
      _places = places;
      if (widget.zone != null && places.has(widget.zone!)) _place(widget.zone!);
    });
    if (widget.zone != null || widget.record != null) return;
    // The phone's own zone, if it says, and nothing was chosen meanwhile.
    final zone = await BaziPlaces.ofPhone();
    if (!mounted || zone == null || !places.has(zone)) return;
    if (_zone == null &&
        _longitude == null &&
        _plainOffset == widget.utcOffset) {
      setState(() => _place(zone));
    }
  }

  // Puts the chart in [zone], at the longitude the sky is already read
  // from if there is one, or else the zone's own city.
  void _place(String zone) {
    _zone = zone;
    _longitude = SkyPlace.current.value?.longitude ?? _places!.longitudes[zone];
    _placed++;
  }

  BaziChart get _chart => BaziChart.at(
    DateTime.utc(
      _date.year,
      _date.month,
      _date.day,
      _minute ~/ 60,
      _minute % 60,
    ).subtract(_offset),
    utcOffset: _offset,
    longitude: _longitude,
    config: _config,
  );

  // Today, now: the chart of this moment.
  void _toNow() {
    final now = DateTime.now();
    setState(() {
      _date = CivilDate.fromDateTime(now);
      _minute = now.hour * 60 + now.minute;
    });
  }

  void _choose(BaziField field) {
    HapticFeedback.selectionClick();
    setState(() => _field = field);
  }

  Future<void> _useHere() async {
    if (_finding) return;
    HapticFeedback.selectionClick();
    setState(() => _finding = true);
    try {
      final fix = await Locator.current.find();
      if (!mounted) return;
      setState(() {
        // To a tenth of a degree: under half a minute of sun time.
        _longitude = (fix.longitude * 10).round() / 10;
        _finding = false;
      });
      final zone = await BaziPlaces.ofPhone();
      if (!mounted || zone == null || _places?.has(zone) != true) return;
      setState(() {
        _zone = zone;
        _placed++;
      });
    } on LocateFailed {
      if (mounted) setState(() => _finding = false);
    }
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _clock(DateTime time) =>
      '${_two(time.hour)}:${_two(time.minute)}';

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final strings = Strings.of(context);
    final tables = _tables;
    final chart = _chart;
    // The entry whose chart this is, while editing it.
    final editing = _stillThere(_source);

    // Back, while the panel asks something or lists the journal, closes
    // that first, as Cancel does.
    return PopScope(
      canPop: _side == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSide();
      },
      child: ColoredBox(
        color: colors.background,
        child: SafeArea(
          child: Recentre(
            onToday: _toNow,
            atToday: _date == CivilDate.fromDateTime(DateTime.now()),
            child: FourParts(
              top: TopBar(
                key: const ValueKey('bazi-top-bar'),
                leading: TopBarTitle(label: strings.baziTitle),
                // Editing an entry's chart: its title, so it is plain that
                // this is that entry and not a new one.
                trailing: editing != null
                    ? _EntryCapsule(title: editing.title)
                    : Text(
                        '八字',
                        style: theme.type.title.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                subtitle:
                    '${strings.gregorian(_date)} · '
                    '${_two(_minute ~/ 60)}:${_two(_minute % 60)} · '
                    'UTC${BaziPlaces.label(_offset)}',
              ),
              body: Stack(
                children: [
                  Positioned.fill(
                    child: tables == null
                        ? const SizedBox.expand()
                        : SingleChildScrollView(
                            key: const ValueKey('bazi-body'),
                            padding: EdgeInsets.only(bottom: spacing.md),
                            child: _body(theme, strings, chart, tables),
                          ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Toast(message: _toast),
                  ),
                ],
              ),
              panel: switch (_side) {
                _JournalSide.write => _writePanel(
                  theme,
                  strings,
                  chart,
                  tables,
                ),
                _JournalSide.read => _readPanel(theme, strings),
                _JournalSide.discard => _discardPanel(theme, strings),
                null => _panel(theme, strings),
              },
              bar: const RoomBar(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(
    SmThemeData theme,
    Strings strings,
    BaziChart chart,
    BaziTables tables,
  ) {
    final spacing = theme.spacing;
    final colors = theme.colors;
    final caption = theme.type.caption.copyWith(
      color: colors.textSecondary,
      letterSpacing: 1.2,
    );
    final note = theme.type.label.copyWith(
      color: colors.textSecondary,
      height: 1.45,
    );

    Widget heading(String text) => Padding(
      padding: EdgeInsets.only(top: spacing.lg, bottom: spacing.xs),
      child: Text(text.toUpperCase(), style: caption),
    );

    String local(DateTime instant) {
      final at = instant.add(_offset);
      return '${strings.gregorian(CivilDate(at.year, at.month, at.day))} · '
          '${_clock(at)}';
    }

    // The term that opened the month and the one that closes it.
    final opened = (315 + 30 * ((chart.month.branch.index - 2) % 12)) % 360;
    String term(double longitude) {
      final words = BaziTerms.solarTerm(longitude);
      return '${words.hanzi} ${strings.baziTerm(words)}';
    }

    final relations = relationsAmong([
      chart.year.branch,
      chart.month.branch,
      chart.day.branch,
      chart.hour.branch,
    ], tables);
    final four = [chart.year, chart.month, chart.day, chart.hour];
    // Stems five apart combine, wherever in the chart they stand.
    final combined = <Stem>{
      for (final pillar in four)
        if (pillar.stem.index < 5 &&
            four.any((other) => other.stem == pillar.stem.combination))
          pillar.stem,
    };
    // How many of the eight characters are of each element.
    final tally = {
      for (final element in Unsur.values)
        element: four
            .expand((p) => [p.stem.unsur, tables.elementOf(p.branch)])
            .where((e) => e == element)
            .length,
    };
    final empty = chart.day.voidBranches;
    // How far into its month the chart is, and by a table that divides
    // the month, the stem that has it in hand.
    final intoMonth = chart.instant.difference(chart.termBefore);
    final monthDay = intoMonth.inSeconds ~/ Duration.secondsPerDay + 1;
    final commanding = tables.commanding(chart.month.branch, intoMonth);
    final luck = _male == null ? null : chart.luck(male: _male!);
    final other = chart.inLateZiHour
        ? chart.withConfig(
            _config.copyWith(
              ziHourRule: _config.ziHourRule == ZiHourRule.unified
                  ? ZiHourRule.split
                  : ZiHourRule.unified,
            ),
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BaziPillars(
          chart: chart,
          tables: tables,
          strings: strings,
          commanding: commanding,
        ),
        // The time the day and hour were read from.
        Padding(
          padding: EdgeInsets.only(top: spacing.md),
          child: Text(
            chart.correction != Duration.zero
                ? strings.baziSolar(
                    _clock(chart.clockTime),
                    _clock(chart.chartTime),
                    (chart.correction.inSeconds / 60).round(),
                  )
                : _config.timeMode == TimeMode.clock
                ? strings.baziByClock
                : strings.baziNoPlace,
            key: const ValueKey('bazi-time-note'),
            style: note,
          ),
        ),
        if (_zone != null)
          Padding(
            padding: EdgeInsets.only(top: spacing.xs),
            child: Text(
              strings.baziZone(
                BaziPlaces.cityOf(_zone!),
                BaziPlaces.label(_offset),
              ),
              key: const ValueKey('bazi-zone-note'),
              style: note,
            ),
          ),
        // The hour before midnight: say that schools differ, and offer
        // the other reading.
        if (other != null)
          GestureDetector(
            key: const ValueKey('bazi-late-zi'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _config = other.config;
                _ruled++;
              });
            },
            child: Padding(
              padding: EdgeInsets.only(top: spacing.sm),
              child: Text(
                strings.baziLateZi(chart.day.hanzi, other.day.hanzi),
                style: note.copyWith(color: colors.accent),
              ),
            ),
          ),
        heading(strings.baziMonthOpened),
        Text(
          '${term(opened.toDouble())}\n${local(chart.termBefore)}',
          key: const ValueKey('bazi-term-before'),
          style: theme.type.body.copyWith(color: colors.textPrimary),
        ),
        heading(strings.baziMonthCloses),
        Text(
          '${term((opened + 30) % 360)}\n${local(chart.termAfter)}',
          key: const ValueKey('bazi-term-after'),
          style: theme.type.body.copyWith(color: colors.textPrimary),
        ),
        if (commanding != null) ...[
          heading(
            '${BaziTerms.command.hanzi} '
            '${strings.baziTerm(BaziTerms.command)}',
          ),
          Text.rich(
            TextSpan(
              children: [
                for (final (stem, days)
                    in tables.command![chart.month.branch]!) ...[
                  TextSpan(
                    text: '${stem.hanzi} $days',
                    style: TextStyle(
                      color: stem == commanding
                          ? elementColors[stem.unsur]
                          : colors.textFaint,
                    ),
                  ),
                  const TextSpan(text: '   '),
                ],
                TextSpan(
                  text: '· ${strings.baziMonthDay(monthDay)}',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ],
            ),
            key: const ValueKey('bazi-command'),
            style: theme.type.body.copyWith(color: colors.textPrimary),
          ),
        ],
        heading(
          '五行 '
          '${strings.baziElements}',
        ),
        Text.rich(
          TextSpan(
            children: [
              for (final element in Unsur.values) ...[
                TextSpan(
                  text: BaziTerms.element(element).hanzi,
                  style: TextStyle(color: elementColors[element]),
                ),
                TextSpan(text: ' ${tally[element]}     '),
              ],
            ],
          ),
          key: const ValueKey('bazi-elements'),
          style: theme.type.body.copyWith(color: colors.textPrimary),
        ),
        heading(
          '${BaziTerms.voidBranches.hanzi} '
          '${strings.baziTerm(BaziTerms.voidBranches)}',
        ),
        Text(
          '${empty.map((b) => b.hanzi).join()} · '
          '${strings.baziVoidIn([for (final (place, pillar) in four.indexed)
            if (place != 2 && empty.contains(pillar.branch)) strings.baziTerm(BaziTerms.pillars[place])])}',
          key: const ValueKey('bazi-void'),
          style: theme.type.body.copyWith(color: colors.textPrimary),
        ),
        heading(strings.baziRelations),
        for (final stem in combined)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '${stem.hanzi}${stem.combination.hanzi}  '
              '${BaziTerms.stemCombination.hanzi} '
              '${strings.baziTerm(BaziTerms.stemCombination)} · '
              '${BaziTerms.element(stem.combinedElement).hanzi}',
              style: theme.type.body.copyWith(color: colors.textPrimary),
            ),
          ),
        if (relations.isEmpty && combined.isEmpty)
          Text(strings.baziNoRelations, style: note)
        else
          for (final relation in relations)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${relation.branches.map((b) => b.hanzi).join()}  '
                '${relation.kind.hanzi} ${strings.baziTerm(relation.kind)}'
                '${relation.detail == null ? '' : ' · ${relation.detail}'}',
                style: theme.type.body.copyWith(color: colors.textPrimary),
              ),
            ),
        heading('${BaziTerms.luckPillars.hanzi} ${strings.baziLuck}'),
        if (luck == null)
          Text(strings.baziLuckNeedsSex, style: note)
        else ...[
          Text(
            luck.rounding == LuckRounding.exact
                ? strings.baziLuckStart(
                    luck.forward,
                    luck.startAgeParts.years,
                    luck.startAgeParts.months,
                    luck.startAgeParts.days,
                  )
                : strings.baziLuckStartYears(
                    luck.forward,
                    luck.firstAge,
                    luck.rounding == LuckRounding.nearestYear,
                  ),
            key: const ValueKey('bazi-luck-start'),
            style: note,
          ),
          SizedBox(height: spacing.sm),
          SingleChildScrollView(
            key: const ValueKey('bazi-luck'),
            scrollDirection: Axis.horizontal,
            // Room under the ages for the scroll bar.
            padding: EdgeInsets.only(bottom: spacing.md),
            child: Row(
              children: [
                for (final (i, pillar) in luck.pillars.indexed)
                  Padding(
                    padding: EdgeInsets.only(right: spacing.md),
                    child: Column(
                      children: [
                        Text(
                          pillar.hanzi,
                          style: theme.type.title.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          strings.baziAge(luck.firstAge + i * 10),
                          style: theme.type.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        Padding(
          padding: EdgeInsets.only(top: spacing.lg),
          child: Text(
            strings.baziLineage(tables.hidden, tables.relations),
            key: const ValueKey('bazi-lineage'),
            style: theme.type.caption.copyWith(
              color: colors.textFaint,
              height: 1.45,
            ),
          ),
        ),
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

  /// The lower panel while writing: for a chart that already has an
  /// entry (read from it, or written to it), whether to change that entry
  /// or add another; then, for another, which category it goes into.
  Widget _writePanel(
    SmThemeData theme,
    Strings strings,
    BaziChart chart,
    BaziTables? tables,
  ) {
    // The chart's entry, if it is still in the journal (it may have been
    // deleted meanwhile); else one holding this very chart.
    final editing = _stillThere(_source);
    final source = editing ?? _sameChart();
    if (source == null || _anew) {
      return _exportPanel(theme, strings, chart, tables);
    }
    final spacing = theme.spacing;
    final colors = theme.colors;
    return SingleChildScrollView(
      key: const ValueKey('bazi-write-ask'),
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            editing != null
                ? strings.baziSaveAsk(source.title)
                : strings.baziWriteAsk(source.title),
            style: theme.type.label.copyWith(
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          SizedBox(height: spacing.md),
          Row(
            children: [
              Expanded(
                child: BarButton(
                  key: const ValueKey('bazi-write-edit'),
                  label: editing != null
                      ? strings.baziSaveHere
                      : strings.baziWriteEdit,
                  compact: true,
                  onTap: tables == null
                      ? () {}
                      : () => _overwrite(source, strings, chart, tables),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: BarButton(
                  key: const ValueKey('bazi-write-new'),
                  label: editing != null
                      ? strings.baziSaveNew
                      : strings.baziWriteNew,
                  compact: true,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _anew = true);
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          _cancel(strings),
        ],
      ),
    );
  }

  // Back to the chart, the panel's question unanswered: the same as the
  // back gesture.
  Widget _cancel(Strings strings) => BarButton(
    key: const ValueKey('bazi-cancel'),
    label: strings.cancel,
    compact: true,
    onTap: _closeSide,
  );

  void _closeSide() {
    HapticFeedback.selectionClick();
    setState(() {
      _side = null;
      _anew = false;
    });
  }

  /// The lower panel asking whether to let go of every change made to the
  /// entry's chart.
  Widget _discardPanel(SmThemeData theme, Strings strings) {
    final spacing = theme.spacing;
    final entry = _stillThere(_source);
    return SingleChildScrollView(
      key: const ValueKey('bazi-discard-ask'),
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.baziDiscardAsk(entry?.title ?? ''),
            style: theme.type.label.copyWith(
              color: theme.colors.textSecondary,
              height: 1.4,
            ),
          ),
          SizedBox(height: spacing.md),
          Row(
            children: [
              Expanded(
                child: BarButton(
                  key: const ValueKey('bazi-discard-yes'),
                  label: strings.baziDiscard,
                  compact: true,
                  tint: dangerColor,
                  primary: true,
                  onTap: _discard,
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(child: _cancel(strings)),
            ],
          ),
        ],
      ),
    );
  }

  /// The lower panel while reading: every chart written to the journal,
  /// newest first. One whose line is whole, and whose tables and zone the
  /// app has, is read back by a touch; one lacking anything is shown
  /// faint and cannot be.
  Widget _readPanel(SmThemeData theme, Strings strings) {
    final spacing = theme.spacing;
    final colors = theme.colors;
    final journal = JournalScope.of(context);
    final charts = journal.allEntries().where((e) => e.bazi != null).toList()
      ..sort((a, b) {
        final day = b.date.dayNumber.compareTo(a.date.dayNumber);
        return day != 0 ? day : b.secondOfDay.compareTo(a.secondOfDay);
      });
    if (charts.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Text(
            strings.baziReadNone,
            key: const ValueKey('bazi-read-none'),
            textAlign: TextAlign.center,
            style: theme.type.label.copyWith(color: colors.textFaint),
          ),
        ),
      );
    }
    return ListView(
      key: const ValueKey('bazi-read-list'),
      padding: EdgeInsets.symmetric(vertical: spacing.xs),
      children: [
        for (final entry in charts)
          Builder(
            builder: (context) {
              final record = _usable(BaziRecord.parse(entry.bazi));
              final category = journal.category(entry.categoryId);
              return GestureDetector(
                key: ValueKey('bazi-read-${entry.id}'),
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
                                  ? strings.baziReadIncomplete
                                  : strings.baziReadWritten(
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

  // What the chart on the screen is read from, as its line in an entry.
  BaziRecord get _record => BaziRecord(
    date: _date,
    minute: _minute,
    offset: _offset,
    zone: _zone,
    longitude: _longitude,
    male: _male,
    config: _config,
    hidden: BaziLibrary.hiddenStemFiles[_hiddenTable],
    relations: BaziLibrary.relationFiles[_relationTable],
  );

  // [entry] as the journal now has it, or null if it is gone.
  Entry? _stillThere(Entry? entry) => entry == null
      ? null
      : JournalScope.of(context)
            .entriesFor(entry.date, utcOffset: entry.utcOffset)
            .where((e) => e.id == entry.id)
            .firstOrNull;

  // The newest entry that holds this very chart, if the journal has one.
  Entry? _sameChart() {
    final value = _record.value;
    final found = JournalScope.of(context)
        .allEntries()
        .where((e) => e.bazi == value)
        .toList();
    if (found.isEmpty) return null;
    found.sort(
      (a, b) => b.date.dayNumber != a.date.dayNumber
          ? b.date.dayNumber.compareTo(a.date.dayNumber)
          : b.secondOfDay.compareTo(a.secondOfDay),
    );
    return found.first;
  }

  // [record] if the app can read it back whole: its tables are ones the
  // app has, and its zone, if any, is one it knows.
  BaziRecord? _usable(BaziRecord? record) {
    if (record == null) return null;
    if (!BaziLibrary.hiddenStemFiles.contains(record.hidden)) return null;
    if (!BaziLibrary.relationFiles.contains(record.relations)) return null;
    final zone = record.zone;
    if (zone != null && _places?.has(zone) != true) return null;
    return record;
  }

  // The chart as [record] has it, and [entry] remembered as its own.
  void _load(Entry entry, BaziRecord record) {
    HapticFeedback.selectionClick();
    setState(() {
      _apply(record, entry);
      _side = null;
    });
    _say(Strings.of(context).baziLoaded(entry.title));
  }

  // Ends editing the chart's entry, the chart back as the entry has it,
  // once the user has said so (the discard panel). Opened from that
  // entry, back to it, nothing changed.
  void _discard() {
    HapticFeedback.mediumImpact();
    final entry = _stillThere(_source);
    if (entry == null) return;
    if (widget.source?.id == entry.id) {
      Navigator.of(context).pop();
      return;
    }
    final record = BaziRecord.parse(entry.bazi);
    setState(() {
      if (record != null) _apply(record, null);
      _source = null;
      _side = null;
      _anew = false;
    });
    _say(Strings.of(context).baziDiscarded);
  }

  // Sets the chart to [record]'s, with [entry] as its own.
  void _apply(BaziRecord record, Entry? entry) {
    _date = record.date;
    _minute = record.minute;
    _zone = record.zone;
    _plainOffset = record.offset;
    _longitude = record.longitude;
    _male = record.male;
    _config = record.config;
    // A table the app no longer has falls back to the first.
    _hiddenTable = math.max(
      0,
      BaziLibrary.hiddenStemFiles.indexOf(record.hidden),
    );
    _relationTable = math.max(
      0,
      BaziLibrary.relationFiles.indexOf(record.relations),
    );
    _placed++;
    _ruled++;
    _source = entry;
  }

  /// The lower panel while saving: which of the journal's categories the
  /// chart goes into. Touching one saves it there and opens the entry.
  Widget _exportPanel(
    SmThemeData theme,
    Strings strings,
    BaziChart chart,
    BaziTables? tables,
  ) {
    final spacing = theme.spacing;
    final colors = theme.colors;
    final journal = JournalScope.of(context);
    return Padding(
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.baziExportTo,
            style: theme.type.caption.copyWith(
              color: colors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: spacing.sm),
          PillRow(
            listKey: const ValueKey('bazi-export-categories'),
            inset: 0,
            children: [
              for (final category in journal.categories)
                _Category(
                  key: ValueKey('bazi-export-${category.id}'),
                  category: category,
                  onTap: tables == null
                      ? null
                      : () =>
                            _export(journal, category, strings, chart, tables),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _export(
    JournalStore journal,
    JournalCategory category,
    Strings strings,
    BaziChart chart,
    BaziTables tables,
  ) async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final draft = Entry(
      id: '',
      date: CivilDate(now.year, now.month, now.day),
      minuteOfDay: now.hour * 60 + now.minute,
      second: now.second,
      utcOffset: now.timeZoneOffset,
      categoryId: category.id,
      title: _autoTitle(strings, _record),
      content: '',
      bazi: _record.value,
    );
    // Writing done, the chart is no longer an entry's being edited.
    setState(() {
      _side = null;
      _anew = false;
      _source = null;
    });
    // Opened to be named, and saved only by its tick: the title chosen,
    // ready to type over. Let go, nothing is in the journal.
    await Navigator.of(context).push(
      fadeRoute<void>(
        context,
        (context) => EntryScreen(
          date: draft.date,
          utcOffset: draft.utcOffset,
          minuteOfDay: draft.minuteOfDay,
          draft: draft,
          titling: true,
        ),
      ),
    );
  }

  // Writes the chart over [source], keeping its day, category and tags.
  Future<void> _overwrite(
    Entry source,
    Strings strings,
    BaziChart chart,
    BaziTables tables,
  ) async {
    HapticFeedback.mediumImpact();
    final journal = JournalScope.of(context);
    // Only the chart changes: the user's title stays, unless it is still
    // the one the chart gave it, and the user's writing always stays.
    final old = BaziRecord.parse(source.bazi);
    final named = old == null || source.title != _autoTitle(strings, old);
    final entry = journal.save(
      source.copyWith(
        title: named ? null : _autoTitle(strings, _record),
        bazi: _record.value,
      ),
    );
    // Saved, the chart is no longer that entry's being edited.
    setState(() {
      _side = null;
      _source = null;
    });
    // Opened from that very entry: back to it, which says what was done.
    if (widget.source?.id == entry.id) {
      Navigator.of(context).pop(strings.baziRewritten);
      return;
    }
    await _show(entry, strings.baziRewritten);
  }

  // The title a chart's entry is given until the user names it.
  String _autoTitle(Strings strings, BaziRecord record) =>
      strings.baziEntryTitle(
        '${strings.gregorian(record.date)} · '
        '${_two(record.minute ~/ 60)}:${_two(record.minute % 60)}',
      );

  // Opens [entry] as it now stands, saying in its panel what was done.
  Future<void> _show(Entry entry, String notice) => Navigator.of(context).push(
    fadeRoute<void>(
      context,
      (context) => EntryScreen(
        date: entry.date,
        utcOffset: entry.utcOffset,
        entry: entry,
        notice: notice,
      ),
    ),
  );

  /// The lower panel: the strip of fields, and the instrument for the
  /// one chosen.
  Widget _panel(SmThemeData theme, Strings strings) {
    final spacing = theme.spacing;
    final labels = {
      BaziField.date: strings.baziDate,
      BaziField.time: strings.baziTime,
      BaziField.place: strings.baziPlace,
      BaziField.sex: strings.baziSex,
      BaziField.rules: strings.baziRules,
      BaziField.options: strings.baziOptions,
    };

    return Column(
      children: [
        SizedBox(height: spacing.sm),
        PanelTabs(
          listKey: const ValueKey('bazi-fields'),
          tabs: BaziField.values,
          shown: _field,
          label: (field) => labels[field]!,
          keyOf: (field) => 'bazi-field-${field.name}',
          onChoose: _choose,
        ),
        Expanded(
          // Clipped, so a wheel does not run up under the strip.
          child: ClipRect(
            child: AnimatedSwitcher(
              duration: theme.motion.medium,
              child: KeyedSubtree(
                key: ValueKey(_field),
                child: _instrument(theme, strings),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _instrument(SmThemeData theme, Strings strings) {
    final spacing = theme.spacing;

    Widget choices<T>(
      String name,
      List<(T, String)> options,
      T chosen,
      ValueChanged<T> onPick,
    ) => Wrap(
      alignment: WrapAlignment.center,
      spacing: spacing.sm,
      runSpacing: spacing.sm,
      children: [
        for (final (value, label) in options)
          BarButton(
            key: ValueKey('$name-$value'),
            label: label,
            compact: true,
            filled: value == chosen,
            onTap: () {
              HapticFeedback.selectionClick();
              onPick(value);
            },
          ),
      ],
    );

    switch (_field) {
      // What was in the bar: the chart from and to the journal, as cards,
      // from at the left and to at the right (owner, 20 October 2026).
      case BaziField.options:
        final editing = _stillThere(_source);
        return ActionCards(
          key: const ValueKey('bazi-options'),
          cards: editing == null
              ? [
                  ActionCard(
                    id: 'bazi-read',
                    glyph: Glyph.import,
                    name: strings.baziFromJournal,
                    line: strings.baziFromJournalLine,
                    onTap: () => _toggle(_JournalSide.read),
                  ),
                  ActionCard(
                    id: 'bazi-export',
                    glyph: Glyph.journal,
                    name: strings.baziToJournal,
                    line: strings.baziToJournalLine,
                    onTap: () => _toggle(_JournalSide.write),
                  ),
                ]
              : [
                  ActionCard(
                    id: 'bazi-discard',
                    glyph: Glyph.close,
                    name: strings.baziDiscard,
                    line: strings.baziDiscardLine,
                    onTap: () => _toggle(_JournalSide.discard),
                  ),
                  ActionCard(
                    id: 'bazi-export',
                    glyph: Glyph.save,
                    name: strings.baziSaveHere,
                    line: strings.baziSaveLine,
                    onTap: () => _toggle(_JournalSide.write),
                  ),
                ],
        );
      case BaziField.date:
        return Center(
          child: DatePicker(
            date: _date,
            strings: strings,
            onChanged: (date) => setState(() => _date = date),
          ),
        );
      case BaziField.time:
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.lg),
          child: TimePicker(
            minuteOfDay: _minute,
            onChanged: (minute) => setState(() => _minute = minute),
          ),
        );
      case BaziField.place:
        // The zone on two wheels, the longitude in whole degrees beside
        // them; the glyph takes both from the phone.
        final places = _places;
        if (places == null) return const SizedBox.expand();
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.md),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: PlacePicker(
                  key: ValueKey('bazi-zone-$_placed'),
                  places: places,
                  zone: _zone,
                  offset: _offset,
                  onZone: (zone) => setState(() {
                    _zone = zone;
                    _longitude = places.longitudes[zone];
                  }),
                  onOffset: (offset) => setState(() {
                    _zone = null;
                    _plainOffset = offset;
                  }),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                flex: 4,
                child: StepField(
                  name: 'bazi-longitude',
                  label: strings.baziLongitude,
                  value: _longitude == null
                      ? strings.baziNoLongitude
                      : '${_longitude!.abs().toStringAsFixed(1)}° '
                            '${_longitude! < 0 ? 'W' : 'E'}',
                  onStep: (by) => setState(
                    () => _longitude =
                        ((_longitude ??
                                    (_offset.inMinutes / 4).roundToDouble()) +
                                by)
                            .clamp(-180.0, 180.0),
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              GlyphButton(
                key: const ValueKey('bazi-here'),
                glyph: Glyph.place,
                square: true,
                marked: _finding,
                onTap: _useHere,
              ),
            ],
          ),
        );
      case BaziField.sex:
        return Center(
          child: choices<bool?>(
            'bazi-sex',
            [
              (null, strings.baziNoSex),
              (true, strings.baziMale),
              (false, strings.baziFemale),
            ],
            _male,
            (male) => setState(() => _male = male),
          ),
        );
      case BaziField.rules:
        // Each rule a chart rests on, and beside it the ways schools
        // take it.
        final rules = _rules(strings);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.md),
          child: TwoWheels(
            key: ValueKey('bazi-rules-$_ruled'),
            name: 'bazi-rules',
            headings: [for (final rule in rules) rule.name],
            under: (rule) => rules[rule].options,
            heading: _rule,
            chosen: (rule) => rules[rule].chosen,
            onChanged: (rule, choice) {
              _rule = rule;
              _rules(strings)[rule].pick(choice);
            },
            firstFlex: 2,
            secondFlex: 5,
          ),
        );
    }
  }

  /// The rules on offer: what each is called, the ways it can be taken,
  /// which is chosen, and how to choose another.
  List<
    ({String name, List<String> options, int chosen, ValueChanged<int> pick})
  >
  _rules(Strings strings) {
    ({String name, List<String> options, int chosen, ValueChanged<int> pick})
    rule<T>(
      String name,
      List<T> values,
      T chosen,
      String Function(T value) label,
      BaziConfig Function(T value) taken,
    ) => (
      name: name,
      options: [for (final value in values) label(value)],
      chosen: values.indexOf(chosen),
      pick: (index) => setState(() => _config = taken(values[index])),
    );

    return [
      rule<TimeMode>(
        strings.baziRuleTime,
        TimeMode.values.reversed.toList(),
        _config.timeMode,
        strings.baziTimeMode,
        (mode) => _config.copyWith(timeMode: mode),
      ),
      rule<ZiHourRule>(
        strings.baziRuleZi,
        ZiHourRule.values,
        _config.ziHourRule,
        strings.baziZiRule,
        (rule) => _config.copyWith(ziHourRule: rule),
      ),
      rule<YearBoundary>(
        strings.baziRuleYear,
        YearBoundary.values,
        _config.yearBoundary,
        strings.baziYearBoundary,
        (boundary) => _config.copyWith(yearBoundary: boundary),
      ),
      rule<LuckAnchor>(
        strings.baziRuleLuckFrom,
        LuckAnchor.values,
        _config.luckAnchor,
        strings.baziLuckAnchor,
        (anchor) => _config.copyWith(luckAnchor: anchor),
      ),
      rule<LuckRounding>(
        strings.baziRuleLuckAge,
        LuckRounding.values,
        _config.luckRounding,
        strings.baziLuckRounding,
        (rounding) => _config.copyWith(luckRounding: rounding),
      ),
      // The tables schools differ on, where there are several to hand.
      if (widget.tables == null && _library != null) ...[
        (
          name: strings.baziRuleHidden,
          options: [
            for (final table in _library!.hiddenStems) strings.baziTable(table),
          ],
          chosen: _hiddenTable,
          pick: (index) => setState(() => _hiddenTable = index),
        ),
        (
          name: strings.baziRulePunish,
          options: [
            for (final table in _library!.relations) strings.baziTable(table),
          ],
          chosen: _relationTable,
          pick: (index) => setState(() => _relationTable = index),
        ),
      ],
    ];
  }
}

/// The four pillars, hour to year, as they are written: all as tall as
/// the tallest. The bazi page's and the journal's chart card's.
class BaziPillars extends StatelessWidget {
  final BaziChart chart;
  final BaziTables tables;
  final Strings strings;

  /// The hidden stem in command of the month, where a table says.
  final Stem? commanding;

  const BaziPillars({
    super.key,
    required this.chart,
    required this.tables,
    required this.strings,
    this.commanding,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = SmTheme.of(context).spacing;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (place, pillar) in [
            (3, chart.hour),
            (2, chart.day),
            (1, chart.month),
            (0, chart.year),
          ]) ...[
            if (place != 3) SizedBox(width: spacing.sm),
            Expanded(
              child: _PillarColumn(
                key: ValueKey(
                  'pillar-${const ['year', 'month', 'day', 'hour'][place]}',
                ),
                title: strings.baziTerm(BaziTerms.pillars[place]),
                pillar: pillar,
                dayMaster: chart.dayMaster,
                isDay: place == 2,
                commanding: place == 1 ? commanding : null,
                tables: tables,
                strings: strings,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One pillar of the chart: what it is, what its stem is to the day
/// master, the stem, the branch, and the stems the branch hides with what
/// each of those is to the day master.
class _PillarColumn extends StatelessWidget {
  final String title;
  final Pillar pillar;
  final Stem dayMaster;
  final bool isDay;

  /// The hidden stem in command, on the month's pillar by a table that
  /// says; it is marked.
  final Stem? commanding;
  final BaziTables tables;
  final Strings strings;

  const _PillarColumn({
    super.key,
    required this.title,
    required this.pillar,
    required this.dayMaster,
    required this.isDay,
    this.commanding,
    required this.tables,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final small = theme.type.caption.copyWith(color: colors.textSecondary);

    Widget glyph(String hanzi, Unsur element, BaziTerm words) => Column(
      children: [
        Text(
          hanzi,
          style: theme.type.title.copyWith(
            fontSize: 30,
            height: 1.2,
            color: elementColors[element],
          ),
        ),
        Text(
          strings.baziReading(words),
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: small,
        ),
      ],
    );

    String god(Stem stem) => TenGod.of(dayMaster, stem).hanzi;

    return Container(
      padding: EdgeInsets.symmetric(vertical: spacing.sm, horizontal: 2),
      decoration: BoxDecoration(
        color: isDay ? colors.surfaceRaised : colors.surface,
        border: Border.all(color: isDay ? colors.accent : colors.outline),
        borderRadius: BorderRadius.circular(theme.radii.md),
      ),
      child: Column(
        children: [
          Text(
            title.toUpperCase(),
            maxLines: 1,
            style: small.copyWith(letterSpacing: 1.2),
          ),
          SizedBox(height: spacing.xs),
          // What the stem is to the self; the day's own is the self.
          Text(
            isDay ? BaziTerms.dayMaster.hanzi : god(pillar.stem),
            style: small.copyWith(
              color: isDay ? colors.accent : colors.textSecondary,
            ),
          ),
          glyph(
            pillar.stem.hanzi,
            pillar.stem.unsur,
            BaziTerms.stem(pillar.stem),
          ),
          SizedBox(height: spacing.xs),
          glyph(
            pillar.branch.hanzi,
            tables.elementOf(pillar.branch),
            BaziTerms.branch(pillar.branch),
          ),
          Text(
            strings.baziTerm(BaziTerms.branch(pillar.branch)),
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: small,
          ),
          SizedBox(height: spacing.sm),
          // The stems it hides, principal first.
          for (final hidden in tables.hiddenStems[pillar.branch]!)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: hidden.hanzi,
                    style: TextStyle(color: elementColors[hidden.unsur]),
                  ),
                  TextSpan(text: ' ${god(hidden)}'),
                ],
              ),
              maxLines: 1,
              style: hidden == commanding
                  ? small.copyWith(color: colors.accent)
                  : small,
            ),
          // Pushed to the foot, so the four stand level whatever each
          // branch hides.
          const Spacer(),
          SizedBox(height: spacing.sm),
          Text(
            pillar.nayin,
            key: const ValueKey('nayin'),
            maxLines: 1,
            style: small.copyWith(color: elementColors[pillar.nayinElement]),
          ),
        ],
      ),
    );
  }
}

/// One of the journal's categories, offered to take the chart: its dot
/// and its name.
class _Category extends StatelessWidget {
  final JournalCategory category;
  final VoidCallback? onTap;

  const _Category({super.key, required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    return SmPressable(
      onTap: onTap ?? () {},
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
              style: theme.type.label.copyWith(color: colors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

enum _JournalSide { write, read, discard }

/// The title of the entry whose chart is being edited, in a capsule of
/// fixed width in the bar: long titles are cut.
class _EntryCapsule extends StatelessWidget {
  final String title;

  const _EntryCapsule({required this.title});

  static const width = 150.0;

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    return Container(
      key: const ValueKey('bazi-entry-capsule'),
      width: width,
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
