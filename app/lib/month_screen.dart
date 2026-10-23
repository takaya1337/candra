import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import 'parts.dart';

import 'app_shell.dart';
import 'calendar_system.dart';
import 'date_picker.dart';
import 'day_reading.dart';
import 'deferred_build.dart';
import 'glyph_button.dart';
import 'journal/entry.dart';
import 'journal/journal_store.dart';
import 'month_grid.dart';
import 'pixel_snap.dart';
import 'reminders/reminder_store.dart';
import 'routes.dart';
import 'language_toggle.dart';
import 'planets/planets_screen.dart';
import 'reading_screen.dart';
import 'strings.dart';
import 'sky_place.dart';
import 'system_months.dart';
import 'system_picker.dart';
import 'utilities.dart';
import 'toast.dart';
import 'year_grid.dart';
import 'bazi/bazi_screen.dart';
import 'mangsa/mangsa_screen.dart';
import 'salat/salat_screen.dart';
import 'sky/sky_screen.dart';
import 'house.dart';
import 'menu/manual_screen.dart';
import 'day_agenda.dart';
import 'day_page.dart';
import 'hilal/hilal_screen.dart';
import 'light/light_screen.dart';
import 'local_clock.dart';
import 'stars/star_screen.dart';

/// What the lower panel can show in place of the day reading.
enum _Picker { date, system, utility }

/// The three views of the calendar's upper area: the month, the year,
/// and the day as a sheet. The view button goes round them in that order.
enum MonthScreenView { month, year, day }

class MonthScreen extends StatefulWidget {
  /// Overrides the current date; for tests.
  final CivilDate? today;

  /// Overrides the device's timezone offset; for tests.
  final Duration? utcOffset;

  /// The view locked as the one to start in, if any; [startView]
  /// otherwise.
  final MonthScreenView? lockedView;

  /// The view to start in when none is locked: the day in the app, the
  /// month where a test does not say.
  final MonthScreenView startView;

  /// Called with the newly locked view, or null when the lock is released,
  /// to persist it.
  final ValueChanged<MonthScreenView?>? onLockView;

  const MonthScreen({
    super.key,
    this.today,
    this.utcOffset,
    this.lockedView,
    this.startView = MonthScreenView.month,
    this.onLockView,
  });

  @override
  State<MonthScreen> createState() => _MonthScreenState();
}

class _MonthScreenState extends State<MonthScreen>
    with TickerProviderStateMixin
    implements LivingRoom {
  late final CivilDate _today =
      widget.today ?? CivilDate.fromDateTime(DateTime.now());

  // The phone's offset on [date], at noon: where the clocks change, a
  // summer day reads by summer time even from winter. Unless one was
  // given.
  Duration _offsetOn(CivilDate date) =>
      LocalClock.dayOffset(date, widget.utcOffset);
  late CivilDate _selected = _today;
  late int _page = _pageOf(_today);
  late PageController _pages = PageController(initialPage: _page);

  // 0 = reading mode, 1 = picker mode. Everything that moves between the two
  // is driven by this one value so it travels as a single gesture.
  late final AnimationController _picker = AnimationController(vsync: this);

  // The view the screen opens in.
  late final MonthScreenView _first = widget.lockedView ?? widget.startView;

  // 0 = month view, 1 = year view. The month grid shrinks into its place
  // among the year's twelve as this runs.
  late final AnimationController _zoom = AnimationController(
    vsync: this,
    value: _first == MonthScreenView.year ? 1 : 0,
  );
  late bool _yearView = _first == MonthScreenView.year;
  late MonthScreenView? _lockedView = widget.lockedView;
  PageController? _years;

  // 0 = month view, 1 = day view: the month steps back and the one day's
  // sheet comes forward.
  late final AnimationController _dayZoom = AnimationController(
    vsync: this,
    value: _first == MonthScreenView.day ? 1 : 0,
  );
  late bool _dayView = _first == MonthScreenView.day;
  PageController? _days;

  MonthScreenView get _view => _dayView
      ? MonthScreenView.day
      : _yearView
      ? MonthScreenView.year
      : MonthScreenView.month;

  // While zooming, each view is drawn once into a picture and the picture
  // is scaled. Scaling live text re-rasterises every glyph at every size,
  // which is what made the zoom stutter.
  final _monthSnapshot = SnapshotController();
  final _yearSnapshot = SnapshotController();

  // The same for the lower panel's two layers while a picker opens or
  // closes.
  final _readingSnapshot = SnapshotController();
  final _pickerSnapshot = SnapshotController();

  // Fingers on the grid, for the pinch.
  final _pointers = <int, Offset>{};
  double? _pinchSpan;
  bool _pinchUsed = false;

  // The picker that is open, and the one last shown (still on screen while
  // it animates away).
  _Picker? _open;
  _Picker _shown = _Picker.date;

  // The wheels report every notch; the grid only follows once they slow
  // down, so a fast spin costs one grid rebuild instead of dozens.
  static const _pickSettle = Duration(milliseconds: 120);
  CivilDate? _pendingPick;
  Timer? _pickTimer;

  // Built grids by page, with the system and selection they were built for.
  final _grids = <int, (CalendarSystem, CivilDate, int, Widget)>{};

  // Dips when the grid jumps to a far month, so the new month fades in.
  late final AnimationController _gridFade = AnimationController(
    vsync: this,
    value: 1,
  );

  String? _toast;
  Timer? _toastTimer;

  // True when the last toast was sent away early to free the lower panel.
  bool _toastHurried = false;

  // The calendar is the house's living room: what the bar reads of it,
  // and the house it is in.
  final _cards = ValueNotifier(LivingCards.none);
  final _utilityOpen = ValueNotifier(false);
  HouseState? _house;

  @override
  ValueListenable<LivingCards> get cards => _cards;

  @override
  ValueListenable<bool> get utilityOpen => _utilityOpen;

  @override
  void showCards(LivingCards cards, {bool instantly = false}) =>
      _setPicker(switch (cards) {
        LivingCards.none => null,
        LivingCards.systems => _Picker.system,
        LivingCards.utilities => _Picker.utility,
      }, instantly: instantly);

  @override
  void lockSystem() => _lockSystem();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final systems = SystemScope.of(context);
    if (systems != _systems) {
      _systems?.removeListener(_onSystem);
      final had = _systems != null;
      _systems = systems;
      systems.addListener(_onSystem);
      // Another controller, standing on another system: as a change.
      if (had && systems.value != _system) {
        _onSystem();
      } else {
        _system = systems.value;
      }
      // The year view, opened on, starts on the system's year.
      if (_yearView && _years == null) {
        _years = PageController(initialPage: _year);
      }
    }
    final house = House.maybeOf(context);
    if (house == _house) return;
    _house?.room.removeListener(_onRoom);
    _house = house;
    house?.living = this;
    house?.room.addListener(_onRoom);
  }

  // Back in the living room: the calendar takes up the day the last room
  // was left on.
  void _onRoom() {
    final house = _house;
    if (house == null || house.room.value != Room.living) return;
    if (house.day != _selected) {
      _pendingPick = house.day;
      _applyPick();
    }
  }

  @override
  void initState() {
    super.initState();
    if (_dayView) _days = PageController(initialPage: _selected.dayNumber);
  }

  // The calendar is counted in the system's own months, where it has them
  // (owner, 21 October 2026; see SystemCalendar), so what a page is
  // depends on the system: read through [_calendar].
  SystemController? _systems;
  CalendarSystem? _system;
  SystemCalendar get _calendar =>
      SystemCalendar.of(_system ?? CalendarSystem.gregorian);

  // One page per month, numbered on continuously.
  int _pageOf(CivilDate date) => _calendar.pageOf(date);

  // The year of the page in view, as the system numbers it, and the
  // page's place in it, from 1.
  int get _year => _calendar.yearOfPage(_page);
  int get _month => _calendar.indexInYear(_page);

  // The system changed: the same day, on the page that holds it now.
  void _onSystem() {
    final system = _systems?.value;
    if (system == null || system == _system) return;
    _system = system;
    _grids.clear();
    final page = _pageOf(_selected);
    // New pagers, standing on the page that holds the day: the old ones'
    // pages mean other months, and may run past the new system's last.
    final pages = _pages;
    final years = _years;
    setState(() {
      _page = page;
      _pages = PageController(initialPage: page);
      if (years != null) {
        _years = PageController(initialPage: _calendar.yearOf(_selected));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pages.dispose();
      years?.dispose();
    });
  }

  @override
  void dispose() {
    _systems?.removeListener(_onSystem);
    _house?.room.removeListener(_onRoom);
    if (_house?.living == this) _house!.living = null;
    _cards.dispose();
    _utilityOpen.dispose();
    _toastTimer?.cancel();
    _pickTimer?.cancel();
    _gridFade.dispose();
    _zoom.dispose();
    _dayZoom.dispose();
    _days?.dispose();
    _monthSnapshot.dispose();
    _yearSnapshot.dispose();
    _readingSnapshot.dispose();
    _pickerSnapshot.dispose();
    _years?.dispose();
    _picker.dispose();
    _pages.dispose();
    super.dispose();
  }

  // Read through the scope, so the grids are redrawn with their entry dots
  // whenever the journal changes.
  JournalStore get _journal => JournalScope.of(context);

  ReminderStore get _reminders => ReminderScope.of(context);

  void _pickSystem(CalendarSystem system) {
    final systems = SystemScope.of(context);
    if (systems.value == system) return;
    systems.value = system;
  }

  // Back closes an open picker. With nothing to close, the first press
  // asks and a second, while the toast is still up, leaves the app.
  void _onBack() {
    if (_open != null) {
      _setPicker(null);
      return;
    }
    final ask = Strings.of(context).pressBackAgain;
    if (_toast == ask) {
      SystemNavigator.pop();
      return;
    }
    _say(ask);
  }

  void _say(String message) {
    _toastTimer?.cancel();
    _toastTimer = Timer(
      const Duration(seconds: 3),
      () => setState(() => _toast = null),
    );
    setState(() {
      _toast = message;
      _toastHurried = false;
    });
  }

  /// Sends any toast away at once, briskly but not abruptly, so whatever is
  /// about to use the lower panel does not have to wait for it. Everything
  /// that takes over the lower panel calls this first.
  void _clearLowerPanel() {
    if (_toast == null) return;
    _toastTimer?.cancel();
    setState(() {
      _toast = null;
      _toastHurried = true;
    });
  }

  // The hold's own haptic tick has already fired by the time these run.
  // Holding on a choice that is already locked releases the lock.
  void _lockSystem() {
    final systems = SystemScope.of(context);
    final strings = Strings.of(context);
    _say(
      systems.toggleLock()
          ? strings.lockedAsDefault(systems.value)
          : strings.systemLockReleased(),
    );
  }

  void _lockView() {
    final strings = Strings.of(context);
    final locking = _lockedView != _view;
    setState(() => _lockedView = locking ? _view : null);
    widget.onLockView?.call(_lockedView);
    _say(
      locking
          ? strings.viewLockedAsDefault(year: _yearView, day: _dayView)
          : strings.viewLockReleased(),
    );
  }

  /// Zooms out to the year, or in to [month] of the year on screen.
  void _setYearView(bool yearView, {int? month}) {
    if (yearView == _yearView) return;
    HapticFeedback.selectionClick();
    final motion = SmTheme.of(context).motion;

    if (yearView) {
      _years?.dispose();
      _years = PageController(initialPage: _year);
      setState(() => _yearView = true);
    } else {
      final page = _calendar.pageOfYearMonth(_year, month ?? _month);
      setState(() {
        _yearView = false;
        _page = page;
      });
      _pages.jumpToPage(page);
    }
    _monthSnapshot.allowSnapshotting = true;
    _yearSnapshot.allowSnapshotting = true;
    _zoom.animateTo(yearView ? 1 : 0, duration: motion.transition).whenComplete(
      () {
        // Back to live drawing once it has come to rest.
        if (_zoom.isAnimating) return;
        _monthSnapshot.allowSnapshotting = false;
        _yearSnapshot.allowSnapshotting = false;
        // Anything placed to the pixel was placed mid-zoom: place it again.
        PixelSnap.settled.now();
      },
    );
  }

  /// Steps in from the month to the selected day's own sheet, or back
  /// out to the month it is in.
  void _setDayView(bool dayView) {
    if (dayView == _dayView) return;
    HapticFeedback.selectionClick();
    final motion = SmTheme.of(context).motion;
    if (dayView) {
      _days?.dispose();
      _days = PageController(initialPage: _selected.dayNumber);
    }
    // Either way the month is the selected day's: the title names it,
    // and stepping out lands on it.
    final page = _pageOf(_selected);
    if (_pages.page?.round() != page) _pages.jumpToPage(page);
    setState(() {
      _dayView = dayView;
      _page = page;
    });
    _dayZoom.animateTo(
      dayView ? 1 : 0,
      duration: motion.transition,
      curve: motion.transitionCurve,
    );
  }

  /// The zoom button goes round the three views: from the month out to
  /// the year, from the year in to the day, from the day out to the month.
  void _nextView() {
    if (_dayView) {
      _setDayView(false);
    } else if (_yearView) {
      _setYearView(
        false,
        month: _calendar.yearOf(_selected) == _year
            ? _calendar.indexInYear(_pageOf(_selected))
            : null,
      );
      _setDayView(true);
    } else {
      _setYearView(true);
    }
  }

  // The day sheets follow a day chosen elsewhere: the wheels, Today, or
  // the day the journal was left on.
  void _showSelectedDay({bool glide = false}) {
    final days = _days;
    if (!_dayView || days == null || !days.hasClients) return;
    final from = days.page?.round() ?? _selected.dayNumber;
    if (from == _selected.dayNumber) return;
    // Only a day or two away is worth leafing to.
    if (glide && (from - _selected.dayNumber).abs() <= 3) {
      final motion = SmTheme.of(context).motion;
      days.animateToPage(
        _selected.dayNumber,
        duration: motion.medium,
        curve: motion.curve,
      );
    } else {
      days.jumpToPage(_selected.dayNumber);
    }
  }

  void _onDayLeafed(int dayNumber) {
    final date = CivilDate.fromDayNumber(dayNumber);
    if (date == _selected) return;
    final page = _pageOf(date);
    setState(() {
      _selected = date;
      _page = page;
    });
    // The month behind follows, so stepping out lands on the right one.
    if (_pages.hasClients && _pages.page?.round() != page) {
      _pages.jumpToPage(page);
    }
  }

  /// Opens a utility from its card. The strip stays open behind it, so
  /// coming back, by the button or the gesture, is coming back to the
  /// utilities (owner, 16 October 2026); the calendar is a step further.
  ///
  /// While it is open the house's bar has the utilities lit, and their
  /// button, or the swipe back, comes back to the cards.
  Future<void> _openUtility(Utility utility) async {
    HapticFeedback.selectionClick();
    _utilityOpen.value = true;
    // Always opened on this day and this moment, and where the phone is
    // if it may be read, whatever day the calendar stands on (owner, 21
    // October 2026: a utility opened on another day showed the wrong
    // planetary hours).
    unawaited(SkyPlace.recentre());
    final now = CivilDate.fromDateTime(DateTime.now());
    try {
      await switch (utility) {
        Utility.bazi => pushBazi(context, date: now, utcOffset: _offsetOn(now)),
        Utility.mangsa => pushMangsa(context, date: now),
        Utility.salat => pushSalat(context, date: now),
        Utility.sky => pushSky(context, date: now),
        Utility.stars => pushStars(context, date: now),
        Utility.light => pushLight(context, date: now),
        Utility.lintang => pushLintang(context, date: now),
        Utility.hilal => pushHilal(context, date: now),
        Utility.planets => pushPlanets(context, date: now),
      };
    } finally {
      _utilityOpen.value = false;
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 2) {
      final [a, b] = _pointers.values.toList();
      // Rebuilds with the grid's own scrolling switched off for the pinch.
      setState(() {
        _pinchSpan = (a - b).distance;
        _pinchUsed = false;
      });
    }
  }

  void _onPointerMove(PointerMoveEvent event, Size size) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;
    final span = _pinchSpan;
    if (_pointers.length != 2 || span == null || _pinchUsed) return;

    final [a, b] = _pointers.values.toList();
    final ratio = (a - b).distance / span;
    if (ratio < 0.8 && !_yearView) {
      // Pinching steps out: from the day to its month, from the month
      // to the year.
      _pinchUsed = true;
      _dayView ? _setDayView(false) : _setYearView(true);
    } else if (ratio > 1.25 && _yearView) {
      // Zooms in to the month the fingers are spreading over.
      _pinchUsed = true;
      _setYearView(
        false,
        month: YearGrid.monthAt(
          (a + b) / 2,
          size,
          _calendar.pagesOfYear(_year).length,
        ),
      );
    } else if (ratio > 1.25 && !_dayView) {
      _pinchUsed = true;
      _setDayView(true);
    }
  }

  void _onPointerUp(PointerEvent event) {
    final wasPinching = _pointers.length >= 2;
    _pointers.remove(event.pointer);
    if (wasPinching && _pointers.length < 2) {
      setState(() => _pinchSpan = null);
    }
  }

  void _setPicker(_Picker? picker, {bool instantly = false}) {
    if (!instantly) HapticFeedback.selectionClick();
    final motion = SmTheme.of(context).motion;
    if (picker != _Picker.date) _applyPick();
    if (picker != null) _clearLowerPanel();
    setState(() {
      _open = picker;
      if (picker != null) _shown = picker;
    });
    _cards.value = switch (picker) {
      _Picker.system => LivingCards.systems,
      _Picker.utility => LivingCards.utilities,
      _ => LivingCards.none,
    };
    final target = picker == null ? 0.0 : 1.0;
    if (_picker.value == target) return;
    if (instantly) {
      _picker.value = target;
      return;
    }
    // The layers move as pictures: text scaled live is drawn afresh at
    // every size, which costs more than a frame allows.
    _readingSnapshot.allowSnapshotting = true;
    _pickerSnapshot.allowSnapshotting = true;
    _picker
        .animateTo(
          target,
          duration: motion.transition,
          curve: motion.transitionCurve,
        )
        .whenComplete(() {
          if (_picker.isAnimating) return;
          _readingSnapshot.allowSnapshotting = false;
          _pickerSnapshot.allowSnapshotting = false;
        });
  }

  void _pick(CivilDate date) {
    // A day within the month on screen only moves the highlight, which is
    // cheap, so it follows the wheel notch by notch.
    if (_pageOf(date) == _page) {
      _select(date);
      return;
    }
    _pendingPick = date;
    _pickTimer?.cancel();
    _pickTimer = Timer(_pickSettle, _applyPick);
  }

  void _applyPick() {
    _pickTimer?.cancel();
    final date = _pendingPick;
    if (date == null) return;
    _pendingPick = null;

    setState(() => _selected = date);
    final years = _years;
    if (_yearView && years != null && years.hasClients) {
      final year = _calendar.yearOf(date);
      if (years.page?.round() != year) years.jumpToPage(year);
    }
    if (_pageOf(date) != _page) {
      _pages.jumpToPage(_pageOf(date));
      final motion = SmTheme.of(context).motion;
      _gridFade.value = 0.2;
      _gridFade.animateTo(1, duration: motion.medium, curve: motion.curve);
    }
    _showSelectedDay();
  }

  void _select(CivilDate date) {
    _pickTimer?.cancel();
    _pendingPick = null;
    setState(() => _selected = date);
    _showSelectedDay();
  }

  void _expandReading() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      fadeRoute<void>(
        context,
        (context) => ReadingScreen(
          date: _selected,
          utcOffset: _offsetOn(_selected),
          today: _today,
        ),
      ),
    );
  }

  void _goToToday() {
    final motion = SmTheme.of(context).motion;
    if (_dayView) {
      setState(() {
        _selected = _today;
        _page = _pageOf(_today);
      });
      if (_pages.page?.round() != _page) _pages.jumpToPage(_page);
      _showSelectedDay(glide: true);
      return;
    }
    if (_yearView) {
      setState(() {
        _selected = _today;
        _page = _pageOf(_today);
      });
      _years?.animateToPage(
        _calendar.yearOf(_today),
        duration: motion.medium,
        curve: motion.curve,
      );
      return;
    }
    setState(() => _selected = _today);
    _pages.animateToPage(
      _pageOf(_today),
      duration: motion.medium,
      curve: motion.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final systems = SystemScope.of(context);
    // The day the house is on, while the house is here.
    final house = _house;
    if (house != null && house.room.value == Room.living) {
      house.day = _pendingPick ?? _selected;
    }

    return Recentre(
      onToday: _goToToday,
      // Today is already selected and on screen, when going there would
      // change nothing.
      atToday:
          _selected == _today &&
          (_dayView ||
              (_yearView
                  ? _year == _calendar.yearOf(_today)
                  : _page == _pageOf(_today))),
      child: _screen(theme, systems),
    );
  }

  Widget _screen(SmThemeData theme, SystemController systems) {
    final system = systems.value;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: ColoredBox(
        color: theme.colors.background,
        child: SafeArea(
          child: FourParts(
            top: _header(theme, system),
            body: LayoutBuilder(
              builder: (context, constraints) => AnimatedBuilder(
                animation: Listenable.merge([_zoom, _dayZoom]),
                builder: (context, _) =>
                    _zoomStack(theme, system, constraints.biggest, _zoom.value),
              ),
            ),
            panel: Stack(
              children: [
                // The panel steps back while a toast is speaking.
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: _toast == null ? 1 : 0.04,
                    duration: _toastHurried
                        ? Toast.makeWay
                        : theme.motion.medium,
                    // Cards raised into the panel are let down by
                    // drawing them down, and by nothing else that moves.
                    child: PullDown(
                      enabled:
                          _open == _Picker.system || _open == _Picker.utility,
                      onPull: () => _setPicker(null),
                      child: _animatedPanel(systems),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Toast(message: _toast, hurried: _toastHurried),
                ),
              ],
            ),
            bar: const RoomBar(),
          ),
        ),
      ),
    );
  }

  Widget _header(SmThemeData theme, CalendarSystem system) {
    final calendar = _calendar;
    final month = calendar.monthAt(_page);
    final first = month.first;
    final last = month.last;
    final strings = Strings.of(context);
    // The day's own sheet already carries its month and year: over it
    // the button says how far the day is from today.
    final title = _dayView
        ? strings.dayFromToday(_selected.dayNumber - _today.dayNumber)
        : _yearView
        ? calendar.yearName(first, strings)
        : calendar.title(_page, strings);
    // In month view the title sits in a box as wide as the longest month
    // name, so the button holds its size from month to month.
    final titleWidth = _yearView || _dayView
        ? null
        : _widestMonthTitle(strings, theme.type.title);
    // Under a system's own month or year: the Gregorian days it spans.
    final subtitle = calendar.shifts
        ? strings.gregorianSpan(
            _yearView
                ? calendar.monthAt(calendar.pagesOfYear(_year).first).first
                : first,
            _yearView
                ? calendar.monthAt(calendar.pagesOfYear(_year).last).last
                : last,
          )
        : (_yearView
                  ? strings.yearSubtitle(system, _year, _selected)
                  : strings.monthSubtitle(system, first, last)) ??
              '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // Takes the room the toggle leaves, with the button at its left.
            Expanded(
              child: LayoutBuilder(
                builder: (context, room) {
                  // The most the title can have: the room less the
                  // button's padding, border, gap and chevron.
                  final most = math.max(
                    0.0,
                    room.maxWidth -
                        2 * theme.spacing.md -
                        theme.spacing.sm -
                        10 -
                        2,
                  );
                  // In month view every month of the year is set at one
                  // size, the longest's: smaller, if that is too long for
                  // the room, so the button holds its size.
                  // The size is a whole quarter point, so every month's
                  // line is exactly as tall; a point is left spare, since
                  // a face set smaller is not always narrower in exact
                  // proportion.
                  final size = theme.type.title.fontSize ?? 14;
                  final shrink = titleWidth == null || titleWidth <= most
                      ? 1.0
                      : ((size * (most - 1) / titleWidth) * 4).floor() /
                            4 /
                            size;
                  // The line stays as tall as at full size, so the button
                  // and the bar keep their height.
                  final lineHeight = (TextPainter(
                    text: TextSpan(text: ' ', style: theme.type.title),
                    textDirection: TextDirection.ltr,
                    textScaler: MediaQuery.textScalerOf(context),
                    maxLines: 1,
                  )..layout()).height;
                  final titleStyle = theme.type.title.copyWith(
                    color: theme.colors.textPrimary,
                    fontSize: size * shrink,
                  );
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: SmPressable(
                            onTap: () => _setPicker(
                              _open == _Picker.date ? null : _Picker.date,
                            ),
                            child: AnimatedContainer(
                              key: const ValueKey('month-button'),
                              duration: theme.motion.transition,
                              curve: theme.motion.transitionCurve,
                              padding: EdgeInsets.symmetric(
                                horizontal: theme.spacing.md,
                                vertical: theme.spacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: _open == _Picker.date
                                    ? theme.colors.surfaceRaised
                                    : theme.colors.surfaceRaised.withValues(
                                        alpha: 0,
                                      ),
                                border: Border.all(color: theme.colors.outline),
                                borderRadius: BorderRadius.circular(
                                  theme.radii.md,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // The title cross-fades, and the button's width follows,
                                  // when the month or the language changes.
                                  Flexible(
                                    child: AnimatedSize(
                                      duration: theme.motion.medium,
                                      curve: theme.motion.curve,
                                      alignment: Alignment.centerLeft,
                                      child: AnimatedSwitcher(
                                        duration: theme.motion.medium,
                                        layoutBuilder: (current, previous) =>
                                            Stack(
                                              alignment: Alignment.centerLeft,
                                              clipBehavior: Clip.none,
                                              children: [
                                                for (final child in previous)
                                                  Positioned.fill(
                                                    child: OverflowBox(
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      maxWidth: double.infinity,
                                                      child: child,
                                                    ),
                                                  ),
                                                ?current,
                                              ],
                                            ),
                                        // As wide as the longest title of
                                        // the year, never wider than there is
                                        // room for; a title longer than the
                                        // room is set smaller, so every month
                                        // of every system fits (owner, 21
                                        // October 2026).
                                        child: SizedBox(
                                          key: ValueKey(title),
                                          height: lineHeight,
                                          width: titleWidth == null
                                              ? null
                                              : math.min(
                                                  titleWidth * shrink,
                                                  most,
                                                ),
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: most,
                                            ),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                title,
                                                maxLines: 1,
                                                softWrap: false,
                                                style: titleStyle,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: theme.spacing.sm),
                                  AnimatedRotation(
                                    turns: _open == _Picker.date ? 0.5 : 0,
                                    duration: theme.motion.transition,
                                    curve: theme.motion.transitionCurve,
                                    child: CustomPaint(
                                      size: const Size(10, 6),
                                      painter: _ChevronPainter(
                                        theme.colors.textSecondary,
                                      ),
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
                },
              ),
            ),
            SizedBox(width: theme.spacing.md),
            const LanguageToggle(),
            // The view button is anchored at the far end, where it never
            // moves whatever the title beside the picker says, and far
            // enough from the language toggle not to be hit for it.
            SizedBox(width: theme.spacing.md),
            GlyphButton(
              key: const ValueKey('zoom-button'),
              // The view a tap goes to next.
              glyph: _dayView
                  ? Glyph.monthView
                  : _yearView
                  ? Glyph.dayView
                  : Glyph.yearView,
              square: true,
              onHold: _lockView,
              marked: _lockedView == _view,
              onTap: _nextView,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        AnimatedSwitcher(
          duration: theme.motion.medium,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.centerLeft,
            children: [...previous, ?current],
          ),
          // One line's height whether or not the system has anything to
          // say here (Gregorian does not), so what is below never shifts
          // when the system changes.
          child: SizedBox(
            key: ValueKey(subtitle),
            width: double.infinity,
            height: MediaQuery.textScalerOf(context)
                .scale(theme.type.label.fontSize! * theme.type.label.height!)
                .ceilToDouble(),
            child: Text(
              subtitle,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              style: theme.type.label.copyWith(
                color: theme.colors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _weekdayRow(SmThemeData theme) => Row(
    children: [
      for (final (day, initial) in Strings.of(context).weekdayInitials.indexed)
        Expanded(
          child: Center(
            child: AnimatedSwitcher(
              duration: theme.motion.medium,
              child: Text(
                initial,
                key: ValueKey('$day$initial'),
                style: theme.type.label.copyWith(color: theme.colors.textFaint),
              ),
            ),
          ),
        ),
    ],
  );

  /// The month view and the year view, one turning into the other. At
  /// [t] = 0 the month fills the area; as [t] rises it shrinks into its slot
  /// among the year's twelve mini-months while the year grid, starting
  /// magnified on that slot, settles to full view.
  Widget _zoomStack(
    SmThemeData theme,
    CalendarSystem system,
    Size size,
    double t,
  ) {
    final eased = theme.motion.transitionCurve.transform(t);
    // How far the day's sheet has come forward over the month.
    final d = _dayZoom.value;
    final behind = 1 - const Interval(0, 0.55).transform(d);
    final slot = YearGrid.slotOf(
      _month,
      size,
      _calendar.pagesOfYear(_year).length,
    );
    final frame = Rect.lerp(Offset.zero & size, slot, eased)!;
    final strings = Strings.of(context);

    // Maps the month view's full area onto [frame].
    final shrink = Matrix4.identity()
      ..translateByDouble(frame.left, frame.top, 0, 1)
      ..scaleByDouble(
        frame.width / size.width,
        frame.height / size.height,
        1,
        1,
      );
    // Maps the year grid so that [slot] lands on [frame].
    final magnifyX = frame.width / slot.width;
    final magnifyY = frame.height / slot.height;
    final magnify = Matrix4.identity()
      ..translateByDouble(
        frame.left - slot.left * magnifyX,
        frame.top - slot.top * magnifyY,
        0,
        1,
      )
      ..scaleByDouble(magnifyX, magnifyY, 1, 1);

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: (event) => _onPointerMove(event, size),
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      child: ClipRect(
        child: Stack(
          children: [
            // Always present, so the month pages keep their place.
            Positioned.fill(
              key: const ValueKey('month-view'),
              child: IgnorePointer(
                ignoring: t > 0 || d > 0,
                child: Opacity(
                  opacity: (1 - const Interval(0, 0.55).transform(t)) * behind,
                  child: Transform(
                    transform: shrink,
                    child: SnapshotWidget(
                      controller: _monthSnapshot,
                      child: Column(
                        children: [
                          _weekdayRow(theme),
                          SizedBox(height: theme.spacing.xs),
                          Expanded(
                            child: FadeTransition(
                              opacity: _gridFade,
                              child: PageView.builder(
                                key: ValueKey(system),
                                controller: _pages,
                                scrollDirection: Axis.vertical,
                                physics: _pinchSpan == null
                                    ? null
                                    : const NeverScrollableScrollPhysics(),
                                // Keeps the months either side alive. They
                                // are laid out while nothing is moving, so a
                                // swipe never pays for putting a grid
                                // together.
                                allowImplicitScrolling: true,
                                onPageChanged: (page) =>
                                    setState(() => _page = page),
                                itemCount: _calendar.pageCount,
                                itemBuilder: (context, page) => DeferredBuild(
                                  eager: page == _page,
                                  busy: _pages.position.isScrollingNotifier,
                                  child: _gridFor(page, system, theme),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (t > 0)
              Positioned.fill(
                key: const ValueKey('year-view'),
                child: IgnorePointer(
                  ignoring: t < 1,
                  child: Opacity(
                    opacity: const Interval(0.25, 1).transform(t) * behind,
                    child: Transform(
                      transform: magnify,
                      child: SnapshotWidget(
                        controller: _yearSnapshot,
                        child: PageView.builder(
                          key: ValueKey(system),
                          controller: _years,
                          scrollDirection: Axis.vertical,
                          physics: _pinchSpan == null
                              ? null
                              : const NeverScrollableScrollPhysics(),
                          onPageChanged: (year) => setState(
                            () =>
                                _page = _calendar.pageOfYearMonth(year, _month),
                          ),
                          itemCount: _calendar.yearCount,
                          itemBuilder: (context, year) => YearGrid(
                            months: [
                              for (final page in _calendar.pagesOfYear(year))
                                _calendar.monthAt(page),
                            ],
                            monthLabels: [
                              for (final page in _calendar.pagesOfYear(year))
                                _calendar.shifts
                                    ? _calendar.monthName(
                                        _calendar.monthAt(page),
                                        strings,
                                      )
                                    : strings.monthNames[page % 12].substring(
                                        0,
                                        3,
                                      ),
                            ],
                            system: system,
                            today: _today,
                            selected: _selected,
                            strings: strings,
                            onTapMonth: (month) =>
                                _setYearView(false, month: month),
                            // A month's dots are its reminders: one for
                            // each category with a reminder in it.
                            dotsOf: (month) {
                              final span = _calendar.monthAt(
                                _calendar.pagesOfYear(year)[month - 1],
                              );
                              return [
                                for (final category in byHue(
                                  _reminders
                                      .marksBetween(
                                        span.first,
                                        span.length,
                                        _journal.categories,
                                      )
                                      .take(YearGrid.maxDots),
                                ))
                                  category.color,
                              ];
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // The day's own sheet, one of an endless block leafed through
            // up and down as the months are. It only slides and fades:
            // text scaled live is drawn afresh at every size.
            if (d > 0)
              Positioned.fill(
                key: const ValueKey('day-view'),
                child: IgnorePointer(
                  ignoring: d < 1,
                  child: Opacity(
                    opacity: const Interval(0.25, 1).transform(d),
                    child: Transform.translate(
                      offset: Offset(0, 24 * (1 - d)),
                      child: PageView.builder(
                        controller: _days,
                        scrollDirection: Axis.vertical,
                        physics: _pinchSpan == null
                            ? null
                            : const NeverScrollableScrollPhysics(),
                        onPageChanged: _onDayLeafed,
                        itemBuilder: (context, dayNumber) {
                          final date = CivilDate.fromDayNumber(dayNumber);
                          return Padding(
                            padding: EdgeInsets.only(bottom: theme.spacing.md),
                            child: DayPage(
                              date: date,
                              today: _today,
                              system: system,
                              utcOffset: _offsetOn(date),
                              strings: strings,
                              dots: [
                                for (final category in byHue(
                                  _reminders
                                      .marksOn(date, _journal.categories)
                                      .take(MonthGrid.maxDots),
                                ))
                                  category.color,
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Width of the longest "Month Year" in the current language and year.
  final _titleWidths = <String, double>{};

  double _widestMonthTitle(Strings strings, TextStyle style) {
    final scaler = MediaQuery.textScalerOf(context);
    final calendar = _calendar;
    final key =
        '${calendar.system.name}|${strings.language.name}|$_year|'
        '${scaler.scale(1)}';
    return _titleWidths[key] ??= [
      for (final page in calendar.pagesOfYear(_year))
        (TextPainter(
          text: TextSpan(text: calendar.title(page, strings), style: style),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: 1,
        )..layout()).width,
    ].reduce((a, b) => a > b ? a : b).ceilToDouble();
  }

  /// The grid for [page]. The same widget is handed back until what it
  /// shows changes, so a swipe (which rebuilds this screen to update the
  /// month button) does not rebuild every cell of every month in view.
  Widget _gridFor(int page, CalendarSystem system, SmThemeData theme) {
    final journal = _journal;
    final reminders = _reminders;
    final stamp = Object.hash(journal.revision, reminders.revision);
    final cached = _grids[page];
    if (cached != null &&
        cached.$1 == system &&
        cached.$2 == _selected &&
        cached.$3 == stamp) {
      return cached.$4;
    }
    if (_grids.length > 8) _grids.clear();

    // One cross-fade for the whole grid when the system changes.
    final grid = AnimatedSwitcher(
      key: ValueKey(
        SystemCalendar.of(system).shifts
            ? 'month-${system.name}-$page'
            : 'month-${page ~/ 12}-${page % 12 + 1}',
      ),
      duration: theme.motion.medium,
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: MonthGrid(
        key: ValueKey(system),
        span: SystemCalendar.of(system).monthAt(page),
        shifted: SystemCalendar.of(system).shifts,
        system: system,
        today: _today,
        selected: _selected,
        // A second tap on the day already chosen steps in to its sheet,
        // as a tap on a month of the year steps in to the month.
        onSelect: (date) =>
            date == _selected ? _setDayView(true) : _select(date),
        // A day's dots are its reminders: one for each category with a
        // reminder that day. The journal is not shown here; it looks
        // back, and has its own calendar on the journal screen.
        //
        // Which dots show is decided by time, the earliest reminders
        // first; the order they stand in is decided by colour, so that
        // colours far apart are not put side by side, where they seem to
        // sit at different heights.
        dotsOf: (date) => [
          for (final category in byHue(
            reminders.marksOn(date, journal.categories).take(MonthGrid.maxDots),
          ))
            category.color,
        ],
      ),
    );
    _grids[page] = (system, _selected, stamp, grid);
    return grid;
  }

  /// Cross-fades [child] with its own translation when the language changes.
  Widget _languageFade(Widget child, {String key = ''}) {
    final language = Strings.of(context).language;
    return AnimatedSwitcher(
      duration: SmTheme.of(context).motion.medium,
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: KeyedSubtree(key: ValueKey('$key${language.name}'), child: child),
    );
  }

  /// The lower panel, animated between the reading and a picker. What
  /// each layer shows is built here, once for each build of the screen,
  /// and only the layers' fade, slide and scale follow the animation:
  /// building the reading and the picker anew on every frame of it (the
  /// day's whole reading worked out again, every card's date in its own
  /// system) cost more than a frame on the iPad.
  Widget _animatedPanel(SystemController systems) {
    final strings = Strings.of(context);
    final reading = SnapshotWidget(
      controller: _readingSnapshot,
      child: _languageFade(
        key: _yearView
            ? 'year'
            : _dayView
            ? 'agenda'
            : 'day',
        _yearView
            // The reading of the Gregorian year the system's begins in.
            ? YearReading(
                year: _calendar.monthAt(_page).first.year,
                selected: _selected,
                strings: strings,
              )
            : _dayView
            // The sheet above already names the day in every system:
            // here, what it leaves out.
            ? DayAgenda(
                date: _selected,
                strings: strings,
                reminders: _reminders.on(_selected),
                bell: _reminders
                    .marksOn(_selected, _journal.categories)
                    .firstOrNull
                    ?.color,
                onExpand: _expandReading,
              )
            : DayReading(
                date: _selected,
                short: true,
                utcOffset: _offsetOn(_selected),
                strings: strings,
                onExpand: _expandReading,
                // A bell when the day has reminders, in the colour of
                // the earliest.
                bell: _reminders
                    .marksOn(_selected, _journal.categories)
                    .firstOrNull
                    ?.color,
              ),
      ),
    );
    final picker = SnapshotWidget(
      controller: _pickerSnapshot,
      child: _languageFade(key: _shown.name, switch (_shown) {
        _Picker.date => DatePicker(
          date: _selected,
          strings: strings,
          onChanged: _pick,
        ),
        _Picker.system => SystemPicker(
          strings: strings,
          date: _selected,
          active: systems.value,
          locked: systems.locked,
          onPick: _pickSystem,
        ),
        _Picker.utility => UtilityPicker(
          strings: strings,
          system: systems.value,
          onOpen: _openUtility,
        ),
      }),
    );
    return AnimatedBuilder(
      animation: _picker,
      builder: (context, _) => _panel(_picker.value, reading, picker),
    );
  }

  /// The lower quarter: the reading lifts away as the wheels rise into place.
  Widget _panel(double t, Widget reading, Widget picker) {
    final leaving = const Interval(0, 0.55).transform(t);
    final arriving = const Interval(0.25, 1).transform(t);

    return Stack(
      children: [
        // Keyed, so one layer coming or going never rebuilds the other from
        // scratch (which reset the system picker's scroll and flickered).
        if (t < 1)
          Positioned.fill(
            key: const ValueKey('reading-layer'),
            child: IgnorePointer(
              ignoring: t > 0,
              child: Opacity(
                opacity: 1 - leaving,
                child: Transform.translate(
                  offset: Offset(0, -20 * t),
                  child: Transform.scale(scale: 1 - 0.06 * t, child: reading),
                ),
              ),
            ),
          ),
        if (t > 0)
          Positioned.fill(
            key: const ValueKey('picker-layer'),
            child: IgnorePointer(
              ignoring: t < 1,
              child: Opacity(
                opacity: arriving,
                child: Transform.translate(
                  offset: Offset(0, 28 * (1 - t)),
                  child: Transform.scale(scale: 0.94 + 0.06 * t, child: picker),
                ),
              ),
            ),
          ),
        // Where the manual is, said once to someone new: over the panel
        // until it is put away, then never again.
        Positioned.fill(
          child: ValueListenableBuilder(
            valueListenable: Manual.offered,
            builder: (context, offered, _) => offered && t == 0
                ? const ManualOffer()
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

/// A small downward-pointing chevron.
class _ChevronPainter extends CustomPainter {
  final Color color;

  const _ChevronPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.color != color;
}
