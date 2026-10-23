import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import '../panel_tabs.dart';
import '../date_picker.dart';
import '../glyph_button.dart';
import '../house.dart';
import '../local_clock.dart';
import '../night_dome.dart';
import '../parts.dart';
import '../place_editor.dart';
import '../routes.dart';
import '../sky/sky_screen.dart';
import '../sky_place.dart';
import '../strings.dart';
import '../time_picker.dart';
import '../planets/planet_look.dart';
import 'javanese_stars.dart';
import 'star_catalog.dart';

/// Opens the star map of [date].
Future<void> pushStars(BuildContext context, {required CivilDate date}) =>
    Navigator.of(context)
        .push(fadeRoute<void>(context, (context) => StarScreen(date: date)));

/// Opens Lintang Jawa, the Javanese sky, of [date].
Future<void> pushLintang(BuildContext context, {required CivilDate date}) =>
    Navigator.of(context).push(
      fadeRoute<void>(
        context,
        (context) => StarScreen(date: date, javanese: true),
      ),
    );

/// What the lower panel shows.
enum _Panel {
  lintang,
  mangsa,
  star,
  bright,
  search,
  constellations,
  galaxies,
  date,
  time,
  place,
}

/// The sky of a place at a moment, as it truly stands: every star the eye
/// can see, the constellations' figures, the sun and the moon.
///
///  * Top bar: the name of the screen, the clock time, the day and the
///    place.
///  * Main body: the same dome as the ephemeris (the horizon its rim, the
///    zenith its centre, north at the top, east on the right), with the
///    stars on it, larger the brighter, the brightest in their colour; the
///    constellations' figures and the chief ones' names; the brightest
///    stars named. Under it the day's strip, to move through the night.
///  * Lower panel: the star touched, the date, the time, the place.
///  * Bottom bar: back to the calendar, and back to now.
class StarScreen extends StatefulWidget {
  final CivilDate date;

  /// For tests: the zone's offset, else the phone's.
  final Duration? utcOffset;

  /// Lintang Jawa: the Javanese sky, its figures and what they mark.
  final bool javanese;

  /// The minute after midnight to open at, on a day not today; nine in
  /// the evening unless given.
  final int? minute;

  const StarScreen({
    super.key,
    required this.date,
    this.utcOffset,
    this.javanese = false,
    this.minute,
  });

  @override
  State<StarScreen> createState() => _StarScreenState();
}

class _StarScreenState extends State<StarScreen>
    with SingleTickerProviderStateMixin {
  late CivilDate _date = widget.date;
  late bool _following = widget.date == _today();

  // The moment, minutes after local midnight: now while it follows the
  // clock; nine in the evening on any other day, when there are stars.
  late int _minute = _following ? _minuteNow() : widget.minute ?? 21 * 60;
  Timer? _tick;
  int _jump = 0;

  late _Panel _panel = SkyPlace.current.value == null
      ? _Panel.place
      : (widget.javanese ? _Panel.lintang : _Panel.star);

  // The panels this sky has, in order.
  late final List<_Panel> _panels = widget.javanese
      ? const [
          _Panel.lintang,
          _Panel.mangsa,
          _Panel.star,
          _Panel.date,
          _Panel.time,
          _Panel.place,
        ]
      : const [
          _Panel.star,
          _Panel.bright,
          _Panel.constellations,
          _Panel.galaxies,
          _Panel.search,
          _Panel.date,
          _Panel.time,
          _Panel.place,
        ];

  // The Javanese figure chosen from the list, drawn boldest.
  String? _figure;

  // The constellation (three letters) and the galaxy chosen from their
  // lists.
  String? _constellation;
  int? _galaxy;
  List<Galaxy> _galaxies = const [];

  // How near the sky is drawn, and the glide to a new view.
  final _view = ValueNotifier(StarView.whole);
  late final _glide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  StarView _glideFrom = StarView.whole;
  StarView _glideTo = StarView.whole;

  // Brings the point at [altitude], [azimuth] to the centre of the dome,
  // at least [nearest] times nearer: a glide, not a jump.
  void _centreOn(double altitude, double azimuth, {double nearest = 2.5}) {
    final p = starProject(Offset.zero, 1, altitude, azimuth);
    _glideFrom = _view.value;
    _glideTo = StarView(math.max(_view.value.zoom, nearest), p).kept;
    _glide.forward(from: 0);
  }

  // The whole dome again, gliding there from wherever the view is.
  void _wholeAgain() {
    if (_view.value == StarView.whole ||
        (_glide.isAnimating && _glideTo == StarView.whole)) {
      return;
    }
    _glideFrom = _view.value;
    _glideTo = StarView.whole;
    _glide.forward(from: 0);
  }

  void _setView(StarView view) {
    _glide.stop();
    _view.value = view;
  }

  // Waluku at dawn this year at this place, against the mangsa: worked out
  // away from the screen, once a year and place.
  String? _walukuFor;
  WalukuYear? _waluku;
  int? _selected;

  // The planet touched, read in the star's place; and where the seven
  // stand at the moment, worked out with the stars.
  Body? _planet;
  List<PlanetAt> _planets = const [];

  // A name being typed in the bar, to find a star by.
  bool _typing = false;

  // A bright star opened from the list: its reading shown in the list's
  // place, with back to the list.
  bool _brightOpen = false;
  final _query = TextEditingController();
  final _queryFocus = FocusNode();

  StarCatalog? _catalog;

  // Where every star stands at the moment, worked out when the moment or
  // the place changes and only then.
  String? _placedFor;
  Float32List _altitude = Float32List(0);
  Float32List _azimuth = Float32List(0);
  StarSky? _sky;

  ({double latitude, double longitude})? _pathsPlace;
  CivilDate? _pathsDate;
  SkyDayPaths? _paths;

  Duration get _offset => LocalClock.dayOffset(_date, widget.utcOffset);

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
    StarCatalog.load().then((catalog) {
      if (mounted) setState(() => _catalog = catalog);
    });
    if (!widget.javanese) {
      Galaxy.load().then((galaxies) {
        if (mounted) setState(() => _galaxies = galaxies);
      });
    }
    _glide.addListener(() {
      final t = Curves.easeOutCubic.transform(_glide.value);
      _view.value = StarView.lerp(_glideFrom, _glideTo, t);
    });
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
    _glide.dispose();
    _view.dispose();
    _query.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  void _startTyping() {
    setState(() => _typing = true);
    _queryFocus.requestFocus();
  }

  void _stopTyping() {
    _queryFocus.unfocus();
    setState(() => _typing = false);
  }

  DateTime get _instant => LocalClock.instant(_date, _minute, widget.utcOffset);

  void _place(StarCatalog catalog, ({double latitude, double longitude}) at) {
    final key = '${_date.dayNumber} $_minute ${at.latitude} ${at.longitude}';
    if (key == _placedFor) return;
    _placedFor = key;
    final sky = StarSky.at(
      _instant,
      latitude: at.latitude,
      longitude: at.longitude,
    );
    final n = catalog.length;
    final altitude = Float32List(n);
    final azimuth = Float32List(n);
    for (var i = 0; i < n; i++) {
      final p = sky.place(catalog.rightAscension[i], catalog.declination[i]);
      altitude[i] = p.altitude;
      azimuth[i] = p.azimuth;
    }
    _sky = sky;
    _altitude = altitude;
    _azimuth = azimuth;
    _planets = PlanetLook.at(
      _instant,
      latitude: at.latitude,
      longitude: at.longitude,
    );
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

  void _moveTo(int minute, {bool fromWheels = false}) {
    // The strip shows what is up from here as the night turns: the whole
    // sky first, the view put back.
    if (!fromWheels) _wholeAgain();
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
    _wholeAgain();
    setState(() {
      _date = _today();
      _minute = _minuteNow();
      _following = true;
      _jump++;
    });
  }

  void _choose(_Panel panel) {
    if (panel == _panel && !(panel == _Panel.search && !_typing)) return;
    HapticFeedback.selectionClick();
    // Moving off the search puts the keyboard away, keeping the words.
    if (_typing && panel != _Panel.search) _stopTyping();
    setState(() {
      _panel = panel;
      _brightOpen = false;
    });
    if (panel == _Panel.search) _startTyping();
  }

  void _select(int? star) {
    HapticFeedback.selectionClick();
    if (_typing) _stopTyping();
    setState(() {
      _selected = star;
      _planet = null;
      _panel = _Panel.star;
      _brightOpen = false;
    });
  }

  // A planet touched on the dome: read where a star would be.
  void _selectPlanet(Body planet) {
    HapticFeedback.selectionClick();
    if (_typing) _stopTyping();
    setState(() {
      _planet = planet;
      _selected = null;
      _panel = _Panel.star;
      _brightOpen = false;
    });
  }

  // The planets shown or not, on every tab but the search.
  void _togglePlanets() {
    HapticFeedback.selectionClick();
    setState(() {
      PlanetLook.shown.value = !PlanetLook.shown.value;
      if (!PlanetLook.shown.value) _planet = null;
    });
  }

  // A star chosen from the bright stars: read where the list was.
  void _openBright(int star) {
    HapticFeedback.selectionClick();
    setState(() {
      _selected = star;
      _brightOpen = true;
    });
    _centreOnStar(star);
  }

  void _centreOnStar(int star) {
    if (_altitude.length > star) _centreOn(_altitude[star], _azimuth[star]);
  }

  // A star found by name: read, and brought to the centre.
  void _pickFound(int star) {
    _select(star);
    _centreOnStar(star);
  }

  void _closeBright() {
    HapticFeedback.selectionClick();
    setState(() => _brightOpen = false);
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final strings = Strings.of(context);

    return ValueListenableBuilder(
      valueListenable: SkyPlace.current,
      builder: (context, place, _) {
        final catalog = _catalog;
        if (catalog != null && place != null) _place(catalog, place);
        final paths = place == null ? null : _pathsFor(place);
        final sun = place == null
            ? null
            : SkyNow.sun(
                _instant,
                latitude: place.latitude,
                longitude: place.longitude,
              );
        final moon = place == null
            ? null
            : SkyNow.moon(
                _instant,
                latitude: place.latitude,
                longitude: place.longitude,
              );

        final Widget body;
        if (place == null) {
          body = Center(
            child: Padding(
              padding: EdgeInsets.all(spacing.lg),
              child: Text(
                strings.skyAskPlace,
                key: const ValueKey('stars-ask-place'),
                textAlign: TextAlign.center,
                style: theme.type.body.copyWith(color: colors.textSecondary),
              ),
            ),
          );
        } else if (catalog == null) {
          body = const SizedBox.expand();
        } else {
          body = Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: NightDome(
                        child: StarDome(
                          key: const ValueKey('stars-dome'),
                          catalog: catalog,
                          starSky: _sky!,
                          altitude: _altitude,
                          azimuth: _azimuth,
                          sun: sun!,
                          moon: moon!,
                          selected: _selected,
                          compass: strings.compassFour,
                          onSelect: _select,
                          planets: PlanetLook.shown.value ? _planets : const [],
                          planet: _planet,
                          onPlanet: _selectPlanet,
                          planetName: (p) => _planetName(p, strings),
                          javanese: widget.javanese,
                          figure: _figure,
                          view: _view,
                          onView: _setView,
                          constellation: _constellation,
                          galaxies: _galaxies,
                          galaxy: _galaxy,
                        ),
                      ),
                    ),
                    // The planets, shown while lit: at the body's bottom
                    // right, in the corner the round sky leaves.
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GlyphButton(
                        key: const ValueKey('stars-planets'),
                        glyph: Glyph.planets,
                        square: true,
                        lit: PlanetLook.shown.value,
                        onTap: _togglePlanets,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing.sm),
              DayStrip(
                key: const ValueKey('stars-strip'),
                paths: paths!,
                minute: _minute,
                onMove: _moveTo,
              ),
            ],
          );
        }

        final reading = _brightOpen && _panel == _Panel.bright;
        return PopScope(
          // Back, by the button or the gesture, closes a bright star's
          // reading before it leaves the map.
          canPop: !reading,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _closeBright();
          },
          child: ColoredBox(
            color: colors.background,
            child: SafeArea(
              child: Recentre(
                onToday: _backToNow,
                atToday: _following,
                child: FourParts(
                  top: TopBar(
                    key: const ValueKey('stars-top-bar'),
                    leading: TopBarTitle(
                      label: widget.javanese
                          ? strings.lintangTitle
                          : strings.starsTitle,
                    ),
                    trailing: Text(
                      '${_two(_minute ~/ 60)}:${_two(_minute % 60)}',
                      key: const ValueKey('stars-clock'),
                      style: theme.type.title.copyWith(
                        color: _following
                            ? colors.accent
                            : colors.textSecondary,
                      ),
                    ),
                    subtitle: place == null
                        ? strings.gregorian(_date)
                        : '${strings.gregorian(_date)} · '
                              '${SkyPlace.label(place)}',
                  ),
                  body: body,
                  panel: _panelView(theme, strings, catalog, place),
                  bar: RoomBar(
                    // While a star is searched for, the field for it.
                    typing: _typing
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
                              child: _queryBar(theme, strings),
                            ),
                          )
                        : null,
                  ),
                ),
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
    StarCatalog? catalog,
    ({double latitude, double longitude})? place,
  ) {
    final spacing = theme.spacing;
    final labels = {
      _Panel.lintang: strings.lintangFigures,
      _Panel.mangsa: strings.lintangMangsa,
      _Panel.star: strings.starsStar,
      _Panel.bright: strings.starsBright,
      _Panel.search: strings.starsSearch,
      _Panel.constellations: strings.starsConstellations,
      _Panel.galaxies: strings.starsGalaxies,
      _Panel.date: strings.skyDate,
      _Panel.time: strings.skyTime,
      _Panel.place: strings.skyPlaceTab,
    };
    final shown = place == null && _panel == _Panel.star
        ? _Panel.place
        : _panel;

    Widget content() {
      switch (shown) {
        case _Panel.lintang:
          return _figureList(theme, strings, catalog);
        case _Panel.mangsa:
          return _mangsaRows(theme, strings, place);
        case _Panel.star:
          return _starRows(theme, strings, catalog);
        case _Panel.bright:
          if (catalog == null) return const SizedBox.shrink();
          return AnimatedSwitcher(
            duration: theme.motion.medium,
            child: _brightOpen
                ? KeyedSubtree(
                    key: const ValueKey('stars-bright-reading'),
                    child: _starRows(theme, strings, catalog),
                  )
                : _starList(
                    theme,
                    strings,
                    catalog,
                    catalog.brightNamed(),
                    'stars-bright',
                    onTap: _openBright,
                  ),
          );
        case _Panel.search:
          return catalog == null
              ? const SizedBox.shrink()
              : ValueListenableBuilder(
                  valueListenable: _query,
                  builder: (context, value, _) => value.text.trim().isEmpty
                      ? Center(
                          // Kept off the panel's edges, as every hint is.
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: theme.spacing.md,
                            ),
                            child: Text(
                              strings.starsSearchHint,
                              key: const ValueKey('stars-search-hint'),
                              textAlign: TextAlign.center,
                              style: theme.type.label.copyWith(
                                color: theme.colors.textFaint,
                              ),
                            ),
                          ),
                        )
                      : _foundList(theme, strings, catalog, value.text),
                );
        case _Panel.constellations:
          return catalog == null
              ? const SizedBox.shrink()
              : _constellationList(theme, strings, catalog);
        case _Panel.galaxies:
          return _galaxyList(theme, strings, catalog);
        case _Panel.date:
          return Center(
            child: DatePicker(
              key: ValueKey('stars-date-$_jump'),
              date: _date,
              strings: strings,
              onChanged: _setDate,
            ),
          );
        case _Panel.time:
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.lg),
            child: TimePicker(
              key: ValueKey('stars-time-$_jump'),
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
          listKey: const ValueKey('stars-panels'),
          tabs: _panels,
          shown: shown,
          label: (panel) => labels[panel]!,
          keyOf: (panel) => 'stars-panel-${panel.name}',
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

  // The Javanese figures: each its names, what they mean, the Western
  // figure it is, what the sources say it marks, how firm the ground is,
  // and whether it is up now. Touching one draws it boldest.
  Widget _figureList(SmThemeData theme, Strings strings, StarCatalog? catalog) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    final en = strings.language == AppLanguage.en;
    bool up(JavaneseFigure f) {
      final patch = f.patch;
      if (patch != null) {
        final sky = _sky;
        return sky != null &&
            sky.place(patch.rightAscension, patch.declination).altitude > 0;
      }
      return catalog != null &&
          f.stars.any((hip) {
            final i = catalog.byHip(hip);
            return i != null && _altitude.length > i && _altitude[i] > 0;
          });
    }

    return ListView(
      key: const ValueKey('lintang-figures'),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.xs,
      ),
      children: [
        for (final f in javaneseFigures)
          GestureDetector(
            key: ValueKey('lintang-${f.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _figure = _figure == f.id ? null : f.id);
            },
            child: Padding(
              padding: EdgeInsets.only(bottom: spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          f.name,
                          style: theme.type.body.copyWith(
                            color: f.id == _figure
                                ? colors.accent
                                : colors.textPrimary,
                          ),
                        ),
                      ),
                      if (f.stars.isNotEmpty ||
                          f.figure != null ||
                          f.patch != null)
                        Text(
                          up(f) ? strings.lintangUp : strings.starsDown,
                          style: theme.type.label.copyWith(
                            color: up(f)
                                ? colors.textSecondary
                                : colors.textFaint,
                          ),
                        )
                      else
                        Text(
                          strings.lintangNotDrawn,
                          style: theme.type.label.copyWith(
                            color: colors.textFaint,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    [
                      f.western,
                      if ((en ? f.meaningEn : f.meaningId).isNotEmpty)
                        en ? f.meaningEn : f.meaningId,
                    ].join(' · '),
                    style: theme.type.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  if (f.aliases.isNotEmpty)
                    Text(
                      strings.lintangAlsoCalled(
                        f.aliases.join(', '),
                        popular: f.aliasGround == Ground.popular,
                      ),
                      style: theme.type.caption.copyWith(
                        color: colors.textFaint,
                      ),
                    ),
                  if ((en ? f.marksEn : f.marksId).isNotEmpty) ...[
                    SizedBox(height: spacing.xs),
                    Text(
                      en ? f.marksEn : f.marksId,
                      style: theme.type.label.copyWith(
                        color: colors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        Text(
          strings.lintangSources,
          style: theme.type.caption.copyWith(
            color: colors.textFaint,
            height: 1.4,
          ),
        ),
        SizedBox(height: spacing.md),
      ],
    );
  }

  // Waluku against the mangsa: when, at this place, it first stands in
  // the east before dawn and last in the west at dawn, beside the days
  // Kasa and Kapitu open, and how the dawn is reckoned.
  Widget _mangsaRows(
    SmThemeData theme,
    Strings strings,
    ({double latitude, double longitude})? place,
  ) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    if (place == null) return const SizedBox.shrink();
    final key = '${_date.year} ${place.latitude} ${place.longitude}';
    if (_walukuFor != key) {
      _walukuFor = key;
      _waluku = null;
      WalukuYear.workApart(
        _date.year,
        place.latitude,
        place.longitude,
        _offset,
      ).then((result) {
        if (mounted && _walukuFor == key) setState(() => _waluku = result);
      });
    }
    final w = _waluku;
    if (w == null) {
      return Center(
        child: Text(
          strings.lintangWorking,
          style: theme.type.label.copyWith(color: colors.textFaint),
        ),
      );
    }
    String day(CivilDate? d) =>
        d == null ? strings.notThatDay : strings.gregorian(d);
    String gap(CivilDate? a, CivilDate b) =>
        a == null ? '' : strings.lintangDaysApart(a.dayNumber - b.dayNumber);
    final rows = <(String, String)>[
      (strings.lintangRises, day(w.rises)),
      (strings.lintangKasaOpens, day(w.kasa)),
      ('', gap(w.rises, w.kasa)),
      (strings.lintangSets, day(w.sets)),
      (strings.lintangKapituOpens, day(w.kapitu)),
      ('', gap(w.sets, w.kapitu)),
    ];
    return SingleChildScrollView(
      key: const ValueKey('lintang-mangsa'),
      padding: EdgeInsets.fromLTRB(
        spacing.md,
        spacing.sm,
        spacing.md,
        spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (label, value) in rows)
            if (value.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: spacing.xs),
                child: Row(
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
                    Text(
                      value,
                      style: theme.type.label.copyWith(
                        color: label.isEmpty
                            ? colors.textSecondary
                            : colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
          SizedBox(height: spacing.sm),
          Text(
            strings.lintangHow,
            style: theme.type.caption.copyWith(
              color: colors.textFaint,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // A row of a list to choose from: the name, a line under it, and how
  // high it stands now (or that it is down). Touched, it is chosen;
  // touched again, let go.
  Widget _pickRow(
    SmThemeData theme,
    Strings strings, {
    required Key key,
    required String name,
    required String detail,
    required double altitude,
    required bool chosen,
    required VoidCallback onTap,
  }) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    final up = altitude >= 0;
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.xs + 2,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.type.body.copyWith(
                      color: chosen ? colors.accent : colors.textPrimary,
                    ),
                  ),
                  Text(
                    detail,
                    style: theme.type.caption.copyWith(color: colors.textFaint),
                  ),
                ],
              ),
            ),
            Text(
              up ? '${altitude.toStringAsFixed(0)}°' : strings.starsDown,
              style: theme.type.label.copyWith(
                color: up ? colors.textSecondary : colors.textFaint,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // What the words find, of every kind: the constellations whose name or
  // letters begin with them or hold them as a word, then the galaxies
  // whose name or designation does (spaces aside: "m31" finds M 31), then
  // the stars. Touched, each is chosen and brought to the centre.
  Widget _foundList(
    SmThemeData theme,
    Strings strings,
    StarCatalog catalog,
    String words,
  ) {
    final q = words.trim().toLowerCase();
    final bare = q.replaceAll(' ', '');
    bool holds(String text) {
      final t = text.toLowerCase();
      return t.startsWith(q) || t.contains(' $q');
    }

    final sky = _sky;
    final figures = [
      for (final f in catalog.figures)
        if (holds(f.name) || f.id.toLowerCase() == q) f,
    ]..sort((a, b) => a.name.compareTo(b.name));
    final galaxies = [
      for (final (k, g) in _galaxies.indexed)
        if (holds(g.name) ||
            g.designations
                .toLowerCase()
                .replaceAll(' ', '')
                .split('·')
                .any((d) => d.startsWith(bare)))
          k,
    ];
    final stars = catalog.find(words, limit: 30);
    final names = {for (final f in catalog.figures) f.id: f.name};
    if (figures.isEmpty && galaxies.isEmpty && stars.isEmpty) {
      return Center(
        child: Text(
          strings.starsNoneFound,
          key: const ValueKey('stars-found-none'),
          style: theme.type.label.copyWith(color: theme.colors.textFaint),
        ),
      );
    }
    return ListView(
      key: const ValueKey('stars-found'),
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      children: [
        for (final f in figures)
          Builder(
            builder: (context) {
              final p = sky?.place(f.labelRightAscension, f.labelDeclination);
              return _pickRow(
                theme,
                strings,
                key: ValueKey('stars-found-con-${f.id}'),
                name: f.name,
                detail: '${strings.starsConstellation} · ${f.id}',
                altitude: p?.altitude ?? -90,
                chosen: f.id == _constellation,
                onTap: () {
                  _stopTyping();
                  setState(() => _constellation = f.id);
                  if (p != null) {
                    _centreOn(p.altitude, p.azimuth, nearest: 1.6);
                  }
                },
              );
            },
          ),
        for (final k in galaxies)
          Builder(
            builder: (context) {
              final g = _galaxies[k];
              final p = sky?.place(g.rightAscension, g.declination);
              return _pickRow(
                theme,
                strings,
                key: ValueKey('stars-found-gal-$k'),
                name: g.name,
                detail:
                    '${strings.starsGalaxy} · '
                    '${g.designations == g.name ? '' : '${g.designations} · '}'
                    '${names[g.constellation] ?? g.constellation}',
                altitude: p?.altitude ?? -90,
                chosen: k == _galaxy,
                onTap: () {
                  _stopTyping();
                  setState(() => _galaxy = k);
                  if (p != null) _centreOn(p.altitude, p.azimuth, nearest: 3);
                },
              );
            },
          ),
        for (final i in stars)
          _pickRow(
            theme,
            strings,
            key: ValueKey('stars-found-$i'),
            name: catalog.labelOf(i),
            detail:
                '${names[catalog.constellation[i]] ?? catalog.constellation[i]}'
                ' · ${catalog.magnitude[i].toStringAsFixed(2)}',
            altitude: _altitude.length > i ? _altitude[i] : -90,
            chosen: i == _selected,
            onTap: () => _pickFound(i),
          ),
      ],
    );
  }

  // The 88 constellations by name, each with how high its middle stands;
  // one chosen is drawn boldest and brought to the centre.
  Widget _constellationList(
    SmThemeData theme,
    Strings strings,
    StarCatalog catalog,
  ) {
    final sky = _sky;
    final figures = [...catalog.figures]
      ..sort((a, b) => a.name.compareTo(b.name));
    return ListView(
      key: const ValueKey('stars-constellations'),
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      children: [
        for (final f in figures)
          Builder(
            builder: (context) {
              final p = sky?.place(f.labelRightAscension, f.labelDeclination);
              return _pickRow(
                theme,
                strings,
                key: ValueKey('stars-constellation-${f.id}'),
                name: f.name,
                detail: f.id,
                altitude: p?.altitude ?? -90,
                chosen: f.id == _constellation,
                onTap: () {
                  final chosen = _constellation == f.id;
                  setState(() => _constellation = chosen ? null : f.id);
                  if (!chosen && p != null) {
                    _centreOn(p.altitude, p.azimuth, nearest: 1.6);
                  }
                },
              );
            },
          ),
      ],
    );
  }

  // The brighter galaxies, brightest first; one chosen is marked, named
  // and brought to the centre.
  Widget _galaxyList(SmThemeData theme, Strings strings, StarCatalog? catalog) {
    final sky = _sky;
    final names = {
      for (final f in catalog?.figures ?? const <Constellation>[]) f.id: f.name,
    };
    return ListView(
      key: const ValueKey('stars-galaxies'),
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      children: [
        for (final (k, g) in _galaxies.indexed)
          Builder(
            builder: (context) {
              final p = sky?.place(g.rightAscension, g.declination);
              final ids = g.designations == g.name
                  ? ''
                  : '${g.designations} · ';
              return _pickRow(
                theme,
                strings,
                key: ValueKey('stars-galaxy-$k'),
                name: g.name,
                detail:
                    '$ids${names[g.constellation] ?? g.constellation} · '
                    '${g.magnitude.toStringAsFixed(1)}',
                altitude: p?.altitude ?? -90,
                chosen: k == _galaxy,
                onTap: () {
                  final chosen = _galaxy == k;
                  setState(() => _galaxy = chosen ? null : k);
                  if (!chosen && p != null) {
                    _centreOn(p.altitude, p.azimuth, nearest: 3);
                  }
                },
              );
            },
          ),
      ],
    );
  }

  Widget _queryBar(SmThemeData theme, Strings strings) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    return Row(
      key: const ValueKey('stars-query-bar'),
      children: [
        GlyphButton(
          key: const ValueKey('stars-query-clear'),
          glyph: Glyph.close,
          square: true,
          // Words to clear, cleared; none, the keyboard put away.
          onTap: () =>
              _query.text.isEmpty ? _queryFocus.unfocus() : _query.clear(),
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
              key: const ValueKey('stars-query'),
              controller: _query,
              focusNode: _queryFocus,
              labels: strings.textToolbar,
              placeholder: strings.starsSearchPlaceholder,
              plain: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _stopTyping(),
              style: theme.type.body.copyWith(color: colors.textPrimary),
            ),
          ),
        ),
        SizedBox(width: spacing.sm),
        GlyphButton(
          key: const ValueKey('stars-query-done'),
          glyph: Glyph.save,
          square: true,
          lit: true,
          onTap: _stopTyping,
        ),
      ],
    );
  }

  // Stars as rows to choose from: the name, its constellation and
  // brightness, and how high it stands now (or that it is down).
  Widget _starList(
    SmThemeData theme,
    Strings strings,
    StarCatalog catalog,
    List<int> stars,
    String name, {
    ValueChanged<int>? onTap,
  }) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    if (stars.isEmpty) {
      return Center(
        child: Text(
          strings.starsNoneFound,
          key: ValueKey('$name-none'),
          style: theme.type.label.copyWith(color: colors.textFaint),
        ),
      );
    }
    final figureNames = {for (final f in catalog.figures) f.id: f.name};
    return ListView.builder(
      key: ValueKey(name),
      padding: EdgeInsets.symmetric(vertical: spacing.xs),
      itemCount: stars.length,
      itemBuilder: (context, k) {
        final i = stars[k];
        final up = _altitude.length > i && _altitude[i] >= 0;
        return GestureDetector(
          key: ValueKey('$name-$i'),
          behavior: HitTestBehavior.opaque,
          onTap: () => (onTap ?? _select)(i),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.md,
              vertical: spacing.xs + 2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        catalog.labelOf(i),
                        style: theme.type.body.copyWith(
                          color: i == _selected
                              ? colors.accent
                              : colors.textPrimary,
                        ),
                      ),
                      Text(
                        '${figureNames[catalog.constellation[i]] ?? catalog.constellation[i]}'
                        ' · ${catalog.magnitude[i].toStringAsFixed(2)}',
                        style: theme.type.caption.copyWith(
                          color: colors.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  up
                      ? '${_altitude[i].toStringAsFixed(0)}°'
                      : strings.starsDown,
                  style: theme.type.label.copyWith(
                    color: up ? colors.textSecondary : colors.textFaint,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // What a planet is called here: Venus by its Javanese name on the
  // Javanese sky.
  String _planetName(PlanetAt p, Strings strings) =>
      widget.javanese && p.body == Body.venus
      ? strings.panjer(evening: p.view.east)
      : strings.planetName(p.body);

  // The planet touched: how bright, where it stands, which side of the
  // sun, how far, how lit, how large.
  Widget _planetRows(SmThemeData theme, Strings strings, PlanetAt p) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    String arc(double degrees) {
      final sign = degrees < 0 ? '−' : '+';
      final d = degrees.abs();
      return '$sign${d.floor()}° ${_two((d * 60 % 60).floor())}′';
    }

    String hours(double degrees) {
      final h = degrees / 15;
      return '${h.floor()}h ${_two((h * 60 % 60).floor())}m';
    }

    final v = p.view;
    final rows = <(String, String)>[
      (strings.starsMagnitude, v.magnitude.toStringAsFixed(1)),
      (
        strings.skyAltitude,
        p.at.altitude < 0
            ? '${arc(p.at.altitude)} · ${strings.skyBelow}'
            : arc(p.at.altitude),
      ),
      (
        strings.skyAzimuth,
        '${p.at.azimuth.toStringAsFixed(1)}° '
            '${strings.compassPoint(((p.at.azimuth + 22.5) ~/ 45))}',
      ),
      (
        strings.planetSide,
        v.east ? strings.planetEvening : strings.planetMorning,
      ),
      (strings.planetFromSun, '${v.elongation.toStringAsFixed(1)}°'),
      (strings.planetDistance, strings.planetAu(v.distance)),
      (strings.planetLit, '${(v.illumination * 100).toStringAsFixed(0)}%'),
      (strings.planetSize, '${v.diameter.toStringAsFixed(1)}″'),
      (strings.skyRightAscension, hours(p.at.rightAscension)),
      (strings.skyDeclination, arc(p.at.declination)),
    ];
    final javaneseVenus = widget.javanese && p.body == Body.venus;
    return SingleChildScrollView(
      key: const ValueKey('stars-planet-rows'),
      padding: EdgeInsets.fromLTRB(spacing.md, spacing.sm, spacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            javaneseVenus
                ? '${_planetName(p, strings)} · ${strings.planetName(p.body)}'
                : '${PlanetLook.symbolOf(p.body)}  ${_planetName(p, strings)}',
            key: const ValueKey('stars-planet-name'),
            style: theme.type.title.copyWith(
              fontSize: 17,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: spacing.sm),
          for (final (label, value) in rows)
            Padding(
              padding: EdgeInsets.only(bottom: spacing.xs),
              child: Row(
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
                  Text(
                    value,
                    style: theme.type.label.copyWith(
                      color: colors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          if (javaneseVenus) ...[
            SizedBox(height: spacing.xs),
            Text(
              strings.planetPanjerNote,
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

  // The star touched: what it is called, how bright, where it stands now
  // and where on the sky it is today.
  Widget _starRows(SmThemeData theme, Strings strings, StarCatalog? catalog) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    final planet = _planet;
    if (planet != null) {
      final p = _planets.where((x) => x.body == planet).firstOrNull;
      if (p != null) return _planetRows(theme, strings, p);
    }
    final i = _selected;
    if (catalog == null || i == null || _sky == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Text(
            strings.starsTouchOne,
            key: const ValueKey('stars-hint'),
            textAlign: TextAlign.center,
            style: theme.type.label.copyWith(color: colors.textFaint),
          ),
        ),
      );
    }
    final ofDate = _sky!.ofDate(
      catalog.rightAscension[i],
      catalog.declination[i],
    );
    final figure = catalog.figures
        .where((f) => f.id == catalog.constellation[i])
        .firstOrNull;
    String arc(double degrees) {
      final sign = degrees < 0 ? '−' : '+';
      final d = degrees.abs();
      return '$sign${d.floor()}° ${_two((d * 60 % 60).floor())}′';
    }

    String hours(double degrees) {
      final h = degrees / 15;
      return '${h.floor()}h ${_two((h * 60 % 60).floor())}m';
    }

    final altitude = _altitude[i];
    final rows = <(String, String)>[
      (strings.starsMagnitude, catalog.magnitude[i].toStringAsFixed(2)),
      if (figure != null) (strings.starsConstellation, figure.name),
      (
        strings.skyAltitude,
        altitude < 0 ? '${arc(altitude)} · ${strings.skyBelow}' : arc(altitude),
      ),
      (
        strings.skyAzimuth,
        '${_azimuth[i].toStringAsFixed(1)}° '
            '${strings.compassPoint(((_azimuth[i] + 22.5) ~/ 45))}',
      ),
      (strings.skyRightAscension, hours(ofDate.rightAscension)),
      (strings.skyDeclination, arc(ofDate.declination)),
    ];
    return SingleChildScrollView(
      key: const ValueKey('stars-star-rows'),
      padding: EdgeInsets.fromLTRB(spacing.md, spacing.sm, spacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            catalog.labelOf(i),
            key: const ValueKey('stars-star-name'),
            style: theme.type.title.copyWith(
              fontSize: 17,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: spacing.sm),
          for (final (label, value) in rows)
            Padding(
              padding: EdgeInsets.only(bottom: spacing.xs),
              child: Row(
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
                  Text(
                    value,
                    style: theme.type.label.copyWith(
                      color: colors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The dome with the stars on it. A touch picks the star nearest the
/// finger, favouring the brighter.
class StarDome extends StatelessWidget {
  final StarCatalog catalog;
  final StarSky starSky;
  final Float32List altitude;
  final Float32List azimuth;
  final SkyPosition sun;
  final SkyPosition moon;
  final int? selected;
  final List<String> compass;
  final ValueChanged<int?> onSelect;

  /// The planets drawn (none when hidden), the one chosen, a touch on
  /// one, and what each is called here.
  final List<PlanetAt> planets;
  final Body? planet;
  final ValueChanged<Body>? onPlanet;
  final String Function(PlanetAt)? planetName;

  /// The Javanese sky: its figures and names instead of the Western
  /// ones, the figure [figure] (by id) drawn boldest.
  final bool javanese;
  final String? figure;

  /// How near the sky is drawn: [StarView.whole] the whole dome, else
  /// magnified about a point of it. One finger moves it, two bring it
  /// nearer, through [onView]; pinched back out, it is whole again.
  final ValueListenable<StarView> view;
  final ValueChanged<StarView> onView;

  /// The constellation chosen (by its three letters), drawn boldest; the
  /// galaxies, and the one chosen (by its place in [galaxies]).
  final String? constellation;
  final List<Galaxy> galaxies;
  final int? galaxy;

  const StarDome({
    super.key,
    required this.catalog,
    required this.starSky,
    required this.altitude,
    required this.azimuth,
    required this.sun,
    required this.moon,
    required this.selected,
    required this.compass,
    required this.onSelect,
    this.planets = const [],
    this.planet,
    this.onPlanet,
    this.planetName,
    this.javanese = false,
    this.figure,
    required this.view,
    required this.onView,
    this.constellation,
    this.galaxies = const [],
    this.galaxy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    StarView? start;
    Offset? startFocal;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final centre = size.center(Offset.zero);
        final radius = size.shortestSide / 2 - 18;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (d) {
            start = view.value;
            startFocal = d.localFocalPoint;
          },
          onScaleUpdate: (d) {
            final from = start;
            if (from == null) return;
            // One finger moves the sky; two also bring it nearer.
            if (d.pointerCount < 2) {
              onView(
                StarView(
                  from.zoom,
                  from.pan -
                      (d.localFocalPoint - startFocal!) / (radius * from.zoom),
                ).kept,
              );
              return;
            }
            final zoom = (from.zoom * d.scale).clamp(1.0, StarView.most);
            // The point of the sky under the fingers stays under them.
            final held =
                from.pan + (startFocal! - centre) / (radius * from.zoom);
            final pan = held - (d.localFocalPoint - centre) / (radius * zoom);
            // Near enough to whole is whole, centred.
            onView(zoom < 1.04 ? StarView.whole : StarView(zoom, pan).kept);
          },
          onTapUp: (details) {
            final p = details.localPosition;
            final v = view.value;
            // A planet first, if one is near the finger.
            PlanetAt? near;
            var nearest = 24.0;
            for (final planet in planets) {
              final at = v.place(
                starProject(
                  centre,
                  radius,
                  planet.at.altitude,
                  planet.at.azimuth,
                ),
                centre,
                radius,
              );
              final d = (at - p).distance;
              if (d < nearest && (at - centre).distance <= radius) {
                nearest = d;
                near = planet;
              }
            }
            if (near != null && onPlanet != null) {
              onPlanet!(near.body);
              return;
            }
            int? best;
            var bestScore = double.infinity;
            for (var i = 0; i < altitude.length; i++) {
              final at = v.place(
                starProject(centre, radius, altitude[i], azimuth[i]),
                centre,
                radius,
              );
              final d = (at - p).distance;
              // Only what shows in the window.
              if (d > 28 || (at - centre).distance > radius) continue;
              // A brighter star wins over a fainter one a little nearer.
              final score = d + catalog.magnitude[i] * 3;
              if (score < bestScore) {
                bestScore = score;
                best = i;
              }
            }
            onSelect(best);
          },
          child: ValueListenableBuilder(
            valueListenable: view,
            builder: (context, v, _) => CustomPaint(
              size: size,
              painter: _StarPainter(
                view: v,
                constellation: constellation,
                galaxies: galaxies,
                galaxy: galaxy,
                catalog: catalog,
                starSky: starSky,
                javanese: javanese,
                figure: figure,
                altitude: altitude,
                azimuth: azimuth,
                sun: sun,
                moon: moon,
                selected: selected,
                planets: planets,
                planet: planet,
                planetName: planetName,
                compass: compass,
                radius: radius,
                sky: colors.surface,
                ink: colors.textPrimary,
                line: colors.outline,
                faint: colors.textFaint,
                accent: colors.accent,
                sunColor: skySunIn(context),
                moonColor: skyMoonIn(context),
                label: theme.type.caption,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Where a height and a bearing fall on the star map's dome of [radius]
/// about [centre]: as the ephemeris's dome, the distance from the centre
/// growing evenly with the distance from the zenith, but carried on past
/// the horizon, so the sky out of sight has a place too (the nadir at
/// twice the horizon's reach).
Offset starProject(
  Offset centre,
  double radius,
  double altitude,
  double azimuth,
) {
  final r = radius * (90 - altitude) / 90;
  final a = azimuth * math.pi / 180;
  return centre + Offset(math.sin(a) * r, -math.cos(a) * r);
}

/// How near the star map draws the sky: magnified [zoom] times about
/// [pan], a point of the dome in units of its radius from its centre (the
/// zenith is the origin, the horizon the unit circle).
@immutable
class StarView {
  final double zoom;
  final Offset pan;

  const StarView(this.zoom, this.pan);

  static const whole = StarView(1, Offset.zero);
  static const most = 8.0;

  /// The same view, the window kept on the sky: the whole sphere lies
  /// within twice the horizon's reach of the zenith.
  StarView get kept {
    final most = math.max(0.0, 2 - 1 / zoom);
    final reach = pan.distance;
    return reach <= most ? this : StarView(zoom, pan / reach * most);
  }

  /// Where a point of the whole dome, [p], is drawn.
  Offset place(Offset p, Offset centre, double radius) =>
      centre + ((p - centre) / radius - pan) * zoom * radius;

  static StarView lerp(StarView a, StarView b, double t) =>
      StarView(a.zoom + (b.zoom - a.zoom) * t, Offset.lerp(a.pan, b.pan, t)!);

  @override
  bool operator ==(Object other) =>
      other is StarView && other.zoom == zoom && other.pan == pan;

  @override
  int get hashCode => Object.hash(zoom, pan);
}

class _StarPainter extends CustomPainter {
  final StarView view;
  final String? constellation;
  final List<Galaxy> galaxies;
  final int? galaxy;
  final StarCatalog catalog;
  final StarSky starSky;
  final bool javanese;
  final String? figure;
  final Float32List altitude;
  final Float32List azimuth;
  final SkyPosition sun;
  final SkyPosition moon;
  final int? selected;
  final List<PlanetAt> planets;
  final Body? planet;
  final String Function(PlanetAt)? planetName;
  final List<String> compass;
  final double radius;
  final Color sky;
  final Color ink;
  final Color line;
  final Color faint;
  final Color accent;
  final Color sunColor;
  final Color moonColor;
  final TextStyle label;

  const _StarPainter({
    required this.view,
    required this.constellation,
    required this.galaxies,
    required this.galaxy,
    required this.catalog,
    required this.starSky,
    required this.javanese,
    required this.figure,
    required this.altitude,
    required this.azimuth,
    required this.sun,
    required this.moon,
    required this.selected,
    required this.planets,
    required this.planet,
    required this.planetName,
    required this.compass,
    required this.radius,
    required this.sky,
    required this.ink,
    required this.line,
    required this.faint,
    required this.accent,
    required this.sunColor,
    required this.moonColor,
    required this.label,
  });

  // Brighter is larger: a radius for each whole magnitude.
  static double _size(double magnitude) =>
      math.max(0.55, 2.9 - 0.42 * magnitude);

  // The colour of a bright star from its B−V: blue-white to orange.
  static Color _tint(double bv, Color ink) {
    if (bv.isNaN) return ink;
    final t = ((bv + 0.3) / 2.0).clamp(0.0, 1.0);
    const blue = Color(0xFFAFC8FF);
    const white = Color(0xFFFFFFFF);
    const orange = Color(0xFFFFB46B);
    return t < 0.25
        ? Color.lerp(blue, white, t / 0.25)!
        : Color.lerp(white, orange, (t - 0.25) / 0.75)!;
  }

  // A name set at [at] unless it would lie across one already set.
  void _label(
    Canvas canvas,
    List<Rect> taken,
    String text,
    Offset at,
    TextStyle style, {
    bool centred = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final origin = centred
        ? at - Offset(painter.width / 2, painter.height / 2)
        : at;
    final box = (origin & painter.size).inflate(2);
    if (taken.any((other) => other.overlaps(box))) return;
    taken.add(box);
    painter.paint(canvas, origin);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final zoom = view.zoom;
    Offset at(double alt, double az) =>
        view.place(starProject(centre, radius, alt, az), centre, radius);
    // Below the horizon, drawn fainter: the sky is there, out of sight.
    double seen(double alt) => alt < 0 ? 0.4 : 1.0;
    final window = Rect.fromCircle(center: centre, radius: radius);
    bool inside(Offset p) => (p - centre).distance <= radius + 12;
    // The zenith, as drawn: the horizon and the rings are circles round it.
    final zenith = view.place(centre, centre, radius);

    // The sky: the window it is seen through, the horizon, the rings at
    // 30 and 60 degrees, the compass (on the whole dome only).
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
    canvas.save();
    canvas.clipPath(Path()..addOval(window));
    // The ground: what lies past the horizon, in a tint of its own, the
    // sky inside the horizon.
    canvas
      ..drawRect(window, Paint()..color = Color.lerp(sky, ink, 0.07)!)
      ..drawCircle(zenith, radius * zoom, Paint()..color = sky)
      ..drawCircle(
        zenith,
        radius * zoom,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = line,
      );
    for (final ring in [1 / 3, 2 / 3]) {
      canvas.drawCircle(
        zenith,
        radius * ring * zoom,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = line.withValues(alpha: 0.5),
      );
    }
    canvas.restore();
    if (zoom == 1 && view.pan == Offset.zero) {
      final compassStyle = label.copyWith(color: faint);
      for (var k = 0; k < 4; k++) {
        final p = at(-1, k * 90.0);
        final dir = (p - centre) / radius;
        final painter = TextPainter(
          text: TextSpan(text: compass[k], style: compassStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          p + dir * 10 - Offset(painter.width / 2, painter.height / 2),
        );
      }
    }

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: centre, radius: radius)),
    );
    // Stars grow a little as the sky comes nearer.
    final grow = 1 + (zoom - 1) * 0.18;

    // In daylight the stars are out of sight: drawn faint, as a chart.
    final daylight = sun.altitude > -6 ? (sun.altitude > 0 ? 0.35 : 0.6) : 1.0;

    // The constellations' figures under the stars.
    final figureNames = <(String, Offset)>[];
    final ringed = <int>{};
    if (javanese) {
      _javaneseFigures(canvas, at, daylight, figureNames, ringed);
    } else {
      _figures(canvas, at, daylight, figureNames);
    }

    // The stars, faintest first so the bright sit on top. Each band of
    // magnitude drawn at once.
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var band = 6; band >= 2; band--) {
      final up = <double>[], down = <double>[];
      for (var i = 0; i < altitude.length; i++) {
        final m = catalog.magnitude[i];
        if (m.floor().clamp(2, 6) != band) continue;
        final p = at(altitude[i], azimuth[i]);
        if (!inside(p)) continue;
        (altitude[i] < 0 ? down : up)
          ..add(p.dx)
          ..add(p.dy);
      }
      final alpha = (0.95 - (band - 2) * 0.16) * daylight;
      paint.strokeWidth = _size(band + 0.5) * 2 * grow;
      for (final (points, shown) in [(up, 1.0), (down, 0.4)]) {
        paint.color = ink.withValues(alpha: alpha * shown);
        canvas.drawRawPoints(
          PointMode.points,
          Float32List.fromList(points),
          paint,
        );
      }
    }
    // The brightest, each in its own colour.
    final dot = Paint();
    for (var i = 0; i < altitude.length; i++) {
      final m = catalog.magnitude[i];
      if (m >= 2) break; // brightest first
      dot.color = _tint(
        catalog.colour[i],
        ink,
      ).withValues(alpha: daylight * seen(altitude[i]));
      canvas.drawCircle(at(altitude[i], azimuth[i]), _size(m) * grow, dot);
    }
    // Their names.
    final nameStyle = label.copyWith(
      color: faint.withValues(alpha: 0.9 * daylight),
      fontSize: 9,
    );
    // Names that never lie across each other: the bright stars' first,
    // brightest first, then the constellations' where they still fit.
    final taken = <Rect>[];
    // The planets' names first: they move, and are what is looked for.
    for (final p in planets) {
      final name = planetName?.call(p);
      final where = at(p.at.altitude, p.at.azimuth);
      if (name == null || !inside(where)) continue;
      final size = math.max(2.2, _size(p.view.magnitude)) * grow;
      _label(
        canvas,
        taken,
        name,
        where + Offset(size + 3, -5),
        nameStyle.copyWith(
          color: PlanetLook.colorOf(p.body)
              .withValues(alpha: 0.9 * seen(p.at.altitude)),
        ),
      );
    }
    for (var i = 0; i < altitude.length && !javanese; i++) {
      if (catalog.magnitude[i] >= 1.6 + (zoom - 1) * 0.5) break;
      if (catalog.name[i].isEmpty) continue;
      final p = at(altitude[i], azimuth[i]);
      if (!inside(p)) continue;
      _label(
        canvas,
        taken,
        catalog.name[i],
        p + const Offset(5, -5),
        altitude[i] < 0
            ? nameStyle.copyWith(
                color: nameStyle.color!.withValues(
                  alpha: nameStyle.color!.a * 0.5,
                ),
              )
            : nameStyle,
      );
    }
    final figureStyle = javanese
        ? label.copyWith(
            color: accent.withValues(alpha: daylight),
            fontSize: 11,
            letterSpacing: 1,
          )
        : label.copyWith(
            color: faint.withValues(alpha: 0.7 * daylight),
            fontSize: 9,
            letterSpacing: 1,
          );
    // The Javanese figures' stars, ringed.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = accent.withValues(alpha: 0.8 * daylight);
    for (final i in ringed) {
      canvas.drawCircle(
        at(altitude[i], azimuth[i]),
        _size(catalog.magnitude[i]) + 3,
        ring,
      );
    }
    for (final (name, where) in figureNames) {
      _label(canvas, taken, name, where, figureStyle, centred: true);
    }

    // The galaxies, each an oval as wide as it is on the sky (at least a
    // few points), the chosen one in the accent colour and named; the
    // brightest named when there is room.
    if (!javanese) {
      for (final (k, g) in galaxies.indexed) {
        final p = starSky.place(g.rightAscension, g.declination);
        final chosen = k == galaxy;
        final across = math.max(6.0, (g.major ?? 10) / 60 * radius / 90 * zoom);
        final tall = across * ((g.minor ?? g.major ?? 10) / (g.major ?? 10));
        final where = at(p.altitude, p.azimuth);
        canvas.drawOval(
          Rect.fromCenter(center: where, width: across, height: tall),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = chosen ? 1.6 : 0.8
            ..color = (chosen ? accent : faint).withValues(
              alpha: (chosen ? 1 : 0.6) * daylight * seen(p.altitude),
            ),
        );
        if (chosen || g.magnitude < 4 + (zoom - 1)) {
          _label(
            canvas,
            taken,
            g.name,
            where + Offset(across / 2 + 3, -4),
            chosen ? nameStyle.copyWith(color: accent) : nameStyle,
          );
        }
      }
    }

    // The planets: a disc as bright as the planet is, in its colour, and
    // its name; the one chosen ringed.
    for (final p in planets) {
      final where = at(p.at.altitude, p.at.azimuth);
      if (!inside(where)) continue;
      final shown = seen(p.at.altitude);
      final size = math.max(2.2, _size(p.view.magnitude)) * grow;
      canvas.drawCircle(
        where,
        size,
        Paint()..color = PlanetLook.colorOf(p.body).withValues(alpha: shown),
      );
      if (p.body == planet) {
        canvas.drawCircle(
          where,
          size + 5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = accent,
        );
      }
    }

    // The sun and the moon, where they stand.
    canvas
      ..drawCircle(
        at(sun.altitude, sun.azimuth),
        7,
        Paint()..color = sunColor.withValues(alpha: seen(sun.altitude)),
      )
      ..drawCircle(
        at(moon.altitude, moon.azimuth),
        6,
        Paint()..color = moonColor.withValues(alpha: seen(moon.altitude)),
      );

    // The star chosen, ringed.
    final s = selected;
    if (s != null) {
      canvas.drawCircle(
        at(altitude[s], azimuth[s]),
        _size(catalog.magnitude[s]) + 5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = accent,
      );
    }
    canvas.restore();
  }

  // The figures: each stroke's J2000 points placed in the same sky as the
  // stars, a segment drawn where both its ends are up; and the names of
  // the chief constellations where their label point is up.
  void _figures(
    Canvas canvas,
    Offset Function(double, double) at,
    double daylight,
    List<(String, Offset)> figureNames,
  ) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = line.withValues(alpha: 0.9 * daylight);
    final bold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = accent.withValues(alpha: daylight);
    final below = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = line.withValues(alpha: 0.4 * daylight);
    for (final figure in catalog.figures) {
      final chosen = figure.id == constellation;
      for (final points in figure.strokes) {
        ({double altitude, double azimuth})? last;
        for (var k = 0; k + 1 < points.length; k += 2) {
          final here = starSky.place(points[k], points[k + 1]);
          if (last != null) {
            final low = last.altitude < 0 || here.altitude < 0;
            canvas.drawLine(
              at(last.altitude, last.azimuth),
              at(here.altitude, here.azimuth),
              chosen ? bold : (low ? below : stroke),
            );
          }
          last = here;
        }
      }
      if (figure.rank == 1 || chosen) {
        final p = starSky.place(
          figure.labelRightAscension,
          figure.labelDeclination,
        );
        if (p.altitude > 8 || chosen) {
          figureNames.add((
            figure.name.toUpperCase(),
            at(p.altitude, p.azimuth),
          ));
        }
      }
    }
  }

  // The Javanese figures: lines between their own stars, or a Western
  // figure's lines where the sources name the constellation; their stars
  // ringed; each named in Javanese where it stands. The chosen one boldest.
  void _javaneseFigures(
    Canvas canvas,
    Offset Function(double, double) at,
    double daylight,
    List<(String, Offset)> names,
    Set<int> ringed,
  ) {
    for (final f in javaneseFigures) {
      final chosen = f.id == figure;
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = chosen ? 2 : 1.2
        ..color = accent.withValues(alpha: (chosen ? 1 : 0.7) * daylight);
      // A cluster with no lines (Wuluh) is ringed as one; the stars of
      // a figure with lines each.
      final cluster = f.lines.isEmpty && f.figure == null;
      final points = <Offset>[];
      for (final hip in f.stars) {
        final i = catalog.byHip(hip);
        if (i == null) continue;
        if (!cluster) ringed.add(i);
        points.add(at(altitude[i], azimuth[i]));
      }
      for (final (a, b) in f.lines) {
        final i = catalog.byHip(a), j = catalog.byHip(b);
        if (i == null || j == null) continue;
        {
          canvas.drawLine(
            at(altitude[i], azimuth[i]),
            at(altitude[j], azimuth[j]),
            stroke,
          );
        }
      }
      // A patch with no stars (the Coalsack): a ring its size.
      final patch = f.patch;
      if (patch != null) {
        final c = starSky.place(patch.rightAscension, patch.declination);
        final edge = starSky.place(
          patch.rightAscension,
          patch.declination + patch.radius,
        );
        if (c.altitude > 0) {
          final centre = at(c.altitude, c.azimuth);
          final reach = (at(edge.altitude, edge.azimuth) - centre).distance;
          canvas.drawCircle(centre, reach, stroke);
          points
            ..add(centre + Offset(0, reach))
            ..add(centre - Offset(0, reach));
        }
      }
      final western = f.figure == null
          ? null
          : catalog.figures.where((c) => c.id == f.figure).firstOrNull;
      if (western != null) {
        for (final strokePoints in western.strokes) {
          ({double altitude, double azimuth})? last;
          for (var k = 0; k + 1 < strokePoints.length; k += 2) {
            final here = starSky.place(strokePoints[k], strokePoints[k + 1]);
            if (last != null) {
              final from = at(last.altitude, last.azimuth);
              final to = at(here.altitude, here.azimuth);
              canvas.drawLine(from, to, stroke);
              points
                ..add(from)
                ..add(to);
            }
            last = here;
          }
        }
      }
      if (points.isEmpty) continue;
      var centre = Offset.zero;
      var lowest = points.first.dy, highest = points.first.dy;
      for (final p in points) {
        centre += p;
        if (p.dy > lowest) lowest = p.dy;
        if (p.dy < highest) highest = p.dy;
      }
      centre = centre / points.length.toDouble();
      if (cluster) {
        var reach = 0.0;
        for (final p in points) {
          reach = math.max(reach, (p - centre).distance);
        }
        canvas.drawCircle(centre, reach + 7, stroke);
        lowest = math.max(lowest, centre.dy + reach + 7);
        highest = math.min(highest, centre.dy - reach - 7);
      }
      // Named beside its stars: just below the lowest of them, or above
      // the highest where below would fall off the dome.
      final zenith = at(90, 0);
      final below = Offset(centre.dx, lowest + 12);
      names.add((
        f.name.toUpperCase(),
        (below - zenith).distance < radius - 10
            ? below
            : Offset(centre.dx, highest - 12),
      ));
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.view != view ||
      !identical(old.planets, planets) ||
      old.planet != planet ||
      old.constellation != constellation ||
      old.galaxy != galaxy ||
      !identical(old.galaxies, galaxies) ||
      !identical(old.altitude, altitude) ||
      old.selected != selected ||
      old.figure != figure ||
      old.radius != radius ||
      old.ink != ink ||
      old.sun.altitude != sun.altitude;
}

/// Waluku at dawn through a year at a place, against the mangsa it marks:
/// the first morning its middle Belt star stands 5° high in the east when
/// the sun is 12° below the horizon (its rising before dawn), and the
/// first morning after it has sunk to 5° in the west by then (its setting
/// at dawn); and the days Kasa and Kapitu open that year.
class WalukuYear {
  final CivilDate? rises;
  final CivilDate? sets;
  final CivilDate kasa;
  final CivilDate kapitu;

  const WalukuYear({
    required this.rises,
    required this.sets,
    required this.kasa,
    required this.kapitu,
  });

  /// [work] away from the screen. A function of its own, so the work
  /// sent off holds nothing of the screen's.
  static Future<WalukuYear> workApart(
    int year,
    double latitude,
    double longitude,
    Duration utcOffset,
  ) => Isolate.run(() => work(year, latitude, longitude, utcOffset));

  /// The Gregorian [year]'s, at [latitude], [longitude].
  static WalukuYear work(
    int year,
    double latitude,
    double longitude,
    Duration utcOffset,
  ) {
    const ra = 84.05338, dec = -1.20192;
    CivilDate? first(CivilDate from, bool Function(double, double) holds) =>
        StarMornings.first(
          ra,
          dec,
          from,
          200,
          latitude: latitude,
          longitude: longitude,
          utcOffset: utcOffset,
          holds: holds,
        );
    return WalukuYear(
      rises: first(CivilDate(year, 4, 1), (alt, az) => alt >= 5 && az < 180),
      sets: first(CivilDate(year, 9, 1), (alt, az) => alt <= 5 && az > 180),
      kasa: PranataMangsa.startOf(year - 1854, Mangsa.kasa),
      kapitu: PranataMangsa.startOf(year - 1854, Mangsa.kapitu),
    );
  }
}
