import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import 'day_reading.dart';
import 'glyph_button.dart';
import 'house.dart';
import 'parts.dart';
import 'journal/entry.dart';
import 'journal/journal_store.dart';
import 'reminders/reminder.dart';
import 'reminders/reminder_screen.dart';
import 'reminders/reminder_store.dart';
import 'reminders/reminder_time.dart';
import 'sky_section.dart';
import 'strings.dart';
import 'toast.dart';

/// Detailed mode: a day, for reading at leisure. Like an entry being
/// read, it breaks the pattern of the other screens on purpose: no top
/// bar and no lower panel, only the day, with the whole screen above the
/// bottom bar to itself.
///
/// The day sheet holds the full day reading and, under it, the sky: the
/// sun's and the moon's paths, their rising and setting, and the moon's
/// coming phases. On a day with reminders a second sheet under it lists
/// them, as tall as they need up to three rows, and scrolls past that;
/// the day sheet has the rest. On a day with none, it has all of it.
///
/// Over the sheets at the top right: copying the reading, and keeping the
/// day sheet as a picture. The bottom bar is the house's; it is opened in
/// the living room and goes back to it.
class ReadingScreen extends StatefulWidget {
  final CivilDate date;
  final Duration utcOffset;

  /// Today, to mark now on the sky's paths; the clock's unless a test
  /// says.
  final CivilDate? today;

  /// Rows of the reminders sheet shown at once; the rest scroll.
  static const reminderRows = 3;
  static const reminderRowHeight = 52.0;

  const ReadingScreen({
    super.key,
    required this.date,
    required this.utcOffset,
    this.today,
  });

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  static const _gallery = MethodChannel('candra/gallery');

  // Wraps the whole of the day sheet, the part scrolled out of sight
  // too: what Save image captures.
  final _cardKey = GlobalKey();

  String? _toast;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _say(String message) {
    if (!mounted) return;
    _toastTimer?.cancel();
    _toastTimer = Timer(
      const Duration(seconds: 3),
      () => setState(() => _toast = null),
    );
    setState(() => _toast = message);
  }

  Future<void> _copy() async {
    HapticFeedback.selectionClick();
    final strings = Strings.of(context);
    await Clipboard.setData(
      ClipboardData(
        text: readingText(
          widget.date,
          utcOffset: widget.utcOffset,
          strings: strings,
        ),
      ),
    );
    _say(strings.copied);
  }

  Future<void> _saveImage() async {
    HapticFeedback.selectionClick();
    final strings = Strings.of(context);
    final boundary =
        _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    try {
      await _gallery.invokeMethod<void>('savePng', {
        'bytes': png!.buffer.asUint8List(),
        'name': 'candra-${widget.date}.png',
      });
      _say(strings.imageSaved);
    } on PlatformException {
      _say(strings.imageNotSaved);
    } on MissingPluginException {
      _say(strings.imageNotSaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final strings = Strings.of(context);
    final store = ReminderScope.of(context);
    final categories = JournalScope.of(context).categories;
    final reminders = store.on(widget.date);
    final now = DateTime.now();
    final isToday =
        widget.date == (widget.today ?? CivilDate.fromDateTime(now));

    Widget sheet({required Key key, required Widget child}) => Container(
      key: key,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(theme.radii.md),
      ),
      child: child,
    );

    final sideways = FourParts.sideways(context);
    // The day sheet: the whole of the body.
    final daySheet = sheet(
      key: const ValueKey('day-sheet'),
      child: SingleChildScrollView(
        child: RepaintBoundary(
          key: _cardKey,
          child: ColoredBox(
            color: colors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: spacing.sm),
                  child: DayReading(
                    date: widget.date,
                    utcOffset: widget.utcOffset,
                    strings: strings,
                  ),
                ),
                SkySection(
                  date: widget.date,
                  utcOffset: widget.utcOffset,
                  strings: strings,
                  nowMinute: isToday ? now.hour * 60 + now.minute : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Upright the parts stand one over another as before; on its side
    // the day sheet has the left at full height, and the buttons, the
    // reminders and the bar the column (22 October 2026).
    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: Stack(
          children: [
            FourParts.fitted(
              // Copying the reading and keeping it as a picture, at the
              // top right, over the sheets.
              top: Padding(
                padding: EdgeInsets.fromLTRB(
                  spacing.md,
                  spacing.md,
                  spacing.md,
                  0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GlyphButton(
                      key: const ValueKey('copy-reading'),
                      glyph: Glyph.copy,
                      square: true,
                      onTap: _copy,
                    ),
                    SizedBox(width: spacing.sm),
                    GlyphButton(
                      key: const ValueKey('save-reading'),
                      glyph: Glyph.saveImage,
                      square: true,
                      onTap: _saveImage,
                    ),
                  ],
                ),
              ),
              body: Padding(
                padding: EdgeInsets.fromLTRB(
                  spacing.md,
                  spacing.md,
                  spacing.md,
                  sideways || reminders.isEmpty ? spacing.md : 0,
                ),
                child: daySheet,
              ),
              // The reminders sheet, on a day that has any: as tall as
              // its reminders, up to three; more than that scroll.
              panel: reminders.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: EdgeInsets.all(spacing.md),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight:
                              ReadingScreen.reminderRows *
                                  ReadingScreen.reminderRowHeight +
                              2 * spacing.sm,
                        ),
                        child: sheet(
                          key: const ValueKey('reminders-sheet'),
                          child: _remindersList(
                            theme,
                            strings,
                            store,
                            categories,
                            reminders,
                          ),
                        ),
                      ),
                    ),
              bar: const RoomBar(),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: RoomBar.heightOf(context),
              child: Center(child: Toast(message: _toast)),
            ),
          ],
        ),
      ),
    );
  }

  /// The day's reminders, earliest first: each with a bell in its
  /// category's colour, its name, its time, and how it repeats. Tapping
  /// one opens it.
  Widget _remindersList(
    SmThemeData theme,
    Strings strings,
    ReminderStore store,
    List<JournalCategory> categories,
    List<Reminder> reminders,
  ) {
    final spacing = theme.spacing;
    final colors = theme.colors;

    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.sm,
      ),
      children: [
        for (final reminder in reminders)
          GestureDetector(
            key: ValueKey('day-reminder-${reminder.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              pushReminder(context, reminder: reminder, day: widget.date);
            },
            child: SizedBox(
              height: ReadingScreen.reminderRowHeight,
              child: Row(
                children: [
                  // A bell in the colour of its category.
                  GlyphMark(
                    glyph: Glyph.reminder,
                    size: 16,
                    color:
                        (categories
                                    .where((c) => c.id == reminder.categoryId)
                                    .firstOrNull ??
                                categories.firstOrNull)
                            ?.color ??
                        colors.accent,
                  ),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.type.body.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        SizedBox(height: spacing.xs / 2),
                        Text(
                          strings.repeatLabel(
                            reminder.repeat,
                            reminder.start,
                            store.utcOffset,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.type.label.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: spacing.md),
                  Text(
                    reminderClock(reminder, widget.date),
                    style: theme.type.body.copyWith(color: colors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
