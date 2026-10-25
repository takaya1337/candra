import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import 'app_shell.dart';
import 'glyph_button.dart';
import 'journal/journal_screen.dart';
import 'menu/menu_screen.dart';
import 'native_bar.dart';
import 'parts.dart';
import 'sky_place.dart';
import 'practice/practice.dart';
import 'practice/practice_screen.dart';
import 'reminders/reminders_screen.dart';
import 'sync/sync_controller.dart';
import 'system_button.dart';
import 'utilities.dart';

/// The rooms of the house, each with its button in the bar.
///
/// The app is a house, not a set of screens switched between (owner,
/// 20 October 2026): the calendar is the living room at its centre, and
/// round it stand the menu, the practice, the reminders and the journal.
/// Each room keeps its place, the place of its button in the bar, so its
/// neighbours are always the same: going from one room to another slides
/// the house the way the second lies from the first, and everything
/// opened inside a room stays in that room.
enum Room {
  menu(0),
  living(3),
  practice(4),
  reminders(5),
  journal(6);

  const Room(this.place);

  /// Where the room's button stands in the bar, counted from the left:
  /// the menu, today, the utilities, the system at the centre (the
  /// living room's), the practice, the reminders, the journal.
  final int place;
}

/// Which cards the living room's lower panel holds, if any.
enum LivingCards { none, systems, utilities }

/// What the living room lets the bar do with it: the calendar's own
/// screen implements it.
abstract interface class LivingRoom {
  /// The cards its lower panel shows.
  ValueListenable<LivingCards> get cards;

  /// Whether a utility is open over it, opened from its card.
  ValueListenable<bool> get utilityOpen;

  /// Raises [cards] into the lower panel, or with [LivingCards.none]
  /// lets them down; [instantly], with no movement, for a change made
  /// out of sight (under a utility being taken away).
  void showCards(LivingCards cards, {bool instantly = false});

  /// Locks the system shown as the one the app starts in, or releases it.
  void lockSystem();
}

/// The house: the rooms, and the one bar that stands over all of them
/// and never moves.
///
/// The bar holds, from the left: the menu, today, the utilities, the
/// system at the centre, the practice, the reminders and the journal;
/// never more, whatever is open. The room the house is in has its button
/// lit from behind. Only the keyboard takes the bar's place, by the bar a
/// page has for typing ([RoomBar.typing]): the format bar, a field's own.
///
/// Each room has its own way down ([Navigator]): what is opened in a room
/// stays in it, and is left by going back, by a swipe from the left edge
/// or the phone's own back, never by a button. A room's own button, in a
/// page inside it, goes back to the room.
class House extends StatefulWidget {
  /// The living room: the calendar.
  final Widget living;

  /// Today and the phone's offset, for the rooms that need them; the
  /// clock's, unless a test says.
  final CivilDate? today;
  final Duration? utcOffset;

  const House({super.key, required this.living, this.today, this.utcOffset});

  /// The house [context] is in, if any.
  static HouseState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_HouseScope>()?.house;

  /// The room [context] is in, if it is in one.
  static Room? roomOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RoomScope>()?.room;

  @override
  State<House> createState() => HouseState();
}

class HouseState extends State<House> with SingleTickerProviderStateMixin {
  /// The room the house is in.
  final room = ValueNotifier<Room>(Room.living);

  /// The day the rooms are on: the one the last room was left on, which
  /// the next one entered takes up (the calendar's selected day, the
  /// journal's, the reminders').
  late CivilDate day = today;

  late final CivilDate today =
      widget.today ?? CivilDate.fromDateTime(DateTime.now());
  late final Duration utcOffset =
      widget.utcOffset ?? DateTime.now().timeZoneOffset;

  /// The living room, once it has said so.
  LivingRoom? living;

  final _navigators = {
    for (final room in Room.values) room: GlobalKey<NavigatorState>(),
  };
  late final _ways = {for (final room in Room.values) room: _Way(_changed)};

  // The rooms built so far: each the first time it is entered, and kept.
  final _built = <Room>{Room.living};

  // The room being left while the house slides, and the slide.
  Room? _from;
  late final _slide = AnimationController(vsync: this);

  // The pages that can go to today, and the bars for typing.
  final _targets = <RecentreState>[];
  final _typing = <_RoomBarState>[];

  // Tells the bar something it shows may have changed: after the frame,
  // since it is often heard during one.
  final _bar = _Signal();
  bool _barDue = false;
  void _changed() {
    if (_barDue) return;
    _barDue = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _barDue = false;
      if (mounted) _bar.tell();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void initState() {
    super.initState();
    // On an iPhone, the phone's bar is the bar of the page in front.
    NativeBar.inFront = (context, route) {
      // Read without depending: this is asked after a frame, not in one.
      final of = context.getInheritedWidgetOfExactType<_RoomScope>()?.room;
      return of == null || _isFront(of, route);
    };
  }

  @override
  void dispose() {
    if (NativeBar.inFront != null) NativeBar.inFront = null;
    room.dispose();
    _slide.dispose();
    _bar.dispose();
    super.dispose();
  }

  /// The way down of [room]: its navigator.
  NavigatorState? navigatorOf(Room room) => _navigators[room]!.currentState;

  /// Goes to [to], sliding the house the way it lies from the room the
  /// house is in. Nothing in either room changes.
  void go(Room to) {
    if (to == room.value) return;
    HapticFeedback.selectionClick();
    final motion = SmTheme.of(context).motion;
    setState(() {
      _from = room.value;
      _built.add(to);
    });
    room.value = to;
    _changed();
    _slide.value = 0;
    _slide
        .animateTo(
          1,
          duration: motion.transition,
          curve: motion.transitionCurve,
        )
        .whenComplete(() {
          if (_slide.isAnimating || !mounted) return;
          setState(() => _from = null);
        });
  }

  /// Goes to [to] and opens [route] there, once the room is built.
  Future<T?> openIn<T>(Room to, Route<T> route) {
    go(to);
    final done = Completer<T?>();
    void push() {
      final navigator = navigatorOf(to);
      if (navigator == null) {
        SchedulerBinding.instance.addPostFrameCallback((_) => push());
        return;
      }
      done.complete(navigator.push(route));
    }

    push();
    return done.future;
  }

  /// Goes back in [room] to the room itself, page by page, each page
  /// going as its own back would have it. A page that steps back within
  /// itself instead (a question it asks first) stops it there.
  Future<void> toRoomItself(Room room) async {
    final navigator = navigatorOf(room);
    final way = _ways[room]!;
    while (navigator != null && navigator.canPop()) {
      final top = way.top;
      await navigator.maybePop();
      if (way.top == top) break;
    }
  }

  // The phone's own back: back in the room; at a room itself, to the
  // living room; in the living room, the calendar's own (which asks
  // before leaving the app).
  Future<void> _back() async {
    final navigator = navigatorOf(room.value);
    if (navigator != null && await navigator.maybePop()) return;
    if (room.value != Room.living) go(Room.living);
  }

  // The front of the house: the page shown in the room the house is in.
  bool _isFront(Room? of, ModalRoute<Object?>? route) =>
      of == room.value && (route?.isCurrent ?? true);

  RecentreState? get _target {
    for (final target in _targets.reversed) {
      if (target.mounted && _isFront(target._room, target._route)) {
        return target.widget.enabled ? target : null;
      }
    }
    return null;
  }

  bool get _typingNow => _typing.any(
    (bar) =>
        bar.mounted &&
        bar.widget.typing != null &&
        _isFront(bar._room, bar._route),
  );

  // The bar's buttons.

  void _tapRoom(Room to) {
    if (to != room.value) {
      // Entered by its button, a room is as it first stands: what was
      // left open in it is put away, unseen, before it slides in (owner,
      // 20 October 2026). Only the utilities are kept.
      _clear(to);
      return go(to);
    }
    HapticFeedback.selectionClick();
    toRoomItself(to);
  }

  // Takes away, at once and unseen, every page opened in [of].
  void _clear(Room of) {
    final navigator = navigatorOf(of);
    if (navigator == null) return;
    for (final route in _ways[of]!.routes.skip(1).toList().reversed) {
      navigator.removeRoute(route);
    }
  }

  void _tapToday() {
    final target = _target;
    if (target == null) return;
    HapticFeedback.selectionClick();
    target.widget.onToday();
    // The place too, where the phone already lets it be read.
    SkyPlace.recentre();
  }

  /// Home, with [cards] up in the living room's panel (or none), from
  /// wherever the house is: whatever was open at home goes first. For the
  /// manual's offer to take you somewhere.
  void homeWith(LivingCards cards) {
    _clear(Room.living);
    living?.showCards(cards, instantly: true);
    if (room.value == Room.living) return;
    go(Room.living);
  }

  // The utilities: from another room, home with their cards up, or to
  // the utility left open there (owner, 20 October 2026: one tap). At
  // home, the cards up or down; from a utility, back to its cards.
  void _tapUtilities() {
    final living = this.living;
    if (room.value != Room.living) {
      if (living?.utilityOpen.value != true) {
        // Whatever else was open at home goes; the cards are up as the
        // house arrives.
        _clear(Room.living);
        living?.showCards(LivingCards.utilities, instantly: true);
      }
      return go(Room.living);
    }
    if (living == null) return;
    if (living.utilityOpen.value) {
      HapticFeedback.selectionClick();
      toRoomItself(Room.living);
      return;
    }
    living.showCards(
      living.cards.value == LivingCards.utilities
          ? LivingCards.none
          : LivingCards.utilities,
    );
  }

  // The system: from anywhere else, home, and only home; at home the
  // systems' cards, and with them up, the tick that lets them down.
  void _tapSystem() {
    final living = this.living;
    if (room.value != Room.living || (living?.utilityOpen.value ?? false)) {
      // Home, with nothing over it: the cards under the utility let
      // down at once, out of sight, before it goes, so they are never
      // seen going (owner, 20 October 2026: "the blip").
      living?.showCards(LivingCards.none, instantly: true);
      _clear(Room.living);
      if (room.value != Room.living) {
        go(Room.living);
      } else {
        HapticFeedback.selectionClick();
      }
      return;
    }
    if (living == null) return;
    // Home with a page open over it (the day's full reading, a place):
    // home closes it, eased (owner, 26 October 2026), before it does
    // anything else.
    if (_ways[Room.living]!.routes.length > 1) {
      HapticFeedback.selectionClick();
      navigatorOf(Room.living)?.popUntil((route) => route.isFirst);
      return;
    }
    living.showCards(
      living.cards.value == LivingCards.systems
          ? LivingCards.none
          : LivingCards.systems,
    );
  }

  Widget _rootOf(Room of) => switch (of) {
    Room.menu => const MenuScreen(),
    Room.living => widget.living,
    Room.practice => const PracticeScreen(),
    Room.reminders => RemindersScreen(
      day: day,
      utcOffset: utcOffset,
      today: today,
    ),
    Room.journal => JournalScreen(
      date: day,
      utcOffset: utcOffset,
      today: today,
    ),
  };

  // How far across [of] stands while the house slides, as a share of its
  // width: the room entered comes in from the side it lies on, and the
  // one left goes out the other way.
  double _shift(Room of, double t) {
    final from = _from;
    if (from == null) return 0;
    final way = room.value.place > from.place ? 1.0 : -1.0;
    if (of == room.value) return way * (1 - t);
    if (of == from) return -way * t;
    return 0;
  }

  Widget _room(Room of) {
    final shown = of == room.value || of == _from;
    return KeyedSubtree(
      key: ValueKey(of),
      child: Offstage(
        offstage: !shown,
        child: TickerMode(
          enabled: shown,
          child: AnimatedBuilder(
            animation: _slide,
            builder: (context, child) => FractionalTranslation(
              translation: Offset(_shift(of, _slide.value), 0),
              child: child,
            ),
            child: RepaintBoundary(
              child: _RoomScope(
                room: of,
                child: Navigator(
                  key: _navigators[of],
                  observers: [_ways[of]!],
                  onGenerateInitialRoutes: (_, _) => [
                    PageRouteBuilder<void>(
                      settings: RouteSettings(name: of.name),
                      pageBuilder: (context, _, _) => _rootOf(of),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = room.value;
    // Hidden rooms at the back, the room left over them, the room entered
    // on top.
    final order = [
      for (final of in Room.values)
        if (_built.contains(of) && of != current && of != _from) of,
      ?_from,
      current,
    ];
    return _HouseScope(
      house: this,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: ColoredBox(
          color: SmTheme.of(context).colors.background,
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (final of in order) _room(of),
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: SizedBox(
                    width: FourParts.sideways(context)
                        ? FourParts.columnWidth
                        : double.infinity,
                    child: ListenableBuilder(
                      listenable: Listenable.merge([_bar, room]),
                      builder: (context, _) => _HouseBar(house: this),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Signal extends ChangeNotifier {
  void tell() => notifyListeners();
}

/// Keeps the pages of a room as they come and go, and says when they do.
class _Way extends NavigatorObserver {
  final VoidCallback onChange;

  _Way(this.onChange);

  final routes = <Route<Object?>>[];

  Route<Object?>? get top => routes.lastOrNull;

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) {
    routes.add(route);
    onChange();
  }

  @override
  void didPop(Route<Object?> route, Route<Object?>? previousRoute) {
    routes.remove(route);
    onChange();
  }

  @override
  void didRemove(Route<Object?> route, Route<Object?>? previousRoute) {
    routes.remove(route);
    onChange();
  }

  @override
  void didReplace({Route<Object?>? newRoute, Route<Object?>? oldRoute}) {
    final at = oldRoute == null ? -1 : routes.indexOf(oldRoute);
    if (at >= 0 && newRoute != null) {
      routes[at] = newRoute;
    } else if (newRoute != null) {
      routes.add(newRoute);
    }
    if (at >= 0 && newRoute == null) routes.removeAt(at);
    onChange();
  }
}

class _HouseScope extends InheritedWidget {
  final HouseState house;

  const _HouseScope({required this.house, required super.child});

  @override
  bool updateShouldNotify(_HouseScope old) => old.house != house;
}

class _RoomScope extends InheritedWidget {
  final Room room;

  const _RoomScope({required this.room, required super.child});

  @override
  bool updateShouldNotify(_RoomScope old) => old.room != room;
}

/// Tells the house that the page [child] is in has days and goes to
/// today with [onToday]: the bar's today button, while the page is in
/// front, does that and only that; what the page shows then follows
/// from the day (owner, 20 October 2026). [atToday] lights the button,
/// when going there would change nothing.
class Recentre extends StatefulWidget {
  final VoidCallback onToday;
  final bool atToday;

  /// Whether the page has days just now (the search, on a month or a
  /// year but not on its list).
  final bool enabled;

  final Widget child;

  const Recentre({
    super.key,
    required this.onToday,
    required this.atToday,
    this.enabled = true,
    required this.child,
  });

  @override
  State<Recentre> createState() => RecentreState();
}

class RecentreState extends State<Recentre> {
  HouseState? _house;
  Room? _room;
  ModalRoute<Object?>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final house = House.maybeOf(context);
    if (house != _house) {
      _house?._targets.remove(this);
      _house = house;
      house?._targets.add(this);
    }
    _room = House.roomOf(context);
    _route = ModalRoute.of(context);
    _house?._changed();
  }

  @override
  void didUpdateWidget(Recentre oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.atToday != widget.atToday ||
        oldWidget.enabled != widget.enabled) {
      _house?._changed();
    }
  }

  @override
  void dispose() {
    _house?._targets.remove(this);
    _house?._changed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A page's place for the bar, at the foot of its four parts: empty, as
/// tall as the house's bar, which stands over it; or, while something is
/// typed, the page's own bar for it, [typing] (a [BottomBar] the keyboard
/// lifts: the format bar, a name being given). The house's bar gives way
/// to it.
class RoomBar extends StatefulWidget {
  final Widget? typing;

  const RoomBar({super.key, this.typing});

  /// How tall the house's bar stands: a bar button, 40, with 16 above
  /// and below it; on Android the line over it; on a tablet upright, the
  /// phone's bar scaled.
  static double heightOf(BuildContext context) =>
      72 * FourParts.phoneScale(context) + (BottomBar.glass ? 0 : 1);

  @override
  State<RoomBar> createState() => _RoomBarState();
}

class _RoomBarState extends State<RoomBar> {
  HouseState? _house;
  Room? _room;
  ModalRoute<Object?>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final house = House.maybeOf(context);
    if (house != _house) {
      _house?._typing.remove(this);
      _house = house;
      house?._typing.add(this);
    }
    _room = House.roomOf(context);
    _route = ModalRoute.of(context);
    _house?._changed();
  }

  @override
  void didUpdateWidget(RoomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.typing == null) != (widget.typing == null)) {
      _house?._changed();
    }
  }

  @override
  void dispose() {
    _house?._typing.remove(this);
    _house?._changed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typing = widget.typing;
    final theme = SmTheme.of(context);
    return AnimatedSwitcher(
      duration: theme.motion.shift,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.bottomCenter,
        children: [...previous, ?current],
      ),
      child:
          typing ??
          // The keyboard, up with nothing to type on it here, lifts the
          // panel all the same.
          SizedBox(
            key: const ValueKey('room-bar'),
            width: double.infinity,
            height:
                RoomBar.heightOf(context) +
                MediaQuery.viewInsetsOf(context).bottom,
          ),
    );
  }
}

/// The bar of the house. See [House].
class _HouseBar extends StatelessWidget {
  final HouseState house;

  const _HouseBar({required this.house});

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final systems = SystemScope.of(context);
    final room = house.room.value;
    final living = house.living;
    // Gives way to the keyboard, and to a page's bar for typing.
    final away =
        MediaQuery.viewInsetsOf(context).bottom > 0 || house._typingNow;
    final target = house._target;

    return ListenableBuilder(
      listenable: Listenable.merge([
        PracticeTimer.running,
        ?living?.cards,
        ?living?.utilityOpen,
      ]),
      builder: (context, _) {
        final cards = living?.cards.value ?? LivingCards.none;
        final utility = living?.utilityOpen.value ?? false;
        // Where the house is, lit from behind: in the living room the
        // system, or the utilities while theirs are up or one is open.
        final here =
            room == Room.living && (utility || cards == LivingCards.utilities)
            ? null
            : room;
        final utilitiesHere =
            room == Room.living && (utility || cards == LivingCards.utilities);
        final hasUtilities = Utility.of(systems.value).isNotEmpty;
        final practice = PracticeTimer.running.value;
        final ticking = room == Room.living && cards == LivingCards.systems;

        return IgnorePointer(
          ignoring: away,
          child: AnimatedOpacity(
            opacity: away ? 0 : 1,
            duration: theme.motion.shift,
            child: BottomBar(
              padding: EdgeInsets.all(spacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.outline)),
              ),
              // The seven, as far from each other all along, the system at
              // the very centre and a little wider than the rest (owner, 20
              // October 2026).
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GlyphButton(
                    key: const ValueKey('menu-button'),
                    glyph: Glyph.menu,
                    // A dot when syncing wants a look: conflicts to
                    // settle, or a token GitHub will not take.
                    marked: SyncScope.maybeOf(context)?.needsAttention ?? false,
                    square: true,
                    here: here == Room.menu,
                    onTap: () => house._tapRoom(Room.menu),
                  ),
                  // Faint where the page in front has no days.
                  Opacity(
                    opacity: target == null ? 0.35 : 1,
                    child: GlyphButton(
                      key: const ValueKey('today-button'),
                      glyph: Glyph.today,
                      square: true,
                      // Lit while today is already where the page
                      // is, when tapping it would change nothing.
                      lit: target?.widget.atToday ?? false,
                      onTap: house._tapToday,
                    ),
                  ),
                  // Faint under a system that has none.
                  Opacity(
                    opacity: hasUtilities ? 1 : 0.35,
                    child: GlyphButton(
                      key: const ValueKey('utilities-button'),
                      glyph: Glyph.utilities,
                      square: true,
                      here: utilitiesHere,
                      onTap: hasUtilities || room != Room.living
                          ? house._tapUtilities
                          : () {},
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: theme.motion.medium,
                    switchInCurve: theme.motion.curve,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.9, end: 1.0).animate(animation),
                        child: child,
                      ),
                    ),
                    child: ticking
                        ? GlyphButton(
                            key: const ValueKey('picker-done'),
                            glyph: Glyph.save,
                            lit: true,
                            here: true,
                            onTap: house._tapSystem,
                          )
                        : SystemButton(
                            key: const ValueKey('system-label'),
                            system: systems.value,
                            here: here == Room.living,
                            onTap: house._tapSystem,
                            onHold: () => living?.lockSystem(),
                            marked: systems.locked == systems.value,
                          ),
                  ),

                  // The practice timer; lit while one runs.
                  GlyphButton(
                    key: const ValueKey('practice-button'),
                    glyph: Glyph.practice,
                    square: true,
                    lit: practice != null,
                    marked: practice != null,
                    here: here == Room.practice,
                    onTap: () => house._tapRoom(Room.practice),
                  ),
                  GlyphButton(
                    key: const ValueKey('reminder-button'),
                    glyph: Glyph.reminder,
                    square: true,
                    here: here == Room.reminders,
                    onTap: () => house._tapRoom(Room.reminders),
                  ),
                  GlyphButton(
                    key: const ValueKey('journal-button'),
                    glyph: Glyph.journal,
                    square: true,
                    here: here == Room.journal,
                    onTap: () => house._tapRoom(Room.journal),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Lets what was raised into a lower panel (the living room's cards) be
/// drawn down again: a drag down across it, or, where the panel scrolls
/// up and down (the cards running down a tablet's column), a pull past
/// its top. Nothing while [enabled] is false.
class PullDown extends StatefulWidget {
  final bool enabled;
  final VoidCallback onPull;
  final Widget child;

  const PullDown({
    super.key,
    required this.enabled,
    required this.onPull,
    required this.child,
  });

  /// How far down a finger must draw, or a list be pulled past its top.
  static const far = 48.0;

  /// A flick down this fast, logical pixels a second, is enough however
  /// short.
  static const flick = 500.0;

  @override
  State<PullDown> createState() => _PullDownState();
}

class _PullDownState extends State<PullDown> {
  double _drawn = 0;
  bool _done = false;

  void _pull() {
    if (_done || !widget.enabled) return;
    _done = true;
    widget.onPull();
  }

  bool _heard(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollStartNotification) {
      _drawn = 0;
      _done = false;
    }
    final past = switch (notification) {
      // Android: the list stands still at its top and says how far.
      OverscrollNotification(:final overscroll, :final dragDetails)
          when dragDetails != null && overscroll < 0 =>
        -overscroll,
      // iPhone: the list goes on past its top.
      ScrollUpdateNotification(
        :final metrics,
        :final scrollDelta,
        :final dragDetails,
      )
          when dragDetails != null &&
              metrics.pixels < metrics.minScrollExtent &&
              (scrollDelta ?? 0) < 0 =>
        -(scrollDelta ?? 0),
      _ => 0.0,
    };
    _drawn += past;
    if (_drawn > PullDown.far) _pull();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: widget.enabled
          ? (_) {
              _drawn = 0;
              _done = false;
            }
          : null,
      onVerticalDragUpdate: widget.enabled
          ? (details) {
              _drawn += details.delta.dy;
              if (_drawn > PullDown.far) _pull();
            }
          : null,
      onVerticalDragEnd: widget.enabled
          ? (details) {
              if ((details.primaryVelocity ?? 0) > PullDown.flick) _pull();
            }
          : null,
      child: NotificationListener<ScrollNotification>(
        onNotification: widget.enabled ? _heard : null,
        child: widget.child,
      ),
    );
  }
}

/// For the page a room opens on when it stands on a day (the journal, the
/// reminders): it takes up the house's day each time its room is entered
/// ([enterDay]), and while it is in front tells the house its own
/// ([tellDay], from its build), so the next room entered takes that up.
mixin RoomDay<T extends StatefulWidget> on State<T> {
  HouseState? _dayHouse;
  Room? _dayRoom;

  /// The day the page stands on.
  CivilDate get roomDay;

  /// Goes to [day], the house's, as the room is entered.
  void enterDay(CivilDate day);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dayRoom = House.roomOf(context);
    final house = House.maybeOf(context);
    if (house == _dayHouse) return;
    _dayHouse?.room.removeListener(_entered);
    _dayHouse = house;
    house?.room.addListener(_entered);
  }

  void _entered() {
    final house = _dayHouse;
    if (house == null || house.room.value != _dayRoom) return;
    if (house.day != roomDay) enterDay(house.day);
  }

  /// Tells the house the page's day, while its room is the one the house
  /// is in.
  void tellDay() {
    final house = _dayHouse;
    if (house != null && house.room.value == _dayRoom) house.day = roomDay;
  }

  @override
  void dispose() {
    _dayHouse?.room.removeListener(_entered);
    super.dispose();
  }
}
