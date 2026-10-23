import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import 'appearance.dart';
import 'calendar_system.dart';
import 'colour_schemes.dart';
import 'keyboard_lift.dart';
import 'journal/journal_store.dart';
import 'reminders/reminder_store.dart';
import 'strings.dart';
import 'sync/sync_controller.dart';
import 'system_palettes.dart';

/// The active calendar system, and the one locked as the startup default.
///
/// With nothing locked the app starts in Gregorian.
class SystemController extends ValueNotifier<CalendarSystem> {
  /// Called with the newly locked system, or null when the lock is
  /// released, to persist it.
  final void Function(CalendarSystem? system)? onLock;

  CalendarSystem? _locked;

  SystemController({CalendarSystem? locked, this.onLock})
    : _locked = locked,
      super(locked ?? CalendarSystem.gregorian);

  /// The system the app starts in when nothing is locked.
  static const fallback = CalendarSystem.gregorian;

  CalendarSystem? get locked => _locked;

  void shift() => value = value.next;

  /// Makes the active system the one the app starts in. Returns true.
  /// If it already is, releases the lock instead, so the app goes back to
  /// starting in [fallback], and returns false.
  bool toggleLock() {
    final locking = _locked != value;
    _locked = locking ? value : null;
    notifyListeners();
    onLock?.call(_locked);
    return locking;
  }
}

/// Gives the subtree the [SystemController]. Widgets that read it rebuild
/// when the active or locked system changes.
class SystemScope extends InheritedNotifier<SystemController> {
  const SystemScope({
    super.key,
    required SystemController super.notifier,
    required super.child,
  });

  static SystemController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SystemScope>()!.notifier!;
}

/// Themes everything below it in the active system's colours, on the
/// dark side or the light.
class AppShell extends StatelessWidget {
  static const _base = SmThemeData.dusk;

  final SystemController controller;
  final AppearanceController appearance;
  final LanguageController language;
  final JournalStore journal;
  final ReminderStore reminders;
  final SyncController? sync;
  final Widget child;

  const AppShell({
    super.key,
    required this.controller,
    required this.appearance,
    required this.language,
    required this.journal,
    required this.reminders,
    this.sync,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return JournalScope(
      notifier: journal,
      child: ReminderScope(
        notifier: reminders,
        child: LanguageScope(
          notifier: language,
          child: SystemScope(
            notifier: controller,
            child: AppearanceScope(
              notifier: appearance,
              child: _ColourShift(
                controller: controller,
                appearance: appearance,
                base: _base,
                child: KeyboardLift(
                  child: sync == null
                      ? child
                      : SyncScope(notifier: sync, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Themes [child] in the active system's colours, on the side the app is
/// on, and fades from the old colours to the new when the system or the
/// side changes (the side also when the phone turns while it is followed).
///
/// The fade is between two pictures, not two themes: the screen as it was
/// is kept as an image and faded away over the screen as it now is.
/// Working the colours through in between would mean rebuilding everything
/// on screen for every frame of the fade, which is too much to do in time.
class _ColourShift extends StatefulWidget {
  final SystemController controller;
  final AppearanceController appearance;
  final SmThemeData base;
  final Widget child;

  const _ColourShift({
    required this.controller,
    required this.appearance,
    required this.base,
    required this.child,
  });

  @override
  State<_ColourShift> createState() => _ColourShiftState();
}

class _ColourShiftState extends State<_ColourShift>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _screen = GlobalKey();

  late CalendarSystem _system = widget.controller.value;

  // The side shown.
  late Brightness _side = _wanted;

  Brightness get _wanted => widget.appearance.of(
    WidgetsBinding.instance.platformDispatcher.platformBrightness,
  );

  // The screen in the colours it is leaving, while it fades.
  ui.Image? _before;

  late final _fade =
      AnimationController(vsync: this, duration: widget.base.motion.shift)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _drop();
        });

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onSystem);
    widget.appearance.addListener(_onSystem);
    ColourChoice.chosen.addListener(_onScheme);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangePlatformBrightness() => _onSystem();

  @override
  void dispose() {
    widget.controller.removeListener(_onSystem);
    widget.appearance.removeListener(_onSystem);
    ColourChoice.chosen.removeListener(_onScheme);
    WidgetsBinding.instance.removeObserver(this);
    _fade.dispose();
    _before?.dispose();
    super.dispose();
  }

  // A scheme chosen in the menu's Colours: the app in it at once.
  void _onScheme() => setState(() {});

  void _onSystem() {
    final system = widget.controller.value;
    final side = _wanted;
    if (system == _system && side == _side) return;
    final screen = _screen.currentContext?.findRenderObject();
    final before = screen is _RenderScreen
        ? screen.picture(MediaQuery.devicePixelRatioOf(context))
        : null;
    setState(() {
      _before?.dispose();
      _before = before;
      _system = system;
      _side = side;
    });
    if (before != null) _fade.forward(from: 0);
  }

  void _drop() {
    if (_before == null) return;
    setState(() {
      _before!.dispose();
      _before = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final motion = widget.base.motion;
    final light = _side == Brightness.light;
    // Set before anything below is built, which reads it.
    Legible.light = light;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The phone's own bars: dark marks on the light side, light on the
      // dark. On the light side the status bar is left clear and the
      // strip under the bar takes the bar's colour, so no dark band or
      // grey veil crosses the paper.
      value: light
          ? SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: const Color(0x00000000),
              systemNavigationBarColor: _system.on(_side).surface,
              systemNavigationBarIconBrightness: Brightness.dark,
            )
          : SystemUiOverlayStyle.light,
      child: SmTheme(
        data: widget.base.withColors(_system.on(_side)),
        // Anything touched during the fade is shown as it is, at once.
        child: Listener(
          onPointerDown: (_) => _drop(),
          // The picture takes in the fade itself, so a change that comes in
          // the middle of one starts from what is showing, not from a jump.
          child: _Screen(
            key: _screen,
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.child,
                if (_before != null)
                  IgnorePointer(
                    // Faded by the image's own opacity: no extra layer.
                    child: RawImage(
                      key: const ValueKey('colour-shift'),
                      image: _before,
                      fit: BoxFit.fill,
                      opacity: ReverseAnimation(
                        CurvedAnimation(
                          parent: _fade,
                          curve: motion.shiftCurve,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A part of the screen that can hand over a picture of itself as it was
/// last painted.
class _Screen extends SingleChildRenderObjectWidget {
  const _Screen({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderScreen();
}

class _RenderScreen extends RenderRepaintBoundary {
  ui.Image? picture(double pixelRatio) {
    final layer = this.layer;
    if (layer is! OffsetLayer || !hasSize || size.isEmpty) return null;
    return layer.toImageSync(Offset.zero & size, pixelRatio: pixelRatio);
  }
}
