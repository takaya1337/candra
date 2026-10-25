import 'package:flutter/gestures.dart';

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import '../confirm_bar.dart';
import '../date_picker.dart';
import '../dot_picker.dart';
import '../glyph_button.dart';
import '../house.dart';
import '../journal/journal_store.dart';
import '../panel_tabs.dart';
import '../parts.dart';
import '../planets/planet_look.dart';
import '../search/query.dart';
import '../sky_place.dart';
import '../strings.dart';
import '../time_picker.dart';
import '../toast.dart';
import 'reminder.dart';
import 'reminder_store.dart';
import '../search/tags_ui.dart';
import '../wheel_row.dart';

/// Opens one reminder for changes, or with no [reminder] a new one that
/// starts on [day] in category [categoryId]. Returns it as saved, or null
/// if it was left alone or deleted.
Future<Reminder?> pushReminder(
  BuildContext context, {
  Reminder? reminder,
  required CivilDate day,
  String? categoryId,
}) {
  final motion = SmTheme.of(context).motion;
  return Navigator.of(context).push(
    PageRouteBuilder<Reminder>(
      transitionDuration: motion.medium,
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, _) =>
          ReminderScreen(reminder: reminder, day: day, categoryId: categoryId),
      transitionsBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        child: child,
      ),
    ),
  );
}

/// What a reminder is made of, besides its name. Each is a line on the
/// sheet, and the one chosen has its instrument in the lower panel.
enum ReminderField { category, start, time, repeat }

/// One reminder, open for changes.
///
///  * Top bar: whether it is new, and how it stands in a line: how it
///    repeats and when.
///  * Main body: the sheet, tinted in its category's colour: its name,
///    then a line each for its category, its first day, its time and how
///    it repeats.
///  * Lower panel: the instrument for the line chosen on the sheet: the
///    category picker, the date wheels, the time wheels, or the wheel of
///    repeats. The repeats are put in the words of the first day in every
///    calendar that can place it: "Every Minggu Legi", "Javanese: every 28
///    Bakdamulud". The panel steps aside for the keyboard.
///  * Bottom bar: the bin on the left, Save in the middle, the cross on
///    the right.
class ReminderScreen extends StatefulWidget {
  final Reminder? reminder;
  final CivilDate day;
  final String? categoryId;

  const ReminderScreen({
    super.key,
    this.reminder,
    required this.day,
    this.categoryId,
  });

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  static const _panelHeight = 180.0;

  late final _title = TextEditingController(text: widget.reminder?.title);
  final _titleFocus = FocusNode();

  // Its id is empty until it is first saved.
  late Reminder _draft =
      widget.reminder ??
      Reminder(
        id: '',
        title: '',
        start: widget.day,
        // The next full hour.
        minuteOfDay: (DateTime.now().hour + 1) % 24 * 60,
        repeat: Repeat.once,
        categoryId: widget.categoryId,
      );

  ReminderField _field = ReminderField.time;

  // True while the tag panel has the lower panel in place of a field's
  // instrument, and while a new tag is being named in the bar.
  bool _tagging = false;
  bool _naming = false;

  // Naming a new category, from the category's instrument: the same bar
  // over the keyboard as a new tag.
  bool _namingCategory = false;
  final _tagName = TextEditingController();
  final _tagFocus = FocusNode();

  // True while the question "delete this reminder?" is up.
  bool _confirming = false;

  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    // A new one is named first.
    if (widget.reminder == null) _titleFocus.requestFocus();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _title.dispose();
    _titleFocus.dispose();
    _tagName.dispose();
    _tagFocus.dispose();
    super.dispose();
  }

  void _say(String message) {
    _toastTimer?.cancel();
    _toastTimer = Timer(
      const Duration(seconds: 3),
      () => setState(() => _toast = null),
    );
    setState(() => _toast = message);
  }

  void _choose(ReminderField field) {
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _field = field;
      _tagging = false;
    });
  }

  // The tag button: the tag panel in the lower panel, or the field's
  // instrument back.
  void _toggleTagging() {
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _tagging = !_tagging;
      _naming = false;
    });
  }

  void _setTags(Set<String> tags) =>
      setState(() => _draft = _draft.copyWith(tags: tags.toList()));

  void _startNaming() {
    setState(() => _naming = true);
    _tagName.clear();
    _tagFocus.requestFocus();
  }

  void _doneNaming() {
    final tag = JournalScope.of(context).addTag(_tagName.text);
    HapticFeedback.selectionClick();
    _tagFocus.unfocus();
    setState(() => _naming = false);
    if (tag != null) _setTags({..._draft.tags, tag.id});
  }

  void _cancelNaming() {
    HapticFeedback.selectionClick();
    _tagFocus.unfocus();
    setState(() {
      _naming = false;
      _namingCategory = false;
    });
  }

  void _startCategory() {
    HapticFeedback.selectionClick();
    if (!JournalScope.of(context).canAddCategory) {
      _say(Strings.of(context).categoryLimit);
      return;
    }
    setState(() => _namingCategory = true);
    _tagName.clear();
    _tagFocus.requestFocus();
  }

  // The new category, in the first free colour, chosen at once. Without a
  // name the keyboard stays, and says so.
  void _doneCategory() {
    final name = _tagName.text.trim();
    if (name.isEmpty) {
      _say(Strings.of(context).categoryNeedsName);
      return;
    }
    final added = JournalScope.of(context).addCategory(name);
    HapticFeedback.selectionClick();
    _tagFocus.unfocus();
    setState(() => _namingCategory = false);
    if (added != null) _change((d) => d.copyWith(categoryId: added.id));
  }

  // Changes the draft. A repeat the new first day cannot have (the moon,
  // off a day of its phases) falls back to once.
  void _change(Reminder Function(Reminder draft) change) {
    final store = ReminderScope.of(context);
    var changed = change(_draft);
    if (!Reminder.offeredFor(
      changed.start,
      utcOffset: store.utcOffset,
    ).contains(changed.repeat)) {
      changed = changed.copyWith(repeat: Repeat.once);
    }
    setState(() => _draft = changed);
  }

  void _save(String? categoryId) {
    final title = _title.text.trim();
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    // Nothing named is nothing to save: Save then leaves as cancelling
    // would, the reminder as it was (owner, 25 October 2026).
    if (title.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final saved = ReminderScope.of(context).save(
      _draft.copyWith(title: title, enabled: true, categoryId: categoryId),
    );
    Navigator.of(context).pop(saved);
  }

  void _delete() {
    HapticFeedback.mediumImpact();
    ReminderScope.of(context).delete(_draft.id);
    Navigator.of(context).pop();
  }

  void _setConfirming(bool confirming) {
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _confirming = confirming);
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final strings = Strings.of(context);
    final store = ReminderScope.of(context);
    final journal = JournalScope.of(context);
    final draft = _draft;
    final isNew = draft.id.isEmpty;
    // One whose category is not here stands under the first, and is saved
    // there.
    final category =
        journal.category(draft.categoryId) ?? journal.categories.firstOrNull;
    final hue = category?.color ?? colors.accent;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    // While the name is typed the panel goes, for the room; except where
    // the panel is tall, which has room for both, and the field's
    // instrument stays in the column beside the keyboard. The tags stay
    // whatever the panel, risen over the keyboard with the bar, as the
    // entry's do: they are chosen while the name is written.
    final typing = FourParts.panelGivesWay(context) && !_tagging;
    final repeat = strings.repeatLabel(
      draft.repeat,
      draft.start,
      store.utcOffset,
    );

    return PopScope(
      // Back takes back the question, the naming of a tag and the tag
      // panel before it leaves.
      canPop: !_confirming && !_naming && !_namingCategory && !_tagging,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_confirming) {
          _setConfirming(false);
        } else if (_naming || _namingCategory) {
          _cancelNaming();
        } else {
          _toggleTagging();
        }
      },
      child: ColoredBox(
        color: colors.background,
        child: SafeArea(
          child: FourParts.fitted(
            // Where the panel is tall: at the top of the column while the
            // name is typed, so the room over the bar the keyboard lifts
            // is the tabs' and the wheels'; and for the category, whose
            // dots and names are read from the top.
            panelAtTop:
                inset > 0 || !_tagging && _field == ReminderField.category,
            top: Padding(
              padding: EdgeInsets.all(spacing.md),
              child: TopBar(
                key: const ValueKey('reminder-top-bar'),
                leading: TopBarTitle(
                  label: isNew ? strings.newReminder : strings.editReminder,
                ),
                subtitle: '$repeat · ${strings.reminderTimeWords(draft)}',
                // Deleting it, at the top right; it asks first. One not
                // saved yet has nothing to delete.
                trailing: isNew
                    ? null
                    : GlyphButton(
                        key: const ValueKey('reminder-delete'),
                        glyph: Glyph.delete,
                        square: true,
                        tint: DeleteCardButton.red,
                        onTap: () => _setConfirming(true),
                      ),
              ),
            ),
            body: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: _confirming ? 0.04 : 1,
                    duration: _confirming ? theme.motion.medium : Toast.makeWay,
                    child: IgnorePointer(
                      ignoring: _confirming,
                      child: SingleChildScrollView(
                        // Room at the foot to stand clear of the buttons.
                        padding: EdgeInsets.fromLTRB(
                          spacing.md,
                          0,
                          spacing.md,
                          spacing.md + 40 + spacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sheet(
                              theme,
                              strings,
                              hue,
                              category?.name ?? '',
                              repeat,
                              lit: !typing && !_tagging,
                            ),
                            // By the sun or a planet's hour, what that
                            // comes to on the first day: under the sheet,
                            // which is the same size whatever the time.
                            if (draft.bySun)
                              Padding(
                                padding: EdgeInsets.all(spacing.md),
                                child: Text(
                                  _firstDayNote(strings),
                                  key: const ValueKey('reminder-sun-note'),
                                  textAlign: TextAlign.center,
                                  style: theme.type.label.copyWith(
                                    color: colors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // What the editor is for, at the body's bottom right: the
                // tags, and saving.
                if (inset == 0)
                  Positioned(
                    right: spacing.md,
                    bottom: spacing.md,
                    child: AnimatedOpacity(
                      opacity:
                          _confirming || _naming || _namingCategory || inset > 0
                          ? 0
                          : 1,
                      duration: theme.motion.shift,
                      child: IgnorePointer(
                        ignoring:
                            _confirming ||
                            _naming ||
                            _namingCategory ||
                            inset > 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GlyphButton(
                              key: const ValueKey('reminder-tags'),
                              glyph: Glyph.tag,
                              square: true,
                              lit: _tagging,
                              marked: draft.tags.isNotEmpty,
                              onTap: _toggleTagging,
                            ),
                            SizedBox(width: spacing.sm),
                            GlyphButton(
                              key: const ValueKey('reminder-save'),
                              glyph: Glyph.save,
                              square: true,
                              lit: true,
                              here: true,
                              onTap: () => _save(category?.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: PanelFoot(
                    toast: Toast(
                      hurried: _toast == null,
                      message: _confirming
                          ? strings.deleteReminderQuestion(draft.title)
                          : _toast,
                    ),
                    answer: _confirming
                        ? ConfirmBar(
                            label: strings.delete,
                            onConfirm: _delete,
                            onCancel: () => _setConfirming(false),
                          )
                        : null,
                  ),
                ),
              ],
            ),
            panel: AnimatedSize(
              duration: theme.motion.medium,
              curve: theme.motion.curve,
              alignment: Alignment.bottomCenter,
              child: typing || _confirming
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      key: const ValueKey('reminder-panel'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PanelSeparator(),
                        // Where the panel is tall it takes the whole of
                        // the column's middle, keyboard or not, so the
                        // wheels and lists show more of their rows; on a
                        // tablet upright, the standard panel's height,
                        // as the main pages' panels stand.
                        Builder(
                          builder: (context) => SizedBox(
                            height: switch ((
                              FourParts.roomOf(context),
                              FourParts.standardOf(context),
                            )) {
                              (final room?, _) => room - 1,
                              (_, final standard?) => standard - 1,
                              _ => _panelHeight,
                            },
                            child: AnimatedSwitcher(
                              duration: theme.motion.medium,
                              child: _tagging
                                  ? TagPanel(
                                      key: const ValueKey('instrument-tags'),
                                      chosen: draft.tags.toSet(),
                                      onChanged: _setTags,
                                      onNew: _startNaming,
                                    )
                                  : _instrument(
                                      theme,
                                      strings,
                                      store,
                                      journal,
                                      category?.id,
                                      category?.name ?? '',
                                      tall: FourParts.roomOf(context) != null,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            bar: RoomBar(
              // While a tag or a category is named, its bar.
              typing: _naming || _namingCategory
                  ? BottomBar(
                      padding: EdgeInsets.all(spacing.md)
                          .copyWith(bottom: spacing.md + inset),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border(top: BorderSide(color: colors.outline)),
                      ),
                      child: TagNameBar(
                        controller: _tagName,
                        focusNode: _tagFocus,
                        onDone: _namingCategory ? _doneCategory : _doneNaming,
                        onCancel: _cancelNaming,
                        placeholder: _namingCategory
                            ? strings.categoryNamePlaceholder
                            : null,
                      ),
                    )
                  // The name typed: the tags and Save ride on the
                  // keyboard, in the room over it, clear of the sheet
                  // (owner, 20 October 2026).
                  : inset > 0
                  ? BottomBar(
                      padding: EdgeInsets.all(spacing.md)
                          .copyWith(bottom: spacing.md + inset),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border(top: BorderSide(color: colors.outline)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GlyphButton(
                            key: const ValueKey('reminder-tags'),
                            glyph: Glyph.tag,
                            square: true,
                            lit: _tagging,
                            marked: draft.tags.isNotEmpty,
                            onTap: _toggleTagging,
                          ),
                          SizedBox(width: spacing.sm),
                          GlyphButton(
                            key: const ValueKey('reminder-save'),
                            glyph: Glyph.save,
                            square: true,
                            lit: true,
                            here: true,
                            onTap: () => _save(category?.id),
                          ),
                        ],
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  /// The sheet: the name, then a line for each field. The line whose
  /// instrument is in the lower panel is [lit].
  Widget _sheet(
    SmThemeData theme,
    Strings strings,
    Color hue,
    String category,
    String repeat, {
    required bool lit,
  }) {
    final spacing = theme.spacing;
    final colors = theme.colors;
    final draft = _draft;

    Widget line(ReminderField field, String label, Widget value) {
      final chosen = lit && field == _field;
      return GestureDetector(
        key: ValueKey('field-${field.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _choose(field),
        child: AnimatedContainer(
          duration: theme.motion.medium,
          curve: theme.motion.curve,
          margin: EdgeInsets.only(top: spacing.sm),
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.md - spacing.xs,
          ),
          decoration: BoxDecoration(
            color: hue.withValues(alpha: chosen ? 0.2 : 0.05),
            border: Border.all(
              color: hue.withValues(alpha: chosen ? 0.95 : 0.28),
            ),
            borderRadius: BorderRadius.circular(theme.radii.sm + 2),
          ),
          // The label over the value, so a long one has the whole width.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label.toUpperCase(),
                style: theme.type.caption.copyWith(
                  color: colors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: spacing.xs),
              value,
            ],
          ),
        ),
      );
    }

    Widget words(String text) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.type.body.copyWith(color: colors.textPrimary),
    );

    return AnimatedContainer(
      key: const ValueKey('reminder-editor'),
      duration: theme.motion.medium,
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: hue.withValues(alpha: 0.9), width: 1.2),
        borderRadius: BorderRadius.circular(theme.radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(spacing.sm),
            child: SmTextField(
              key: const ValueKey('reminder-title'),
              controller: _title,
              focusNode: _titleFocus,
              placeholder: strings.reminderPlaceholder,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              labels: SmTextToolbarLabels(
                cut: strings.cut,
                copy: strings.copy,
                paste: strings.paste,
                selectAll: strings.selectAll,
              ),
              style: theme.type.title.copyWith(color: colors.textPrimary),
            ),
          ),
          line(
            ReminderField.category,
            strings.reminderCategory,
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: hue, shape: BoxShape.circle),
                ),
                SizedBox(width: spacing.sm),
                Expanded(child: words(category)),
              ],
            ),
          ),
          line(
            ReminderField.start,
            strings.reminderStarts,
            words(
              '${strings.gregorian(draft.start)} · ${Weton.of(draft.start)}',
            ),
          ),
          line(
            ReminderField.time,
            strings.reminderTime,
            words(strings.reminderTimeWords(draft)),
          ),
          line(ReminderField.repeat, strings.reminderRepeats, words(repeat)),
        ],
      ),
    );
  }

  // What a time by the sun or a planet's hour comes to on the first day,
  // or why there is none.
  String _firstDayNote(Strings strings) {
    final draft = _draft;
    final place = SkyPlace.current.value;
    final first = draft.minuteOn(
      draft.start,
      place: place,
      utcOffset: DateTime(
        draft.start.year,
        draft.start.month,
        draft.start.day,
        12,
      ).timeZoneOffset,
    );
    String two(int v) => v.toString().padLeft(2, '0');
    return place == null
        ? strings.reminderSunNeedsPlace
        : first == null
        ? strings.reminderSunNone
        : strings.reminderSunOn('${two(first ~/ 60)}:${two(first % 60)}');
  }

  Widget _instrument(
    SmThemeData theme,
    Strings strings,
    ReminderStore store,
    JournalStore journal,
    String? categoryId,
    String categoryName, {
    required bool tall,
  }) {
    final draft = _draft;
    switch (_field) {
      case ReminderField.category:
        return Column(
          key: const ValueKey('instrument-category'),
          // In a tall panel, read from the top of it.
          mainAxisAlignment: tall
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            if (tall) SizedBox(height: theme.spacing.lg),
            DotPicker(
              key: const ValueKey('reminder-category'),
              dots: [
                for (final category in journal.categories)
                  (id: category.id, color: category.color),
              ],
              selected: categoryId,
              onPick: (id) => _change((d) => d.copyWith(categoryId: id)),
            ),
            SizedBox(height: theme.spacing.sm),
            Text(
              categoryName,
              style: theme.type.body.copyWith(color: theme.colors.textPrimary),
            ),
            SizedBox(height: theme.spacing.md),
            // A category made here, named over the keyboard.
            GestureDetector(
              key: const ValueKey('reminder-category-new'),
              behavior: HitTestBehavior.opaque,
              onTap: _startCategory,
              child: Padding(
                padding: EdgeInsets.all(theme.spacing.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GlyphMark(
                      glyph: Glyph.add,
                      size: 14,
                      color: theme.colors.accent,
                    ),
                    SizedBox(width: theme.spacing.sm),
                    Text(
                      strings.categoryNew,
                      style: theme.type.body.copyWith(
                        color: theme.colors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      case ReminderField.start:
        return Center(
          key: const ValueKey('instrument-start'),
          child: DatePicker(
            date: draft.start,
            strings: strings,
            onChanged: (date) => _change((d) => d.copyWith(start: date)),
          ),
        );
      case ReminderField.time:
        // By the clock, or by the sun at the place set, so many minutes
        // before.
        const leads = [0, 5, 10, 15, 20, 30, 45, 60, 90, 120];
        return Column(
          key: const ValueKey('instrument-time'),
          children: [
            SizedBox(height: theme.spacing.sm),
            PanelTabs(
              listKey: const ValueKey('reminder-anchors'),
              tabs: SunAnchor.values,
              shown: draft.sun,
              label: strings.sunAnchorName,
              keyOf: (a) => 'reminder-anchor-${a.name}',
              onChoose: (a) {
                HapticFeedback.selectionClick();
                _change((d) => d.copyWith(sun: a));
              },
            ),
            Expanded(
              child: !draft.bySun
                  // Clear of the row's scroll bar above, and kept within
                  // its own room.
                  ? ClipRect(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          theme.spacing.lg,
                          theme.spacing.sm,
                          theme.spacing.lg,
                          0,
                        ),
                        child: TimePicker(
                          minuteOfDay: draft.minuteOfDay,
                          onChanged: (minute) =>
                              _change((d) => d.copyWith(minuteOfDay: minute)),
                        ),
                      ),
                    )
                  // The leads are a list of rows down the panel, as the
                  // search's categories are; by the planetary hour the
                  // planets are a second list beside them, as two wheels
                  // stand side by side. Each list is made anew with the
                  // anchor, so it opens on the chosen row again.
                  : Padding(
                      padding: EdgeInsets.only(top: theme.spacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (draft.sun == SunAnchor.planetaryHour)
                            Expanded(
                              key: const ValueKey('planets-list'),
                              child: _ChoiceList(
                                listKey: const ValueKey('reminder-planets'),
                                choices: CycleKind.planets,
                                chosen: draft.planet ?? Body.sun,
                                label: (p) =>
                                    '${PlanetLook.symbolOf(p)} '
                                    '${strings.planetName(p)}',
                                keyOf: (p) => 'reminder-planet-${p.name}',
                                onChoose: (p) {
                                  HapticFeedback.selectionClick();
                                  _change((d) => d.copyWith(planet: p));
                                },
                              ),
                            ),
                          Expanded(
                            key: ValueKey('leads-list-${draft.sun.name}'),
                            child: _ChoiceList(
                              listKey: const ValueKey('reminder-leads'),
                              choices: leads,
                              chosen: draft.lead,
                              label: strings.reminderLead,
                              keyOf: (m) => 'reminder-lead-$m',
                              onChoose: (m) {
                                HapticFeedback.selectionClick();
                                _change((d) => d.copyWith(lead: m));
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      case ReminderField.repeat:
        final offered = Reminder.offeredFor(
          draft.start,
          utcOffset: store.utcOffset,
        );
        return Padding(
          // A new wheel whenever what is offered changes.
          key: ValueKey('instrument-repeat-${offered.length}'),
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
          child: _RepeatWheel(
            offered: offered,
            chosen: draft.repeat,
            label: (repeat) =>
                strings.repeatLabel(repeat, draft.start, store.utcOffset),
            onChanged: (repeat) => _change((d) => d.copyWith(repeat: repeat)),
          ),
        );
    }
  }
}

/// One wheel of the ways a reminder can repeat, in the manner of the date
/// picker.
class _RepeatWheel extends StatefulWidget {
  final List<Repeat> offered;
  final Repeat chosen;
  final String Function(Repeat repeat) label;
  final ValueChanged<Repeat> onChanged;

  const _RepeatWheel({
    required this.offered,
    required this.chosen,
    required this.label,
    required this.onChanged,
  });

  @override
  State<_RepeatWheel> createState() => _RepeatWheelState();
}

class _RepeatWheelState extends State<_RepeatWheel> {
  static const _itemExtent = 36.0;

  late final _wheel = FixedExtentScrollController(
    initialItem: widget.offered.indexOf(widget.chosen).clamp(0, 1 << 20),
  );

  @override
  void dispose() {
    _wheel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: _itemExtent,
          decoration: BoxDecoration(
            color: theme.colors.surfaceRaised,
            borderRadius: BorderRadius.circular(theme.radii.md),
          ),
        ),
        ListWheelScrollView.useDelegate(
          key: const ValueKey('picker-repeat'),
          controller: _wheel,
          itemExtent: _itemExtent,
          diameterRatio: 1.4,
          overAndUnderCenterOpacity: 0.35,
          physics: const FixedExtentScrollPhysics(),
          // Counted from where the finger went down, so the rows that can
          // be touched (WheelRow) take nothing from the turn.
          dragStartBehavior: DragStartBehavior.down,
          onSelectedItemChanged: (index) {
            HapticFeedback.selectionClick();
            widget.onChanged(widget.offered[index]);
          },
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: widget.offered.length,
            builder: (context, index) => WheelRow(
              controller: _wheel,
              index: index,
              child: Center(
                child: Text(
                  widget.label(widget.offered[index]),
                  key: ValueKey('repeat-${widget.offered[index].name}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.type.body.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Choices as a list of rows down the panel, each as wide as the list,
/// in the look of the search's categories: the chosen one filled. It
/// opens scrolled so that the chosen one is in sight.
class _ChoiceList<T> extends StatefulWidget {
  final Key listKey;
  final List<T> choices;
  final T chosen;
  final String Function(T) label;
  final String Function(T) keyOf;
  final ValueChanged<T> onChoose;

  const _ChoiceList({
    required this.listKey,
    required this.choices,
    required this.chosen,
    required this.label,
    required this.keyOf,
    required this.onChoose,
  });

  @override
  State<_ChoiceList<T>> createState() => _ChoiceListState<T>();
}

class _ChoiceListState<T> extends State<_ChoiceList<T>> {
  // A row's height and the gap under it, as the search's rows stand.
  static const _row = 32.0;

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final spacing = SmTheme.of(context).spacing;
      final position = _scroll.position;
      final index = widget.choices.indexOf(widget.chosen);
      // The chosen row at the middle, as far as the list allows.
      final middle =
          spacing.md +
          index * (_row + spacing.sm) +
          _row / 2 -
          position.viewportDimension / 2;
      _scroll.jumpTo(
        middle.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;

    return ListView(
      key: widget.listKey,
      controller: _scroll,
      padding: EdgeInsets.all(spacing.md),
      children: [
        for (final choice in widget.choices)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.sm),
            child: SearchChip(
              key: ValueKey(widget.keyOf(choice)),
              label: widget.label(choice),
              hue: theme.colors.accent,
              on: choice == widget.chosen,
              onTap: () => widget.onChoose(choice),
            ),
          ),
      ],
    );
  }
}
