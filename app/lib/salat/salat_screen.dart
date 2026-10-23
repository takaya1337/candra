import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import '../date_picker.dart';
import '../house.dart';
import '../local_clock.dart';
import '../panel_tabs.dart';
import '../parts.dart';
import '../place_editor.dart';
import '../routes.dart';
import '../sky_place.dart';
import '../strings.dart';
import '../appearance.dart';
import 'salat_choice.dart';

/// Opens the prayer times of [date].
Future<void> pushSalat(BuildContext context, {required CivilDate date}) =>
    Navigator.of(context)
        .push(fadeRoute<void>(context, (context) => SalatScreen(date: date)));

/// The colour of each time on the dial: the blue of dawn, the pale gold
/// of the forenoon, the full gold of noon, the orange of the afternoon,
/// the red of sunset and the violet of night.
Map<Salat, Color> get salatColors => Legible.map(_salatColors);

const _salatColors = <Salat, Color>{
  Salat.subuh: Color(0xFF6C8FD8),
  Salat.duha: Color(0xFFD8CB8C),
  Salat.zuhur: Color(0xFFE8B04A),
  Salat.asar: Color(0xFFD98A4E),
  Salat.magrib: Color(0xFFD0605E),
  Salat.isya: Color(0xFF8A72C8),
};

/// The times on the dial that hold a stretch of the day, each until the
/// next: the five, and Duha in the forenoon between Terbit and Zuhur.
const _windows = [
  Salat.subuh,
  Salat.duha,
  Salat.zuhur,
  Salat.asar,
  Salat.magrib,
  Salat.isya,
];

/// Where each stretch ends.
const _endOf = {
  Salat.subuh: Salat.terbit,
  Salat.duha: Salat.zuhur,
  Salat.zuhur: Salat.asar,
  Salat.asar: Salat.magrib,
  Salat.magrib: Salat.isya,
  Salat.isya: Salat.subuh,
};

/// What the lower panel shows.
enum _Panel { times, method, date, place }

/// The prayer times of a day, on a clock of twenty-four hours.
///
///  * Top bar: the name of the screen, the day and the place.
///  * Main body: the day as a dial, midnight at the top and noon at the
///    bottom, each prayer's time an arc from its beginning to the next;
///    now, if the day is today, as a hand. In the hub, the time chosen.
///  * Lower panel: every time of the day, what the one chosen is, and how
///    they are reckoned; or the place.
///  * Bottom bar: back.
class SalatScreen extends StatefulWidget {
  final CivilDate date;

  /// The clock the day is read by; the phone's own on that date unless
  /// given.
  final Duration? utcOffset;

  const SalatScreen({super.key, required this.date, this.utcOffset});

  @override
  State<SalatScreen> createState() => _SalatScreenState();
}

class _SalatScreenState extends State<SalatScreen> {
  late CivilDate _date = widget.date;

  late _Panel _panel = SkyPlace.current.value == null
      ? _Panel.place
      : _Panel.times;
  Salat? _chosen;
  Timer? _tick;
  int _minute = _minuteNow();

  // Counts the jumps made from outside the wheels, so they are set
  // afresh then.
  int _jump = 0;

  // Worked out once for each place, day and way of reckoning.
  ({double latitude, double longitude})? _for;
  String? _forKey;
  SalatTimes? _times;

  // The convention the place's times are reckoned by: the ministry's in
  // Indonesia; elsewhere the one chosen, null until then.
  SalatMethod? _method;
  bool get _indonesian => _method == SalatMethod.kemenag;

  SalatTimes _work(
    CivilDate date,
    ({double latitude, double longitude}) place,
    SalatMethod method,
  ) {
    final offset = _offsetOn(date);
    final times = SalatTimes.of(
      date,
      latitude: place.latitude,
      longitude: place.longitude,
      utcOffset: offset,
      method: method,
      madhab: SalatChoice.madhab.value,
      highLatitude: SalatChoice.highLatitude.value,
    );
    if (widget.utcOffset != null) return times;
    // On a day the clocks change, a time before the change by the clock
    // that then stood.
    final midnight = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).subtract(offset);
    return times.shifted(
      (m) =>
          m +
          LocalClock.shift(
            midnight.add(Duration(minutes: m)),
            date,
            widget.utcOffset,
          ),
    );
  }

  Duration _offsetOn(CivilDate date) =>
      LocalClock.dayOffset(date, widget.utcOffset);

  static CivilDate _today() {
    final now = DateTime.now();
    return CivilDate(now.year, now.month, now.day);
  }

  bool get _isToday => _date == _today();

  /// Now, if the day shown is today.
  int? get _now => _isToday ? _minute : null;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      final now = _minuteNow();
      if (now != _minute && mounted) setState(() => _minute = now);
    });
  }

  void _setDate(CivilDate date) {
    if (date == _date) return;
    setState(() {
      _date = date;
      _chosen = null;
    });
  }

  void _backToToday() {
    HapticFeedback.selectionClick();
    setState(() {
      _date = _today();
      _minute = _minuteNow();
      _chosen = null;
      _jump++;
    });
  }

  static int _minuteNow() {
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  // The day after's times, for what comes after tonight's Isya.
  SalatTimes? _tomorrowTimes;
  SalatTimes? _tomorrow() {
    final place = _for;
    final method = _method;
    if (place == null || method == null) return null;
    return _tomorrowTimes ??= _work(_date.addDays(1), place, method);
  }

  SalatTimes? _timesFor(({double latitude, double longitude})? place) {
    if (place == null) return null;
    final method = _method = SalatChoice.methodAt(place);
    if (method == null) return null;
    final key =
        '${_date.dayNumber} $method ${SalatChoice.madhab.value} '
        '${SalatChoice.highLatitude.value}';
    if (place != _for || key != _forKey) {
      _for = place;
      _forKey = key;
      _tomorrowTimes = null;
      _times = _work(_date, place, method);
    }
    return _times;
  }

  /// The stretch [minute] falls in, or null where it falls in none: just
  /// after sunrise, before Duha. Before Subuh it is still the night's
  /// Isya.
  static Salat? windowAt(SalatTimes times, int minute) {
    for (final salat in _windows) {
      final start = times[salat];
      final end = times[_endOf[salat]!];
      if (start == null || end == null) continue;
      final inside = end > start
          ? minute >= start && minute < end
          : minute >= start || minute < end;
      if (inside) return salat;
    }
    return null;
  }

  void _choose(Salat salat) {
    if (salat == _chosen) return;
    HapticFeedback.selectionClick();
    setState(() => _chosen = salat);
  }

  static String _clock(int? minute) {
    if (minute == null) return '—';
    final m = minute % 1440;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:'
        '${(m % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final strings = Strings.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([SkyPlace.current, SalatChoice.all]),
      builder: (context, _) {
        final place = SkyPlace.current.value;
        final times = _timesFor(place);
        final nowIn = times == null || _now == null
            ? null
            : windowAt(times, _now!);
        final chosen = _chosen ?? nowIn ?? Salat.subuh;

        return ColoredBox(
          color: colors.background,
          child: SafeArea(
            child: Recentre(
              onToday: _backToToday,
              atToday: _isToday,
              child: FourParts(
                top: TopBar(
                  key: const ValueKey('salat-top-bar'),
                  leading: TopBarTitle(label: strings.salatTitle),
                  subtitle: place == null
                      ? strings.gregorian(_date)
                      : '${strings.gregorian(_date)} · '
                            '${SkyPlace.label(place)}',
                ),
                body: times == null
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(spacing.lg),
                          child: Text(
                            place == null
                                ? strings.salatAskPlace
                                : strings.salatChooseMethod,
                            key: ValueKey(
                              place == null
                                  ? 'salat-ask-place'
                                  : 'salat-ask-method',
                            ),
                            textAlign: TextAlign.center,
                            style: theme.type.body.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : _body(theme, strings, times, chosen, nowIn),
                panel: _panelView(theme, strings, place, times, chosen),
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
    SalatTimes times,
    Salat chosen,
    Salat? nowIn,
  ) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    final end = _endOf[chosen];
    final now = _now;

    // The next time to come, and how far off it is: after Isya, the
    // next morning's Imsak.
    Salat? next;
    int? wait;
    if (now != null) {
      for (final salat in Salat.values) {
        final at = times[salat];
        if (at != null && at > now) {
          next = salat;
          wait = at - now;
          break;
        }
      }
      if (next == null) {
        // Where there is no Imsak (outside Indonesia), Subuh.
        final first = _tomorrow()?[Salat.imsak] == null
            ? Salat.subuh
            : Salat.imsak;
        final tomorrow = _tomorrow()?[first];
        if (tomorrow != null) {
          next = first;
          wait = 1440 - now + tomorrow;
        }
      }
    }

    return SizedBox.expand(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: SalatDial(
              key: const ValueKey('salat-dial'),
              times: times,
              chosen: chosen,
              now: now,
              onChoose: _choose,
            ),
          ),
          IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (nowIn == chosen)
                  Text(
                    strings.salatNow.toUpperCase(),
                    style: theme.type.caption.copyWith(
                      color: colors.accent,
                      letterSpacing: 1.2,
                    ),
                  ),
                Text(
                  strings
                      .salatName(chosen, indonesian: _indonesian)
                      .toUpperCase(),
                  key: const ValueKey('salat-name'),
                  style: theme.type.title.copyWith(
                    color: colors.textPrimary,
                    letterSpacing: 3,
                  ),
                ),
                Text(
                  end == null
                      ? _clock(times[chosen])
                      : '${_clock(times[chosen])} – ${_clock(times[end])}',
                  key: const ValueKey('salat-span'),
                  style: theme.type.body.copyWith(
                    color: salatColors[chosen] ?? colors.textSecondary,
                  ),
                ),
                if (next != null && wait != null) ...[
                  SizedBox(height: spacing.sm),
                  Text(
                    '${strings.salatNext}: '
                    '${strings.salatName(next, indonesian: _indonesian)} · '
                    '${strings.salatIn(wait)}',
                    key: const ValueKey('salat-next'),
                    style: theme.type.caption.copyWith(color: colors.textFaint),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelView(
    SmThemeData theme,
    Strings strings,
    ({double latitude, double longitude})? place,
    SalatTimes? times,
    Salat chosen,
  ) {
    final spacing = theme.spacing;
    final labels = {
      _Panel.times: strings.salatTimes,
      _Panel.method: strings.salatMethodTab,
      _Panel.date: strings.skyDate,
      _Panel.place: strings.skyPlaceTab,
    };
    final abroad =
        place != null && !Indonesia.has(place.latitude, place.longitude);
    final panels = [
      _Panel.times,
      if (abroad) _Panel.method,
      _Panel.date,
      _Panel.place,
    ];
    // With no place, the place; with a place abroad and no convention yet,
    // the conventions.
    final shown = place == null && _panel != _Panel.date
        ? _Panel.place
        : !panels.contains(_panel)
        ? _Panel.times
        : _panel == _Panel.times && times == null && abroad
        ? _Panel.method
        : _panel;

    Widget content() => switch (shown) {
      _Panel.date => Center(
        child: DatePicker(
          key: ValueKey('salat-date-$_jump'),
          date: _date,
          strings: strings,
          onChanged: _setDate,
        ),
      ),
      _Panel.method => _methodList(theme, strings, place!),
      _Panel.place => PlaceEditor(strings: strings),
      _Panel.times =>
        times == null
            ? PlaceEditor(strings: strings)
            : _timesList(theme, strings, times, chosen),
    };

    return Column(
      children: [
        SizedBox(height: spacing.sm),
        PanelTabs(
          listKey: const ValueKey('salat-panels'),
          tabs: panels,
          shown: shown,
          label: (panel) => labels[panel]!,
          keyOf: (panel) => 'salat-panel-${panel.name}',
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

  // The conventions to choose from outside Indonesia, the likeliest for
  // the place first; under them the madhab for Asar and the rule far north and
  // south, each changed by a touch.
  Widget _methodList(
    SmThemeData theme,
    Strings strings,
    ({double latitude, double longitude}) place,
  ) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    final chosen = SalatChoice.method.value;

    Widget row({
      required Key key,
      required String title,
      required String detail,
      required bool lit,
      required VoidCallback onTap,
    }) => GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.xs + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.type.body.copyWith(
                color: lit ? colors.accent : colors.textPrimary,
              ),
            ),
            Text(
              detail,
              style: theme.type.caption.copyWith(color: colors.textFaint),
            ),
          ],
        ),
      ),
    );

    const rules = [
      null,
      HighLatitudeRule.middleOfTheNight,
      HighLatitudeRule.seventhOfTheNight,
      HighLatitudeRule.twilightAngle,
    ];
    return ListView(
      key: const ValueKey('salat-methods'),
      padding: EdgeInsets.fromLTRB(
        spacing.md,
        spacing.sm,
        spacing.md,
        spacing.md,
      ),
      children: [
        Text(
          strings.salatMethodsHint,
          style: theme.type.label.copyWith(
            color: colors.textSecondary,
            height: 1.4,
          ),
        ),
        SizedBox(height: spacing.sm),
        for (final method in SalatMethod.suggestedFor(
          place.latitude,
          place.longitude,
        ))
          row(
            key: ValueKey('salat-method-${method.name}'),
            title: strings.salatMethodName(method),
            detail: strings.salatMethodAngles(method),
            lit: method == chosen,
            onTap: () {
              SalatChoice.method.value = method;
              setState(() => _panel = _Panel.times);
            },
          ),
        SizedBox(height: spacing.md),
        row(
          key: const ValueKey('salat-madhab'),
          title: strings.salatAsrShadow,
          detail: strings.salatMadhab(SalatChoice.madhab.value),
          lit: false,
          onTap: () => SalatChoice.madhab.value =
              SalatChoice.madhab.value == Madhab.standard
              ? Madhab.hanafi
              : Madhab.standard,
        ),
        row(
          key: const ValueKey('salat-high-latitude'),
          title: strings.salatHighLatitude,
          detail: strings.salatHighLatitudeRule(
            SalatChoice.highLatitude.value,
            place.latitude,
          ),
          lit: false,
          onTap: () => SalatChoice.highLatitude.value =
              rules[(rules.indexOf(SalatChoice.highLatitude.value) + 1) %
                  rules.length],
        ),
      ],
    );
  }

  Widget _timesList(
    SmThemeData theme,
    Strings strings,
    SalatTimes times,
    Salat chosen,
  ) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    return SingleChildScrollView(
      key: const ValueKey('salat-times'),
      padding: EdgeInsets.fromLTRB(spacing.md, spacing.sm, spacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final salat in Salat.values)
            // Imsak is Indonesia's alone.
            if (_indonesian || times[salat] != null)
              GestureDetector(
                key: ValueKey('salat-row-${salat.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _choose(salat),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: spacing.xs),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: salatColors[salat] ?? colors.textFaint,
                        ),
                      ),
                      SizedBox(width: spacing.sm),
                      Expanded(
                        child: Text(
                          strings.salatName(salat, indonesian: _indonesian),
                          style: theme.type.body.copyWith(
                            color: salat == chosen
                                ? colors.accent
                                : (salat.prayer
                                      ? colors.textPrimary
                                      : colors.textSecondary),
                          ),
                        ),
                      ),
                      Text(
                        _clock(times[salat]),
                        key: ValueKey('salat-time-${salat.name}'),
                        style: theme.type.body.copyWith(
                          color: salat == chosen
                              ? colors.accent
                              : colors.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          SizedBox(height: spacing.sm),
          Text(
            _indonesian
                ? strings.salatRule(chosen)
                : strings.salatRuleElsewhere(
                    chosen,
                    _method!,
                    SalatChoice.madhab.value,
                  ),
            key: const ValueKey('salat-rule'),
            style: theme.type.label.copyWith(
              color: colors.textPrimary,
              height: 1.4,
            ),
          ),
          SizedBox(height: spacing.sm),
          Text(
            _indonesian
                ? strings.salatMethod
                : strings.salatMethodElsewhere(_method!),
            style: theme.type.caption.copyWith(
              color: colors.textFaint,
              height: 1.45,
            ),
          ),
          SizedBox(height: spacing.sm),
        ],
      ),
    );
  }
}

/// The day as a dial of twenty-four hours, midnight at the top and noon
/// at the bottom, turning clockwise: each prayer's time an arc from its
/// beginning to the next, in its colour, and Imsak and Terbit as marks.
/// The daylight is a faint band inside the hours. Touching an arc
/// chooses it.
class SalatDial extends StatelessWidget {
  final SalatTimes times;
  final Salat chosen;
  final int? now;
  final ValueChanged<Salat> onChoose;

  const SalatDial({
    super.key,
    required this.times,
    required this.chosen,
    required this.onChoose,
    this.now,
  });

  /// The minute of the day under [position] in a dial of [size], or null
  /// in the hub or outside.
  static int? minuteAt(Offset position, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final offset = position - centre;
    final distance = offset.distance;
    if (distance < radius * 0.58 || distance > radius * 1.04) return null;
    var turn = (math.atan2(offset.dy, offset.dx) + math.pi / 2) / (2 * math.pi);
    turn -= turn.floorToDouble();
    return (turn * 1440).floor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final minute = minuteAt(details.localPosition, constraints.biggest);
          if (minute == null) return;
          final salat = _SalatScreenState.windowAt(times, minute);
          if (salat != null) onChoose(salat);
        },
        child: CustomPaint(
          painter: _DialPainter(
            times: times,
            chosen: chosen,
            now: now,
            ink: theme.colors.textPrimary,
            faint: theme.colors.textFaint,
            numeral: theme.type.caption,
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final SalatTimes times;
  final Salat chosen;
  final int? now;
  final Color ink;
  final Color faint;
  final TextStyle numeral;

  const _DialPainter({
    required this.times,
    required this.chosen,
    required this.now,
    required this.ink,
    required this.faint,
    required this.numeral,
  });

  static double _angle(num minute) => minute / 1440 * 2 * math.pi - math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rim = radius * 0.86;
    final ring = Rect.fromCircle(center: centre, radius: rim);
    Offset at(num minute, double r) =>
        centre + Offset(math.cos(_angle(minute)), math.sin(_angle(minute))) * r;

    // Daylight, Terbit to Magrib, as a faint band inside the hours.
    final rise = times[Salat.terbit];
    final set = times[Salat.magrib];
    if (rise != null && set != null) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius * 0.62),
        _angle(rise),
        _angle(set) - _angle(rise),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.03
          ..color = salatColors[Salat.zuhur]!.withValues(alpha: 0.35),
      );
    }

    // The stretches, each from its time to the next.
    final gap = 3 / rim;
    for (final salat in _windows) {
      final start = times[salat];
      final end = times[_endOf[salat]!];
      if (start == null || end == null) continue;
      final lit = salat == chosen;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = radius * (lit ? 0.16 : 0.09)
        ..color = salatColors[salat]!.withValues(
          alpha: lit ? 1 : (salat.prayer ? 0.5 : 0.25),
        );
      // Isya runs over midnight to the next Subuh: drawn as the night's
      // two ends, from Isya to midnight and from midnight to Subuh.
      final spans = end > start ? [(start, end)] : [(start, 1440), (0, end)];
      for (final (from, to) in spans) {
        final sweep = (to - from) / 1440 * 2 * math.pi;
        final trimFrom = from == 0 ? 0.0 : gap / 2;
        final trimTo = to == 1440 ? 0.0 : gap / 2;
        if (sweep - trimFrom - trimTo <= 0) continue;
        canvas.drawArc(
          ring,
          _angle(from) + trimFrom,
          sweep - trimFrom - trimTo,
          false,
          paint,
        );
      }
    }

    // Imsak and Terbit, which begin no stretch of their own: a mark
    // across the rim.
    for (final salat in const [Salat.imsak, Salat.terbit]) {
      final minute = times[salat];
      if (minute == null) continue;
      canvas.drawLine(
        at(minute, rim - radius * 0.09),
        at(minute, rim + radius * 0.09),
        Paint()
          ..strokeWidth = 1.5
          ..color = salat == chosen ? ink : faint,
      );
    }

    // The hours: a tick for each, and every third numbered.
    for (var hour = 0; hour < 24; hour++) {
      final major = hour % 3 == 0;
      canvas.drawLine(
        at(hour * 60, radius * 0.97),
        at(hour * 60, radius * (major ? 1.02 : 0.995)),
        Paint()
          ..strokeWidth = major ? 1.5 : 1
          ..color = faint,
      );
      if (!major) continue;
      final text = TextPainter(
        text: TextSpan(
          text: hour.toString().padLeft(2, '0'),
          style: numeral.copyWith(color: faint),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        at(hour * 60, radius * 0.70) - Offset(text.width / 2, text.height / 2),
      );
    }

    // Now: a hand from the hours to the rim.
    final minute = now;
    if (minute != null) {
      canvas
        ..drawLine(
          at(minute, radius * 0.76),
          at(minute, radius * 1.0),
          Paint()
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..color = ink,
        )
        ..drawCircle(
          at(minute, radius * 1.0),
          radius * 0.022,
          Paint()..color = ink,
        );
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.times != times ||
      old.chosen != chosen ||
      old.now != now ||
      old.ink != ink ||
      old.faint != faint ||
      old.numeral != numeral;
}
