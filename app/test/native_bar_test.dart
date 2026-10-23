import 'dart:convert';

import 'package:candra/app_shell.dart';
import 'package:candra/main.dart';
import 'package:candra/month_screen.dart';
import 'package:candra/strings.dart';
import 'package:candra/system_button.dart';
import 'package:candra/glyph_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacred_time/sacred_time.dart';

/// What the app hands the iPhone's own bar (`NativeBar`), read as the
/// phone reads it.
void main() {
  const bar = MethodChannel('candra/bar');

  Future<List<Map<String, Object?>>> open(
    WidgetTester tester, {
    Size physical = const Size(1440, 3040),
    double ratio = 3.5,
  }) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = physical;
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
    final shows = <Map<String, Object?>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(bar, (
      call,
    ) async {
      if (call.method == 'show') {
        shows.add(jsonDecode(call.arguments as String) as Map<String, Object?>);
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        bar,
        null,
      ),
    );
    await tester.pumpWidget(
      CalendarJournalApp(
        controller: SystemController(),
        language: LanguageController(saved: AppLanguage.en),
        home: MonthScreen(
          today: CivilDate(2026, 10, 15),
          utcOffset: const Duration(hours: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return shows;
  }

  List<Map<String, Object?>> itemsOf(Map<String, Object?> reading) =>
      (reading['items']! as List).cast<Map<String, Object?>>();

  // Every frame of a transition, as the phone was told of it.
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
  }

  // The glass stands at the reading's top: through a change in the bar it
  // is the same on every frame.
  void expectStill(List<Map<String, Object?>> shows, Object? top) {
    expect(shows, isNotEmpty);
    expect({for (final show in shows) show['top']}, {top});
  }

  Map<String, Map<String, Object?>> byId(Map<String, Object?> reading) => {
    for (final item in itemsOf(reading)) item['id']! as String: item,
  };

  testWidgets('the glass holds still while the system picker opens and '
      'closes: only the system at the centre gives way to its tick', (
    tester,
  ) async {
    final shows = await open(tester);
    final before = shows.last;
    expect(byId(before).keys, contains('system-label'));
    shows.clear();
    tester
        .widget<SystemButton>(find.byKey(const ValueKey('system-label')))
        .onTap();
    await frames(tester);
    // The tick fades in where the system was, over several frames.
    expect(shows.length, greaterThan(3));
    expectStill(shows, before['top']);
    final opened = byId(shows.last);
    expect(opened.keys, contains('picker-done'));
    expect(opened.keys, isNot(contains('system-label')));
    expect(
      opened['picker-done']!['x']! as double,
      closeTo(byId(before)['system-label']!['x']! as double, 20),
    );
    // Everything else as it was.
    expect(
      opened.keys.toSet().difference({'picker-done'}),
      byId(before).keys.toSet().difference({'system-label'}),
    );

    shows.clear();
    tester
        .widget<GlyphButton>(find.byKey(const ValueKey('picker-done')))
        .onTap();
    await frames(tester);
    expectStill(shows, before['top']);
    expect(byId(shows.last).keys, contains('system-label'));
    expect(byId(shows.last).keys, isNot(contains('picker-done')));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the glass holds still while the utilities open: the bar '
      'keeps its buttons, and the utilities\' is lit from behind', (
    tester,
  ) async {
    final shows = await open(tester);
    final before = shows.last;
    expect(byId(before)['system-label']!['selected'], isTrue);
    expect(byId(before)['utilities-button']!['selected'], isFalse);
    shows.clear();
    tester
        .widget<GlyphButton>(find.byKey(const ValueKey('utilities-button')))
        .onTap();
    await frames(tester);
    expectStill(shows, before['top']);
    final after = byId(shows.last);
    expect(after.keys.toSet(), byId(before).keys.toSet());
    expect(after['utilities-button']!['selected'], isTrue);
    expect(after['system-label']!['selected'], isFalse);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('on an iPad upright the phone is told the phone\'s bar, '
      'scaled and centred', (tester) async {
    // The phone the layout is measured on, 412 x 869, as an iPhone
    // draws it.
    final phone = (await open(
      tester,
      physical: const Size(824, 1738),
      ratio: 2,
    )).last;
    // The iPad mini upright.
    final ipad = (await open(
      tester,
      physical: const Size(1488, 2266),
      ratio: 2,
    )).last;
    const scale = 1133 / 869;
    expect(phone['scale'], 1);
    expect(ipad['scale'], closeTo(scale, 1e-9));
    final phoneWidth = phone['w']! as double;
    // The bar's place: the phone's width scaled, at the middle.
    expect(ipad['w'], closeTo(phoneWidth * scale, 0.5));
    expect(ipad['x'], closeTo((744 - phoneWidth * scale) / 2, 0.5));
    // The glass's top, from the row's top, scaled.
    expect(ipad['top'], closeTo((phone['top']! as double) * scale, 0.5));
    final before = {for (final item in itemsOf(phone)) item['id']: item};
    final after = itemsOf(ipad);
    expect(after.map((i) => i['id']).toSet(), before.keys.toSet());
    for (final item in after) {
      final was = before[item['id']]!;
      for (final name in const ['x', 'y', 'w', 'h']) {
        expect(
          item[name],
          closeTo((was[name]! as double) * scale, 0.5),
          reason: '${item['id']} $name',
        );
      }
      // The centre pill is still the centre's.
      expect(item['prominent'], was['prominent']);
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
