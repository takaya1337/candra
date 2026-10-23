import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import '../appearance.dart';
import '../date_picker.dart';
import '../glyph_button.dart';
import '../house.dart';
import '../panel_tabs.dart';
import '../local_clock.dart';
import '../step_field.dart';
import 'compass.dart';
import 'meteor_showers.dart';
import '../night_dome.dart';
import '../parts.dart';
import '../place_editor.dart';
import '../routes.dart';
import '../reminders/reminder.dart';
import '../reminders/reminder_screen.dart';
import '../sky/sky_screen.dart';
import '../sky_place.dart';
import '../strings.dart';
import '../time_picker.dart';

/// Opens Light, for planning photographs by the sun and the moon, on
/// [date].
Future<void> pushLight(BuildContext context, {required CivilDate date}) =>
    Navigator.of(context)
        .push(fadeRoute<void>(context, (context) => LightScreen(date: date)));

/// What the lower panel shows.
enum _Panel {
  hours,
  shadow,
  moon,
  milkyWay,
  night,
  meteors,
  eclipses,
  pairs,
  align,
  date,
  time,
  place,
}

/// What a photograph of the night sky is taken with, for its exposure
/// limits: kept while the app runs.
abstract final class _Lens {
  static const focals = [8, 10, 12, 14, 16, 18, 20, 24, 28, 35, 50, 85, 135];
  static const stops = [1.2, 1.4, 1.8, 2.0, 2.8, 4.0, 5.6, 8.0];
  static const crops = [1.0, 1.5, 1.6, 2.0];
  static int focal = 3;
  static int stop = 4;
  static int crop = 0;

  /// The width of a pixel, in tenths of a micrometre.
  static int pitch = 59;
}

/// The colours of the light bands, the same on the plan and the strip.
Color get lightGoldenColor => Legible.of(const Color(0xFFE0A94F));
Color get lightBlueColor => Legible.of(const Color(0xFF5B7DB8));

/// Light: where the sun and moon come up and go down, seen from above,
/// and when the light is golden or blue, for photographs.
///
///  * Top bar: the name, the clock time, the day and the place.
///  * Main body: the plan, the ground seen from above with you at its
///    centre (north up, east on the right): the bearings the sun and moon
///    rise and set along, where each stands now, the shadow an upright
///    thing casts now, the Milky Way's heart when it is up, and the
///    bearing being lined up. Under it the day's light, band by band, to
///    move through the day.
///  * Lower panel: the golden and blue hours, shadow and rainbow, the
///    moon, the Milky Way, lining up, the date, the time, the place.
///  * Bottom bar: back to the calendar, and back to now.
class LightScreen extends StatefulWidget {
  final CivilDate date;

  /// For tests: the zone's offset, else the phone's.
  final Duration? utcOffset;

  const LightScreen({super.key, required this.date, this.utcOffset});

  @override
  State<LightScreen> createState() => _LightScreenState();
}

class _LightScreenState extends State<LightScreen> {
  late CivilDate _date = widget.date;
  late bool _following = widget.date == _today();
  late int _minute = _following ? _minuteNow() : 17 * 60;
  Timer? _tick;
  int _jump = 0;

  late _Panel _panel = SkyPlace.current.value == null
      ? _Panel.place
      : _Panel.hours;

  // The bearing being lined up, degrees from north; first the sun's
  // setting today.
  double? _bearing;

  // What is worked out once a day and place.
  String? _dayFor;
  SkyDayPaths? _paths;
  LightHours? _hours;

  // What is worked out away from the screen, each with what it was for.
  String? _nightFor;
  String? _meteorsFor;
  List<MeteorShower> _showers = const [];
  List<MeteorNight>? _meteors;
  String? _eclipsesFor;
  List<LocalEclipse>? _eclipses;
  String? _pairsFor;
  List<CloseApproach>? _pairs;
  ({List<Span> dark, List<Span> moonless})? _night;
  String? _moonsFor;
  List<({DateTime at, double distance})>? _moons;
  String? _alignFor;
  LightAlignments? _aligned;

  Duration get _offset => _offsetOn(_date);

  Duration _offsetOn(CivilDate date) =>
      LocalClock.dayOffset(date, widget.utcOffset);

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
    _compass?.cancel();
    _facing.dispose();
    _aiming.dispose();
    super.dispose();
  }

  DateTime get _midnight =>
      DateTime.utc(_date.year, _date.month, _date.day).subtract(_offset);

  DateTime get _instant => LocalClock.instant(_date, _minute, widget.utcOffset);

  String _placeKey(({double latitude, double longitude}) at) =>
      '${_date.dayNumber} ${at.latitude} ${at.longitude} ${_offset.inMinutes}';

  // The day's paths and hours, once a day and place.
  void _workDay(({double latitude, double longitude}) at) {
    final key = _placeKey(at);
    if (key == _dayFor) return;
    _dayFor = key;
    final midnight = _midnight;
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
    _hours = LightHours.of(
      date,
      latitude: at.latitude,
      longitude: at.longitude,
      utcOffset: offset,
    );
  }

  // The night's Milky Way, away from the screen.
  void _workNight(({double latitude, double longitude}) at) {
    final key = _placeKey(at);
    if (key == _nightFor) return;
    _nightFor = key;
    _night = null;
    LightWork.night(_date, at.latitude, at.longitude, _offset).then((night) {
      if (mounted && _nightFor == key) setState(() => _night = night);
    });
  }

  // The coming peaks of the meteor showers, away from the screen.
  void _workMeteors(({double latitude, double longitude}) at) {
    final key = _placeKey(at);
    if (key == _meteorsFor) return;
    _meteorsFor = key;
    _meteors = null;
    MeteorShower.load().then((showers) {
      if (!mounted || _meteorsFor != key) return;
      _showers = showers;
      LightWork.meteors(showers, _date, at.latitude, at.longitude).then((
        nights,
      ) {
        if (mounted && _meteorsFor == key) setState(() => _meteors = nights);
      });
    });
  }

  // The coming ten years' eclipses seen from here, away from the screen.
  void _workEclipses(({double latitude, double longitude}) at) {
    final key = _placeKey(at);
    if (key == _eclipsesFor) return;
    _eclipsesFor = key;
    _eclipses = null;
    LightWork.eclipses(_midnight, at.latitude, at.longitude).then((found) {
      if (mounted && _eclipsesFor == key) setState(() => _eclipses = found);
    });
  }

  // The coming year's close pairs seen from here, away from the screen.
  void _workPairs(({double latitude, double longitude}) at) {
    final key = _placeKey(at);
    if (key == _pairsFor) return;
    _pairsFor = key;
    _pairs = null;
    LightWork.pairs(_midnight, at.latitude, at.longitude).then((found) {
      if (mounted && _pairsFor == key) setState(() => _pairs = found);
    });
  }

  // The coming year's full moons, away from the screen.
  void _workMoons() {
    final key = '${_date.dayNumber} ${_offset.inMinutes}';
    if (key == _moonsFor) return;
    _moonsFor = key;
    _moons = null;
    LightWork.fullMoons(_midnight).then((moons) {
      if (mounted && _moonsFor == key) setState(() => _moons = moons);
    });
  }

  // The days the sun and moon line up with the bearing, away from the
  // screen.
  void _workAlign(({double latitude, double longitude}) at, double bearing) {
    final key = '${_placeKey(at)} ${bearing.round()}';
    if (key == _alignFor) return;
    _alignFor = key;
    _aligned = null;
    LightWork.align(
      _date,
      at.latitude,
      at.longitude,
      _offset,
      bearing.roundToDouble(),
    ).then((aligned) {
      if (mounted && _alignFor == key) setState(() => _aligned = aligned);
    });
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
  }

  // The phone's compass while on: where its top faces from true north
  // (the magnetic heading and the World Magnetic Model's declination at
  // the place), drawn on the plan alone as it moves.
  StreamSubscription<Heading>? _compass;
  final _facing = ValueNotifier<double?>(null);
  bool _rough = false;
  String? _compassProblem;
  double _declination = 0;

  void _toggleCompass() {
    HapticFeedback.selectionClick();
    final on = _compass;
    if (on != null) {
      on.cancel();
      setState(() {
        _compass = null;
        _facing.value = null;
        _compassProblem = null;
      });
      return;
    }
    final place = SkyPlace.current.value;
    _declination = place == null
        ? 0
        : MagneticField.at(
            place.latitude,
            place.longitude,
            year: MagneticField.yearOf(DateTime.now()),
          ).declination;
    setState(() {
      _compass = Compass.headings().listen(
        (h) {
          _rough = h.rough;
          _facing.value = (h.magnetic + _declination + 360) % 360;
        },
        onError: (Object _) {
          if (mounted) {
            setState(
              () => _compassProblem = Strings.of(context).lightCompassNone,
            );
          }
        },
      );
    });
  }

  // Where the bearing is while the finger moves it: only the line is
  // drawn again, and the days are worked out when it lifts.
  final _aiming = ValueNotifier<double?>(null);

  // A touch or a drag on the plan, while lining up: the bearing to it.
  void _aim(double bearing) {
    final rounded = bearing.roundToDouble() % 360;
    final was = _aiming.value ?? _bearing;
    if (rounded == was) return;
    if (was == null || (rounded ~/ 5) != (was ~/ 5)) {
      HapticFeedback.selectionClick();
    }
    _aiming.value = rounded;
  }

  // The finger lifted: the bearing set, and its days worked out.
  void _aimEnd() {
    final aimed = _aiming.value;
    _aiming.value = null;
    if (aimed != null && aimed != _bearing) setState(() => _bearing = aimed);
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  /// An instant as the local clock has it, or "not that day".
  String _clock(DateTime? at, Strings strings) {
    if (at == null) return strings.notThatDay;
    final local = LocalClock.wall(at, widget.utcOffset);
    return '${_two(local.hour)}:${_two(local.minute)}';
  }

  String _span(Span? span, Strings strings) => span == null
      ? strings.notThatDay
      : '${_clock(span.start, strings)} – ${_clock(span.end, strings)}';

  static String _bearingOf(double bearing, Strings strings) =>
      '${bearing.toStringAsFixed(0)}° '
      '${strings.compassPoint(((bearing + 22.5) ~/ 45))}';

  String _withBearing(DateTime? at, double? bearing, Strings strings) =>
      bearing == null
      ? _clock(at, strings)
      : '${_clock(at, strings)} · ${_bearingOf(bearing, strings)}';

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final strings = Strings.of(context);

    return ValueListenableBuilder(
      valueListenable: SkyPlace.current,
      builder: (context, place, _) {
        SkyPosition? sun, moon;
        ({double altitude, double azimuth})? core;
        if (place != null) {
          _workDay(place);
          sun = SkyNow.sun(
            _instant,
            latitude: place.latitude,
            longitude: place.longitude,
          );
          moon = SkyNow.moon(
            _instant,
            latitude: place.latitude,
            longitude: place.longitude,
          );
          core = MilkyWay.at(
            _instant,
            latitude: place.latitude,
            longitude: place.longitude,
          );
          _bearing ??= (_paths!.sunDay.setAzimuth ?? 270).roundToDouble();
          if (_panel == _Panel.align) _workAlign(place, _bearing!);
        }

        final Widget body;
        if (place == null) {
          body = Center(
            child: Padding(
              padding: EdgeInsets.all(spacing.lg),
              child: Text(
                strings.skyAskPlace,
                key: const ValueKey('light-ask-place'),
                textAlign: TextAlign.center,
                style: theme.type.body.copyWith(color: colors.textSecondary),
              ),
            ),
          );
        } else {
          final paths = _paths!;
          body = Column(
            children: [
              Expanded(
                child: NightDome(
                  child: LayoutBuilder(
                    builder: (context, room) {
                      // While the compass is on, its line stands halfway
                      // between the subtitle and the plan's N: as far
                      // from one as from the other (owner, 20 October
                      // 2026). The body starts [spacing.md] under the
                      // subtitle; the N stands 12 points over the
                      // horizon, which is 22 in from the plan's edge.
                      var at = 0.0;
                      var lift = 0.0;
                      if (_compass != null) {
                        final line = (TextPainter(
                          text: TextSpan(text: 'N', style: theme.type.caption),
                          textDirection: TextDirection.ltr,
                        )..layout()).height;
                        double north(double lift) {
                          final h = room.maxHeight - lift;
                          final r = math.min(room.maxWidth, h) / 2 - 22;
                          return lift + h / 2 - r - 12 - line / 2;
                        }

                        at = (north(0) - line - spacing.md) / 2;
                        if (at < 0) {
                          // Too little room over the plan: it moves down
                          // until the line fits with the same gap.
                          at = 0;
                          while (north(lift) < line + spacing.md &&
                              lift < room.maxHeight / 4) {
                            lift += 1;
                          }
                        }
                      }
                      return Stack(
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            top: lift,
                            child: LightPlan(
                              key: const ValueKey('light-plan'),
                              sunDay: paths.sunDay,
                              moonDay: paths.moonDay,
                              sun: sun!,
                              moon: moon!,
                              core: core!,
                              bearing: _panel == _Panel.align ? _bearing : null,
                              aiming: _aiming,
                              onAim: _panel == _Panel.align ? _aim : null,
                              onAimEnd: _panel == _Panel.align ? _aimEnd : null,
                              compass: strings.compassFour,
                              facing: _facing,
                            ),
                          ),
                          // While the compass is on: which way the phone faces.
                          if (_compass != null)
                            Positioned(
                              left: spacing.sm,
                              top: at,
                              right: spacing.sm,
                              child: ValueListenableBuilder(
                                valueListenable: _facing,
                                builder: (context, facing, _) => Text(
                                  _compassProblem ??
                                      (facing == null
                                          ? strings.lintangWorking
                                          : _rough
                                          ? strings.lightCompassRough
                                          : strings.lightFacing(
                                              _bearingOf(facing, strings),
                                              '${_declination >= 0 ? '+' : '−'}'
                                              '${_declination.abs().toStringAsFixed(1)}°',
                                            )),
                                  key: const ValueKey('light-facing'),
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.fade,
                                  style: theme.type.caption.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          // The phone's compass, set to true north: at the
                          // body's bottom right, in the corner the round sky
                          // leaves, as the star map's planets are.
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GlyphButton(
                              key: const ValueKey('light-compass'),
                              glyph: Glyph.compass,
                              square: true,
                              lit: _compass != null,
                              onTap: _toggleCompass,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: spacing.sm),
              LightStrip(
                key: const ValueKey('light-strip'),
                sunPath: paths.sun,
                shift: paths.shift,
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
                  key: const ValueKey('light-top-bar'),
                  leading: TopBarTitle(label: strings.lightTitle),
                  trailing: Text(
                    '${_two(_minute ~/ 60)}:${_two(_minute % 60)}',
                    key: const ValueKey('light-clock'),
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
                panel: _panelView(theme, strings, place, sun, moon, core),
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
    SkyPosition? sun,
    SkyPosition? moon,
    ({double altitude, double azimuth})? core,
  ) {
    final spacing = theme.spacing;
    final labels = {
      _Panel.hours: strings.lightHours,
      _Panel.shadow: strings.lightShadow,
      _Panel.moon: strings.lightMoon,
      _Panel.milkyWay: strings.lightMilkyWay,
      _Panel.night: strings.lightNight,
      _Panel.meteors: strings.lightMeteors,
      _Panel.eclipses: strings.lightEclipses,
      _Panel.pairs: strings.lightPairs,
      _Panel.align: strings.lightAlign,
      _Panel.date: strings.skyDate,
      _Panel.time: strings.skyTime,
      _Panel.place: strings.skyPlaceTab,
    };
    final shown = place == null && _panel.index < _Panel.date.index
        ? _Panel.place
        : _panel;

    Widget content() {
      switch (shown) {
        case _Panel.hours:
          return _hoursRows(theme, strings, sun!);
        case _Panel.shadow:
          return _shadowRows(theme, strings, sun!);
        case _Panel.moon:
          _workMoons();
          return _moonRows(theme, strings, moon!);
        case _Panel.milkyWay:
          _workNight(place!);
          return _milkyWayRows(theme, strings, core!);
        case _Panel.night:
          return _nightRows(theme, strings, place!);
        case _Panel.meteors:
          _workMeteors(place!);
          return _meteorRows(theme, strings);
        case _Panel.eclipses:
          _workEclipses(place!);
          return _eclipseRows(theme, strings);
        case _Panel.pairs:
          _workPairs(place!);
          return _pairRows(theme, strings);
        case _Panel.align:
          return _alignRows(theme, strings);
        case _Panel.date:
          return Center(
            child: DatePicker(
              key: ValueKey('light-date-$_jump'),
              date: _date,
              strings: strings,
              onChanged: _setDate,
            ),
          );
        case _Panel.time:
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.lg),
            child: TimePicker(
              key: ValueKey('light-time-$_jump'),
              minuteOfDay: _minute,
              onChanged: (minute) => _moveTo(minute, fromWheels: true),
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
          listKey: const ValueKey('light-panels'),
          tabs: _Panel.values,
          shown: shown,
          label: (panel) => labels[panel]!,
          keyOf: (panel) => 'light-panel-${panel.name}',
          onChoose: _choose,
        ),
        Expanded(
          child: RepaintBoundary(
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: theme.motion.medium,
                child: KeyedSubtree(key: ValueKey(shown), child: content()),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Label and value rows, with a note under them.
  Widget _rows(
    SmThemeData theme,
    String name,
    List<(String, String)> rows, {
    String? note,
    Map<int, Reminder> remind = const {},
  }) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    return SingleChildScrollView(
      key: ValueKey(name),
      padding: EdgeInsets.fromLTRB(spacing.md, spacing.sm, spacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, (label, value)) in rows.indexed)
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
                        color: label.isEmpty
                            ? colors.textSecondary
                            : colors.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        height: 1.5,
                      ),
                    ),
                  ),
                  // A bell where the moment can be made a reminder.
                  if (remind.isNotEmpty)
                    remind[i] == null
                        ? const SizedBox(width: 30)
                        : GestureDetector(
                            key: ValueKey('$name-remind-$i'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _remind(remind[i]!),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12, top: 2),
                              child: GlyphMark(
                                glyph: Glyph.reminder,
                                size: 18,
                                color: colors.textSecondary,
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

  // Opens a new reminder made from a moment on this screen, for the user
  // to name, file, change and save, or let go.
  Future<void> _remind(Reminder draft) async {
    HapticFeedback.selectionClick();
    await pushReminder(context, reminder: draft, day: draft.start);
  }

  // A reminder by the sun on the day shown, a quarter of an hour ahead:
  // time to be in place.
  Reminder _sunDraft(SunAnchor anchor, Strings strings) {
    final draft = Reminder(
      id: '',
      title: strings.lightRemindSun(anchor),
      start: _date,
      minuteOfDay: 12 * 60,
      repeat: Repeat.once,
      sun: anchor,
      lead: 15,
    );
    final minute = draft.minuteOn(
      _date,
      place: SkyPlace.current.value,
      utcOffset: _offset,
    );
    return minute == null ? draft : draft.copyWith(minuteOfDay: minute);
  }

  // A reminder by the clock at [at], [lead] minutes ahead.
  Reminder _clockDraft(String title, DateTime at, int lead) {
    final wall = LocalClock.wall(
      at.subtract(Duration(minutes: lead)),
      widget.utcOffset,
    );
    return Reminder(
      id: '',
      title: title,
      start: CivilDate(wall.year, wall.month, wall.day),
      minuteOfDay: wall.hour * 60 + wall.minute,
      repeat: Repeat.once,
    );
  }

  // The golden and blue hours, morning and evening, the light now, and
  // the sun's rising and setting with where to look.
  Widget _hoursRows(SmThemeData theme, Strings strings, SkyPosition sun) {
    final h = _hours!;
    final day = _paths!.sunDay;
    return _rows(
      theme,
      'light-hours',
      [
        (strings.lightNow, strings.lightBand(LightBand.of(sun.trueAltitude))),
        (strings.lightMorningBlue, _span(h.morningBlue, strings)),
        (strings.lightMorningGolden, _span(h.morningGolden, strings)),
        (strings.skyRise, _withBearing(day.rise, day.riseAzimuth, strings)),
        (strings.skySet, _withBearing(day.set, day.setAzimuth, strings)),
        (strings.lightEveningGolden, _span(h.eveningGolden, strings)),
        (strings.lightEveningBlue, _span(h.eveningBlue, strings)),
      ],
      note: strings.lightHoursHow,
      remind: {
        if (h.morningBlue != null) 1: _sunDraft(SunAnchor.morningBlue, strings),
        if (day.rise != null) 3: _sunDraft(SunAnchor.sunrise, strings),
        if (day.set != null) 4: _sunDraft(SunAnchor.sunset, strings),
        if (h.eveningGolden != null)
          5: _sunDraft(SunAnchor.eveningGolden, strings),
        if (h.eveningBlue != null) 6: _sunDraft(SunAnchor.eveningBlue, strings),
      },
    );
  }

  // At the moment: the sun's height, the shadow an upright thing casts
  // and where it falls, and where a rainbow would stand.
  Widget _shadowRows(SmThemeData theme, Strings strings, SkyPosition sun) {
    final shadow = SunLight.shadow(sun);
    final bow = SunLight.rainbow(sun);
    String length(double times) =>
        times > 50 ? strings.lightVeryLong : strings.lightTimesHeight(times);
    return _rows(theme, 'light-shadow', [
      (
        strings.lightSunHeight,
        '${sun.altitude < 0 ? '−' : '+'}${sun.altitude.abs().toStringAsFixed(1)}° · '
            '${_bearingOf(sun.azimuth, strings)}',
      ),
      if (shadow == null)
        (strings.lightShadow, strings.lightSunDown)
      else ...[
        (strings.lightShadowLength, length(shadow.length)),
        (strings.lightShadowFalls, _bearingOf(shadow.bearing, strings)),
      ],
      (
        strings.lightRainbow,
        bow == null
            ? (sun.altitude <= 0
                  ? strings.lightSunDown
                  : strings.lightSunTooHigh)
            : strings.lightRainbowAt(
                bow.top.toStringAsFixed(0),
                _bearingOf(bow.bearing, strings),
              ),
      ),
      if (bow?.secondTop != null)
        (strings.lightSecondBow, '${bow!.secondTop!.toStringAsFixed(0)}°'),
      // The ring of ice light 22° round the sun, and its bright spots
      // either side at the sun's own height.
      (
        strings.lightHalo,
        sun.altitude <= 0
            ? strings.lightSunDown
            : strings.lightHaloAt(
                math.max(-22, sun.altitude - 22).toStringAsFixed(0),
                math.min(90, sun.altitude + 22).toStringAsFixed(0),
              ),
      ),
      (
        strings.lightSundogs,
        sun.altitude <= 0
            ? strings.lightSunDown
            : sun.altitude >= 61
            ? strings.lightSunTooHigh
            : strings.lightSundogsAt(
                _bearingOf((sun.azimuth - 22 + 360) % 360, strings),
                _bearingOf((sun.azimuth + 22) % 360, strings),
              ),
      ),
    ], note: strings.lightShadowHow);
  }

  // The moon for photographs: how lit, where it rises and sets, how far,
  // the coming full moons with the nearest marked, and where to start the
  // exposure.
  Widget _moonRows(SmThemeData theme, Strings strings, SkyPosition moon) {
    final face = SkyNow.moonFace(_instant);
    final day = _paths!.moonDay;
    final moons = _moons;
    final rows = <(String, String)>[
      (
        strings.skyPhase,
        '${strings.moonPhase(Moon.of(_date, utcOffset: _offset).phase)} · '
            '${(face.illumination * 100).toStringAsFixed(0)}%',
      ),
      (strings.skyRise, _withBearing(day.rise, day.riseAzimuth, strings)),
      (strings.skySet, _withBearing(day.set, day.setAzimuth, strings)),
      (strings.skyDistance, '${_thousands(moon.distance.round())} km'),
    ];
    final remind = <int, Reminder>{};
    final place = SkyPlace.current.value;
    if (moons != null && moons.isNotEmpty) {
      final nearest = moons.reduce((a, b) => a.distance < b.distance ? a : b);
      final farthest = moons.reduce((a, b) => a.distance > b.distance ? a : b);
      for (final (k, m) in moons.indexed) {
        final local = LocalClock.wall(m.at, widget.utcOffset);
        final day = CivilDate(local.year, local.month, local.day);
        // The full moon's day, as it rises: a quarter of an hour ahead.
        final rise = place == null
            ? null
            : SkyNow.day(
                Body.moon,
                day,
                latitude: place.latitude,
                longitude: place.longitude,
                utcOffset: _offsetOn(day),
              ).rise;
        if (rise != null) {
          remind[rows.length] = _clockDraft(
            strings.lightRemindFullMoon,
            rise,
            15,
          );
        }
        rows.add((
          k == 0 ? strings.lightFullMoons : '',
          '${strings.gregorian(day)} · ${_thousands(m.distance.round())} km'
              '${identical(m, nearest)
                  ? ' · ${strings.lightNearest}'
                  : identical(m, farthest)
                  ? ' · ${strings.lightFarthest}'
                  : ''}',
        ));
      }
    } else {
      rows.add((strings.lightFullMoons, strings.lintangWorking));
    }
    return _rows(
      theme,
      'light-moon',
      rows,
      note: strings.lightLooney,
      remind: remind,
    );
  }

  static String _thousands(int value) => value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  // The Milky Way's heart: where it is now, and tonight's dark hours with
  // it up, with and without the moon.
  Widget _milkyWayRows(
    SmThemeData theme,
    Strings strings,
    ({double altitude, double azimuth}) core,
  ) {
    final night = _night;
    final rows = <(String, String)>[
      (
        strings.lightCoreNow,
        core.altitude < 0
            ? strings.starsDown
            : '${core.altitude.toStringAsFixed(0)}° · '
                  '${_bearingOf(core.azimuth, strings)}',
      ),
    ];
    final remind = <int, Reminder>{};
    // Each dark stretch its own row, and each can be a reminder at its
    // start, a quarter of an hour ahead.
    void spans(String label, String title, List<Span> list) {
      if (list.isEmpty) {
        rows.add((label, strings.lightNone));
        return;
      }
      for (final (k, span) in list.indexed) {
        remind[rows.length] = _clockDraft(title, span.start, 15);
        rows.add((k == 0 ? label : '', _span(span, strings)));
      }
    }

    if (night == null) {
      rows.add((strings.lightTonight, strings.lintangWorking));
    } else {
      spans(
        strings.lightDarkMoonless,
        strings.lightRemindMilkyWay(moon: false),
        night.moonless,
      );
      spans(
        strings.lightDarkMoonUp,
        strings.lightRemindMilkyWay(moon: true),
        _without(night.dark, night.moonless),
      );
    }
    return _rows(
      theme,
      'light-milky-way',
      rows,
      note: strings.lightMilkyWayHow,
      remind: remind,
    );
  }

  // The dark stretches with the moonless ones taken out: when it is dark
  // and the core up but the moon is too.
  static List<Span> _without(List<Span> all, List<Span> out) {
    final result = <Span>[];
    for (final s in all) {
      var from = s.start;
      for (final o in out) {
        if (!o.end.isAfter(from) || !o.start.isBefore(s.end)) continue;
        if (o.start.isAfter(from)) result.add((start: from, end: o.start));
        if (o.end.isAfter(from)) from = o.end;
      }
      if (from.isBefore(s.end)) result.add((start: from, end: s.end));
    }
    return result;
  }

  // The night sky: where it turns, and how long a photograph of it can
  // be held before the stars draw lines.
  Widget _nightRows(
    SmThemeData theme,
    Strings strings,
    ({double latitude, double longitude}) place,
  ) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    final focal = _Lens.focals[_Lens.focal];
    final stop = _Lens.stops[_Lens.stop];
    final crop = _Lens.crops[_Lens.crop];
    final pitch = _Lens.pitch / 10;
    final fiveHundred = 500 / (focal * crop);
    final npf = (35 * stop + 30 * pitch) / focal;
    final south = place.latitude < 0;
    void step(void Function() change) {
      HapticFeedback.selectionClick();
      setState(change);
    }

    return SingleChildScrollView(
      key: const ValueKey('light-night'),
      padding: EdgeInsets.fromLTRB(spacing.md, spacing.sm, spacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.lightPoleAt(
              south: south,
              height: place.latitude.abs().toStringAsFixed(1),
            ),
            key: const ValueKey('light-pole'),
            style: theme.type.label.copyWith(
              color: colors.textPrimary,
              height: 1.4,
            ),
          ),
          SizedBox(height: spacing.md),
          Row(
            children: [
              Expanded(
                child: StepField(
                  name: 'light-focal',
                  label: strings.lightFocal,
                  value: '$focal mm',
                  onStep: (by) => step(
                    () => _Lens.focal = (_Lens.focal + by).clamp(
                      0,
                      _Lens.focals.length - 1,
                    ),
                  ),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: StepField(
                  name: 'light-stop',
                  label: strings.lightAperture,
                  value: 'f/$stop',
                  onStep: (by) => step(
                    () => _Lens.stop = (_Lens.stop + by).clamp(
                      0,
                      _Lens.stops.length - 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Row(
            children: [
              Expanded(
                child: StepField(
                  name: 'light-pitch',
                  label: strings.lightPitch,
                  value: '${pitch.toStringAsFixed(1)} µm',
                  hold: true,
                  onStep: (by) =>
                      step(() => _Lens.pitch = (_Lens.pitch + by).clamp(8, 90)),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: StepField(
                  name: 'light-crop',
                  label: strings.lightSensor,
                  value: strings.lightCrop(crop),
                  onStep: (by) => step(
                    () => _Lens.crop = (_Lens.crop + by).clamp(
                      0,
                      _Lens.crops.length - 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          _rows(theme, 'light-limits', [
            (strings.lightNpf, strings.lightSeconds(npf)),
            (strings.lightFiveHundred, strings.lightSeconds(fiveHundred)),
          ], note: strings.lightNightHow),
        ],
      ),
    );
  }

  // A list of things coming, each its line, a line under it, and a bell
  // where it can be a reminder.
  Widget _comingList(
    SmThemeData theme,
    String name,
    List<({String title, String detail, Reminder? remind, bool lit})> items, {
    String? empty,
    String? note,
  }) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    return ListView(
      key: ValueKey(name),
      padding: EdgeInsets.fromLTRB(spacing.md, spacing.xs, spacing.md, 0),
      children: [
        if (items.isEmpty && empty != null)
          Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.md),
            child: Text(
              empty,
              style: theme.type.label.copyWith(color: colors.textFaint),
            ),
          ),
        for (final (k, item) in items.indexed)
          Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.xs + 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.type.body.copyWith(
                          color: item.lit ? colors.accent : colors.textPrimary,
                        ),
                      ),
                      Text(
                        item.detail,
                        style: theme.type.caption.copyWith(
                          color: colors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.remind case final r?)
                  GestureDetector(
                    key: ValueKey('$name-remind-$k'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _remind(r),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, top: 4),
                      child: GlyphMark(
                        glyph: Glyph.reminder,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (note != null)
          Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.sm),
            child: Text(
              note,
              style: theme.type.caption.copyWith(
                color: colors.textFaint,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }

  String _dayOf(DateTime at, Strings strings) {
    final local = LocalClock.wall(at, widget.utcOffset);
    return strings.gregorian(CivilDate(local.year, local.month, local.day));
  }

  // The showers in the order their peaks come, each with how high its
  // radiant stands in the dark of that night and how much moon there is.
  Widget _meteorRows(SmThemeData theme, Strings strings) {
    final nights = _meteors;
    if (nights == null) {
      return Center(
        child: Text(
          strings.lintangWorking,
          style: theme.type.label.copyWith(color: theme.colors.textFaint),
        ),
      );
    }
    return _comingList(theme, 'light-meteors', [
      for (final n in nights)
        (
          title: '${_showers[n.index].name} · ${_dayOf(n.peak, strings)}',
          detail: [
            strings.lightZhr(_showers[n.index].zhr),
            n.bestAt == null || n.best < 0
                ? strings.lightRadiantDown
                : strings.lightRadiantAt(
                    n.best.toStringAsFixed(0),
                    _clock(n.bestAt, strings),
                  ),
            strings.lightMoonLit((n.moonLit * 100).round()),
            if (_showers[n.index].activeOn(_date.month, _date.day))
              strings.lightActiveNow,
          ].join(' · '),
          remind: n.bestAt == null || n.best < 0
              ? null
              : _clockDraft(
                  strings.lightRemindMeteors(_showers[n.index].name),
                  n.bestAt!,
                  30,
                ),
          lit: _showers[n.index].activeOn(_date.month, _date.day),
        ),
    ], note: strings.lightMeteorsHow);
  }

  // The eclipses to be seen from here over the coming ten years.
  Widget _eclipseRows(SmThemeData theme, Strings strings) {
    final found = _eclipses;
    if (found == null) {
      return Center(
        child: Text(
          strings.lintangWorking,
          style: theme.type.label.copyWith(color: theme.colors.textFaint),
        ),
      );
    }
    return _comingList(
      theme,
      'light-eclipses',
      [
        for (final e in found)
          (
            title:
                '${strings.lightEclipseKind(e.kind, solar: e.solar)} · '
                '${_dayOf(e.greatest, strings)}',
            detail: [
              '${_clock(e.begins, strings)} – ${_clock(e.ends, strings)}',
              if (e.centralBegins != null && e.centralEnds != null)
                strings.lightEclipseCentral(
                  e.kind,
                  '${_clock(e.centralBegins, strings)} – '
                  '${_clock(e.centralEnds, strings)}',
                ),
              strings.lightEclipseGreatest(
                _clock(e.greatest, strings),
                e.solar
                    ? strings.lightEclipseCovered(
                        (e.magnitude * 100).round().clamp(0, 100),
                      )
                    : strings.lightEclipseUmbral(e.magnitude),
                e.height.round(),
                solar: e.solar,
              ),
            ].join('\n'),
            remind: _clockDraft(
              strings.lightEclipseKind(e.kind, solar: e.solar),
              e.begins,
              30,
            ),
            lit: false,
          ),
      ],
      empty: strings.lightNoEclipses,
      note: strings.lightEclipsesHow,
    );
  }

  // The coming year's close pairs: the moon by a planet, two planets
  // together; each when nearest, and when best seen from here.
  Widget _pairRows(SmThemeData theme, Strings strings) {
    final found = _pairs;
    if (found == null) {
      return Center(
        child: Text(
          strings.lintangWorking,
          style: theme.type.label.copyWith(color: theme.colors.textFaint),
        ),
      );
    }
    String two(Body a, Body b) =>
        strings.lightPair(strings.planetName(a), strings.planetName(b));
    return _comingList(
      theme,
      'light-pairs',
      [
        for (final c in found)
          (
            title: '${two(c.first, c.second)} · ${_dayOf(c.closest, strings)}',
            detail: [
              strings.lightPairNearest(
                c.separation.toStringAsFixed(1),
                _clock(c.closest, strings),
              ),
              c.seen == null
                  ? strings.lightPairNotSeen
                  : strings.lightPairSeen(
                      _clock(c.seen, strings),
                      c.height!.round(),
                      c.seenSeparation!.toStringAsFixed(1),
                      // The day too, where it is not the meeting's.
                      day:
                          _dayOf(c.seen!, strings) == _dayOf(c.closest, strings)
                          ? null
                          : _dayOf(c.seen!, strings),
                    ),
            ].join('\n'),
            remind: c.seen == null
                ? null
                : _clockDraft(two(c.first, c.second), c.seen!, 30),
            lit: false,
          ),
      ],
      empty: strings.lightNoPairs,
      note: strings.lightPairsHow,
    );
  }

  // Lining up: the bearing, and the coming days the sun and the moon
  // rise and set along it.
  Widget _alignRows(SmThemeData theme, Strings strings) {
    final bearing = _bearing!;
    final aligned = _aligned;
    final rows = <(String, String)>[
      (strings.lightBearing, _bearingOf(bearing, strings)),
    ];
    final remind = <int, Reminder>{};
    if (aligned == null) {
      rows.add(('', strings.lintangWorking));
    } else {
      void add(String label, String title, List<Aligned> found, int most) {
        if (found.isEmpty) {
          rows.add((label, strings.lightNotThisYear));
          return;
        }
        for (final (k, a) in found.take(most).indexed) {
          // Half an hour ahead, to be in place.
          remind[rows.length] = _clockDraft(title, a.at, 30);
          rows.add((
            k == 0 ? label : '',
            '${strings.gregorian(a.date)} · ${_clock(a.at, strings)}',
          ));
        }
      }

      final along = _bearingOf(bearing, strings);
      add(
        strings.lightSunRises,
        strings.lightRemindAlign(SunAnchor.sunrise, along),
        aligned.sun.rises,
        2,
      );
      add(
        strings.lightSunSets,
        strings.lightRemindAlign(SunAnchor.sunset, along),
        aligned.sun.sets,
        2,
      );
      add(
        strings.lightMoonRises,
        strings.lightRemindAlignMoon(rising: true, along),
        aligned.moon.rises,
        3,
      );
      add(
        strings.lightMoonSets,
        strings.lightRemindAlignMoon(rising: false, along),
        aligned.moon.sets,
        3,
      );
    }
    return _rows(
      theme,
      'light-align',
      rows,
      note: strings.lightAlignHow,
      remind: remind,
    );
  }
}

/// The days over the coming year that the sun and the moon rise and set
/// along a bearing.
typedef LightAlignments = ({
  ({List<Aligned> rises, List<Aligned> sets}) sun,
  ({List<Aligned> rises, List<Aligned> sets}) moon,
});

/// The heavier reckonings of Light, each away from the screen. Functions
/// of their own, so the work sent off holds nothing of the screen's.
/// A shower's coming peak seen from a place: when, how high its radiant
/// stands at best in the dark of that night and when, how much of the
/// moon is lit.
typedef MeteorNight = ({
  int index,
  DateTime peak,
  double best,
  DateTime? bestAt,
  double moonLit,
});

/// An eclipse to be seen from a place: of the sun or the moon, its kind,
/// its greatest, beginning and end (for the moon, of the partial phase,
/// or the penumbral for a penumbral one), its total or annular phase, how
/// much (of the sun covered, or the umbral magnitude), and how high the
/// sun or the moon then stands.
typedef LocalEclipse = ({
  bool solar,
  EclipseKind kind,
  DateTime greatest,
  DateTime begins,
  DateTime ends,
  DateTime? centralBegins,
  DateTime? centralEnds,
  double magnitude,
  double height,
});

abstract final class LightWork {
  static Future<List<MeteorNight>> meteors(
    List<MeteorShower> showers,
    CivilDate from,
    double latitude,
    double longitude,
  ) => Isolate.run(() {
    final start = DateTime.utc(from.year, from.month, from.day);
    final nights = <MeteorNight>[];
    for (final (k, shower) in showers.indexed) {
      var peak = SunLongitude.when(from.year, shower.longitude);
      if (peak.isBefore(start.subtract(const Duration(days: 1)))) {
        peak = SunLongitude.when(from.year + 1, shower.longitude);
      }
      var best = -90.0;
      DateTime? bestAt;
      for (var m = -720; m <= 720; m += 15) {
        final t = peak.add(Duration(minutes: m));
        final sun = SkyNow.sun(t, latitude: latitude, longitude: longitude);
        if (sun.trueAltitude > -12) continue;
        final p = StarSky.at(
          t,
          latitude: latitude,
          longitude: longitude,
        ).place(shower.rightAscension, shower.declination);
        if (p.altitude > best) {
          best = p.altitude;
          bestAt = t;
        }
      }
      nights.add((
        index: k,
        peak: peak,
        best: best,
        bestAt: bestAt,
        moonLit: SkyNow.moonFace(peak).illumination,
      ));
    }
    nights.sort((a, b) => a.peak.compareTo(b.peak));
    return nights;
  });

  static Future<List<CloseApproach>> pairs(
    DateTime from,
    double latitude,
    double longitude,
  ) => Isolate.run(
    () => CloseApproaches.within(
      from,
      366,
      latitude: latitude,
      longitude: longitude,
    ),
  );

  static Future<List<LocalEclipse>> eclipses(
    DateTime from,
    double latitude,
    double longitude,
  ) => Isolate.run(() {
    const days = 3653;
    final found = <LocalEclipse>[
      for (final e in Eclipses.solarFrom(
        from,
        days,
        latitude: latitude,
        longitude: longitude,
      ))
        (
          solar: true,
          kind: e.kind,
          greatest: e.greatest,
          begins: e.begins,
          ends: e.ends,
          centralBegins: e.centralBegins,
          centralEnds: e.centralEnds,
          magnitude: e.magnitude,
          height: e.sunAtGreatest,
        ),
    ];
    double moonAt(DateTime t) =>
        SkyNow.moon(t, latitude: latitude, longitude: longitude).altitude;
    for (final e in Eclipses.lunarFrom(from, days)) {
      final begins = e.partialBegins ?? e.penumbraBegins;
      final ends = e.partialEnds ?? e.penumbraEnds;
      final height = moonAt(e.greatest);
      // Seen if the moon is up for some of it.
      if (height < 0 && moonAt(begins) < 0 && moonAt(ends) < 0) continue;
      found.add((
        solar: false,
        kind: e.kind,
        greatest: e.greatest,
        begins: begins,
        ends: ends,
        centralBegins: e.totalBegins,
        centralEnds: e.totalEnds,
        magnitude: e.umbralMagnitude,
        height: height,
      ));
    }
    found.sort((a, b) => a.greatest.compareTo(b.greatest));
    return found;
  });

  static Future<({List<Span> dark, List<Span> moonless})> night(
    CivilDate date,
    double latitude,
    double longitude,
    Duration utcOffset,
  ) => Isolate.run(
    () => MilkyWay.night(
      date,
      latitude: latitude,
      longitude: longitude,
      utcOffset: utcOffset,
    ),
  );

  static Future<List<({DateTime at, double distance})>> fullMoons(
    DateTime from,
  ) => Isolate.run(() => FullMoons.within(from, 366));

  static Future<LightAlignments> align(
    CivilDate from,
    double latitude,
    double longitude,
    Duration utcOffset,
    double bearing,
  ) => Isolate.run(() {
    ({List<Aligned> rises, List<Aligned> sets}) of(Body body) =>
        Alignments.risesAndSets(
          body,
          bearing: bearing,
          from: from,
          latitude: latitude,
          longitude: longitude,
          utcOffset: utcOffset,
        );
    return (sun: of(Body.sun), moon: of(Body.moon));
  });
}

/// The ground seen from above, you at the centre, north up and east on
/// the right: the bearings the sun and the moon rise and set along that
/// day, where each stands now, the shadow an upright thing casts now, the
/// Milky Way's heart while it is up, and the bearing being lined up.
class LightPlan extends StatelessWidget {
  final SkyDay sunDay;
  final SkyDay moonDay;
  final SkyPosition sun;
  final SkyPosition moon;
  final ({double altitude, double azimuth}) core;

  /// The bearing being lined up; touching or drawing across the plan
  /// moves it, through [onAim] as the finger goes and [onAimEnd] when it
  /// lifts. While it moves, [aiming] holds where it is, and only the line
  /// is drawn again.
  final double? bearing;
  final ValueListenable<double?>? aiming;
  final ValueChanged<double>? onAim;
  final VoidCallback? onAimEnd;

  /// Where the phone faces from true north, while its compass is on.
  final ValueListenable<double?>? facing;

  final List<String> compass;

  const LightPlan({
    super.key,
    required this.sunDay,
    required this.moonDay,
    required this.sun,
    required this.moon,
    required this.core,
    required this.compass,
    this.bearing,
    this.aiming,
    this.onAim,
    this.onAimEnd,
    this.facing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final centre = size.center(Offset.zero);
        void aim(Offset at) {
          final d = at - centre;
          if (d.distance < 8) return;
          onAim?.call((math.atan2(d.dx, -d.dy) * 180 / math.pi + 360) % 360);
        }

        final radius = size.shortestSide / 2 - 22;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: onAim == null ? null : (d) => aim(d.localPosition),
          onTapUp: onAimEnd == null ? null : (_) => onAimEnd!(),
          onPanUpdate: onAim == null ? null : (d) => aim(d.localPosition),
          onPanEnd: onAimEnd == null ? null : (_) => onAimEnd!(),
          child: Stack(
            children: [
              // Everything but the bearing, drawn once for the moment.
              RepaintBoundary(
                child: CustomPaint(
                  size: size,
                  painter: _PlanPainter(
                    sunDay: sunDay,
                    moonDay: moonDay,
                    sun: sun,
                    moon: moon,
                    core: core,
                    bearing: bearing,
                    compass: compass,
                    rim: colors.outline,
                    faint: colors.textFaint,
                    ink: colors.textPrimary,
                    accent: colors.accent,
                    sunColor: skySunIn(context),
                    moonColor: skyMoonIn(context),
                    label: theme.type.caption,
                  ),
                ),
              ),
              // Where the phone faces, alone, as it turns.
              if (facing != null)
                ValueListenableBuilder(
                  valueListenable: facing!,
                  builder: (context, toward, _) => toward == null
                      ? const SizedBox.shrink()
                      : CustomPaint(
                          size: size,
                          painter: _FacingPainter(
                            toward: toward,
                            radius: radius,
                            ink: colors.textPrimary,
                          ),
                        ),
                ),
              // The bearing, alone, as the finger moves it.
              if (bearing != null)
                ValueListenableBuilder(
                  valueListenable: aiming ?? ValueNotifier<double?>(null),
                  builder: (context, live, _) => CustomPaint(
                    size: size,
                    painter: _BearingPainter(
                      bearing: live ?? bearing!,
                      radius: radius,
                      accent: colors.accent,
                      label: theme.type.caption,
                      showing: live != null,
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

/// Where the phone faces: a soft wedge from the centre toward it.
class _FacingPainter extends CustomPainter {
  final double toward;
  final double radius;
  final Color ink;

  _FacingPainter({
    required this.toward,
    required this.radius,
    required this.ink,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final a = (toward - 90) * math.pi / 180;
    const half = 12 * math.pi / 180;
    canvas.drawPath(
      Path()
        ..moveTo(centre.dx, centre.dy)
        ..arcTo(
          Rect.fromCircle(center: centre, radius: radius),
          a - half,
          2 * half,
          false,
        )
        ..close(),
      Paint()..color = ink.withValues(alpha: 0.14),
    );
    canvas.drawLine(
      centre,
      centre + Offset(math.cos(a), math.sin(a)) * radius,
      Paint()
        ..color = ink.withValues(alpha: 0.5)
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_FacingPainter old) => old.toward != toward;
}

/// The bearing being lined up: a line from the centre to the horizon, and
/// while it is being moved, its degrees at the end.
class _BearingPainter extends CustomPainter {
  final double bearing;
  final double radius;
  final Color accent;
  final TextStyle label;
  final bool showing;

  _BearingPainter({
    required this.bearing,
    required this.radius,
    required this.accent,
    required this.label,
    required this.showing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    Offset toward(double r) {
      final a = bearing * math.pi / 180;
      return centre + Offset(math.sin(a) * r, -math.cos(a) * r);
    }

    canvas.drawLine(
      centre,
      toward(radius + 6),
      Paint()
        ..color = accent
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    if (!showing) return;
    final text = TextPainter(
      text: TextSpan(
        text: '${bearing.round() % 360}°',
        style: label.copyWith(color: accent),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      toward(radius * 0.72) - Offset(text.width / 2, text.height / 2),
    );
  }

  @override
  bool shouldRepaint(_BearingPainter old) =>
      old.bearing != bearing || old.showing != showing || old.accent != accent;
}

class _PlanPainter extends CustomPainter {
  final SkyDay sunDay;
  final SkyDay moonDay;
  final SkyPosition sun;
  final SkyPosition moon;
  final ({double altitude, double azimuth}) core;
  final double? bearing;
  final List<String> compass;
  final Color rim;
  final Color faint;
  final Color ink;
  final Color accent;
  final Color sunColor;
  final Color moonColor;
  final TextStyle label;

  _PlanPainter({
    required this.sunDay,
    required this.moonDay,
    required this.sun,
    required this.moon,
    required this.core,
    required this.bearing,
    required this.compass,
    required this.rim,
    required this.faint,
    required this.ink,
    required this.accent,
    required this.sunColor,
    required this.moonColor,
    required this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 22;
    Offset toward(double azimuth, double r) {
      final a = azimuth * math.pi / 180;
      return centre + Offset(math.sin(a) * r, -math.cos(a) * r);
    }

    void text(String s, Offset at, Color color) {
      final painter = TextPainter(
        text: TextSpan(
          text: s,
          style: label.copyWith(color: color),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
    }

    // The horizon all round, the rings, the ticks every 10°, the points.
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = rim;
    canvas.drawCircle(centre, radius, thin);
    canvas.drawCircle(
      centre,
      radius * 2 / 3,
      thin..color = rim.withValues(alpha: 0.5),
    );
    canvas.drawCircle(centre, radius / 3, thin);
    thin.color = rim;
    for (var d = 0; d < 360; d += 10) {
      canvas.drawLine(
        toward(d.toDouble(), radius),
        toward(d.toDouble(), radius - (d % 90 == 0 ? 10 : 5)),
        thin,
      );
    }
    for (var k = 0; k < 4; k++) {
      text(compass[k], toward(k * 90.0, radius + 12), faint);
    }

    // The day's risings and settings, out to the horizon.
    void ray(double? azimuth, Color color, {bool dashed = false}) {
      if (azimuth == null) return;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      if (!dashed) {
        canvas.drawLine(centre, toward(azimuth, radius), paint);
      } else {
        for (var r = 0.0; r < radius; r += 10) {
          canvas.drawLine(
            toward(azimuth, r),
            toward(azimuth, math.min(r + 5, radius)),
            paint,
          );
        }
      }
      canvas.drawCircle(toward(azimuth, radius), 3.5, Paint()..color = color);
    }

    ray(sunDay.riseAzimuth, sunColor);
    ray(sunDay.setAzimuth, sunColor.withValues(alpha: 0.6));
    ray(moonDay.riseAzimuth, moonColor, dashed: true);
    ray(moonDay.setAzimuth, moonColor.withValues(alpha: 0.6), dashed: true);

    // The shadow of an upright thing at the centre, its length to scale
    // (the inner ring is its own height), cut at the horizon.
    final shadow = SunLight.shadow(sun);
    if (shadow != null) {
      final length = math.min(shadow.length * radius / 3, radius);
      canvas.drawLine(
        centre,
        toward(shadow.bearing, length),
        Paint()
          ..color = ink.withValues(alpha: 0.8)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(centre, 4, Paint()..color = ink);

    // Where they stand now: the nearer the centre, the higher (the
    // centre overhead); on the horizon when down, hollow.
    void now(double altitude, double azimuth, Color color, double size) {
      final r = radius * (90 - math.max(altitude, 0)) / 90;
      final at = toward(azimuth, r);
      if (altitude >= 0) {
        canvas.drawCircle(at, size, Paint()..color = color);
      } else {
        canvas.drawCircle(
          toward(azimuth, radius),
          size - 1,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = color.withValues(alpha: 0.6),
        );
      }
    }

    if (core.altitude >= 0) {
      final at = toward(core.azimuth, radius * (90 - core.altitude) / 90);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = ink.withValues(alpha: 0.7);
      canvas.drawOval(
        Rect.fromCenter(center: at, width: 22, height: 10),
        paint,
      );
      canvas.drawCircle(at, 2, Paint()..color = ink.withValues(alpha: 0.7));
    }
    now(moon.altitude, moon.azimuth, moonColor, 7);
    now(sun.altitude, sun.azimuth, sunColor, 9);
  }

  @override
  bool shouldRepaint(_PlanPainter old) =>
      old.sun.azimuth != sun.azimuth ||
      old.sun.altitude != sun.altitude ||
      old.moon.azimuth != moon.azimuth ||
      old.bearing != bearing ||
      !identical(old.sunDay, sunDay) ||
      old.ink != ink;
}

/// The day's light, midnight to midnight, band by band: night, blue,
/// golden, day. Touching or drawing along it moves the moment.
class LightStrip extends StatelessWidget {
  final List<SkyPosition> sunPath;

  /// Each sample's distance from the wall clock, on a day the clocks
  /// change ([SkyDayPaths.shift]).
  final List<int> shift;
  final int minute;
  final ValueChanged<int> onMove;

  const LightStrip({
    super.key,
    required this.sunPath,
    this.shift = const [],
    required this.minute,
    required this.onMove,
  });

  static const height = 40.0;

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          void move(Offset position) =>
              onMove((position.dx / width * 1440).round());
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => move(details.localPosition),
            onHorizontalDragUpdate: (details) => move(details.localPosition),
            child: CustomPaint(
              size: Size(width, height),
              painter: _StripPainter(
                sunPath: sunPath,
                shift: shift,
                minute: minute,
                night: colors.surfaceRaised,
                blue: lightBlueColor,
                golden: lightGoldenColor,
                day: colors.textSecondary.withValues(alpha: 0.3),
                ink: colors.textPrimary,
                faint: colors.textFaint,
                label: theme.type.caption,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StripPainter extends CustomPainter {
  final List<SkyPosition> sunPath;
  final List<int> shift;
  final int minute;
  final Color night, blue, golden, day, ink, faint;
  final TextStyle label;

  _StripPainter({
    required this.sunPath,
    required this.shift,
    required this.minute,
    required this.night,
    required this.blue,
    required this.golden,
    required this.day,
    required this.ink,
    required this.faint,
    required this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const bar = 24.0;
    final rect = Offset.zero & Size(size.width, bar);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)));
    // Every minute's band, from the sun's height every ten minutes.
    final colors = {
      LightBand.night: night,
      LightBand.blue: blue,
      LightBand.golden: golden,
      LightBand.day: day,
    };
    double heightAt(int m) {
      final i = m ~/ 10;
      if (i >= sunPath.length - 1) return sunPath.last.trueAltitude;
      final f = (m % 10) / 10;
      return sunPath[i].trueAltitude * (1 - f) +
          sunPath[i + 1].trueAltitude * f;
    }

    // Where the day's minute [m] stands by the wall clock: on a day the
    // clocks change, the hour before the change is moved to where the
    // clock had it, and a spring day shows the hour that never was as a
    // gap.
    double xOf(int m) {
      final i = (m ~/ 10).clamp(0, shift.isEmpty ? 0 : shift.length - 1);
      final at = m + (shift.isEmpty ? 0 : shift[i]);
      return (at / 1440).clamp(0.0, 1.0) * size.width;
    }

    var from = 0;
    var band = LightBand.of(heightAt(0));
    for (var m = 1; m <= 1440; m++) {
      final here = m == 1440 ? null : LightBand.of(heightAt(m));
      if (here != band) {
        canvas.drawRect(
          Rect.fromLTRB(xOf(from), 0, xOf(m), bar),
          Paint()..color = colors[band]!,
        );
        from = m;
        if (here != null) band = here;
      }
    }
    canvas.restore();

    // The moment.
    final x = minute / 1440 * size.width;
    canvas.drawLine(
      Offset(x, -2),
      Offset(x, bar + 2),
      Paint()
        ..color = ink
        ..strokeWidth = 2,
    );

    // The hours under it.
    for (var h = 0; h <= 24; h += 6) {
      final painter = TextPainter(
        text: TextSpan(
          text: h.toString().padLeft(2, '0'),
          style: label.copyWith(color: faint),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final px = (h / 24 * size.width - painter.width / 2).clamp(
        0.0,
        size.width - painter.width,
      );
      painter.paint(canvas, Offset(px, bar + 2));
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      old.minute != minute ||
      !identical(old.sunPath, sunPath) ||
      old.night != night;
}
