import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import '../date_picker.dart';
import '../house.dart';
import '../local_clock.dart';
import '../night_dome.dart';
import '../panel_tabs.dart';
import '../parts.dart';
import '../place_editor.dart';
import '../routes.dart';
import '../sky/sky_screen.dart';
import '../sky_place.dart';
import '../strings.dart';
import '../time_picker.dart';
import 'planet_look.dart';

/// Opens the planets of [date].
Future<void> pushPlanets(BuildContext context, {required CivilDate date}) =>
    Navigator.of(context)
        .push(fadeRoute<void>(context, (context) => PlanetsScreen(date: date)));

/// What the lower panel shows.
enum _Panel { planets, hours, lore, date, time, place }

/// The planets' days at a place, worked out away from the screen.
abstract final class PlanetsWork {
  static Future<Map<Body, SkyDay>> days(
    CivilDate date,
    double latitude,
    double longitude,
    Duration utcOffset,
  ) => Isolate.run(
    () => {
      for (final body in Planets.all)
        body: SkyNow.day(
          body,
          date,
          latitude: latitude,
          longitude: longitude,
          utcOffset: utcOffset,
        ),
    },
  );
}

/// The planets: where they stand, when they rise and set, the old
/// planetary hours, and what each planet was held to stand for.
///
///  * Top bar: the name, the clock time, the day and the place.
///  * Main body: the sky as a dome seen from above (the horizon its rim,
///    north at the top, east on the right, as the ephemeris and the star
///    map): the ecliptic the planets keep to, the sun, the moon and the
///    planets up at the moment. Under it the day's strip, to move
///    through the day.
///  * Lower panel: the planets, each with its height, brightness, rising
///    and setting and which side of the sun; the planetary hours of the
///    day; the planets' old correspondences; the date, the time, the
///    place.
///  * Bottom bar: back to the calendar, and back to now.
class PlanetsScreen extends StatefulWidget {
  final CivilDate date;

  /// For tests: the zone's offset, else the phone's.
  final Duration? utcOffset;

  /// The minute after midnight to open at, on a day not today; nine in
  /// the evening unless given.
  final int? minute;

  const PlanetsScreen({
    super.key,
    required this.date,
    this.utcOffset,
    this.minute,
  });

  @override
  State<PlanetsScreen> createState() => _PlanetsScreenState();
}

class _PlanetsScreenState extends State<PlanetsScreen> {
  late CivilDate _date = widget.date;
  late bool _following = widget.date == _today();
  late int _minute = _following ? _minuteNow() : widget.minute ?? 21 * 60;
  Timer? _tick;
  int _jump = 0;

  late _Panel _panel = SkyPlace.current.value == null
      ? _Panel.place
      : _Panel.planets;

  Body? _chosen;

  // The row of the hour now, brought into view when the hours open.
  final _nowHour = GlobalKey(debugLabel: 'planets-hour-now');

  // What is worked out once a day and place.
  ({double latitude, double longitude})? _pathsPlace;
  CivilDate? _pathsDate;
  SkyDayPaths? _paths;
  String? _daysFor;
  Map<Body, SkyDay>? _days;
  String? _hoursFor;
  List<PlanetaryHour>? _hours;

  Duration get _offset => LocalClock.dayOffset(_date, widget.utcOffset);

  DateTime get _instant => LocalClock.instant(_date, _minute, widget.utcOffset);

  static CivilDate _today() {
    final now = DateTime.now();
    return CivilDate(now.year, now.month, now.day);
  }

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
      if (now != _minute || _today() != _date) {
        setState(() {
          _minute = now;
          _date = _today();
        });
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  SkyDayPaths _pathsFor(({double latitude, double longitude}) at) {
    if (at != _pathsPlace || _date != _pathsDate || _paths == null) {
      _pathsPlace = at;
      _pathsDate = _date;
      final midnight = DateTime.utc(
        _date.year,
        _date.month,
        _date.day,
      ).subtract(_offset);
      final date = _date;
      final offset = _offset;
      _paths = SkyDayPaths(
        path: (body) => [
          for (var minute = 0; minute <= 1440; minute += 10)
            (body == Body.sun ? SkyNow.sun : SkyNow.moon)(
              midnight.add(Duration(minutes: minute)),
              latitude: at.latitude,
              longitude: at.longitude,
            ),
        ],
        day: (body, samples) => SkyNow.day(
          body,
          date,
          latitude: at.latitude,
          longitude: at.longitude,
          utcOffset: offset,
          samples: samples,
        ),
        shift: [
          for (var minute = 0; minute <= 1440; minute += 10)
            LocalClock.shift(
              midnight.add(Duration(minutes: minute)),
              date,
              widget.utcOffset,
            ),
        ],
      );
    }
    return _paths!;
  }

  void _workDays(({double latitude, double longitude}) at) {
    final key = '${_date.dayNumber} ${at.latitude} ${at.longitude}';
    if (key == _daysFor) return;
    _daysFor = key;
    _days = null;
    PlanetsWork.days(_date, at.latitude, at.longitude, _offset).then((days) {
      if (mounted && _daysFor == key) setState(() => _days = days);
    });
  }

  // The hours that hold the moment: today's from its sunrise, or, before
  // sunrise, the night of the day before.
  List<PlanetaryHour>? _hoursFor0(({double latitude, double longitude}) at) {
    final key = '${_date.dayNumber} $_minute ${at.latitude} ${at.longitude}';
    if (key == _hoursFor) return _hours;
    _hoursFor = key;
    List<PlanetaryHour>? of(CivilDate date) => PlanetaryHours.of(
      date,
      latitude: at.latitude,
      longitude: at.longitude,
      utcOffset: LocalClock.dayOffset(date, widget.utcOffset),
      nextOffset: LocalClock.dayOffset(date.addDays(1), widget.utcOffset),
    );
    final today = of(_date);
    _hours = today != null && _instant.isBefore(today.first.start)
        ? of(_date.addDays(-1)) ?? today
        : today;
    return _hours;
  }

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

  void _backToNow() {
    HapticFeedback.selectionClick();
    setState(() {
      _date = _today();
      _minute = _minuteNow();
      _following = true;
      _jump++;
    });
  }

  void _choose(_Panel panel) {
    if (panel == _panel) return;
    HapticFeedback.selectionClick();
    setState(() => _panel = panel);
    if (panel == _Panel.hours) {
      // Once laid out, the hour now in the middle of the list.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final row = _nowHour.currentContext;
        if (row != null) {
          Scrollable.ensureVisible(
            row,
            alignment: 0.4,
            duration: SmTheme.of(context).motion.medium,
          );
        }
      });
    }
  }

  void _pick(Body body) {
    HapticFeedback.selectionClick();
    setState(() {
      _chosen = _chosen == body ? null : body;
      _panel = _Panel.planets;
    });
  }

  String _clock(DateTime? at, Strings strings) {
    if (at == null) return strings.notThatDay;
    final w = LocalClock.wall(at, widget.utcOffset);
    return '${w.hour.toString().padLeft(2, '0')}:'
        '${w.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final strings = Strings.of(context);
    return ValueListenableBuilder(
      valueListenable: SkyPlace.current,
      builder: (context, place, _) {
        List<PlanetAt>? planets;
        SkyPosition? sun, moon;
        Widget body;
        if (place == null) {
          body = Center(
            child: Padding(
              padding: EdgeInsets.all(spacing.lg),
              child: Text(
                strings.planetsAskPlace,
                key: const ValueKey('planets-ask-place'),
                textAlign: TextAlign.center,
                style: theme.type.body.copyWith(color: colors.textSecondary),
              ),
            ),
          );
        } else {
          final t = _instant;
          planets = PlanetLook.at(
            t,
            latitude: place.latitude,
            longitude: place.longitude,
          );
          sun = SkyNow.sun(
            t,
            latitude: place.latitude,
            longitude: place.longitude,
          );
          moon = SkyNow.moon(
            t,
            latitude: place.latitude,
            longitude: place.longitude,
          );
          _workDays(place);
          body = Column(
            children: [
              Expanded(
                child: NightDome(
                  child: Builder(
                    builder: (context) => PlanetDome(
                      key: const ValueKey('planets-dome'),
                      instant: t,
                      place: place,
                      planets: planets!,
                      sun: sun!,
                      moon: moon!,
                      chosen: _chosen,
                      compass: strings.compassFour,
                      sunColor: skySunIn(context),
                      moonColor: skyMoonIn(context),
                      onPick: _pick,
                    ),
                  ),
                ),
              ),
              SizedBox(height: spacing.sm),
              DayStrip(
                key: const ValueKey('planets-strip'),
                paths: _pathsFor(place),
                minute: _minute,
                onMove: _moveTo,
              ),
            ],
          );
        }

        return ColoredBox(
          color: colors.background,
          child: SafeArea(
            child: Recentre(
              onToday: _backToNow,
              atToday: _following,
              child: FourParts(
                top: TopBar(
                  key: const ValueKey('planets-top-bar'),
                  leading: TopBarTitle(label: strings.planetsTitle),
                  trailing: Text(
                    '${(_minute ~/ 60).toString().padLeft(2, '0')}:'
                    '${(_minute % 60).toString().padLeft(2, '0')}',
                    key: const ValueKey('planets-clock'),
                    style: theme.type.title.copyWith(
                      color: _following ? colors.accent : colors.textSecondary,
                    ),
                  ),
                  subtitle: place == null
                      ? strings.gregorian(_date)
                      : '${strings.gregorian(_date)} · '
                            '${SkyPlace.label(place)}',
                ),
                body: body,
                panel: _panelView(theme, strings, place, planets),
                bar: const RoomBar(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _panelView(
    SmThemeData theme,
    Strings strings,
    ({double latitude, double longitude})? place,
    List<PlanetAt>? planets,
  ) {
    final spacing = theme.spacing;
    final labels = {
      _Panel.planets: strings.planetsTitle,
      _Panel.hours: strings.planetsHours,
      _Panel.lore: strings.planetsLore,
      _Panel.date: strings.skyDate,
      _Panel.time: strings.skyTime,
      _Panel.place: strings.skyPlaceTab,
    };
    final shown =
        place == null && (_panel == _Panel.planets || _panel == _Panel.hours)
        ? _Panel.place
        : _panel;
    Widget content() => switch (shown) {
      _Panel.planets => _planetRows(theme, strings, planets!),
      _Panel.hours => _hourRows(theme, strings, place!),
      _Panel.lore => _loreRows(theme, strings),
      _Panel.date => Center(
        child: DatePicker(
          key: ValueKey('planets-date-$_jump'),
          date: _date,
          strings: strings,
          onChanged: _setDate,
        ),
      ),
      _Panel.time => Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.lg),
        child: TimePicker(
          key: ValueKey('planets-time-$_jump'),
          minuteOfDay: _minute,
          onChanged: (minute) => _moveTo(minute, fromWheels: true),
        ),
      ),
      _Panel.place => PlaceEditor(strings: strings),
    };
    return Column(
      children: [
        SizedBox(height: spacing.sm),
        PanelTabs(
          listKey: const ValueKey('planets-panels'),
          tabs: _Panel.values,
          shown: shown,
          label: (panel) => labels[panel]!,
          keyOf: (panel) => 'planets-panel-${panel.name}',
          onChoose: _choose,
        ),
        Expanded(
          child: ClipRect(
            child: AnimatedSwitcher(
              duration: theme.motion.medium,
              child: KeyedSubtree(key: ValueKey(shown), child: content()),
            ),
          ),
        ),
      ],
    );
  }

  // Each planet: its symbol and name in its colour, how high and how
  // bright now, when it rises and sets today, which side of the sun.
  Widget _planetRows(
    SmThemeData theme,
    Strings strings,
    List<PlanetAt> planets,
  ) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    final days = _days;
    return ListView(
      key: const ValueKey('planets-list'),
      padding: EdgeInsets.fromLTRB(spacing.md, spacing.sm, spacing.md, 0),
      children: [
        for (final p in planets)
          GestureDetector(
            key: ValueKey('planets-row-${p.body.name}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _pick(p.body),
            child: Padding(
              padding: EdgeInsets.only(bottom: spacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        '${PlanetLook.symbolOf(p.body)}  '
                        '${strings.planetName(p.body)}',
                        style: theme.type.body.copyWith(
                          color: p.body == _chosen
                              ? colors.accent
                              : PlanetLook.colorOf(p.body),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        p.at.altitude < 0
                            ? strings.starsDown
                            : '${p.at.altitude.round()}° '
                                  '${strings.compassPoint((p.at.azimuth + 22.5) ~/ 45)}',
                        style: theme.type.label.copyWith(
                          color: p.at.altitude < 0
                              ? colors.textFaint
                              : colors.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    [
                      strings.planetsMagnitude(p.view.magnitude),
                      if (days != null && days[p.body] != null) ...[
                        '${strings.skyRise} ${_clock(days[p.body]!.rise, strings)}',
                        '${strings.skySet} ${_clock(days[p.body]!.set, strings)}',
                      ],
                      p.view.east
                          ? strings.planetsEvening
                          : strings.planetsMorning,
                    ].join(' · '),
                    style: theme.type.caption.copyWith(
                      color: colors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (p.body == _chosen)
                    Text(
                      [
                        '${strings.planetFromSun} '
                            '${p.view.elongation.toStringAsFixed(1)}°',
                        '${strings.planetLit} '
                            '${(p.view.illumination * 100).round()}%',
                        strings.planetAu(p.view.distance),
                        '${p.view.diameter.toStringAsFixed(1)}″',
                      ].join(' · '),
                      key: ValueKey('planets-more-${p.body.name}'),
                      style: theme.type.caption.copyWith(
                        color: colors.textFaint,
                      ),
                    ),
                ],
              ),
            ),
          ),
        Text(
          strings.planetsHow,
          style: theme.type.caption.copyWith(
            color: colors.textFaint,
            height: 1.4,
          ),
        ),
        SizedBox(height: spacing.md),
      ],
    );
  }

  // The planetary hours that hold the moment: the day's twelve from
  // sunrise, the night's twelve from sunset, each with its planet; the
  // one now in the accent.
  Widget _hourRows(
    SmThemeData theme,
    Strings strings,
    ({double latitude, double longitude}) place,
  ) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    final hours = _hoursFor0(place);
    if (hours == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Text(
            strings.planetsNoHours,
            textAlign: TextAlign.center,
            style: theme.type.label.copyWith(color: colors.textFaint),
          ),
        ),
      );
    }
    final now = _instant;
    final ruler = hours.first.ruler;
    final firstDay = LocalClock.wall(hours.first.start, widget.utcOffset);
    Widget heading(String text) => Padding(
      padding: EdgeInsets.only(top: spacing.sm, bottom: spacing.xs),
      child: Text(
        text.toUpperCase(),
        style: theme.type.caption.copyWith(
          color: colors.textFaint,
          letterSpacing: 1.2,
        ),
      ),
    );
    // Twenty-four rows, all laid out, so the hour now can be scrolled to.
    return SingleChildScrollView(
      key: const ValueKey('planets-hours'),
      padding: EdgeInsets.fromLTRB(spacing.md, spacing.xs, spacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.planetsDayOf(
              strings.weekdayName(
                Weekday.of(
                  CivilDate(firstDay.year, firstDay.month, firstDay.day),
                ),
              ),
              '${PlanetLook.symbolOf(ruler)} ${strings.planetName(ruler)}',
            ),
            key: const ValueKey('planets-day-ruler'),
            style: theme.type.body.copyWith(color: colors.textPrimary),
          ),
          for (final (k, h) in hours.indexed) ...[
            if (k == 0) heading(strings.planetsDayHours),
            if (k == 12) heading(strings.planetsNightHours),
            // The hour now on a ground of its own, to stand out.
            Container(
              key: h.holds(now) ? _nowHour : ValueKey('planets-hour-$k'),
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              margin: const EdgeInsets.symmetric(vertical: 1),
              decoration: h.holds(now)
                  ? BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.16),
                      border: Border.all(color: colors.accent),
                      borderRadius: BorderRadius.circular(theme.radii.sm),
                    )
                  : null,
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${h.number}',
                      style: theme.type.label.copyWith(
                        color: h.holds(now) ? colors.accent : colors.textFaint,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${PlanetLook.symbolOf(h.ruler)}  '
                      '${strings.planetName(h.ruler)}',
                      style: theme.type.label.copyWith(
                        color: h.holds(now)
                            ? colors.textPrimary
                            : PlanetLook.colorOf(h.ruler),
                      ),
                    ),
                  ),
                  Text(
                    '${_clock(h.start, strings)} – ${_clock(h.end, strings)}',
                    style: theme.type.label.copyWith(
                      color: h.holds(now)
                          ? colors.textPrimary
                          : colors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: spacing.sm),
          Text(
            strings.planetsHoursHow,
            style: theme.type.caption.copyWith(
              color: colors.textFaint,
              height: 1.4,
            ),
          ),
          SizedBox(height: spacing.md),
        ],
      ),
    );
  }

  // The seven of the old astronomy in the Chaldean order, each with its
  // symbol, its metal and its day of the week.
  Widget _loreRows(SmThemeData theme, Strings strings) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    return ListView(
      key: const ValueKey('planets-lore'),
      padding: EdgeInsets.fromLTRB(spacing.md, spacing.sm, spacing.md, 0),
      children: [
        for (final body in PlanetaryHours.chaldean)
          Padding(
            key: ValueKey('planets-lore-${body.name}'),
            padding: EdgeInsets.only(bottom: spacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    PlanetLook.symbolOf(body),
                    style: theme.type.title.copyWith(
                      color: PlanetLook.colorOf(body),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        strings.planetName(body),
                        style: theme.type.body.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        strings.planetsOtherNames(body),
                        style: theme.type.caption.copyWith(
                          color: colors.textFaint,
                        ),
                      ),
                      Text(
                        [
                          strings.planetsMetal(body),
                          strings.planetsWeekday(body),
                        ].join(' · '),
                        style: theme.type.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        [
                          strings.planetsSigns(body),
                          strings.planetsSect(body),
                        ].join(' · '),
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
        Text(
          strings.planetsLoreHow,
          style: theme.type.caption.copyWith(
            color: colors.textFaint,
            height: 1.4,
          ),
        ),
        SizedBox(height: spacing.md),
      ],
    );
  }
}

/// The sky from above with the planets on it: the horizon the rim, north
/// up, east on the right; the ecliptic dotted; the sun, the moon and
/// each planet up, the planets with their symbols. A touch picks the
/// planet nearest the finger.
class PlanetDome extends StatelessWidget {
  final DateTime instant;
  final ({double latitude, double longitude}) place;
  final List<PlanetAt> planets;
  final SkyPosition sun;
  final SkyPosition moon;
  final Body? chosen;
  final List<String> compass;
  final Color sunColor;
  final Color moonColor;
  final ValueChanged<Body> onPick;

  const PlanetDome({
    super.key,
    required this.instant,
    required this.place,
    required this.planets,
    required this.sun,
    required this.moon,
    required this.chosen,
    required this.compass,
    required this.sunColor,
    required this.moonColor,
    required this.onPick,
  });

  // The ecliptic every five degrees of longitude, where each point
  // stands from the place: the sun's own road, which the planets keep
  // near.
  List<SkyPosition> _ecliptic() {
    final jd = 2440587.5 + instant.toUtc().microsecondsSinceEpoch / 86400e6;
    return [
      for (var l = 0; l <= 360; l += 5)
        SkyNow.place(
          Body.sun,
          jd,
          l.toDouble(),
          0,
          SkyNow.astronomicalUnit,
          0,
          place.latitude,
          place.longitude,
          0,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final ecliptic = _ecliptic();
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final centre = size.center(Offset.zero);
        final radius = size.shortestSide / 2 - 18;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            Body? best;
            var nearest = 28.0;
            for (final p in planets) {
              if (p.at.altitude < 0) continue;
              final at = SkyDome.project(
                centre,
                radius,
                p.at.altitude,
                p.at.azimuth,
              );
              final distance = (at - d.localPosition).distance;
              if (distance < nearest) {
                nearest = distance;
                best = p.body;
              }
            }
            if (best != null) onPick(best);
          },
          child: CustomPaint(
            size: size,
            painter: _PlanetPainter(
              planets: planets,
              ecliptic: ecliptic,
              sun: sun,
              moon: moon,
              chosen: chosen,
              compass: compass,
              radius: radius,
              sky: colors.surface,
              line: colors.outline,
              faint: colors.textFaint,
              accent: colors.accent,
              sunColor: sunColor,
              moonColor: moonColor,
              label: theme.type.caption,
            ),
          ),
        );
      },
    );
  }
}

class _PlanetPainter extends CustomPainter {
  final List<PlanetAt> planets;
  final List<SkyPosition> ecliptic;
  final SkyPosition sun;
  final SkyPosition moon;
  final Body? chosen;
  final List<String> compass;
  final double radius;
  final Color sky, line, faint, accent, sunColor, moonColor;
  final TextStyle label;

  _PlanetPainter({
    required this.planets,
    required this.ecliptic,
    required this.sun,
    required this.moon,
    required this.chosen,
    required this.compass,
    required this.radius,
    required this.sky,
    required this.line,
    required this.faint,
    required this.accent,
    required this.sunColor,
    required this.moonColor,
    required this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    Offset at(double alt, double az) =>
        SkyDome.project(centre, radius, alt, az);

    canvas
      ..drawCircle(centre, radius, Paint()..color = sky)
      ..drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = line,
      );
    for (final ring in [1 / 3, 2 / 3]) {
      canvas.drawCircle(
        centre,
        radius * ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = line.withValues(alpha: 0.5),
      );
    }
    for (var k = 0; k < 4; k++) {
      final p = at(-1, k * 90.0);
      final dir = (p - centre) / radius;
      final painter = TextPainter(
        text: TextSpan(
          text: compass[k],
          style: label.copyWith(color: faint),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        p + dir * 10 - Offset(painter.width / 2, painter.height / 2),
      );
    }

    // The ecliptic, dotted, where it is up.
    final dot = Paint()..color = faint.withValues(alpha: 0.6);
    for (final e in ecliptic) {
      if (e.trueAltitude < 0) continue;
      canvas.drawCircle(at(e.trueAltitude, e.azimuth), 1.1, dot);
    }

    // The sun and the moon, where they are up.
    if (sun.altitude > 0) {
      canvas.drawCircle(
        at(sun.altitude, sun.azimuth),
        7,
        Paint()..color = sunColor,
      );
    }
    if (moon.altitude > 0) {
      canvas.drawCircle(
        at(moon.altitude, moon.azimuth),
        6,
        Paint()..color = moonColor,
      );
    }

    // The planets up, each a disc as bright as it is, its symbol beside.
    for (final p in planets) {
      if (p.at.altitude < 0) continue;
      final where = at(p.at.altitude, p.at.azimuth);
      final colour = PlanetLook.colorOf(p.body);
      final r = math.max(2.5, 4.2 - 0.45 * p.view.magnitude);
      canvas.drawCircle(where, r, Paint()..color = colour);
      if (p.body == chosen) {
        canvas.drawCircle(
          where,
          r + 5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = accent,
        );
      }
      final painter = TextPainter(
        text: TextSpan(
          text: PlanetLook.symbolOf(p.body),
          style: label.copyWith(color: colour, fontSize: 13),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, where + Offset(r + 3, -painter.height / 2));
    }
  }

  @override
  bool shouldRepaint(_PlanetPainter old) =>
      !identical(old.planets, planets) ||
      old.chosen != chosen ||
      old.sky != sky;
}
