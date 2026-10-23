import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';

import 'calendar_system.dart';
import 'day_reading.dart';
import 'journal/entry.dart';
import 'journal/journal_store.dart';
import 'practice/practice.dart';
import 'reminders/reminder_store.dart';
import 'strings.dart';

/// What the app has standing in the phone's own surfaces, outside
/// itself: on an iPhone the Dynamic Island and the lock screen widgets;
/// on Android a notification that stays put, with its clock running.
///
/// The app only says what should be there; the phone's side draws it. A
/// phone with no such surface simply does not answer, and nothing
/// happens.
///
/// **The island** is for one thing only: a practice under way. A
/// stopwatch counts up in it, a countdown counts down. With no practice
/// there is nothing in it. Tapping it opens the practice.
///
/// **The widgets** are given the coming days as every calendar reads
/// them, worked out here, since the phone's side cannot run the
/// calendars itself.
class PhoneSurfaces with WidgetsBindingObserver {
  static const _island = MethodChannel('candra/island');
  static const _widgets = MethodChannel('candra/widgets');

  /// How many days ahead the widgets are told about. They are told again
  /// every time the app is opened.
  static const daysAhead = 30;

  final JournalStore journal;
  final ReminderStore reminders;
  final LanguageController language;

  /// Called when the island is tapped: to show the practice.
  final VoidCallback? onOpenPractice;

  PhoneSurfaces({
    required this.journal,
    required this.reminders,
    required this.language,
    this.onOpenPractice,
  });

  /// Shows what there is to show now, and again whenever it changes or
  /// the app comes back to the front.
  void attach() {
    WidgetsBinding.instance.addObserver(this);
    PracticeTimer.running.addListener(refresh);
    reminders.addListener(refresh);
    language.addListener(refresh);
    _island.setMethodCallHandler((call) async {
      if (call.method == 'opened') onOpenPractice?.call();
    });
    refresh();
    // Opened by a tap on the island, from cold.
    _island
        .invokeMethod<bool>('launched')
        .then((launched) {
          if (launched == true) onOpenPractice?.call();
        })
        .catchError((Object _) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    final now = PracticeTimer.now();
    final strings = Strings(language.value);
    try {
      final content = island(strings);
      if (content == null) {
        await _island.invokeMethod<void>('end');
      } else {
        await _island.invokeMethod<void>('show', content);
      }
      await _widgets.invokeMethod<void>('publish', {
        'days': jsonEncode(days(now, strings)),
      });
    } on MissingPluginException {
      // A phone without these surfaces.
    } on PlatformException {
      // One that will not have them just now: switched off, or too many.
    }
  }

  /// What the island should show, or null for nothing.
  Map<String, Object?>? island(Strings strings) {
    final practice = PracticeTimer.running.value;
    // Over, and waiting in the app to be written or discarded: no longer
    // running on the island.
    if (practice == null || practice.finished(PracticeTimer.now())) {
      return null;
    }
    final category = journal.category(practice.categoryId);
    return {
      'title': category?.name ?? strings.practiceTitle,
      'detail': strings.practiceTitle,
      'color': (category?.color ?? const Color(0xFFD9D9D2)).toARGB32(),
      // A stopwatch counts up from here; a countdown, down to its end.
      'start': practice.startedAt.millisecondsSinceEpoch,
      'end': practice.endsAt?.millisecondsSinceEpoch,
    };
  }

  /// The days from [now] on, as the widgets show them.
  List<Map<String, Object?>> days(DateTime now, Strings strings) {
    final today = CivilDate(now.year, now.month, now.day);
    return [
      for (var ahead = 0; ahead < daysAhead; ahead++)
        _day(today.addDays(ahead), now.timeZoneOffset, strings),
    ];
  }

  Map<String, Object?> _day(CivilDate date, Duration offset, Strings strings) {
    final weton = Weton.of(date);
    final moon = Moon.of(date, utcOffset: offset);
    final hijri = HijriDate.supports(date) ? HijriDate.of(date) : null;
    final chinese = ChineseDate.supports(date) ? ChineseDate.of(date) : null;
    final javanese = JavaneseDate.supports(date) ? JavaneseDate.of(date) : null;
    String two(int value) => value.toString().padLeft(2, '0');
    String label(CalendarSystem system) =>
        strings.systemLabel(system).toUpperCase();
    return {
      'date': '${date.year}-${two(date.month)}-${two(date.day)}',
      'day': date.day,
      'month': strings.monthNames[date.month - 1],
      'year': date.year,
      'weekday': strings.weekdayName(weton.weekday),
      'sunday': weton.weekday == Weekday.values.last,
      'weton': '$weton',
      'pasaran': weton.pasaran.label,
      'neptu': weton.neptu,
      // Each system in two lines, as the day sheet has them.
      'hijriLabel': label(CalendarSystem.hijri),
      'hijriDay': hijri == null
          ? ''
          : '${hijri.day} ${strings.hijriMonth(hijri.month)}',
      'hijriYear': hijri == null ? '' : strings.hijriYear(hijri),
      'chineseLabel': label(CalendarSystem.chinese),
      // The day in the Hokkien month names, and in characters.
      'chineseDay': chinese == null
          ? ''
          : '${chinese.day} ${chinese.monthLabel}',
      'chineseHanzi': chinese == null ? '' : Strings.chineseHanzi(chinese),
      'zodiac': chinese == null ? '' : strings.zodiac(chinese),
      // The day's element in full, yin or yang, and its colour.
      'element': strings.dayElement(date),
      'elementHanzi': Strings.dayElementHanzi(date),
      // Which of the eight phases, new moon being 0.
      'moonIndex': moon.phase.index,
      'elementColor': elementColors[ChineseDate.dayUnsur(date)]!.toARGB32(),
      'javaneseLabel': label(CalendarSystem.javanese),
      'javaneseDay': javanese == null
          ? ''
          : '${javanese.day} ${javanese.month.label}',
      'javaneseYear': javanese == null ? '' : strings.javaneseYear(javanese),
      'wetonLabel': label(CalendarSystem.weton),
      'moon': strings.moonPhase(moon.phase),
      'lit': (moon.illumination * 100).round(),
      // A dot for each category with a reminder that day, as the month
      // grid has them.
      'dots': [
        for (final category in byHue(
          reminders.marksOn(date, journal.categories).take(4),
        ))
          category.color.toARGB32(),
      ],
    };
  }
}
