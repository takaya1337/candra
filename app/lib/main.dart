import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sm_design/sm_design.dart';

import 'app_shell.dart';
import 'appearance.dart';
import 'house.dart';
import 'first_run.dart';
import 'calendar_system.dart';
import 'colour_schemes.dart';
import 'journal/journal_storage.dart';
import 'journal/samples.dart';
import 'journal/showcase_text.dart';
import 'menu/manual_screen.dart';
import 'tour.dart';
import 'phone_surfaces.dart';
import 'practice/practice.dart';
import 'moment_stamp.dart';
import 'planets/planet_look.dart';
import 'reminders/announcer.dart';
import 'strings.dart';
import 'journal/journal_store.dart';
import 'month_screen.dart';
import 'reminders/rearm.dart';
import 'reminders/reminder_store.dart';
import 'salat/salat_choice.dart';
import 'sky_place.dart';
import 'sync/sync_controller.dart';
import 'scroll_bars.dart';
import 'look.dart';
import 'shots.dart';
import 'review_walk.dart';
import 'sigil.dart';

const _lockedSystemKey = 'locked_calendar_system';
const _lockedViewKey = 'locked_view';
const _appearanceKey = 'appearance';
const _guideOfferedKey = 'guide_offered';
const _sigilShownKey = 'sigil_shown';
const _practiceTallyKey = 'practice_tally';
const _salatMethodKey = 'salat_method';
const _coloursKey = 'colour_schemes';
const _salatMadhabKey = 'salat_madhab';
const _salatHighLatitudeKey = 'salat_high_latitude';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final saved = preferences.getString(_lockedSystemKey);
  final savedLanguage = preferences.getString(languageKey);
  // The place the sun's and moon's times are worked out for, if one was
  // ever set; kept whenever it changes.
  final skyLatitude = preferences.getDouble(SkyPlace.latitudeKey);
  final skyLongitude = preferences.getDouble(SkyPlace.longitudeKey);
  if (skyLatitude != null && skyLongitude != null) {
    SkyPlace.current.value = (latitude: skyLatitude, longitude: skyLongitude);
  }
  SkyPlace.current.addListener(() {
    final place = SkyPlace.current.value;
    if (place == null) return;
    preferences
      ..setDouble(SkyPlace.latitudeKey, place.latitude)
      ..setDouble(SkyPlace.longitudeKey, place.longitude);
  });
  // The store's screenshots are taken at a fixed place, never the
  // phone's own.
  if (Shots.enabled) {
    SkyPlace.current.value = SkyPlace.rounded(Shots.latitude, Shots.longitude);
  }
  // Each calendar's colour scheme, if any was changed.
  ColourChoice.decode(preferences.getString(_coloursKey));
  ColourChoice.chosen.addListener(
    () => preferences.setString(_coloursKey, ColourChoice.encode()),
  );

  // Whether the star map shows the planets.
  PlanetLook.shown.value = preferences.getBool(PlanetLook.shownKey) ?? true;
  PlanetLook.shown.addListener(
    () => preferences.setBool(PlanetLook.shownKey, PlanetLook.shown.value),
  );

  // How prayer times are reckoned outside Indonesia, once chosen.
  T? named<T extends Enum>(List<T> values, String key) {
    final name = preferences.getString(key);
    return values.where((v) => v.name == name).firstOrNull;
  }

  SalatChoice.method.value = named(SalatMethod.values, _salatMethodKey);
  SalatChoice.madhab.value =
      named(Madhab.values, _salatMadhabKey) ?? Madhab.standard;
  SalatChoice.highLatitude.value = named(
    HighLatitudeRule.values,
    _salatHighLatitudeKey,
  );
  SalatChoice.all.addListener(() {
    void keep(String key, Enum? value) => value == null
        ? preferences.remove(key)
        : preferences.setString(key, value.name);
    keep(_salatMethodKey, SalatChoice.method.value);
    keep(_salatMadhabKey, SalatChoice.madhab.value);
    keep(_salatHighLatitudeKey, SalatChoice.highLatitude.value);
  });
  // The journal lives in the app's own folder, which no other app can read.
  final root = await getApplicationSupportDirectory();
  final journal = JournalStore(FileJournalStorage.open(root));
  // Each new entry and reminder keeps the moment it was first saved;
  // its sky only from the entry's own geotag.
  journal.stamp = (geotag) => MomentStamp.of(
    DateTime.now(),
    utcOffset: DateTime.now().timeZoneOffset,
    geotag: geotag == null
        ? null
        : (latitude: geotag.latitude, longitude: geotag.longitude),
  );
  // Does nothing in an ordinary build. The showcase is laid out around
  // today, so the app agrees with the phone's own status bar, in the
  // screenshots' language.
  final started = DateTime.now();
  final today = CivilDate.fromDateTime(started);
  final showcaseText = Samples.mode == 'showcase'
      ? ShowcaseText.parse(
          await rootBundle.loadString(ShowcaseText.asset),
          Shots.enabled ? Shots.language : AppLanguage.en,
        )
      : null;
  Samples.apply(
    journal,
    root,
    DateTime.now().timeZoneOffset,
    today: today,
    now: started.hour * 60 + started.minute,
    showcaseText: showcaseText,
  );
  // Kept in the journal folder, so a copy of the journal has them too.
  final reminders = ReminderStore(
    // Each day by its own clock, where the clocks change.
    zoneOffset: (d) => DateTime(d.year, d.month, d.day, 12).timeZoneOffset,
    // The sun's reminders follow the place.
    placeOf: () => SkyPlace.current.value,
    file: File('${journal.journalPath}/reminders.json'),
    announcer: PhoneAnnouncer(),
    utcOffset: DateTime.now().timeZoneOffset,
  );
  reminders.stamp = () =>
      MomentStamp.of(DateTime.now(), utcOffset: DateTime.now().timeZoneOffset);
  SkyPlace.current.addListener(reminders.announce);

  // Does nothing in an ordinary build.
  Samples.applyShowcaseReminders(
    reminders,
    journal,
    today: today,
    text: showcaseText,
    utcOffset: DateTime.now().timeZoneOffset,
  );
  Samples.applySearch(journal, reminders, root, DateTime.now().timeZoneOffset);

  // The reminders' coming days are handed over again in the background
  // as well, so they keep coming however long the app stays closed.
  unawaited(scheduleRearm());

  // A sync token left in the Keychain by an earlier install goes, before
  // sync reads it.
  await FirstRun.clearLeftovers(preferences: preferences, root: root);

  // Does nothing, and touches no network, until it is set up.
  final sync = SyncController(
    root: root,
    journal: journal,
    reminders: reminders,
  );
  unawaited(sync.start());

  // A practice begun before the app was last closed is still running.
  final practiceStarted = preferences.getInt(practiceStartedKey);
  final practiceCategory = preferences.getString(practiceCategoryKey);
  final practiceLength = preferences.getInt(practiceLengthKey);
  final practiceEnded = preferences.getInt(practiceEndedKey);
  if (practiceStarted != null && practiceCategory != null) {
    PracticeTimer.running.value = Practice(
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        practiceStarted,
        isUtc: true,
      ),
      categoryId: practiceCategory,
      length: practiceLength == null ? null : Duration(seconds: practiceLength),
      // Stopped, and still waiting to be written or discarded.
      endedAt: practiceEnded == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(practiceEnded, isUtc: true),
    );
  }
  PracticeTimer.running.addListener(() {
    final practice = PracticeTimer.running.value;
    if (practice == null) {
      preferences
        ..remove(practiceStartedKey)
        ..remove(practiceCategoryKey)
        ..remove(practiceLengthKey)
        ..remove(practiceEndedKey);
    } else {
      preferences
        ..setInt(practiceStartedKey, practice.startedAt.millisecondsSinceEpoch)
        ..setString(practiceCategoryKey, practice.categoryId);
      if (practice.length == null) {
        preferences.remove(practiceLengthKey);
      } else {
        preferences.setInt(practiceLengthKey, practice.length!.inSeconds);
      }
      final ended = practice.endedAt;
      if (ended == null) {
        preferences.remove(practiceEndedKey);
      } else {
        preferences.setInt(practiceEndedKey, ended.millisecondsSinceEpoch);
      }
    }
    // A countdown's end is announced like a reminder.
    reminders.announce();
  });

  // The tally stands where it was left.
  PracticeTally.count.value = preferences.getInt(_practiceTallyKey) ?? 0;
  PracticeTally.count.addListener(
    () => preferences.setInt(_practiceTallyKey, PracticeTally.count.value),
  );

  // The sigil traces itself once, the first time the app is ever opened.
  // Not in the builds that walk the app on their own.
  // The walk recorded for App Review opens on it every time.
  SigilOpening.showing.value =
      ReviewWalk.enabled ||
      !Shots.enabled &&
          !Tour.enabled &&
          !Look.enabled &&
          !(preferences.getBool(_sigilShownKey) ?? false);
  SigilOpening.showing.addListener(() {
    if (!SigilOpening.showing.value) preferences.setBool(_sigilShownKey, true);
  });

  // The guide is offered once, the first time the app is opened.
  Manual.offered.value =
      !Shots.enabled &&
      !ReviewWalk.enabled &&
      !(preferences.getBool(_guideOfferedKey) ?? false);
  Manual.offered.addListener(() {
    if (!Manual.offered.value) preferences.setBool(_guideOfferedKey, true);
  });

  final language = LanguageController(
    saved: Shots.enabled
        ? Shots.language
        // App Review reads English.
        : ReviewWalk.enabled
        ? AppLanguage.en
        : AppLanguage.values.where((l) => l.name == savedLanguage).firstOrNull,
    onChange: (language) => preferences.setString(languageKey, language.name),
  );
  // Dark or light, once chosen; the phone's side until then.
  final appearance = AppearanceController(
    saved: Shots.enabled
        ? Brightness.dark
        : Brightness.values
              .where((b) => b.name == preferences.getString(_appearanceKey))
              .firstOrNull,
    onChange: (chosen) => chosen == null
        ? preferences.remove(_appearanceKey)
        : preferences.setString(_appearanceKey, chosen.name),
  );
  final home = GlobalKey();
  // A countdown's end, among what the phone is given to announce.
  reminders.alsoAnnounce = () {
    final practice = PracticeTimer.running.value;
    final ends = practice?.endsAt;
    if (practice == null || ends == null) return const [];
    return [
      Announcement(
        id: 1,
        when: ends.toLocal(),
        title: Strings(language.value).practiceComplete,
        body: journal.category(practice.categoryId)?.name ?? '',
      ),
    ];
  };
  // The Dynamic Island and the widgets, on a phone that has them.
  PhoneSurfaces(
    journal: journal,
    reminders: reminders,
    language: language,
    // A tap on the island shows the practice, unless it is showing.
    onOpenPractice: () {
      final context = home.currentContext;
      if (context == null) return;
      if (PracticeTimer.running.value == null) return;
      // The house goes to the practice, wherever it was.
      House.maybeOf(context)?.go(Room.practice);
    },
  ).attach();

  runApp(
    // Does nothing in an ordinary build.
    Look.wrap(
      Shots.wrap(
        Tour.wrap(
          CalendarJournalApp(
            journal: journal,
            reminders: reminders,
            sync: sync,
            controller: SystemController(
              locked: Shots.enabled
                  ? null
                  : CalendarSystem.values
                        .where((s) => s.name == saved)
                        .firstOrNull,
              onLock: (system) => system == null
                  ? preferences.remove(_lockedSystemKey)
                  : preferences.setString(_lockedSystemKey, system.name),
            ),
            language: language,
            appearance: appearance,
            home: MonthScreen(
              key: home,
              lockedView: Shots.enabled
                  ? null
                  : MonthScreenView.values
                        .where(
                          (v) =>
                              v.name == preferences.getString(_lockedViewKey),
                        )
                        .firstOrNull,
              startView: MonthScreenView.day,
              onLockView: (view) => view == null
                  ? preferences.remove(_lockedViewKey)
                  : preferences.setString(_lockedViewKey, view.name),
            ),
          ),
        ),
      ),
    ),
  );
  if (Tour.enabled) unawaited(Tour.run(() => home.currentContext!));
  if (Shots.enabled) unawaited(Shots.run(() => home.currentContext!));
  if (Look.enabled) unawaited(Look.run(() => home.currentContext!));
  if (ReviewWalk.enabled) {
    unawaited(ReviewWalk.run(() => home.currentContext!));
  }
}

class CalendarJournalApp extends StatefulWidget {
  final SystemController controller;
  final LanguageController language;

  /// Dark or light. Defaults to dark, chosen, so tests do not follow the
  /// test phone's side.
  final AppearanceController? appearance;

  /// Defaults to a journal kept in memory, with placeholder entries.
  final JournalStore? journal;

  /// Defaults to reminders kept in memory that announce nothing.
  final ReminderStore? reminders;

  /// Syncing with a repository; none in tests unless given.
  final SyncController? sync;

  /// The first screen; tests pass a [MonthScreen] with a fixed date.
  final Widget home;

  const CalendarJournalApp({
    super.key,
    required this.controller,
    required this.language,
    this.appearance,
    this.journal,
    this.reminders,
    this.sync,
    this.home = const MonthScreen(),
  });

  @override
  State<CalendarJournalApp> createState() => _CalendarJournalAppState();
}

class _CalendarJournalAppState extends State<CalendarJournalApp> {
  late final JournalStore _journal = widget.journal ?? JournalStore();
  late final ReminderStore _reminders =
      widget.reminders ??
      ReminderStore(utcOffset: DateTime.now().timeZoneOffset);
  late final AppearanceController _appearance =
      widget.appearance ?? AppearanceController(saved: Brightness.dark);

  @override
  Widget build(BuildContext context) {
    const theme = SmThemeData.dusk;

    return WidgetsApp(
      color: theme.colors.background,
      textStyle: theme.type.body.copyWith(color: theme.colors.textPrimary),
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, _, _) => builder(context),
      ),
      builder: (context, child) => Stack(
        children: [
          AppShell(
            controller: widget.controller,
            appearance: _appearance,
            language: widget.language,
            journal: _journal,
            reminders: _reminders,
            sync: widget.sync,
            child: ScrollConfiguration(
              behavior: const CandraScrollBehavior(),
              child: child!,
            ),
          ),
          // The first time ever, the sigil traces itself over the app.
          ValueListenableBuilder(
            valueListenable: SigilOpening.showing,
            builder: (context, showing, _) => showing
                ? const Positioned.fill(child: SigilOpening())
                : const SizedBox.shrink(),
          ),
        ],
      ),
      // The calendar is the living room of the house.
      home: House(
        living: widget.home,
        today: switch (widget.home) {
          final MonthScreen month => month.today,
          _ => null,
        },
        utcOffset: switch (widget.home) {
          final MonthScreen month => month.utcOffset,
          _ => null,
        },
      ),
    );
  }
}
