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

/// Opens the crescent of the new moon nearest [date].
Future<void> pushHilal(BuildContext context, {required CivilDate date}) =>
    Navigator.of(context)
        .push(fadeRoute<void>(context, (context) => HilalScreen(date: date)));

/// What the lower panel shows.
enum _Panel { evening, criteria, months, date, place }

/// How high the moon stands and how far from the sun, anywhere in
/// Indonesia that evening: the highest, the widest, and whether MABIMS is
/// met at any of the places tried.
typedef IndonesiaSweep = ({double altitude, double elongation, bool met});

/// One new moon and, at the place, its evening and the next.
typedef NewMoonEvenings = ({
  DateTime conjunction,
  List<({CivilDate date, bool mabims, OdehZone? odeh})> evenings,
});

/// The work that takes a while, off the main thread.
abstract final class HilalWork {
  /// Every whole degree of latitude and longitude over Indonesia that is
  /// Indonesia's, with the clock of its own zone.
  static Future<IndonesiaSweep> indonesia(CivilDate date) => Isolate.run(() {
    var altitude = -90.0, elongation = 0.0;
    var met = false;
    for (var lat = -11; lat <= 6; lat++) {
      for (var lon = 95; lon <= 141; lon++) {
        if (!Indonesia.has(lat.toDouble(), lon.toDouble())) continue;
        final s = Hilal.atSunset(
          date,
          latitude: lat.toDouble(),
          longitude: lon.toDouble(),
          utcOffset: Duration(hours: (lon / 15).round()),
        );
        if (s == null) continue;
        altitude = math.max(altitude, s.altitude);
        elongation = math.max(elongation, s.elongation);
        if (s.altitude >= 3 && s.elongation >= 6.4) met = true;
      }
    }
    return (altitude: altitude, elongation: elongation, met: met);
  });

  /// The [count] new moons from [from], each with its evening at the
  /// place (the day it falls on there) and the next.
  static Future<List<NewMoonEvenings>> months(
    DateTime from,
    double latitude,
    double longitude,
    Duration utcOffset, {
    int count = 12,
  }) => Isolate.run(() {
    final found = <NewMoonEvenings>[];
    var near = from;
    for (var k = 0; k < count; k++) {
      final c = Hilal.conjunctionNear(near);
      final wall = c.add(utcOffset);
      final day = CivilDate(wall.year, wall.month, wall.day);
      found.add((
        conjunction: c,
        evenings: [
          for (final date in [day, day.addDays(1)])
            if (Hilal.evening(
                  date,
                  latitude: latitude,
                  longitude: longitude,
                  utcOffset: utcOffset,
                )
                case final e?)
              (date: date, mabims: e.mabims, odeh: e.odeh),
        ],
      ));
      near = c.add(const Duration(days: 29, hours: 12));
    }
    return found;
  });
}

/// The young crescent on the evening after a new moon, at the place set.
///
///  * Top bar: the name, the evening and the place.
///  * Main body: the western sky at sunset, a degree the same up as
///    across: the horizon, the sun just under it, the moon where it
///    stands with its lit side toward the sun, its path to its setting,
///    and the 3° of MABIMS as a dashed line.
///  * Lower panel: the evening's numbers; what each criterion makes of
///    them; the coming new moons; the date; the place.
///  * Bottom bar: back, and back to the new moon nearest today.
///
/// Astronomy only: the screen never says a month has begun.
class HilalScreen extends StatefulWidget {
  final CivilDate date;

  /// The clock the day is read by; the phone's own on that date unless
  /// given.
  final Duration? utcOffset;

  const HilalScreen({super.key, required this.date, this.utcOffset});

  @override
  State<HilalScreen> createState() => _HilalScreenState();
}

class _HilalScreenState extends State<HilalScreen> {
  late CivilDate _date = _eveningNear(widget.date);
  late final CivilDate _home = _eveningNear(_today());

  late _Panel _panel = SkyPlace.current.value == null
      ? _Panel.place
      : _Panel.criteria;

  // Changed each time the date is set from outside the wheels.
  int _jump = 0;

  // Worked out once for each evening and place.
  String? _forKey;
  CrescentEvening? _evening;
  Future<IndonesiaSweep>? _sweep;
  CivilDate? _sweepFor;
  Future<List<NewMoonEvenings>>? _months;
  String? _monthsKey;

  // The evening the list of new moons begins from: the one shown when
  // it was set by the wheels or the button, kept while one is picked
  // from the list itself, so the list holds still under the finger.
  late CivilDate _monthsFrom = _date;

  static CivilDate _today() {
    final now = DateTime.now();
    return CivilDate(now.year, now.month, now.day);
  }

  Duration _offsetOn(CivilDate date) =>
      LocalClock.dayOffset(date, widget.utcOffset);

  /// The evening of the new moon nearest [date]: the day it falls on by
  /// the clock here, or, if that new moon is more than three days past,
  /// the next one's.
  CivilDate _eveningNear(CivilDate date) {
    final offset = _offsetOn(date);
    final noon = DateTime.utc(
      date.year,
      date.month,
      date.day,
      12,
    ).subtract(offset);
    var c = Hilal.conjunctionNear(noon);
    if (noon.difference(c) > const Duration(days: 3)) {
      c = Hilal.conjunctionNear(c.add(const Duration(days: 29, hours: 12)));
    }
    final wall = c.add(offset);
    return CivilDate(wall.year, wall.month, wall.day);
  }

  CrescentEvening? _eveningFor(({double latitude, double longitude}) place) {
    final key = '${_date.dayNumber} ${place.latitude} ${place.longitude}';
    if (key != _forKey) {
      _forKey = key;
      _evening = Hilal.evening(
        _date,
        latitude: place.latitude,
        longitude: place.longitude,
        utcOffset: _offsetOn(_date),
      );
    }
    return _evening;
  }

  Future<IndonesiaSweep> _sweepOf(CivilDate date) {
    if (_sweepFor != date || _sweep == null) {
      _sweepFor = date;
      _sweep = HilalWork.indonesia(date);
    }
    return _sweep!;
  }

  Future<List<NewMoonEvenings>> _monthsOf(
    ({double latitude, double longitude}) place,
  ) {
    final from = _monthsFrom;
    final key = '${from.dayNumber} ${place.latitude} ${place.longitude}';
    if (key != _monthsKey || _months == null) {
      _monthsKey = key;
      final offset = _offsetOn(from);
      _months = HilalWork.months(
        DateTime.utc(from.year, from.month, from.day).subtract(offset),
        place.latitude,
        place.longitude,
        offset,
      );
    }
    return _months!;
  }

  void _setDate(CivilDate date) {
    if (date == _date) return;
    setState(() => _date = _monthsFrom = date);
  }

  // An evening picked from the list of new moons, opened on its
  // criteria; the list keeps its place.
  void _openEvening(CivilDate date) {
    HapticFeedback.selectionClick();
    setState(() {
      _date = date;
      _panel = _Panel.criteria;
      _jump++;
    });
  }

  void _backHome() {
    HapticFeedback.selectionClick();
    setState(() {
      _date = _monthsFrom = _home;
      _jump++;
    });
  }

  String _clock(DateTime? at) {
    if (at == null) return '–';
    final w = LocalClock.wall(at, widget.utcOffset);
    return '${w.hour.toString().padLeft(2, '0')}:'
        '${w.minute.toString().padLeft(2, '0')}';
  }

  static String _deg(double d) => '${d.toStringAsFixed(1)}°';

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final strings = Strings.of(context);

    return ValueListenableBuilder(
      valueListenable: SkyPlace.current,
      builder: (context, place, _) {
        final evening = place == null ? null : _eveningFor(place);
        return ColoredBox(
          color: colors.background,
          child: SafeArea(
            child: Recentre(
              onToday: _backHome,
              atToday: _date == _home,
              child: FourParts(
                top: TopBar(
                  key: const ValueKey('hilal-top-bar'),
                  leading: TopBarTitle(label: strings.hilalTitle),
                  subtitle: place == null
                      ? strings.gregorian(_date)
                      : '${strings.gregorian(_date)} · '
                            '${SkyPlace.label(place)}',
                ),
                body: evening == null
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(spacing.lg),
                          child: Text(
                            place == null
                                ? strings.hilalAskPlace
                                : strings.hilalNoSunset,
                            key: const ValueKey('hilal-ask'),
                            textAlign: TextAlign.center,
                            style: theme.type.body.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : NightDome(
                        child: Builder(
                          builder: (context) => HilalSky(
                            key: const ValueKey('hilal-sky'),
                            evening: evening,
                            place: place!,
                            sunColor: skySunIn(context),
                            moonColor: skyMoonIn(context),
                            caption: evening.altitude < 0
                                ? strings.hilalMoonDown
                                : '${strings.hilalHeight} '
                                      '${_deg(evening.altitude)} · '
                                      '${strings.hilalElongation} '
                                      '${_deg(evening.elongation)}',
                          ),
                        ),
                      ),
                panel: _panelView(theme, strings, place, evening),
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
    CrescentEvening? evening,
  ) {
    final spacing = theme.spacing;
    final labels = {
      _Panel.evening: strings.hilalEvening,
      _Panel.criteria: strings.hilalCriteria,
      _Panel.months: strings.hilalMonths,
      _Panel.date: strings.skyDate,
      _Panel.place: strings.skyPlaceTab,
    };
    final shown =
        (place == null || evening == null) &&
            _panel != _Panel.date &&
            _panel != _Panel.place
        ? (place == null ? _Panel.place : _Panel.date)
        : _panel;

    Widget content() => switch (shown) {
      _Panel.evening => _eveningRows(theme, strings, evening!),
      _Panel.criteria => _criteriaRows(theme, strings, evening!),
      _Panel.months => _monthRows(theme, strings, place!),
      _Panel.date => Center(
        child: DatePicker(
          key: ValueKey('hilal-date-$_jump'),
          date: _date,
          strings: strings,
          onChanged: _setDate,
        ),
      ),
      _Panel.place => PlaceEditor(strings: strings),
    };

    return Column(
      children: [
        SizedBox(height: spacing.sm),
        PanelTabs(
          listKey: const ValueKey('hilal-panels'),
          tabs: _Panel.values,
          shown: shown,
          label: (panel) => labels[panel]!,
          keyOf: (panel) => 'hilal-panel-${panel.name}',
          onChoose: (panel) {
            if (panel == shown) return;
            HapticFeedback.selectionClick();
            setState(() => _panel = panel);
          },
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

  // Rows of a label and its value, and a note under them.
  Widget _rows(
    SmThemeData theme,
    String name,
    List<(String, String)> rows, {
    String? note,
  }) {
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
                    flex: 2,
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
                  Expanded(
                    flex: 3,
                    child: Text(
                      value,
                      textAlign: TextAlign.end,
                      style: theme.type.label.copyWith(
                        color: colors.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (note != null) ...[
            SizedBox(height: spacing.sm),
            Text(
              note,
              style: theme.type.caption.copyWith(
                color: colors.textFaint,
                height: 1.4,
              ),
            ),
          ],
          SizedBox(height: spacing.md),
        ],
      ),
    );
  }

  Widget _eveningRows(SmThemeData theme, Strings strings, CrescentEvening e) {
    final c = LocalClock.wall(e.conjunction, widget.utcOffset);
    final lag = e.lag;
    return _rows(theme, 'hilal-evening', [
      (
        strings.hilalConjunction,
        '${strings.gregorian(CivilDate(c.year, c.month, c.day))} '
            '${_clock(e.conjunction)}',
      ),
      (strings.hilalSunset, _clock(e.sunset)),
      (strings.hilalMoonset, _clock(e.moonset)),
      if (lag != null)
        (strings.hilalLag, strings.hilalLagValue((lag.inSeconds / 60).round())),
      (strings.hilalAge, strings.hilalAgeValue(e.age.inMinutes)),
      (strings.hilalHeight, _deg(e.altitude)),
      (strings.hilalHeightAir, _deg(e.apparentAltitude)),
      (strings.hilalElongation, _deg(e.elongation)),
      (strings.hilalElongationHere, _deg(e.topocentricElongation)),
      (strings.hilalLit, '${(e.illumination * 100).toStringAsFixed(2)}%'),
      if (e.bestTime != null) (strings.hilalBest, _clock(e.bestTime)),
    ], note: strings.hilalEveningHow);
  }

  Widget _criteriaRows(SmThemeData theme, Strings strings, CrescentEvening e) {
    final colors = theme.colors;
    final spacing = theme.spacing;

    Widget criterion(
      String key,
      String name,
      String? who,
      String value, {
      required String about,
    }) => Padding(
      key: ValueKey('hilal-$key'),
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: name.toUpperCase(),
                  style: theme.type.caption.copyWith(
                    color: colors.textFaint,
                    letterSpacing: 1.2,
                  ),
                ),
                if (who != null)
                  TextSpan(
                    text: '  $who',
                    style: theme.type.caption.copyWith(color: colors.textFaint),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: theme.type.label.copyWith(
              color: colors.textPrimary,
              height: 1.4,
            ),
          ),
          // What the criterion is, for whoever has not met it.
          Text(
            about,
            style: theme.type.caption.copyWith(
              color: colors.textFaint,
              height: 1.4,
            ),
          ),
        ],
      ),
    );

    final odeh = e.odeh;
    final yallop = e.yallop;
    return SingleChildScrollView(
      key: const ValueKey('hilal-criteria'),
      padding: EdgeInsets.fromLTRB(spacing.md, spacing.sm, spacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          criterion(
            about: strings.hilalAboutMabims,
            'mabims',
            strings.hilalMabims,
            strings.hilalMabimsWho,
            strings.hilalMabimsValue(
              e.mabims,
              _deg(e.altitude),
              _deg(e.elongation),
            ),
          ),
          FutureBuilder(
            future: _sweepOf(_date),
            builder: (context, snap) => criterion(
              about: strings.hilalAboutIndonesia,
              'indonesia',
              strings.hilalIndonesia,
              null,
              snap.data == null
                  ? strings.lintangWorking
                  : strings.hilalIndonesiaValue(
                      snap.data!.met,
                      _deg(snap.data!.altitude),
                      _deg(snap.data!.elongation),
                    ),
            ),
          ),
          criterion(
            about: strings.hilalAboutWujud,
            'wujud',
            strings.hilalWujud,
            strings.hilalWujudWho,
            strings.hilalWujudValue(e.wujudulHilal),
          ),
          criterion(
            about: strings.hilalAboutOdeh,
            'odeh',
            strings.hilalOdeh,
            null,
            odeh == null
                ? strings.hilalSetsFirst
                : '${strings.hilalOdehZone(odeh)} (V ${e.v!.toStringAsFixed(2)})',
          ),
          criterion(
            about: strings.hilalAboutYallop,
            'yallop',
            strings.hilalYallop,
            null,
            yallop == null
                ? strings.hilalSetsFirst
                : '${strings.hilalYallopClass(yallop)} '
                      '(q ${e.q!.toStringAsFixed(3)})',
          ),
          SizedBox(height: spacing.xs),
          Text(
            strings.hilalCriteriaHow,
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

  Widget _monthRows(
    SmThemeData theme,
    Strings strings,
    ({double latitude, double longitude}) place,
  ) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    return FutureBuilder(
      future: _monthsOf(place),
      builder: (context, snap) {
        final months = snap.data;
        if (months == null) {
          return Center(
            child: Text(
              strings.lintangWorking,
              style: theme.type.label.copyWith(color: colors.textFaint),
            ),
          );
        }
        return ListView(
          key: const ValueKey('hilal-months'),
          padding: EdgeInsets.fromLTRB(spacing.md, spacing.sm, spacing.md, 0),
          children: [
            for (final (i, m) in months.indexed)
              GestureDetector(
                key: ValueKey('hilal-month-$i'),
                behavior: HitTestBehavior.opaque,
                onTap: m.evenings.isEmpty
                    ? null
                    : () => _openEvening(m.evenings.first.date),
                child: Padding(
                  padding: EdgeInsets.only(bottom: spacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        m.evenings.isEmpty
                            ? _clock(m.conjunction)
                            : '${strings.gregorian(m.evenings.first.date)} · '
                                  '${strings.hilalMonthAt(_clock(m.conjunction))}',
                        style: theme.type.label.copyWith(
                          color:
                              m.evenings.isNotEmpty &&
                                  m.evenings.first.date == _date
                              ? colors.accent
                              : colors.textPrimary,
                        ),
                      ),
                      // Each evening its own touch, the new moon's line
                      // the first evening's.
                      for (final e in m.evenings)
                        GestureDetector(
                          key: ValueKey('hilal-evening-${e.date.dayNumber}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _openEvening(e.date),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text(
                              strings.hilalMonthEvening(
                                '${e.date.day}/${e.date.month}',
                                e.mabims,
                                e.odeh?.name.toUpperCase(),
                              ),
                              style: theme.type.caption.copyWith(
                                color: e.date == _date
                                    ? colors.accent
                                    : colors.textSecondary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Text(
              strings.hilalMonthsHow,
              style: theme.type.caption.copyWith(
                color: colors.textFaint,
                height: 1.4,
              ),
            ),
            SizedBox(height: spacing.md),
          ],
        );
      },
    );
  }
}

/// The western sky at sunset: a degree as long up as across, the sun's
/// bearing at the middle.
class HilalSky extends StatelessWidget {
  final CrescentEvening evening;
  final ({double latitude, double longitude}) place;
  final Color sunColor;
  final Color moonColor;
  final String caption;

  const HilalSky({
    super.key,
    required this.evening,
    required this.place,
    required this.sunColor,
    required this.moonColor,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    // The moon's way from sunset to its setting, every four minutes.
    final path = <({double azimuth, double altitude})>[];
    final lag = evening.lag;
    if (lag != null && lag > Duration.zero) {
      for (
        // From the first step after sunset: at sunset itself the moon
        // is drawn whole.
        var t = evening.sunset.add(const Duration(minutes: 4));
        !t.isAfter(evening.moonset!);
        t = t.add(const Duration(minutes: 4))
      ) {
        final m = SkyNow.moon(
          t,
          latitude: place.latitude,
          longitude: place.longitude,
        );
        path.add((azimuth: m.azimuth, altitude: m.trueAltitude));
      }
    }
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _SkyPainter(
              evening: evening,
              path: path,
              sun: sunColor,
              moon: moonColor,
              ground: colors.surfaceRaised,
              line: colors.outline,
              faint: colors.textFaint,
              accent: colors.accent,
              type: theme.type.caption,
            ),
          ),
        ),
        Positioned(
          left: theme.spacing.md,
          top: theme.spacing.sm,
          right: theme.spacing.md,
          child: Text(
            caption,
            key: const ValueKey('hilal-caption'),
            style: theme.type.caption.copyWith(color: colors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _SkyPainter extends CustomPainter {
  final CrescentEvening evening;
  final List<({double azimuth, double altitude})> path;
  final Color sun, moon, ground, line, faint, accent;
  final TextStyle type;

  _SkyPainter({
    required this.evening,
    required this.path,
    required this.sun,
    required this.moon,
    required this.ground,
    required this.line,
    required this.faint,
    required this.accent,
    required this.type,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Close about the sun and the moon: from a little under the
    // horizon to a little over the moon (and over 3°), across the two
    // bearings with room either side; a degree as long up as across.
    final low = math.min(-2.0, evening.altitude - 1.5);
    final high = math.max(5.0, evening.altitude + 2.5);
    final across = math.max(
      14.0,
      2.2 * (evening.moonAzimuth - evening.sunAzimuth).abs() + 6,
    );
    // The horizon two thirds of the way down: the sky is what is looked
    // at, the ground only what lies under it.
    final top = size.height * 0.14;
    final horizon = size.height * 0.68;
    final scale = [
      size.width / across,
      (horizon - top) / high,
      (size.height - horizon - 24) / -low,
    ].reduce(math.min);
    final middle = (evening.moonAzimuth + evening.sunAzimuth) / 2;
    Offset at(double azimuth, double altitude) => Offset(
      size.width / 2 + (azimuth - middle) * scale,
      horizon - altitude * scale,
    );

    // The ground under the horizon.
    canvas.drawRect(
      Rect.fromLTRB(0, horizon, size.width, size.height),
      Paint()..color = ground,
    );
    canvas.drawLine(
      Offset(0, horizon),
      Offset(size.width, horizon),
      Paint()
        ..color = line
        ..strokeWidth = 1.2,
    );

    // The bearings every five degrees along the horizon.
    final half = size.width / 2 / scale;
    final first = ((middle - half) / 5).ceil() * 5;
    for (var b = first; b <= middle + half; b += 5) {
      final x = at(b.toDouble(), 0).dx;
      canvas.drawLine(
        Offset(x, horizon),
        Offset(x, horizon + 5),
        Paint()..color = line,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${(b % 360 + 360) % 360}°',
          style: type.copyWith(color: faint, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(x - label.width / 2, horizon + 7));
    }

    // MABIMS's three degrees, dashed.
    final three = horizon - 3 * scale;
    final dash = Paint()
      ..color = accent.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, three), Offset(x + 5, three), dash);
    }
    final mark = TextPainter(
      text: TextSpan(
        text: '3°',
        style: type.copyWith(color: accent.withValues(alpha: 0.8)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    mark.paint(
      canvas,
      Offset(size.width - mark.width - 8, three - mark.height),
    );

    // The moon's way to its setting.
    final way = Paint()..color = moon.withValues(alpha: 0.45);
    for (final p in path) {
      canvas.drawCircle(at(p.azimuth, p.altitude), 1.4, way);
    }

    // The sun, its centre just under the horizon at sunset: bright
    // above the ground's line, faint below it.
    final sunAt = at(evening.sunAzimuth, -0.8333);
    final sunDisc = Rect.fromCircle(
      center: sunAt,
      radius: math.max(6, 0.27 * scale),
    );
    canvas.drawOval(sunDisc, Paint()..color = sun.withValues(alpha: 0.35));
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, horizon));
    canvas.drawOval(sunDisc, Paint()..color = sun);
    canvas.restore();

    // The moon, larger than it is to be seen, its lit side to the sun:
    // the lit part the fraction it is, at least a sliver.
    final moonAt = at(evening.moonAzimuth, evening.altitude);
    const r = 11.0;
    final toward = sunAt - moonAt;
    final angle = math.atan2(toward.dy, toward.dx);
    final lit = evening.illumination.clamp(0.04, 1.0);
    canvas.save();
    canvas.translate(moonAt.dx, moonAt.dy);
    canvas.rotate(angle);
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = moon.withValues(alpha: 0.35),
    );
    // The lit limb toward +x; the terminator an ellipse across.
    final inner = r * (1 - 2 * lit);
    canvas.drawPath(
      Path()
        ..addArc(
          Rect.fromCircle(center: Offset.zero, radius: r),
          -math.pi / 2,
          math.pi,
        )
        ..arcTo(
          Rect.fromCenter(
            center: Offset.zero,
            width: 2 * inner.abs(),
            height: 2 * r,
          ),
          math.pi / 2,
          inner >= 0 ? -math.pi : math.pi,
          false,
        )
        ..close(),
      Paint()
        ..color = evening.altitude < 0 ? moon.withValues(alpha: 0.4) : moon,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      !identical(old.evening, evening) || old.sun != sun || old.moon != moon;
}
