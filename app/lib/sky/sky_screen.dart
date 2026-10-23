import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import '../panel_tabs.dart';
import '../date_picker.dart';
import '../glyph_button.dart';
import '../house.dart';
import '../moon_glyph.dart';
import '../local_clock.dart';
import '../night_dome.dart';
import '../parts.dart';
import '../place_editor.dart';
import '../routes.dart';
import '../snapshot_paint.dart';
import '../sky_place.dart';
import '../strings.dart';
import '../time_picker.dart';
import 'sky_year.dart';
import '../appearance.dart';

/// Opens the sky of [date].
Future<void> pushSky(BuildContext context, {required CivilDate date}) =>
    Navigator.of(context)
        .push(fadeRoute<void>(context, (context) => SkyScreen(date: date)));

/// What the lower panel shows.
enum _Panel { sun, moon, date, time, place }

/// How much of time the dome shows: a day's paths, a month's, a year's.
enum SkyView { day, month, year }

/// The sun's gold and the moon's blue-white: the two told apart wherever
/// they are drawn, in the cool of the Gregorian palette.
Color get skySunColor => Legible.of(_sun);
Color get skyMoonColor => Legible.of(_moon);
const _sun = Color(0xFFD9B26A);
const _moon = Color(0xFFCADBEE);

/// The sun's and moon's colours where [context] is: as they are under a
/// dome drawn at night, else as [Legible] has them.
Color skySunIn(BuildContext context) =>
    NightDome.isNight(context) ? _sun : skySunColor;
Color skyMoonIn(BuildContext context) =>
    NightDome.isNight(context) ? _moon : skyMoonColor;

/// The positions of the sun and the moon over a day, every ten minutes,
/// and when each rises, culminates and sets: each worked out only when
/// first asked for. The month's and the year's views draw from their
/// grids instead, so dragging through the days pays only for what the
/// panel shows.
class SkyDayPaths {
  final List<SkyPosition> Function(Body body) _work;
  final SkyDay Function(Body body, List<SkyPosition> path) _workDay;

  /// For each sample (every ten minutes from the day's midnight by its
  /// noon offset), how many minutes the wall clock stands from it: on a
  /// day the clocks change, the hour before the change is drawn where the
  /// clock had it ([LocalClock.shift]). Empty: none anywhere.
  final List<int> shift;

  SkyDayPaths({
    required List<SkyPosition> Function(Body body) path,
    required SkyDay Function(Body body, List<SkyPosition> path) day,
    this.shift = const [],
  }) : _work = path,
       _workDay = day;

  /// Where across the day, 0 to 1, sample [i] stands by the wall clock.
  double fractionAt(int i) =>
      ((i * 10 + (i < shift.length ? shift[i] : 0)) / 1440).clamp(0.0, 1.0);

  late final List<SkyPosition> sun = _work(Body.sun);
  late final List<SkyPosition> moon = _work(Body.moon);
  late final SkyDay sunDay = _workDay(Body.sun, sun);
  late final SkyDay moonDay = _workDay(Body.moon, moon);
}

/// Where the sun and the moon stand, seen from a place, at a moment of a
/// day.
///
///  * Top bar: the name of the screen, the clock time, the day and the
///    place.
///  * Main body: the sky as a dome seen from above, the horizon its rim
///    and the zenith its centre, north at the top: the day's paths of the
///    sun and the moon over it, and where each stands at the moment. Under
///    it the day as a strip, light where the sun is up and shaded through
///    the twilights; dragging along it moves the moment.
///
///    Or the year: the sun's path on the 21st of every month, and the
///    figure-of-eight it traces at each hour of the clock, with the day's
///    path over them. Under it the year as a picture, the days across and
///    the hours down; dragging over it moves the day and the hour at once.
///  * Lower panel: the sun's figures, the moon's, the date, the time, or
///    the place.
///  * Bottom bar: back; beside it the way back to today and now, and the
///    day or the year.
class SkyScreen extends StatefulWidget {
  final CivilDate date;

  /// The clock the day is read by; the phone's own on that date unless
  /// given.
  final Duration? utcOffset;

  const SkyScreen({super.key, required this.date, this.utcOffset});

  @override
  State<SkyScreen> createState() => _SkyScreenState();
}

class _SkyScreenState extends State<SkyScreen> {
  late CivilDate _date = widget.date;

  Duration get _offset => _offsetOn(_date);

  Duration _offsetOn(CivilDate date) =>
      LocalClock.dayOffset(date, widget.utcOffset);

  static CivilDate _today() {
    final now = DateTime.now();
    return CivilDate(now.year, now.month, now.day);
  }

  // The moment, in minutes after local midnight: now while it follows
  // the clock, noon on any other day.
  late int _minute = widget.date == _today() ? _minuteNow() : 12 * 60;
  late bool _following = widget.date == _today();
  Timer? _tick;

  // Whose rises and sets the panel shows. Dragging through the days, they
  // are worked out at most every [_eventsEvery] and once more when the
  // drag rests, not for every day passed over.
  SkyDayPaths? _eventsPaths;
  DateTime _eventsAt = DateTime(0);
  Timer? _eventsRest;
  static const _eventsEvery = Duration(milliseconds: 150);

  // Counts the moves made from outside the wheels (the strips, today),
  // so the wheels are set afresh then and only then.
  int _jump = 0;

  late _Panel _panel = SkyPlace.current.value == null
      ? _Panel.place
      : _Panel.sun;

  ({double latitude, double longitude})? _for;
  CivilDate? _forDate;
  SkyDayPaths? _paths;

  SkyView _view = SkyView.day;

  // In the month and the year, the hour held while the day moves.
  bool _timeLocked = false;

  SkyYear? _year;
  String? _yearWanted;
  SkyMonth? _month;
  String? _monthWanted;

  // Where the sun (and, over a month, the moon) stands at the moment's
  // clock time on each day of the month or the year.
  String? _lociKey;
  Float32List _sunLocus = Float32List(0);
  Float32List _moonLocus = Float32List(0);

  // The day's own tracks, read from the month's or the year's grid.
  Float32List? _sunTrack;
  Float32List? _moonTrack;

  static int _minuteNow() {
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_following || !mounted) return;
      final now = _minuteNow();
      final today = _today();
      if (now != _minute || today != _date) {
        setState(() {
          _minute = now;
          _date = today;
        });
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _eventsRest?.cancel();
    super.dispose();
  }

  DateTime _instantAt(int minute) =>
      LocalClock.instant(_date, minute, widget.utcOffset);

  SkyDayPaths _pathsFor(({double latitude, double longitude}) place) {
    if (place != _for || _date != _forDate || _paths == null) {
      _for = place;
      _forDate = _date;
      // On the day's own grid, as the engine reckons its events from;
      // the wall clock's shift kept beside it for drawing.
      final midnight = DateTime.utc(
        _date.year,
        _date.month,
        _date.day,
      ).subtract(_offset);
      DateTime at(int minute) => midnight.add(Duration(minutes: minute));
      List<SkyPosition> path(Body body) => [
        for (var minute = 0; minute <= 1440; minute += 10)
          (body == Body.sun ? SkyNow.sun : SkyNow.moon)(
            at(minute),
            latitude: place.latitude,
            longitude: place.longitude,
          ),
      ];
      SkyDay day(Body body, List<SkyPosition> samples) => SkyNow.day(
        body,
        _date,
        latitude: place.latitude,
        longitude: place.longitude,
        utcOffset: _offset,
        samples: samples,
      );
      _paths = SkyDayPaths(
        path: path,
        day: day,
        shift: [
          for (var minute = 0; minute <= 1440; minute += 10)
            LocalClock.shift(at(minute), _date, widget.utcOffset),
        ],
      );
    }
    return _paths!;
  }

  /// A new moment; from the day's strip, the wheels are set afresh.
  void _moveTo(int minute, {bool fromWheels = false}) {
    final clamped = minute.clamp(0, 1439);
    if (clamped == _minute && !_following) return;
    if (!fromWheels && clamped ~/ 15 != _minute ~/ 15) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _minute = clamped;
      _following = false;
      if (!fromWheels) _jump++;
    });
  }

  void _setDate(CivilDate date) {
    if (date == _date) return;
    setState(() {
      _date = date;
      _following = false;
    });
  }

  /// From the month's or the year's picture: a day and an hour at once,
  /// or the day alone while the time is locked.
  void _moveInPeriod(CivilDate date, int minute) {
    final clamped = _timeLocked ? _minute : minute.clamp(0, 1439);
    if (date == _date && clamped == _minute) return;
    if (date.month != _date.month || clamped ~/ 60 != _minute ~/ 60) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _date = date;
      _minute = clamped;
      _following = false;
      _jump++;
    });
  }

  /// Back to today, and to now.
  void _backToToday() {
    HapticFeedback.selectionClick();
    setState(() {
      _date = _today();
      _minute = _minuteNow();
      _following = true;
      _jump++;
    });
  }

  /// Day, month, year, and round again: as the calendar's own views go.
  void _nextView() {
    HapticFeedback.selectionClick();
    setState(() => _view = SkyView.values[(_view.index + 1) % 3]);
  }

  void _toggleLock() {
    HapticFeedback.selectionClick();
    setState(() => _timeLocked = !_timeLocked);
  }

  /// The month of the day being read, at [place], worked out away from
  /// the screen.
  SkyMonth? _monthFor(({double latitude, double longitude}) place) {
    final wanted =
        '${_date.year}-${_date.month} ${place.latitude} ${place.longitude}';
    final month = _month;
    if (month != null &&
        month.year == _date.year &&
        month.month == _date.month &&
        month.latitude == place.latitude &&
        month.longitude == place.longitude) {
      return month;
    }
    if (_monthWanted != wanted) {
      _monthWanted = wanted;
      final first = CivilDate(_date.year, _date.month, 1);
      SkyMonth.build(_date.year, _date.month, place.latitude, place.longitude, [
        for (var day = 0; day < 31; day++)
          _offsetOn(first.addDays(day)).inSeconds,
      ]).then((month) {
        if (!mounted || _monthWanted != wanted) return;
        setState(() => _month = month);
      });
    }
    return null;
  }

  /// From the month's or the year's grid: the sun's (and, over a month,
  /// the moon's) place at the moment's clock time on each day, and the
  /// day's own tracks. Read, not worked out, so dragging costs nothing.
  void _readGrid(SkyGrid? grid) {
    if (grid == null) {
      _lociKey = null;
      _sunLocus = Float32List(0);
      _moonLocus = Float32List(0);
      _sunTrack = null;
      _moonTrack = null;
      return;
    }
    final key = '${identityHashCode(grid)} $_minute $_date';
    if (key == _lociKey) return;
    _lociKey = key;
    final moon = grid.moon;
    _sunLocus = grid.locus(grid.sun, _minute);
    _moonLocus = moon == null ? Float32List(0) : grid.locus(moon, _minute);
    final day = _date.dayNumber - grid.first.dayNumber;
    final inside = day >= 0 && day < grid.days;
    _sunTrack = inside ? grid.trackOf(grid.sun, day) : null;
    _moonTrack = inside && moon != null ? grid.trackOf(moon, day) : null;
  }

  /// The year of the day being read, at [place]: worked out once, away
  /// from the screen, and drawn when it comes.
  SkyYear? _yearFor(({double latitude, double longitude}) place) {
    final wanted = '${_date.year} ${place.latitude} ${place.longitude}';
    final year = _year;
    if (year != null &&
        year.year == _date.year &&
        year.latitude == place.latitude &&
        year.longitude == place.longitude) {
      return year;
    }
    if (_yearWanted != wanted) {
      _yearWanted = wanted;
      final first = CivilDate(_date.year, 1, 1);
      final days = CivilDate(_date.year + 1, 1, 1).dayNumber - first.dayNumber;
      SkyYear.build(_date.year, place.latitude, place.longitude, [
        for (var day = 0; day < days; day++)
          _offsetOn(first.addDays(day)).inSeconds,
      ]).then((year) {
        if (!mounted || _yearWanted != wanted) return;
        setState(() => _year = year);
      });
    }
    return null;
  }

  SkyDayPaths _eventsFor(SkyDayPaths current) {
    final shown = _eventsPaths;
    if (identical(current, shown)) return current;
    final now = DateTime.now();
    if (shown == null || now.difference(_eventsAt) >= _eventsEvery) {
      _eventsPaths = current;
      _eventsAt = now;
      return current;
    }
    _eventsRest?.cancel();
    _eventsRest = Timer(_eventsEvery, () {
      if (mounted) setState(() {});
    });
    return shown;
  }

  void _choose(_Panel panel) {
    if (panel == _panel) return;
    HapticFeedback.selectionClick();
    setState(() => _panel = panel);
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _clockOf(int minute) =>
      '${_two(minute ~/ 60 % 24)}:${_two(minute % 60)}';

  /// An instant as the local clock has it, or a dash.
  String _clock(DateTime? at, Strings strings) {
    if (at == null) return strings.notThatDay;
    final local = LocalClock.wall(at, widget.utcOffset);
    return '${_two(local.hour)}:${_two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final strings = Strings.of(context);

    return ValueListenableBuilder(
      valueListenable: SkyPlace.current,
      builder: (context, place, _) {
        final paths = place == null ? null : _pathsFor(place);
        final instant = _instantAt(_minute);
        final sun = place == null
            ? null
            : SkyNow.sun(
                instant,
                latitude: place.latitude,
                longitude: place.longitude,
              );
        final moon = place == null
            ? null
            : SkyNow.moon(
                instant,
                latitude: place.latitude,
                longitude: place.longitude,
              );

        return ColoredBox(
          color: colors.background,
          child: SafeArea(
            child: Recentre(
              onToday: _backToToday,
              atToday: _following,
              child: FourParts(
                top: TopBar(
                  key: const ValueKey('sky-top-bar'),
                  leading: TopBarTitle(label: strings.skyTitle),
                  // The moment, and the view at the top right, as on the
                  // calendar: day, month or year, the glyph the view a touch
                  // goes to.
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _clockOf(_minute),
                        key: const ValueKey('sky-clock'),
                        style: theme.type.title.copyWith(
                          color: _following
                              ? colors.accent
                              : colors.textSecondary,
                        ),
                      ),
                      SizedBox(width: spacing.md),
                      GlyphButton(
                        key: const ValueKey('sky-view'),
                        glyph: switch (_view) {
                          SkyView.day => Glyph.monthView,
                          SkyView.month => Glyph.yearView,
                          SkyView.year => Glyph.dayView,
                        },
                        square: true,
                        onTap: _nextView,
                      ),
                    ],
                  ),
                  subtitle: place == null
                      ? strings.gregorian(_date)
                      : '${strings.gregorian(_date)} · '
                            '${SkyPlace.label(place)}',
                ),
                body: paths == null || sun == null || moon == null
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(spacing.lg),
                          child: Text(
                            strings.skyAskPlace,
                            key: const ValueKey('sky-ask-place'),
                            textAlign: TextAlign.center,
                            style: theme.type.body.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : _body(theme, strings, place!, paths, sun, moon),
                panel: _panelView(theme, strings, paths, sun, moon, instant),
                bar: const RoomBar(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(
    SmThemeData theme,
    Strings strings,
    ({double latitude, double longitude}) place,
    SkyDayPaths paths,
    SkyPosition sun,
    SkyPosition moon,
  ) {
    final spacing = theme.spacing;
    final face = SkyNow.moonFace(_instantAt(_minute));
    final chosen = _panel == _Panel.moon ? Body.moon : Body.sun;
    final year = _view == SkyView.year ? _yearFor(place) : null;
    final month = _view == SkyView.month ? _monthFor(place) : null;
    _readGrid(year ?? month);
    final first = _view == SkyView.month
        ? CivilDate(_date.year, _date.month, 1)
        : CivilDate(_date.year, 1, 1);

    Widget strip() {
      switch (_view) {
        case SkyView.day:
          return DayStrip(
            key: const ValueKey('sky-strip'),
            paths: paths,
            minute: _minute,
            onMove: _moveTo,
          );
        case SkyView.month:
          if (month == null) {
            return const SizedBox(
              key: ValueKey('sky-month-waiting'),
              height: PeriodStrip.height,
            );
          }
          return PeriodStrip(
            key: const ValueKey('sky-month-strip'),
            days: month.days,
            sun: month.sunHeights,
            moon: month.moonHeights,
            labels: [
              for (final day in const [1, 8, 15, 22, 29])
                if (day <= month.days) (day - 1, '$day'),
            ],
            day: _date.day - 1,
            minute: _minute,
            locked: _timeLocked,
            onMove: (day, minute) => _moveInPeriod(first.addDays(day), minute),
          );
        case SkyView.year:
          if (year == null) {
            return const SizedBox(
              key: ValueKey('sky-year-waiting'),
              height: PeriodStrip.height,
            );
          }
          return PeriodStrip(
            key: const ValueKey('sky-year-strip'),
            days: year.days,
            sun: year.sunHeights,
            labels: [
              for (var m = 1; m <= 12; m++)
                (
                  CivilDate(year.year, m, 15).dayNumber - first.dayNumber,
                  strings.monthNames[m - 1][0],
                ),
            ],
            day: _date.dayNumber - first.dayNumber,
            minute: _minute,
            locked: _timeLocked,
            onMove: (day, minute) => _moveInPeriod(first.addDays(day), minute),
          );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(spacing.md),
            // Its own layer: the panel's scrolling and the strip's
            // dragging do not repaint it.
            child: RepaintBoundary(
              child: NightDome(
                child: SkyDome(
                  key: const ValueKey('sky-dome'),
                  paths: paths,
                  sun: sun,
                  moon: moon,
                  face: face,
                  chosen: chosen,
                  compass: strings.compassFour,
                  view: _view,
                  year: year,
                  sunLocus: _sunLocus,
                  moonLocus: _moonLocus,
                  sunTrack: _sunTrack,
                  moonTrack: _moonTrack,
                  months: [
                    for (final name in strings.monthNames) name.substring(0, 3),
                  ],
                  onChoose: (body) =>
                      _choose(body == Body.sun ? _Panel.sun : _Panel.moon),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(spacing.md, 0, spacing.md, spacing.sm),
          child: AnimatedSwitcher(
            duration: theme.motion.medium,
            child: strip(),
          ),
        ),
      ],
    );
  }

  Widget _panelView(
    SmThemeData theme,
    Strings strings,
    SkyDayPaths? paths,
    SkyPosition? sun,
    SkyPosition? moon,
    DateTime instant,
  ) {
    final spacing = theme.spacing;
    final labels = {
      _Panel.sun: strings.sun,
      _Panel.moon: strings.moonHeading,
      _Panel.date: strings.skyDate,
      _Panel.time: strings.skyTime,
      _Panel.place: strings.skyPlaceTab,
    };
    final shown =
        paths == null && (_panel == _Panel.sun || _panel == _Panel.moon)
        ? _Panel.place
        : _panel;

    Widget content() {
      switch (shown) {
        case _Panel.sun:
          return _sunRows(theme, strings, _eventsFor(paths!), sun!, instant);
        case _Panel.moon:
          return _moonRows(theme, strings, _eventsFor(paths!), moon!, instant);
        case _Panel.date:
          return Center(
            child: DatePicker(
              key: ValueKey('sky-date-$_jump'),
              date: _date,
              strings: strings,
              onChanged: _setDate,
            ),
          );
        case _Panel.time:
          final wheels = TimePicker(
            key: ValueKey('sky-time-$_jump'),
            minuteOfDay: _minute,
            onChanged: (minute) => _moveTo(minute, fromWheels: true),
          );
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.lg),
            // Over a month or a year, beside the wheels: hold the hour,
            // so the picture moves the day alone.
            child: _view == SkyView.day
                ? wheels
                : Row(
                    children: [
                      Expanded(child: wheels),
                      SizedBox(width: spacing.md),
                      GlyphButton(
                        key: const ValueKey('sky-lock'),
                        glyph: Glyph.lock,
                        square: true,
                        lit: _timeLocked,
                        onTap: _toggleLock,
                      ),
                    ],
                  ),
          );
        case _Panel.place:
          return PlaceEditor(strings: strings);
      }
    }

    return Column(
      children: [
        SizedBox(height: spacing.sm),
        PanelTabs(
          listKey: const ValueKey('sky-panels'),
          tabs: _Panel.values,
          shown: shown,
          label: (panel) => labels[panel]!,
          keyOf: (panel) => 'sky-panel-${panel.name}',
          onChoose: _choose,
        ),
        Expanded(
          // Its own layer, so its scrolling repaints nothing above it.
          child: RepaintBoundary(
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: theme.motion.medium,
                child: KeyedSubtree(
                  // The time's wheels are not rebuilt by their own turning.
                  key: ValueKey(shown),
                  child: content(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rows(SmThemeData theme, String name, List<(String, String)> rows) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    return SingleChildScrollView(
      key: ValueKey(name),
      padding: EdgeInsets.fromLTRB(spacing.md, spacing.sm, spacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: EdgeInsets.only(bottom: spacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      style: theme.type.caption.copyWith(
                        color: colors.textFaint,
                        letterSpacing: 1.2,
                        height: 1.9,
                      ),
                    ),
                  ),
                  SizedBox(width: spacing.sm),
                  Text(
                    value,
                    textAlign: TextAlign.end,
                    style: theme.type.label.copyWith(
                      color: colors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: spacing.sm),
        ],
      ),
    );
  }

  // Where it stands: height and bearing, then the sky's own coordinates.
  List<(String, String)> _placeRows(Strings strings, SkyPosition p) => [
    (
      strings.skyAltitude,
      p.altitude < -0.05
          ? '${_signed(p.trueAltitude)} · ${strings.skyBelow}'
          : _signed(p.altitude),
    ),
    (
      strings.skyAzimuth,
      '${p.azimuth.toStringAsFixed(2)}° '
          '${strings.compassPoint(((p.azimuth + 22.5) ~/ 45))}',
    ),
    (strings.skyHourAngle, _hours(p.hourAngle, signed: true)),
    (strings.skyRightAscension, _hours(p.rightAscension)),
    (strings.skyDeclination, _arc(p.declination)),
    (
      strings.skyEclipticLongitude,
      '${p.eclipticLongitude.toStringAsFixed(4)}°',
    ),
  ];

  // Rise, culmination and set; the rise and set with the bearing they are
  // at, where on the horizon to look.
  List<(String, String)> _dayRows(Strings strings, SkyDay day) => [
    (strings.skyRise, _withBearing(day.rise, day.riseAzimuth, strings)),
    (
      strings.skyTransit,
      day.transit == null
          ? strings.notThatDay
          : '${_clock(day.transit, strings)} · '
                '${_signed(day.transitAltitude!)}',
    ),
    (strings.skySet, _withBearing(day.set, day.setAzimuth, strings)),
  ];

  String _withBearing(DateTime? at, double? bearing, Strings strings) =>
      bearing == null
      ? _clock(at, strings)
      : '${_clock(at, strings)} · ${bearing.toStringAsFixed(0)}° '
            '${strings.compassPoint(((bearing + 22.5) ~/ 45))}';

  Widget _sunRows(
    SmThemeData theme,
    Strings strings,
    SkyDayPaths paths,
    SkyPosition sun,
    DateTime instant,
  ) {
    final day = paths.sunDay;
    String span(DateTime? from, DateTime? to) =>
        '${_clock(from, strings)} – ${_clock(to, strings)}';
    final up = day.rise != null && day.set != null
        ? day.set!.difference(day.rise!).inMinutes
        : null;
    return _rows(theme, 'sky-sun-rows', [
      ..._placeRows(strings, sun),
      (strings.skyDistance, '${sun.distanceAu.toStringAsFixed(6)} au'),
      (strings.skyDiameter, _arc(sun.semidiameter * 2, signed: false)),
      ..._dayRows(strings, day),
      if (up != null) (strings.daylight, strings.hoursMinutes(up)),
      (strings.skyCivil, span(day.civilDawn, day.civilDusk)),
      (strings.skyNautical, span(day.nauticalDawn, day.nauticalDusk)),
      (
        strings.skyAstronomical,
        span(day.astronomicalDawn, day.astronomicalDusk),
      ),
      (
        strings.skyEquationOfTime,
        strings.skyMinutesSeconds(
          Sun.equationOfTimeAt(Sun.julianDayOf(instant)),
        ),
      ),
    ]);
  }

  Widget _moonRows(
    SmThemeData theme,
    Strings strings,
    SkyDayPaths paths,
    SkyPosition moon,
    DateTime instant,
  ) {
    final face = SkyNow.moonFace(instant);
    final date = _date;
    String phase(double elongation) {
      final at = Sky.nextPhase(
        date,
        utcOffset: _offset,
        elongation: elongation,
      ).add(_offset);
      final day = CivilDate(at.year, at.month, at.day);
      return '${strings.gregorian(day)} · '
          '${strings.inDays(day.dayNumber - date.dayNumber)}';
    }

    return _rows(theme, 'sky-moon-rows', [
      ..._placeRows(strings, moon),
      (strings.skyEclipticLatitude, _arc(moon.eclipticLatitude)),
      (strings.skyDistance, '${_thousands(moon.distance.round())} km'),
      (strings.skyDiameter, _arc(moon.semidiameter * 2, signed: false)),
      (
        strings.skyPhase,
        '${strings.moonPhase(Moon.of(date, utcOffset: _offset).phase)} · '
            '${(face.illumination * 100).toStringAsFixed(1)}%',
      ),
      (strings.skyElongation, '${face.elongation.toStringAsFixed(2)}°'),
      ..._dayRows(strings, paths.moonDay),
      (strings.nextFullMoon, phase(180)),
      (strings.nextNewMoon, phase(0)),
    ]);
  }

  static String _signed(double degrees) =>
      '${degrees < 0 ? '−' : '+'}${degrees.abs().toStringAsFixed(2)}°';

  /// Degrees, minutes and seconds of arc: "−8° 04′ 11″".
  static String _arc(double degrees, {bool signed = true}) {
    final seconds = (degrees.abs() * 3600).round();
    final sign = signed ? (degrees < 0 ? '−' : '+') : '';
    final d = seconds ~/ 3600;
    final m = seconds ~/ 60 % 60;
    final s = seconds % 60;
    return d == 0 && !signed
        ? '$m′ ${_two(s)}″'
        : '$sign$d° ${_two(m)}′ ${_two(s)}″';
  }

  /// An angle as hours, minutes and seconds of time: "13h 16m 21s".
  static String _hours(double degrees, {bool signed = false}) {
    final seconds = (degrees.abs() / 15 * 3600).round();
    final sign = signed ? (degrees < 0 ? '−' : '+') : '';
    return '$sign${seconds ~/ 3600}h ${_two(seconds ~/ 60 % 60)}m '
        '${_two(seconds % 60)}s';
  }

  static String _thousands(int value) => value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
}

/// The sky seen from above: the horizon the rim, the zenith the centre,
/// north at the top and east to the right, as on a map. Rings at 30 and
/// 60 degrees up. The day's paths of the sun and the moon where they are
/// above the horizon; each body where it stands, or, below the horizon,
/// as a hollow mark on the rim at its bearing. Touching near a body
/// chooses it.
class SkyDome extends StatelessWidget {
  final SkyDayPaths paths;
  final SkyPosition sun;
  final SkyPosition moon;
  final MoonFace face;
  final Body chosen;
  final List<String> compass;
  final ValueChanged<Body> onChoose;

  /// How much of time it shows.
  final SkyView view;

  /// The year, when the dome shows it.
  final SkyYear? year;

  /// Where the sun stands at the moment's clock time on each day of the
  /// month, or every other day of the year; and the moon, over a month.
  final Float32List sunLocus;
  final Float32List moonLocus;

  /// Over a month or a year, the day's own tracks, read from its grid.
  final Float32List? sunTrack;
  final Float32List? moonTrack;

  /// Short names of the months, to label the year's outermost paths.
  final List<String> months;

  const SkyDome({
    super.key,
    required this.paths,
    required this.sun,
    required this.moon,
    required this.face,
    required this.chosen,
    required this.compass,
    required this.onChoose,
    this.view = SkyView.day,
    this.year,
    required this.sunLocus,
    required this.moonLocus,
    this.sunTrack,
    this.moonTrack,
    this.months = const [],
  });

  /// Where a height and a bearing fall in a dome of [radius] about
  /// [centre]: the distance from the centre grows evenly with the
  /// distance from the zenith. Below the horizon, on the rim.
  static Offset project(
    Offset centre,
    double radius,
    double altitude,
    double azimuth,
  ) {
    final r = radius * (90 - math.max(altitude, 0)) / 90;
    final a = azimuth * math.pi / 180;
    return centre + Offset(math.sin(a) * r, -math.cos(a) * r);
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final centre = size.center(Offset.zero);
        final radius = size.shortestSide / 2 - 18;
        final moonAt = project(centre, radius, moon.altitude, moon.azimuth);
        const moonSize = 22.0;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final sunAt = project(centre, radius, sun.altitude, sun.azimuth);
            final toSun = (details.localPosition - sunAt).distance;
            final toMoon = (details.localPosition - moonAt).distance;
            if (math.min(toSun, toMoon) > 40) return;
            onChoose(toSun <= toMoon ? Body.sun : Body.moon);
          },
          child: Stack(
            children: [
              // What does not move with the moment (the horizon, the
              // rings, the year's paths and figures, their labels), drawn
              // once into an image and shown from it.
              Positioned.fill(
                child: SnapshotPaint(
                  identity: (
                    view,
                    year,
                    radius,
                    months.join(),
                    compass.join(),
                    colors.outline,
                    colors.textFaint,
                    colors.textSecondary,
                  ),
                  painter: _DomePainter(
                    back: true,
                    paths: paths,
                    sun: sun,
                    moon: moon,
                    chosen: chosen,
                    compass: compass,
                    view: view,
                    year: year,
                    sunLocus: sunLocus,
                    moonLocus: moonLocus,
                    sunTrack: sunTrack,
                    moonTrack: moonTrack,
                    months: months,
                    radius: radius,
                    sunColor: skySunIn(context),
                    moonColor: skyMoonIn(context),
                    north: colors.textSecondary,
                    line: colors.outline,
                    faint: colors.textFaint,
                    label: theme.type.caption,
                  ),
                ),
              ),
              // What does: the day's paths, the figures of the moment's
              // hour, the bodies.
              Positioned.fill(
                child: CustomPaint(
                  painter: _DomePainter(
                    back: false,
                    paths: paths,
                    sun: sun,
                    moon: moon,
                    chosen: chosen,
                    compass: compass,
                    view: view,
                    year: year,
                    sunLocus: sunLocus,
                    moonLocus: moonLocus,
                    sunTrack: sunTrack,
                    moonTrack: moonTrack,
                    months: months,
                    radius: radius,
                    sunColor: skySunIn(context),
                    moonColor: skyMoonIn(context),
                    north: colors.textSecondary,
                    line: colors.outline,
                    faint: colors.textFaint,
                    label: theme.type.caption,
                  ),
                ),
              ),
              // The moon as it looks, lit as it is.
              Positioned(
                left: moonAt.dx - moonSize / 2,
                top: moonAt.dy - moonSize / 2,
                child: Opacity(
                  opacity: moon.altitude < 0 ? 0.35 : 1,
                  child: MoonFaceGlyph(
                    illumination: face.illumination,
                    waxing: face.waxing,
                    size: moonSize,
                    color: skyMoonIn(context),
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

class _DomePainter extends CustomPainter {
  /// The layer that holds still: the frame and the year. The other holds
  /// the rest.
  final bool back;
  final SkyDayPaths paths;
  final SkyPosition sun;
  final SkyPosition moon;
  final Body chosen;
  final List<String> compass;
  final SkyView view;
  final SkyYear? year;
  final Float32List sunLocus;
  final Float32List moonLocus;
  final Float32List? sunTrack;
  final Float32List? moonTrack;
  final List<String> months;
  final double radius;
  final Color sunColor;
  final Color moonColor;
  final Color north;
  final Color line;
  final Color faint;
  final TextStyle label;

  const _DomePainter({
    required this.back,
    required this.paths,
    required this.sun,
    required this.moon,
    required this.chosen,
    required this.compass,
    required this.view,
    required this.year,
    required this.sunLocus,
    required this.moonLocus,
    required this.sunTrack,
    required this.moonTrack,
    required this.months,
    required this.radius,
    required this.sunColor,
    required this.moonColor,
    required this.north,
    required this.line,
    required this.faint,
    required this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    Offset at(SkyPosition p) =>
        SkyDome.project(centre, radius, p.altitude, p.azimuth);
    if (back) {
      _paintBack(canvas, centre);
      return;
    }

    // The day's paths, where they are above the horizon: one stroke for
    // each stretch above it, so the line is even.
    void stroke(Path stroke, Color color, bool lit) => canvas.drawPath(
      stroke,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lit ? 2 : 1.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: lit ? 0.7 : 0.42),
    );
    void path(List<SkyPosition> points, Color color, bool lit) {
      final line = Path();
      var drawing = false;
      for (final point in points) {
        if (point.altitude < 0) {
          drawing = false;
          continue;
        }
        final o = at(point);
        drawing ? line.lineTo(o.dx, o.dy) : line.moveTo(o.dx, o.dy);
        drawing = true;
      }
      stroke(line, color, lit);
    }

    void track(Float32List? pairs, Color color, bool lit) {
      if (pairs != null) stroke(_pairsPath(centre, pairs), color, lit);
    }

    switch (view) {
      case SkyView.day:
        path(paths.moon, moonColor, chosen == Body.moon);
        path(paths.sun, sunColor, chosen == Body.sun);
      case SkyView.month:
        // The day's paths faint under the month's places.
        track(moonTrack, moonColor, false);
        track(sunTrack, sunColor, false);
        _paintLocus(canvas, centre, moonLocus, moonColor, numbered: true);
        _paintLocus(canvas, centre, sunLocus, sunColor, numbered: false);
      case SkyView.year:
        // The day's own path, and the figure of the moment's hour, strong
        // over the year's.
        track(sunTrack, sunColor, true);
        _paintLocus(canvas, centre, sunLocus, sunColor, numbered: false);
    }

    // The sun where it stands; hollow on the rim when below.
    final sunAt = at(sun);
    final down = sun.altitude < 0;
    canvas.drawCircle(
      sunAt,
      9,
      Paint()
        ..style = down ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 2
        ..color = sunColor.withValues(alpha: down ? 0.5 : 1),
    );

    // A ring about the body chosen.
    final chosenAt = chosen == Body.sun ? sunAt : at(moon);
    canvas.drawCircle(
      chosenAt,
      16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = (chosen == Body.sun ? sunColor : moonColor).withValues(
          alpha: 0.7,
        ),
    );
  }

  // The horizon, the rings at 30 and 60 degrees up, the four points, and,
  // over a year, its paths and figures.
  void _paintBack(Canvas canvas, Offset centre) {
    // The horizon, and the rings at 30 and 60 degrees up.
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = line,
    );
    for (final up in const [30, 60]) {
      canvas.drawCircle(
        centre,
        radius * (90 - up) / 90,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = line.withValues(alpha: 0.6),
      );
    }
    canvas
      ..drawLine(
        centre - Offset(0, radius),
        centre + Offset(0, radius),
        Paint()..color = line.withValues(alpha: 0.4),
      )
      ..drawLine(
        centre - Offset(radius, 0),
        centre + Offset(radius, 0),
        Paint()..color = line.withValues(alpha: 0.4),
      );

    // North, east, south and west outside the rim.
    for (final (i, point) in compass.indexed) {
      final text = TextPainter(
        text: TextSpan(
          text: point,
          style: label.copyWith(color: i == 0 ? north : faint),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final a = i * math.pi / 2;
      final place = centre + Offset(math.sin(a), -math.cos(a)) * (radius + 10);
      text.paint(canvas, place - Offset(text.width / 2, text.height / 2));
    }

    final year = this.year;
    if (view == SkyView.year && year != null) _paintYear(canvas, centre, year);
  }

  // Where a body stands at one clock time day after day: a dot for each
  // day it is up, joined in order; over a month the moon's numbered by
  // the day of the month, none over another.
  void _paintLocus(
    Canvas canvas,
    Offset centre,
    Float32List points,
    Color color, {
    required bool numbered,
  }) {
    if (points.isEmpty) return;
    Offset at(int i) =>
        SkyDome.project(centre, radius, points[2 * i], points[2 * i + 1]);
    canvas.drawPath(
      _pairsPath(centre, points),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = view == SkyView.year ? 2 : 1
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: view == SkyView.year ? 0.85 : 0.4),
    );
    if (view == SkyView.year) return;
    final dot = Paint()..color = color.withValues(alpha: 0.85);
    final taken = <Rect>[];
    for (var i = 0; i < points.length ~/ 2; i++) {
      if (points[2 * i] < 0) continue;
      final o = at(i);
      canvas.drawCircle(o, 2.6, dot);
      if (!numbered) continue;
      final text = _numbers.putIfAbsent(
        (i + 1, color),
        () => TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: label.copyWith(
              color: color.withValues(alpha: 0.75),
              fontSize: 9,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
      );
      final rect = Rect.fromLTWH(
        o.dx + 4,
        o.dy - text.height - 1,
        text.width,
        text.height,
      );
      if (taken.any((other) => other.inflate(1).overlaps(rect))) continue;
      taken.add(rect);
      text.paint(canvas, rect.topLeft);
    }
  }

  // The day numbers, laid out once.
  static final _numbers = <(int, Color), TextPainter>{};

  // A run of height, bearing pairs as one stroke for each stretch above
  // the horizon.
  Path _pairsPath(Offset centre, Float32List points) {
    final line = Path();
    var drawing = false;
    for (var i = 0; i + 1 < points.length; i += 2) {
      if (points[i] < 0) {
        drawing = false;
        continue;
      }
      final o = SkyDome.project(centre, radius, points[i], points[i + 1]);
      drawing ? line.lineTo(o.dx, o.dy) : line.moveTo(o.dx, o.dy);
      drawing = true;
    }
    return line;
  }

  // The year under the day: the sun's path on the 21st of each month, the
  // solstices' named, and the figure-of-eight of each hour of the clock,
  // numbered at its top.
  void _paintYear(Canvas canvas, Offset centre, SkyYear year) {
    Offset at(double altitude, double azimuth) =>
        SkyDome.project(centre, radius, altitude, azimuth);

    Path stroke(Float32List points) {
      final line = Path();
      var drawing = false;
      for (var i = 0; i + 1 < points.length; i += 2) {
        if (points[i] < 0) {
          drawing = false;
          continue;
        }
        final o = at(points[i], points[i + 1]);
        drawing ? line.lineTo(o.dx, o.dy) : line.moveTo(o.dx, o.dy);
        drawing = true;
      }
      return line;
    }

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = sunColor.withValues(alpha: 0.22);
    for (final track in year.tracks) {
      canvas.drawPath(stroke(track), trackPaint);
    }

    final loopPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.round
      ..color = faint.withValues(alpha: 0.7);
    for (final loop in year.loops) {
      if (loop.isNotEmpty) canvas.drawPath(stroke(loop), loopPaint);
    }

    // The labels, none over another: each is tried at its places in turn
    // and left out if none is free.
    final taken = <Rect>[];
    void place(String text, Color color, List<(Offset, bool)> places) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: label.copyWith(color: color, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      for (final (point, above) in places) {
        final rect = Rect.fromLTWH(
          point.dx - painter.width / 2,
          above ? point.dy - painter.height - 3 : point.dy + 3,
          painter.width,
          painter.height,
        );
        if (taken.any((other) => other.inflate(2).overlaps(rect))) continue;
        taken.add(rect);
        painter.paint(canvas, rect.topLeft);
        return;
      }
    }

    // A path's point furthest north or south on the dome (highest or
    // lowest on the page), above the horizon.
    Offset? end(Float32List points, {required bool north}) {
      Offset? found;
      for (var i = 0; i + 1 < points.length; i += 2) {
        if (points[i] < 2) continue;
        final o = at(points[i], points[i + 1]);
        if (found == null || (north ? o.dy < found.dy : o.dy > found.dy)) {
          found = o;
        }
      }
      return found;
    }

    // The solstices first: June over its path, December under its own.
    if (months.length >= 12) {
      for (final (month, north) in const [(6, true), (12, false)]) {
        // At its noon: the point it stands highest.
        final track = year.tracks[month - 1];
        var high = 0;
        for (var i = 0; i + 1 < track.length; i += 2) {
          if (track[i] > track[high]) high = i;
        }
        if (track[high] < 2) continue;
        final point = at(track[high], track[high + 1]);
        place('21 ${months[month - 1]}', sunColor.withValues(alpha: 0.8), [
          (point, north),
        ]);
      }
    }
    // Then each hour, at whichever end of its figure has room.
    for (final (hour, loop) in year.loops.indexed) {
      if (loop.isEmpty) continue;
      final south = end(loop, north: false);
      final north = end(loop, north: true);
      place(hour.toString().padLeft(2, '0'), faint, [
        if (south != null) (south, false),
        if (north != null) (north, true),
      ]);
    }
  }

  @override
  bool shouldRepaint(_DomePainter old) => back
      ? old.view != view ||
            old.year != year ||
            old.radius != radius ||
            // Lists made afresh each build: the same if their words are.
            !listEquals(old.months, months) ||
            !listEquals(old.compass, compass) ||
            old.sunColor != sunColor ||
            old.north != north ||
            old.line != line ||
            old.faint != faint
      : old.view != view ||
            old.year != year ||
            old.sunLocus != sunLocus ||
            old.moonLocus != moonLocus ||
            old.sunTrack != sunTrack ||
            old.moonTrack != moonTrack ||
            old.paths != paths ||
            old.sun != sun ||
            old.moon != moon ||
            old.chosen != chosen ||
            old.radius != radius ||
            old.sunColor != sunColor ||
            old.moonColor != moonColor ||
            old.line != line ||
            old.faint != faint;
}

/// The day as a strip, midnight to midnight: light where the sun is up,
/// shading through the twilights to night, the moon's time above the
/// horizon a line along the foot, and the moment a mark that a touch or a
/// drag moves.
class DayStrip extends StatelessWidget {
  final SkyDayPaths paths;
  final int minute;
  final ValueChanged<int> onMove;

  const DayStrip({
    super.key,
    required this.paths,
    required this.minute,
    required this.onMove,
  });

  static const height = 40.0;

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void move(Offset position) =>
            onMove((position.dx / width * 1440).round());
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => move(details.localPosition),
          onHorizontalDragUpdate: (details) => move(details.localPosition),
          child: SizedBox(
            height: height,
            child: CustomPaint(
              size: Size(width, height),
              painter: _StripPainter(
                paths: paths,
                minute: minute,
                day: skySunColor,
                night: colors.surfaceRaised,
                moon: skyMoonColor,
                ink: colors.textPrimary,
                faint: colors.textFaint,
                label: theme.type.caption,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StripPainter extends CustomPainter {
  final SkyDayPaths paths;
  final int minute;
  final Color day;
  final Color night;
  final Color moon;
  final Color ink;
  final Color faint;
  final TextStyle label;

  const _StripPainter({
    required this.paths,
    required this.minute,
    required this.day,
    required this.night,
    required this.moon,
    required this.ink,
    required this.faint,
    required this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final band = Rect.fromLTWH(0, 0, size.width, size.height - 14);
    canvas
      ..save()
      ..clipRRect(RRect.fromRectAndRadius(band, const Radius.circular(6)))
      ..drawRect(band, Paint()..color = night);

    // Shaded by how high the sun is: full above the horizon, fading to
    // nothing at 18 degrees below. One gradient, a stop every ten
    // minutes.
    double light(double altitude) =>
        altitude >= 0 ? 0.55 : (1 - math.min(-altitude, 18) / 18) * 0.35;
    final count = paths.sun.length;
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          colors: [
            for (final p in paths.sun) day.withValues(alpha: light(p.altitude)),
          ],
          // Where each sample stands by the wall clock, never going back
          // (an autumn day's repeated hour is drawn once).
          stops: () {
            final stops = <double>[];
            for (var i = 0; i < count; i++) {
              final f = paths.fractionAt(i);
              stops.add(stops.isEmpty ? f : (f < stops.last ? stops.last : f));
            }
            return stops;
          }(),
        ).createShader(band),
    );
    // The moon above the horizon, along the foot of the band.
    final moonLine = Path();
    var up = false;
    for (var i = 0; i < paths.moon.length; i++) {
      if (paths.moon[i].altitude < 0) {
        up = false;
        continue;
      }
      final point = Offset(paths.fractionAt(i) * size.width, band.bottom - 3);
      up
          ? moonLine.lineTo(point.dx, point.dy)
          : moonLine.moveTo(point.dx, point.dy);
      up = true;
    }
    canvas.drawPath(
      moonLine,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = moon.withValues(alpha: 0.6),
    );
    canvas.restore();

    // The hours under it, every sixth.
    for (var hour = 0; hour <= 24; hour += 6) {
      final x = size.width * hour / 24;
      final text = TextPainter(
        text: TextSpan(
          text: hour.toString().padLeft(2, '0'),
          style: label.copyWith(color: faint, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(
          (x - text.width / 2).clamp(0, size.width - text.width),
          size.height - text.height,
        ),
      );
    }

    // The moment.
    final x = size.width * minute / 1440;
    canvas.drawLine(
      Offset(x, band.top - 2),
      Offset(x, band.bottom + 2),
      Paint()
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = ink,
    );
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      old.paths != paths ||
      old.minute != minute ||
      old.day != day ||
      old.night != night ||
      old.moon != moon ||
      old.ink != ink ||
      old.faint != faint;
}

/// A month or a year as a picture: the days across, the first at the
/// left, and the hours down, midnight at the top. Each half hour is gold
/// as high as the sun stands, fading through the twilights to night; over
/// a month, blue-white where the moon is up. The day and the moment are a
/// cross; a touch or a drag moves both, or, with the time locked, the day
/// alone, and the hour's line is drawn solid.
class PeriodStrip extends StatelessWidget {
  final int days;

  /// `days` rows of [SkyGrid.halfHours] heights.
  final Float32List sun;
  final Float32List? moon;

  /// Labels under the days: the day they stand under, and the text.
  final List<(int, String)> labels;

  /// The day chosen, counted from the first; and the moment.
  final int day;
  final int minute;
  final bool locked;
  final void Function(int day, int minute) onMove;

  const PeriodStrip({
    super.key,
    required this.days,
    required this.sun,
    required this.labels,
    required this.day,
    required this.minute,
    required this.locked,
    required this.onMove,
    this.moon,
  });

  static const height = 96.0;
  static const labelHeight = 14.0;

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const band = height - labelHeight;
        void move(Offset position) {
          final day = (position.dx / width * days).floor().clamp(0, days - 1);
          final minute = ((position.dy / band * 1440) / 10).round() * 10;
          onMove(day, minute);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) => move(details.localPosition),
          onPanUpdate: (details) => move(details.localPosition),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                // Drawn once for the period into an image; only the cross
                // moves.
                Positioned.fill(
                  child: SnapshotPaint(
                    identity: (
                      sun,
                      moon,
                      days,
                      colors.surfaceRaised,
                      colors.textFaint,
                    ),
                    painter: _PeriodPicturePainter(
                      days: days,
                      sun: sun,
                      moon: moon,
                      labels: labels,
                      night: colors.surfaceRaised,
                      faint: colors.textFaint,
                      label: theme.type.caption,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CrossPainter(
                      day: day,
                      days: days,
                      minute: minute,
                      locked: locked,
                      ink: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PeriodPicturePainter extends CustomPainter {
  final int days;
  final Float32List sun;
  final Float32List? moon;
  final List<(int, String)> labels;
  final Color night;
  final Color faint;
  final TextStyle label;

  const _PeriodPicturePainter({
    required this.days,
    required this.sun,
    required this.moon,
    required this.labels,
    required this.night,
    required this.faint,
    required this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final band = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height - PeriodStrip.labelHeight,
    );
    canvas
      ..save()
      ..clipRRect(RRect.fromRectAndRadius(band, const Radius.circular(6)))
      ..drawRect(band, Paint()..color = night);
    const halves = SkyGrid.halfHours;
    final columnWidth = band.width / days;
    final rowHeight = band.height / halves;
    final paint = Paint()..isAntiAlias = false;
    final moon = this.moon;
    for (var d = 0; d < days; d++) {
      for (var h = 0; h < halves; h++) {
        // Each edge shared exactly with its neighbour, and drawn without
        // smoothing, so every pixel is shaded once and no seam shows.
        final cell = Rect.fromLTRB(
          d * columnWidth,
          h * rowHeight,
          (d + 1) * columnWidth,
          (h + 1) * rowHeight,
        );
        final altitude = sun[d * halves + h];
        final light = altitude >= 0
            ? 0.55
            : (1 - math.min(-altitude, 18) / 18) * 0.35;
        if (light > 0) {
          paint.color = skySunColor.withValues(alpha: light);
          canvas.drawRect(cell, paint);
        }
        if (moon != null && moon[d * halves + h] >= 0) {
          paint.color = skyMoonColor.withValues(alpha: 0.24);
          canvas.drawRect(cell, paint);
        }
      }
    }
    canvas.restore();

    for (final (day, text) in labels) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: label.copyWith(color: faint, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (day + 0.5) / days * size.width;
      painter.paint(
        canvas,
        Offset(
          (x - painter.width / 2).clamp(0, size.width - painter.width),
          size.height - painter.height,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_PeriodPicturePainter old) =>
      old.sun != sun ||
      old.moon != moon ||
      old.days != days ||
      old.night != night ||
      old.faint != faint;
}

class _CrossPainter extends CustomPainter {
  final int day;
  final int days;
  final int minute;
  final bool locked;
  final Color ink;

  const _CrossPainter({
    required this.day,
    required this.days,
    required this.minute,
    required this.locked,
    required this.ink,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final band = size.height - PeriodStrip.labelHeight;
    final x = (day + 0.5) / days * size.width;
    final y = minute / 1440 * band;
    canvas
      ..drawLine(
        Offset(x, 0),
        Offset(x, band),
        Paint()
          ..strokeWidth = 1.5
          ..color = ink.withValues(alpha: 0.7),
      )
      // Held, the hour's line is solid and strong.
      ..drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..strokeWidth = locked ? 2 : 1
          ..color = ink.withValues(alpha: locked ? 0.95 : 0.5),
      )
      ..drawCircle(Offset(x, y), 4, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(_CrossPainter old) =>
      old.day != day ||
      old.days != days ||
      old.minute != minute ||
      old.locked != locked ||
      old.ink != ink;
}
