import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import '../action_cards.dart';
import '../bar_button.dart';
import '../glyph_button.dart';
import '../house.dart';
import '../journal/entry.dart';
import '../journal/entry_screen.dart';
import '../journal/journal_store.dart';
import '../search/tags_ui.dart';
import '../parts.dart';
import '../reminders/reminder_store.dart';
import '../routes.dart';
import '../strings.dart';
import '../time_picker.dart';
import 'practice.dart';

/// The ways a practice is kept: timed up, timed down, or counted.
enum PracticeWay { stopwatch, countdown, tally }

/// The practice: one sitting, fast or vigil timed from start to stop or
/// down to its end, or a count kept by touch; and written into the
/// journal when it is done, if wanted.
///
///  * Top bar: the name of the screen, and since when it has run.
///  * Main body: at its centre what the way chosen keeps, very large, in
///    the colour of the category: the clock; before a countdown begins,
///    the wheels that set how long; for the tally, the count. At its foot,
///    centred, start or stop (the tally: write), and under it a line on
///    what that will do. For the tally, the reset at the bottom left and
///    the tally itself at the bottom right.
///  * Lower panel: the categories, to say what kind of practice it is (it
///    can be changed while it runs); under them the three ways as cards,
///    the one chosen lit. When it is done (stopped, run out, or the count
///    to be written), the question in their place: write it into the
///    journal, or discard it.
///  * Bottom bar: the house's. The practice is a room of the house
///    (`House`), right of the living room.
///
/// Written, it becomes a journal entry, opened here in the practice's own
/// room, to be read or added to; back comes to the practice again, as the
/// bazi's chart does (owner, 20 October 2026).
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => PracticeScreenState();
}

class PracticeScreenState extends State<PracticeScreen> {
  Timer? _tick;

  // The way chosen before one begins, and a countdown's length.
  PracticeWay _way = PracticeWay.stopwatch;
  int _minutes = 20;

  // The tally's count asked to be written.
  bool _askingTally = false;

  // "Write" answered: the category it goes under is asked next.
  bool _choosing = false;

  /// How many of this screen are showing: one or none.
  static int showing = 0;

  @override
  void initState() {
    super.initState();
    showing++;
    PracticeTimer.running.addListener(_onChange);
    PracticeTally.count.addListener(_onChange);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (PracticeTimer.running.value != null && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    showing--;
    _tick?.cancel();
    PracticeTimer.running.removeListener(_onChange);
    PracticeTally.count.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String clock(Duration elapsed) =>
      '${_two(elapsed.inHours)}:${_two(elapsed.inMinutes % 60)}:'
      '${_two(elapsed.inSeconds % 60)}';

  // Begun with no category: it is chosen as it is written.
  void _start() {
    HapticFeedback.mediumImpact();
    // Its clock stands in the phone's notifications, and a countdown's
    // end is announced: the phone is asked for that, the first time.
    ReminderScope.of(context).askAllowed();
    PracticeTimer.start(
      '',
      length: _way == PracticeWay.countdown
          ? Duration(minutes: _minutes)
          : null,
    );
  }

  // Stopped: it stands as it is, and the panel asks.
  void _stop() {
    HapticFeedback.mediumImpact();
    PracticeTimer.halt();
  }

  void _askTally() {
    HapticFeedback.selectionClick();
    setState(() => _askingTally = true);
  }

  // Into the journal, under [categoryId], and the entry it has become
  // opened here, in the practice's room: back comes to the practice.
  void _write(JournalStore journal, String categoryId) {
    HapticFeedback.mediumImpact();
    final strings = Strings.of(context);
    final Entry? entry;
    if (_askingTally) {
      entry = PracticeTally.write(journal, strings, categoryId);
    } else {
      entry = PracticeTimer.stop(journal, strings, categoryId: categoryId);
    }
    setState(() {
      _askingTally = false;
      _choosing = false;
    });
    if (entry == null) return;
    Navigator.of(context).push(
      fadeRoute<String>(
        context,
        (context) => EntryScreen(
          date: entry!.date,
          utcOffset: entry.utcOffset,
          entry: entry,
        ),
      ),
    );
  }

  void _discard() {
    HapticFeedback.mediumImpact();
    _choosing = false;
    if (_askingTally) {
      PracticeTally.reset();
      setState(() => _askingTally = false);
    } else {
      PracticeTimer.discard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final strings = Strings.of(context);
    final journal = JournalScope.of(context);
    final categories = journal.categories;
    final practice = PracticeTimer.running.value;
    final now = PracticeTimer.now();

    final began = practice?.startedAt.toLocal();
    final today = began ?? now;
    final until = practice?.endsAt?.toLocal();
    final waiting = practice == null;
    // The way chosen, or the way it runs.
    final way = waiting
        ? _way
        : practice.length == null
        ? PracticeWay.stopwatch
        : PracticeWay.countdown;
    final over = practice?.finished(now) ?? false;
    final asking = over || _askingTally && way == PracticeWay.tally;
    // A stopwatch shows what has gone; a countdown, what is left.
    final shown = practice == null
        ? (way == PracticeWay.countdown
              ? Duration(minutes: _minutes)
              : Duration.zero)
        : practice.length == null
        ? practice.elapsed(now)
        : practice.length! - practice.elapsed(now);
    final count = PracticeTally.count.value;
    final ink = colors.textPrimary;

    final big = theme.type.display.copyWith(
      fontSize: 76,
      height: 1.1,
      fontWeight: FontWeight.w700,
      // Every digit as wide as the next, so the clock does not shiver
      // as it counts.
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    // What the way chosen keeps, at the centre of the body.
    final Widget kept = switch (way) {
      PracticeWay.countdown when waiting => SizedBox(
        key: const ValueKey('practice-length'),
        height: 160,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.lg),
          child: TimePicker(
            minuteOfDay: _minutes,
            onChanged: (minutes) =>
                setState(() => _minutes = minutes < 1 ? 1 : minutes),
          ),
        ),
      ),
      PracticeWay.tally => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$count',
          key: const ValueKey('practice-count'),
          style: big.copyWith(color: count > 0 ? ink : colors.textFaint),
        ),
      ),
      _ => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          clock(shown.isNegative ? Duration.zero : shown),
          key: const ValueKey('practice-clock'),
          style: big.copyWith(color: waiting ? colors.textFaint : ink),
        ),
      ),
    };

    // At the foot: start, stop, or for the tally, write.
    final Widget? act = asking || categories.isEmpty
        ? null
        : way == PracticeWay.tally
        ? GlyphButton(
            key: const ValueKey('practice-tally-write'),
            glyph: Glyph.journal,
            lit: true,
            filled: true,
            onTap: _askTally,
          )
        : waiting
        ? GlyphButton(
            key: const ValueKey('practice-start'),
            glyph: Glyph.start,
            lit: true,
            filled: true,
            onTap: _start,
          )
        : GlyphButton(
            key: const ValueKey('practice-stop'),
            glyph: Glyph.stop,
            lit: true,
            onTap: _stop,
          );
    final hint = asking
        ? ''
        : switch (way) {
            PracticeWay.tally => strings.practiceTallyChosen,
            PracticeWay.stopwatch when waiting =>
              strings.practiceStopwatchChosen,
            PracticeWay.countdown when waiting =>
              strings.practiceCountdownChosen,
            PracticeWay.stopwatch => strings.practiceRunning,
            PracticeWay.countdown => strings.practiceCountingDown,
          };

    return PopScope(
      // Back takes back the choosing of a category, then the asking to
      // write the tally; else the house's back has it.
      canPop: !_choosing && !_askingTally,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() {
          if (_choosing) {
            _choosing = false;
          } else {
            _askingTally = false;
          }
        });
      },
      child: ColoredBox(
        color: colors.background,
        child: SafeArea(
          child: FourParts(
            top: TopBar(
              key: const ValueKey('practice-top-bar'),
              leading: TopBarTitle(label: strings.practiceTitle),
              subtitle:
                  '${Weton.of(CivilDate(today.year, today.month, today.day))}'
                  '${began == null ? '' : ' · ${strings.practiceSince('${_two(began.hour)}:${_two(began.minute)}')}'}'
                  '${until == null ? '' : ' · ${strings.practiceUntil('${_two(until.hour)}:${_two(until.minute)}')}'}',
            ),
            body: Stack(
              children: [
                // What the way chosen does, at the top of the body (owner,
                // 21 October 2026).
                Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    hint,
                    key: const ValueKey('practice-hint'),
                    textAlign: TextAlign.center,
                    style: theme.type.label.copyWith(
                      color: colors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: theme.motion.medium,
                      child: KeyedSubtree(
                        key: ValueKey((way, waiting)),
                        child: kept,
                      ),
                    ),
                  ),
                ),
                // Start or stop, or for the tally writing, at the foot;
                // its place kept while the panel asks.
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: spacing.md),
                    child: SizedBox(height: 56, child: Center(child: act)),
                  ),
                ),
                // The tally's own: the reset at the bottom left, the
                // tally itself at the bottom right.
                if (way == PracticeWay.tally && !asking) ...[
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: spacing.md),
                      child: _Frame(
                        key: const ValueKey('practice-tally-reset'),
                        onTap: () {
                          HapticFeedback.heavyImpact();
                          PracticeTally.reset();
                        },
                        child: GlyphMark(
                          glyph: Glyph.reset,
                          size: 22,
                          color: count > 0
                              ? colors.textPrimary
                              : colors.textFaint,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: spacing.md),
                      child: _Frame(
                        key: const ValueKey('practice-tally-add'),
                        lit: true,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          PracticeTally.add();
                        },
                        child: GlyphMark(
                          glyph: Glyph.tally,
                          size: 24,
                          color: colors.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            panel: AnimatedSwitcher(
              duration: theme.motion.medium,
              child: _choosing && asking
                  ? _categories(theme, strings, journal)
                  : asking
                  ? _question(theme, strings)
                  // The three ways, filling the panel; while one runs, the
                  // others stand back.
                  : ActionCards(
                      key: const ValueKey('practice-ways'),
                      compact: true,
                      chosen: 'practice-${way.name}',
                      cards: [
                        for (final each in PracticeWay.values)
                          ActionCard(
                            id: 'practice-${each.name}',
                            glyph: switch (each) {
                              PracticeWay.stopwatch => Glyph.practice,
                              PracticeWay.countdown => Glyph.countdown,
                              PracticeWay.tally => Glyph.tally,
                            },
                            name: switch (each) {
                              PracticeWay.stopwatch =>
                                strings.practiceStopwatch,
                              PracticeWay.countdown =>
                                strings.practiceCountdown,
                              PracticeWay.tally => strings.practiceTally,
                            },
                            enabled: waiting || each == way,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _way = each);
                            },
                          ),
                      ],
                    ),
            ),
            bar: const RoomBar(),
          ),
        ),
      ),
    );
  }

  // Done: into the journal, or away.
  Widget _question(SmThemeData theme, Strings strings) {
    final spacing = theme.spacing;
    return Padding(
      key: const ValueKey('practice-ask'),
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            strings.practiceAsk,
            textAlign: TextAlign.center,
            style: theme.type.body.copyWith(color: theme.colors.textPrimary),
          ),
          SizedBox(height: spacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BarButton(
                key: const ValueKey('practice-discard'),
                label: strings.practiceDiscard,
                tint: dangerColor,
                onTap: _discard,
              ),
              SizedBox(width: spacing.md),
              BarButton(
                key: const ValueKey('practice-write'),
                label: strings.practiceWrite,
                primary: true,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _choosing = true);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Written: under which category, asked next, the categories down the
  // panel as the search's are drawn, one to a row (owner, 21 October
  // 2026). Back goes to the question before.
  Widget _categories(SmThemeData theme, Strings strings, JournalStore journal) {
    final spacing = theme.spacing;
    return Column(
      key: const ValueKey('practice-choose'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.lg,
            spacing.md,
            spacing.lg,
            spacing.sm,
          ),
          child: Text(
            strings.practiceUnder,
            style: theme.type.body.copyWith(color: theme.colors.textPrimary),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.lg, spacing.md),
            children: [
              for (final each in journal.categories)
                Padding(
                  padding: EdgeInsets.only(bottom: spacing.sm),
                  child: SearchChip(
                    key: ValueKey('practice-under-${each.id}'),
                    label: each.name,
                    hue: each.color,
                    on: false,
                    onTap: () => _write(journal, each.id),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One of the tally's two, a framed square at a corner of the body: its
/// glyph alone. The tally lit.
class _Frame extends StatelessWidget {
  final bool lit;
  final VoidCallback onTap;
  final Widget child;

  const _Frame({
    super.key,
    this.lit = false,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    return SmPressable(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: lit ? colors.surfaceRaised : null,
          border: Border.all(color: lit ? colors.accent : colors.outline),
          borderRadius: BorderRadius.circular(theme.radii.md),
        ),
        // The glyph alone, no word under it (owner, 21 October 2026).
        child: Center(child: child),
      ),
    );
  }
}
