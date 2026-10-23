import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'bar_button.dart';
import 'calendar_system.dart';
import 'glyph_button.dart';
import 'native_bar.dart';
import 'system_button.dart';
import 'practice/practice.dart';
import 'app_shell.dart';

/// A walk through the app by itself, for looking at a phone that cannot
/// be seen or touched from the desk: only a build made with
/// `--dart-define=TOUR=1` does it. It taps its way through every screen,
/// keeps a picture of each as Flutter drew it, notes every error the
/// framework reports on the way, and leaves the lot in the app's
/// documents under `tour/`, to be copied off the phone.
///
/// The pictures are of the app's own drawing: the system's bars, the
/// keyboard and anything else the phone draws over it are not in them.
/// What room the phone takes is in `report.json` instead.
abstract final class Tour {
  static const enabled = String.fromEnvironment('TOUR') != '';

  static final boundary = GlobalKey();
  static final _errors = <String>[];
  static final _steps = <Map<String, Object?>>[];
  static late Directory _folder;

  /// Wraps the app so that it can be pictured.
  static Widget wrap(Widget app) =>
      enabled ? RepaintBoundary(key: boundary, child: app) : app;

  static Future<void> _wait([int milliseconds = 900]) =>
      Future<void>.delayed(Duration(milliseconds: milliseconds));

  // Every element on the screen that passes [test], top of the tree first.
  static List<Element> _find(bool Function(Widget widget) test) {
    final found = <Element>[];
    void visit(Element element) {
      if (test(element.widget)) found.add(element);
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement!.visitChildren(visit);
    return found;
  }

  // Where on the screen an element is, if it is on it at all.
  static Rect? _rectOf(Element element) {
    final box = element.renderObject;
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final screen = Offset.zero & view.physicalSize / view.devicePixelRatio;
    return screen.contains(rect.center) ? rect : null;
  }

  static int _pointer = 100;

  static Future<bool> _tapAt(Offset at) async {
    final pointer = _pointer++;
    GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(pointer: pointer, position: at),
    );
    await _wait(60);
    GestureBinding.instance.handlePointerEvent(
      PointerUpEvent(pointer: pointer, position: at),
    );
    await _wait();
    return true;
  }

  static Future<bool> _tap(bool Function(Widget widget) test) async {
    // The last match is the one drawn on top.
    for (final element in _find(test).reversed) {
      // A bar button on an iPhone is drawn and touched by the phone, not
      // by the app: it is pressed by calling what it would call.
      final widget = element.widget;
      final press = switch (widget) {
        GlyphButton() => widget.onTap,
        SystemButton() => widget.onTap,
        BarButton() => widget.onTap,
        _ => null,
      };
      if (press != null &&
          element.findAncestorWidgetOfExactType<NativeBar>() != null) {
        press();
        await _wait();
        return true;
      }
      final rect = _rectOf(element);
      if (rect != null) return _tapAt(rect.center);
    }
    return false;
  }

  static Future<bool> key(String name) =>
      _tap((widget) => widget.key == ValueKey(name));

  /// Scrolls [name] into sight, in whatever list holds it, then touches
  /// it.
  static Future<bool> reveal(String name) async {
    final found = _find((widget) => widget.key == ValueKey(name));
    if (found.isEmpty) return false;
    await Scrollable.ensureVisible(
      found.last,
      duration: const Duration(milliseconds: 200),
      alignment: 0.5,
    );
    await _wait(400);
    return key(name);
  }

  /// Touches the first thing on screen that is touched where it stands
  /// and whose key begins with [prefix], less those [but] names: a tile
  /// of the journal or the reminders, whatever is written there.
  static Future<bool> tile(String prefix, {List<String> but = const []}) async {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    for (final element in _find((widget) {
      final key = widget.key;
      return widget is GestureDetector &&
          key is ValueKey<String> &&
          key.value.startsWith(prefix) &&
          !but.any(key.value.startsWith);
    })) {
      final rect = _rectOf(element);
      if (rect == null) continue;
      // Only one that a touch at its middle would reach, not one behind
      // another.
      final hit = HitTestResult();
      WidgetsBinding.instance.hitTestInView(hit, rect.center, view.viewId);
      if (hit.path.any((entry) => entry.target == element.renderObject)) {
        return _tapAt(rect.center);
      }
    }
    return false;
  }

  /// Puts the keyboard away, keeping what was typed.
  static Future<bool> keyboardAway() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _wait(1200);
    return true;
  }

  /// What the phone's back gesture would do on the screen in front:
  /// one step back, never a save.
  static Future<bool> back(BuildContext context) async {
    // As the phone's own back: the house hands it to the room in front.
    final went = await Navigator.of(context, rootNavigator: true).maybePop();
    await _wait();
    return went;
  }

  /// Touches a field, so that the keyboard comes up, and waits for it.
  static Future<bool> typeIn(String name) async {
    final went = await key(name);
    await _wait(1200);
    return went;
  }

  /// Touches the thing on top whose key begins with [prefix]: one of
  /// many alike, whatever its name (a category's pencil).
  static Future<bool> prefixed(String prefix) => _tap((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith(prefix);
  });

  static Future<bool> text(String words) =>
      _tap((widget) => widget is Text && widget.data == words);

  /// Keeps a picture of the app as it stands, and where its parts are.
  static Future<void> shot(String name) async {
    await _wait(400);
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('${_folder.path}/$name.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
    final media = MediaQueryData.fromView(
      WidgetsBinding.instance.platformDispatcher.views.first,
    );
    _steps.add({
      'shot': name,
      'viewInsets': _edges(media.viewInsets),
      'errorsSoFar': _errors.length,
    });
  }

  // Left, top, right, bottom, as numbers: a profile build keeps no
  // words for what the framework's own values are.
  static List<double> _edges(EdgeInsets edges) => [
    edges.left,
    edges.top,
    edges.right,
    edges.bottom,
  ];

  static Future<void> _step(String name, Future<Object?> Function() run) async {
    try {
      final result = await run();
      _steps.add({'step': name, 'result': '$result'});
    } catch (error) {
      _steps.add({'step': name, 'threw': '$error'});
    }
    _save();
  }

  static void _save() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final media = MediaQueryData.fromView(view);
    File('${_folder.path}/report.json').writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert({
        'platform': Platform.operatingSystem,
        'version': Platform.operatingSystemVersion,
        'size': [media.size.width, media.size.height],
        'devicePixelRatio': media.devicePixelRatio,
        'padding': _edges(media.padding),
        'viewPadding': _edges(media.viewPadding),
        'refreshRate': view.display.refreshRate,
        'steps': _steps,
        'errors': _errors,
      }),
    );
  }

  /// Walks the app. Called once, after the first frame.
  static Future<void> run(BuildContext Function() context) async {
    final documents = await getApplicationDocumentsDirectory();
    _folder = Directory('${documents.path}/tour');
    if (_folder.existsSync()) _folder.deleteSync(recursive: true);
    _folder.createSync(recursive: true);

    final reported = FlutterError.onError;
    FlutterError.onError = (details) {
      _errors.add(details.exceptionAsString().split('\n').take(6).join(' | '));
      reported?.call(details);
    };
    await _wait(2500);

    Future<void> see(String name, [Future<bool> Function()? go]) =>
        _step(name, () async {
          final went = go == null ? true : await go();
          if (went) await shot(name);
          return went;
        });
    SystemController systems() => SystemScope.of(context());

    await see('01-month');
    // The grid draws its numbers itself, so there is no text to find:
    // the 12th is the first cell of the third row.
    await see('02-month-12', () async {
      final grid = _rectOf(
        _find((w) => w.key == const ValueKey('month-view')).first,
      )!;
      return _tapAt(
        grid.topLeft +
            Offset(grid.width / 14, 20 + (grid.height - 20) * 2.5 / 6),
      );
    });
    await see('03-year', () => key('zoom-button'));
    await see('04-day', () => key('zoom-button'));
    await see('05-month-again', () => key('zoom-button'));
    await see('06-date-picker', () => key('month-button'));
    await _step('close date picker', () => key('month-button'));
    await see('07-system-picker', () => key('system-label'));
    await _step('close system picker', () => key('picker-done'));
    await see('08-reading', () => key('expand-reading'));
    await _step('close reading', () => back(context()));

    // Out of a utility, and its cards let down: two steps back.
    Future<bool> home() async {
      await back(context());
      return back(context());
    }

    await _step('to chinese', () async {
      systems().value = CalendarSystem.chinese;
      await _wait();
      return true;
    });
    await see('09-month-chinese');
    await see('10-utilities', () => key('utilities-button'));
    await see('10-bazi', () => key('utility-bazi'));
    await see('11-bazi-place', () => key('bazi-field-place'));
    await see('12-bazi-rules', () => key('bazi-field-rules'));
    await see('13-bazi-sex', () => key('bazi-field-sex'));
    await _step('close bazi', home);

    // Every other utility, each by its card, and the tabs added in 1.2.2.
    Future<void> system(CalendarSystem to) => _step('to ${to.name}', () async {
      systems().value = to;
      await _wait();
      return true;
    });
    Future<bool> open(String utility) async {
      await key('utilities-button');
      return reveal('utility-$utility');
    }

    await system(CalendarSystem.javanese);
    await see('27-mangsa', () => open('mangsa'));
    await _step('close mangsa', home);
    await see('28-lintang', () => open('lintang'));
    await see('28b-lintang-waluku', () => key('lintang-waluku'));
    await _step('lintang mangsa tab', () => reveal('stars-panel-mangsa'));
    await _wait(3000);
    await see('28c-lintang-mangsa');
    await _step('close lintang', home);
    await system(CalendarSystem.hijri);
    await see('29-salat', () => open('salat'));
    await _step('close salat', home);
    await system(CalendarSystem.gregorian);
    await see('30-ephemeris', () => open('sky'));
    await _step('close ephemeris', home);
    await see('31-stars', () => open('stars'));
    await see('31b-stars-bright', () => reveal('stars-panel-bright'));
    await see('31c-stars-reading', () => key('stars-bright-0'));
    await _step('back to the list', () => back(context()));
    await _step('close stars', home);
    await see('32-light', () => open('light'));
    for (final tab in const ['shadow', 'moon', 'milkyWay', 'align']) {
      await see('32-light-$tab', () async {
        final went = await reveal('light-panel-$tab');
        await _wait(2500);
        return went;
      });
    }
    await see('32-light-place', () => reveal('light-panel-place'));
    await see('33-place-finder', () => key('place-find'));
    await _step('leave the finder', () => back(context()));
    await _step('close light', home);

    // The journal, and everything in it that is pictured, with nothing
    // ever saved: entries and reminders are opened, edited and left by
    // the way back, and what is new is never kept.
    Future<bool> leave() => back(context());
    await see('14-journal', () => key('journal-button'));
    // Whatever entry is in front, read.
    await see('15-entry', () => tile('entry-'));
    // Editing starts with the writing in hand, the keyboard up.
    await see('16-entry-edit', () async {
      final went = await key('entry-edit');
      await _wait(1200);
      return went;
    });
    await see('16b-entry-edit-keyboard-down', keyboardAway);
    await see('17-entry-typing', () => typeIn('entry-title'));
    await _step('put the keyboard away', keyboardAway);
    await see('17b-entry-when', () => key('entry-when-change'));
    await _step('leave the entry unsaved', leave);
    await see('18-after-entry');
    // A new entry, never saved.
    await see('18a-new-entry', () async {
      final went = await key('new-entry');
      await _wait(1200);
      return went;
    });
    await see('18a2-new-entry-keyboard-down', keyboardAway);
    await see('18a3-new-entry-title', () => typeIn('entry-title'));
    await _step('put the keyboard away', keyboardAway);
    await _step('leave the new entry unsaved', leave);
    // The categories, and a new one begun and let go.
    await see('18b-categories', () => key('categories'));
    await see('18b2-category-new', () async {
      final went = await key('category-add');
      await _wait(1200);
      return went;
    });
    await see('18b3-category-new-keyboard-down', keyboardAway);
    await see('18b4-category-name', () => typeIn('category-name'));
    await _step('put the keyboard away', keyboardAway);
    await _step('let the new category go', leave);
    // A category there is, opened for changes and let go unsaved.
    await see('18b5-category-edit', () => prefixed('category-'));
    await see('18b6-category-edit-typing', () => typeIn('category-name'));
    await _step('put the keyboard away', keyboardAway);
    await _step('let the category go unsaved', leave);
    await _step('leave categories', leave);
    // The search, every field of its panel, and its three views.
    await see('34-search', () => key('journal-search'));
    for (final look in const ['reminders', 'both', 'entries']) {
      await see('34-search-look-in-$look', () => reveal('search-field-lookIn'));
    }
    for (final field in const ['category', 'tags', 'day', 'evening', 'when']) {
      await see('34-search-$field', () => reveal('search-field-$field'));
    }
    await see('34-search-words', () async {
      final went = await reveal('search-field-words');
      await _wait(1200);
      return went;
    });
    await see('34-search-words-done', () => key('search-words-done'));
    await see('34-search-month', () => key('search-view'));
    await see('34-search-year', () => key('search-view'));
    await _step('search list again', () => key('search-view'));
    await _step('leave search', () => back(context()));
    await see('18c-journal-again');
    await see('19-reminders', () => key('reminder-button'));
    // Whatever reminder is in front; its bell is never touched.
    await see(
      '20-reminder',
      () =>
          tile('reminder-', but: const ['reminder-toggle-', 'reminder-time-']),
    );
    await see('20b-reminder-category', () => key('field-category'));
    await see('20c-reminder-category-typing', () => typeIn('reminder-title'));
    await _step('put the keyboard away', keyboardAway);
    await see('20d-reminder-time', () => key('field-time'));
    await see('20e-reminder-time-typing', () => typeIn('reminder-title'));
    await _step('put the keyboard away', keyboardAway);
    // By the sun, and by the planetary hour; never saved.
    await see('20f-reminder-sunset', () => reveal('reminder-anchor-sunset'));
    await see('20g-reminder-sunset-typing', () => typeIn('reminder-title'));
    await _step('put the keyboard away', keyboardAway);
    await see(
      '20h-reminder-planetary',
      () => reveal('reminder-anchor-planetaryHour'),
    );
    await see('20i-reminder-planetary-typing', () => typeIn('reminder-title'));
    await _step('put the keyboard away', keyboardAway);
    await _step('close reminder', () => back(context()));
    await see('21-new-reminder', () => key('reminder-add'));
    await see('21b-new-reminder-typing', () => typeIn('reminder-title'));
    await _step('put the keyboard away', keyboardAway);
    await see('21c-new-reminder-category', () => key('field-category'));
    await see(
      '21d-new-reminder-category-typing',
      () => typeIn('reminder-title'),
    );
    await _step('put the keyboard away', keyboardAway);
    await _step('close new reminder', () => back(context()));
    await _step('leave reminders', () => key('system-label'));
    await see('22-menu', () => key('menu-button'));
    await see('22-journal-file', () => key('menu-data'));
    await _step('leave journal file', () => back(context()));
    await _step('leave menu', () => key('system-label'));
    await see('23-home');

    await see('24-practice', () => key('practice-button'));
    await see('24b-countdown', () => key('practice-countdown'));
    await _step('stopwatch again', () => key('practice-stopwatch'));
    await _step('start a practice', () => key('practice-start'));
    await _wait(3000);
    await see('25-practice-running');
    await _step('widgets told', () async {
      await const MethodChannel('candra/widgets')
          .invokeMethod<void>('publish', {'days': '[]'});
      return 'told';
    });
    // Thrown away, so the tour leaves nothing in the journal.
    await _step('discard the practice', () async {
      PracticeTimer.discard();
      await _wait();
      return key('system-label');
    });
    await see('26-after-practice');

    // What the phone's own side answers, where nothing has to be asked
    // of the user for it.
    await _step('clock zone', () async {
      return const MethodChannel('candra/clock').invokeMethod<String>('zone');
    });
    _steps.add({'done': true, 'debug': kDebugMode});
    _save();
  }
}
