import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import '../bar_button.dart';
import '../bazi/bazi_card.dart';
import '../bazi/bazi_record.dart';
import '../bazi/bazi_screen.dart';
import '../confirm_bar.dart';
import '../date_picker.dart';
import '../day_reading.dart';
import '../dot_picker.dart';
import '../glyph_button.dart';
import '../house.dart';
import '../panel_tabs.dart';
import '../parts.dart';
import '../scroll_bars.dart';
import '../sky_place.dart';
import '../strings.dart';
import '../time_picker.dart';
import '../toast.dart';
import 'entry.dart';
import 'geo.dart';
import 'journal_store.dart';
import 'markdown.dart';
import '../search/tags_ui.dart';

/// One entry, for reading or for writing.
///
/// An existing entry opens for reading: its text can be selected and
/// copied but not changed. The edit button turns the same sheet into an
/// editor; Save writes it and returns to reading. A new entry starts in
/// the editor.
///
/// While reading, the dots at the top right stand for the day's entries in
/// this category; tapping one turns to that entry.
///
/// Reading breaks the pattern of the other screens on purpose: there is no
/// lower panel and no top bar, only the sheet, with the day and the time
/// inside it, so that nothing stands between the reader and the entry.
/// Editing brings the top bar back above the sheet, and the bottom bar
/// becomes the format bar. An entry stays in the category it was started
/// in.
///
/// An entry can carry one geotag. The pin at the top right of the top bar,
/// while editing, asks the phone where it is and tags the entry with that,
/// rounded to about a hundred metres; pressed again it opens the place
/// bar, where the place is named or the tag taken off. While editing the
/// place stands beside the time in the top bar; while reading it is under
/// the time, and a tap on it there opens it in the phone's maps app.
///
/// Pops with the category of the entry last shown, so the journal can put
/// that card at the front.
class EntryScreen extends StatefulWidget {
  final CivilDate date;
  final Duration utcOffset;

  /// The entry to open, or null to write a new one.
  final Entry? entry;

  /// The category a new entry starts in.
  final String? categoryId;

  /// Overrides the time a new entry is stamped with; for tests.
  final int? minuteOfDay;

  /// Said in the panel as the entry opens: what was just done to it
  /// elsewhere (written from the bazi chart).
  final String? notice;

  /// Opens being written, its title chosen to type over: a chart from
  /// the bazi page, to be named.
  final bool titling;

  /// A new entry that comes with something already in it (a bazi chart,
  /// its title): nothing is saved until the tick is touched.
  final Entry? draft;

  const EntryScreen({
    super.key,
    required this.date,
    required this.utcOffset,
    this.entry,
    this.categoryId,
    this.minuteOfDay,
    this.notice,
    this.titling = false,
    this.draft,
  });

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final _title = TextEditingController();
  final _content = MarkdownController();
  final _titleFocus = FocusNode();
  final _contentFocus = FocusNode();

  // The entry on the sheet, or null while a new one is being written.
  late Entry? _entry = widget.entry;
  late bool _editing = widget.entry == null || widget.titling;
  // The category it is written in: the entry's own, or the one the
  // journal had at the front. It cannot be changed from here.
  late final String? _categoryId =
      widget.entry?.categoryId ?? widget.draft?.categoryId ?? widget.categoryId;

  // What the entry holds beyond the writing: its own, or the draft's.
  String? get _bazi => (_entry ?? widget.draft)?.bazi;

  // A new entry is stamped with the time it was started.
  late final int _startedAt =
      widget.minuteOfDay ?? DateTime.now().hour * 60 + DateTime.now().minute;
  late final int _startedSecond = widget.minuteOfDay == null
      ? DateTime.now().second
      : 0;

  // The date and time being changed while editing (owner, 17 October
  // 2026): kept here until the tick saves them, null while unchanged;
  // and whether the lower panel shows their wheels.
  CivilDate? _whenDate;
  int? _whenMinute;
  bool _moving = false;
  int _whenTab = 0;

  // The day and the minute as they stand on the sheet.
  CivilDate get _date => _whenDate ?? _entry?.date ?? widget.date;
  int get _minuteNow => _whenMinute ?? _entry?.minuteOfDay ?? _startedAt;

  String? _toast;
  Timer? _toastTimer;

  // True while the question "delete this entry?" is up.
  bool _confirming = false;

  // The geotag as it stands on the sheet: the entry's own, until changed.
  GeoTag? _place;

  // True while the phone is being asked where it is.
  bool _locating = false;

  // What the place panel has to say about a search: that it is going on,
  // or why it failed, or that the position found is only approximate.
  // Everything about a geotag is said there, never in a toast.
  String? _placeNotice;
  Timer? _noticeTimer;

  // True while the place bar has the bottom bar: the geotag is being
  // named, or looked at.
  bool _placing = false;
  final _placeName = TextEditingController();
  final _placeFocus = FocusNode();

  // The entry's tags, as they stand on screen. While reading, a change is
  // saved at once; while editing, with the rest, on Save.
  Set<String> _tags = {};

  // True while the tag panel has the lower panel, and while a new tag is
  // being named in the bar.
  bool _tagging = false;
  bool _naming = false;
  final _tagName = TextEditingController();
  final _tagFocus = FocusNode();

  // Whether the keyboard has been seen on screen since it was last gone.
  bool _keyboardUp = false;

  @override
  void initState() {
    super.initState();
    _fill();
    final draft = widget.draft;
    if (widget.entry == null && draft != null) {
      _title.text = draft.title;
      _content.text = draft.content;
    }
    final notice = widget.notice;
    if (notice != null || widget.titling) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.titling) {
          _titleFocus.requestFocus();
          _title.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _title.text.length,
          );
        }
        if (notice != null) _say(notice);
      });
    }
    // The bar changes with whether anything is being typed in.
    _titleFocus.addListener(_onFocus);
    _contentFocus.addListener(_onFocus);
    // And with where the caret is, and what is selected.
    _title.addListener(_onFocus);
    _content.addListener(_onFocus);
    _placeFocus.addListener(_onFocus);
    // The name is the tag's as it is typed.
    _placeName.addListener(() {
      final place = _place;
      if (place == null || place.name == _placeName.text.trim()) return;
      setState(() => _place = place.named(_placeName.text));
    });
  }

  void _onFocus() {
    if (!mounted) return;
    setState(() {
      // Going back to the writing puts away a notice that a search
      // failed.
      if (_typing && !_locating && _place == null) _placeNotice = null;
    });
  }

  // Typing: the keyboard is up for one of the two fields.
  bool get _typing =>
      _editing && (_titleFocus.hasFocus || _contentFocus.hasFocus);

  // Applies one of the format buttons to the content.
  void _format(TextEditingValue Function(TextEditingValue) change) {
    HapticFeedback.selectionClick();
    _content.value = change(_content.value);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _noticeTimer?.cancel();
    // Nothing is left looking for a screen that has gone.
    if (_locating) unawaited(Locator.current.cancel());
    _title.dispose();
    _content.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
    _placeName.dispose();
    _placeFocus.dispose();
    _tagName.dispose();
    _tagFocus.dispose();
    super.dispose();
  }

  // Puts the entry's own words back on the sheet.
  void _fill() {
    _title.text = _entry?.title ?? '';
    _content.text = _entry?.content ?? '';
    _place = _entry?.place;
    _placing = false;
    _placeNotice = null;
    _placeName.text = _place?.name ?? '';
    _tags = {...?_entry?.tags};
    _tagging = false;
    _naming = false;
  }

  // The tag button: the tag panel in the lower panel, or away again.
  void _toggleTagging() {
    HapticFeedback.selectionClick();
    setState(() {
      _tagging = !_tagging;
      _naming = false;
      _placing = false;
      _moving = false;
    });
  }

  // The time under the date touched while editing: the date and time
  // wheels in the lower panel, or away again.
  void _toggleMoving() {
    if (!_editing) return;
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _moving = !_moving;
      _tagging = false;
      _placing = false;
    });
  }

  // The entry's chart in the bazi page; back, the entry as it now stands,
  // and what was done to it said.
  Future<void> _openBazi(Entry entry) async {
    final record = BaziRecord.parse(entry.bazi);
    if (record == null) return;
    final said = await pushBaziOf(context, entry: entry, record: record);
    if (!mounted) return;
    final fresh = JournalScope.of(context)
        .entriesFor(entry.date, utcOffset: entry.utcOffset)
        .where((e) => e.id == entry.id)
        .firstOrNull;
    if (fresh != null) {
      setState(() {
        _entry = fresh;
        _fill();
      });
    }
    if (said != null) _say(said);
  }

  // The sky at the entry's moment, in a line: how the sun lights the land
  // and where it stands, at the entry's own place or else the place set;
  // and how much of the moon is lit, which needs no place. Null for an
  // entry not yet written.
  String? _skyStamp(Strings strings) {
    final entry = _entry;
    if (entry == null) return null;
    final at = DateTime.utc(
      entry.date.year,
      entry.date.month,
      entry.date.day,
    ).add(Duration(seconds: entry.secondOfDay)).subtract(entry.utcOffset);
    final moon = strings.lightMoonLit(
      (SkyNow.moonFace(at).illumination * 100).round(),
    );
    final where = entry.place == null
        ? SkyPlace.current.value
        : (latitude: entry.place!.latitude, longitude: entry.place!.longitude);
    if (where == null) return moon;
    final sun = SkyNow.sun(
      at,
      latitude: where.latitude,
      longitude: where.longitude,
    );
    return [
      strings.lightBand(LightBand.of(sun.trueAltitude)),
      strings.skyStampSun(
        sun.altitude.round(),
        strings.compassPoint((sun.azimuth + 22.5) ~/ 45),
      ),
      moon,
    ].join(' · ');
  }

  void _setTags(Set<String> tags) {
    setState(() => _tags = tags);
    final entry = _entry;
    // While reading there is no Save: the tags are the entry's at once.
    if (!_editing && entry != null) {
      _entry = JournalScope.of(context)
          .save(entry.copyWith(tags: tags.toList()));
    }
  }

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
    if (tag != null) _setTags({..._tags, tag.id});
  }

  void _cancelNaming() {
    HapticFeedback.selectionClick();
    _tagFocus.unfocus();
    setState(() => _naming = false);
  }

  // The geotag button. With no tag: find where the phone is and tag the
  // entry. With one: open the place bar, or close it.
  Future<void> _onPlaceButton() async {
    HapticFeedback.selectionClick();
    // Pressed again while it is looking: stop looking.
    if (_locating) {
      unawaited(Locator.current.cancel());
      return;
    }
    if (_place != null) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _placing = !_placing;
        _placeNotice = null;
      });
      return;
    }
    final strings = Strings.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    _noticeTimer?.cancel();
    setState(() {
      _locating = true;
      _placeNotice = strings.placeFindingStop;
    });
    // Looking can take a while, and indoors may never succeed: say so
    // rather than leave the first message standing.
    _noticeTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _locating) {
        setState(() => _placeNotice = strings.placeStillFinding);
      }
    });
    try {
      final fix = await Locator.current.find();
      final place = GeoTag.rounded(fix.latitude, fix.longitude);
      if (!mounted) return;
      if (place == null) throw const LocateFailed(LocateProblem.unavailable);
      _noticeTimer?.cancel();
      setState(() {
        _locating = false;
        _place = place;
        _placeName.clear();
        // Straight to the place bar, to name it or leave it as it is.
        // The panel over it says, every time, that what is kept is not
        // the exact spot; and here, if the phone itself was only rough.
        _placing = true;
        _placeNotice = fix.accuracy > 1000
            ? strings.placeRough((fix.accuracy / 1000).round())
            : null;
      });
      HapticFeedback.mediumImpact();
    } on LocateFailed catch (failed) {
      if (!mounted) return;
      _noticeTimer?.cancel();
      final why = switch (failed.problem) {
        LocateProblem.denied => strings.placeDenied,
        LocateProblem.off => strings.placeOff,
        LocateProblem.timeout => strings.placeTimeout,
        LocateProblem.sky => strings.placeNeedsSky,
        LocateProblem.unavailable => strings.placeUnavailable,
        // Stopped by the user: nothing to explain.
        LocateProblem.cancelled => null,
      };
      // The reason stays in the panel until something else is done.
      setState(() {
        _locating = false;
        _placeNotice = why;
      });
    }
  }

  void _removePlace() {
    HapticFeedback.mediumImpact();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _place = null;
      _placing = false;
      _placeNotice = null;
      _placeName.clear();
    });
  }

  void _donePlacing() {
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _placing = false;
      _placeNotice = null;
    });
  }

  Future<void> _openPlace(GeoTag place) async {
    HapticFeedback.selectionClick();
    final strings = Strings.of(context);
    if (!await Locator.current.open(place) && mounted) {
      _say(strings.noMapsApp);
    }
  }

  void _say(String message, {int seconds = 3}) {
    _toastTimer?.cancel();
    _toastTimer = Timer(
      Duration(seconds: seconds),
      () => setState(() => _toast = null),
    );
    setState(() => _toast = message);
  }

  void _setConfirming(bool confirming) {
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    _toastTimer?.cancel();
    setState(() {
      _toast = null;
      _confirming = confirming;
    });
  }

  void _leave() => Navigator.of(context).pop(_entry?.categoryId);

  void _startEditing() {
    HapticFeedback.selectionClick();
    setState(() => _editing = true);
    // The cursor at the end of what is there, ready to go on from it.
    _content.selection = TextSelection.collapsed(offset: _content.text.length);
    _contentFocus.requestFocus();
  }

  // Leaves the editor without saving: back to reading, or out altogether
  // when the entry was never saved.
  void _stopEditing() {
    HapticFeedback.selectionClick();
    if (_entry == null) {
      _leave();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _editing = false;
      _moving = false;
      _whenDate = null;
      _whenMinute = null;
      _fill();
    });
  }

  void _save() {
    final store = JournalScope.of(context);
    final title = _title.text.trim();
    final content = _content.text.trim();
    // A chart is something on its own: it needs no words.
    if (title.isEmpty && content.isEmpty && _bazi == null) {
      _say(Strings.of(context).entryNeedsText);
      return;
    }
    HapticFeedback.selectionClick();
    final categoryId = _categoryId ?? store.categories.first.id;
    final wasDraft = _entry == null && widget.draft != null;
    final moved =
        _entry != null &&
        (_date != _entry!.date || _minuteNow != _entry!.minuteOfDay);
    final changed = _entry?.copyWith(
      categoryId: categoryId,
      title: title,
      content: content,
      place: _place,
      untagged: _place == null,
      tags: _tags.toList(),
    );
    final saved = moved
        // A new date or time: the entry moves, its record and its id with
        // it.
        ? store.move(changed!, _date, _minuteNow * 60)
        : store.save(
            changed ??
                Entry(
                  id: '',
                  date: _date,
                  minuteOfDay: _minuteNow,
                  second: _whenMinute == null ? _startedSecond : 0,
                  utcOffset: widget.utcOffset,
                  categoryId: categoryId,
                  title: title,
                  content: content,
                  place: _place,
                  duration: widget.entry?.duration,
                  bazi: widget.draft?.bazi,
                  tags: _tags.toList(),
                ),
          );
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _entry = saved;
      _editing = false;
      _moving = false;
      _whenDate = null;
      _whenMinute = null;
      _fill();
    });
    // A chart from the bazi page is in the journal only now.
    if (wasDraft && saved.bazi != null) {
      _say(Strings.of(context).baziWritten);
    }
  }

  void _delete() {
    final entry = _entry!;
    HapticFeedback.mediumImpact();
    JournalScope.of(context).delete(entry);
    Navigator.of(context).pop(entry.categoryId);
  }

  void _turnTo(Entry entry) => setState(() {
    _entry = entry;
    _fill();
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final strings = Strings.of(context);
    final store = JournalScope.of(context);
    final category =
        store.category(_categoryId) ?? store.categories.firstOrNull;
    // Every category was deleted from under this entry; it is leaving.
    if (category == null) return ColoredBox(color: colors.background);
    final confirming = _confirming && _entry != null;
    // Where the panel is tall, the tags are kept in it while editing, at
    // the top of the column, and what else the panel holds comes under
    // them; the tag button has nothing left to do there.
    final keptTags = _editing && !confirming && FourParts.tallPanel(context);
    // What the lower panel holds: the tags, or the geotag; and what a
    // toast says, which with the panel otherwise empty raises a strip of
    // it to stand on.
    final copying = !confirming && _selectedIn != null;
    final deletable = !_editing && _entry != null && !copying;
    final panelInUse =
        !confirming &&
        (_tagging && !keptTags ||
            _editing && _moving ||
            _editing && (_place == null ? _placeNotice != null : _placing) ||
            copying);
    // Where the panel is tall, an entry being read has its day beside it
    // in the column: the calendars' reading of the day, then the time,
    // the place, the category and the tags. The moment record stays
    // hidden.
    final aside =
        _entry != null &&
        !_editing &&
        !confirming &&
        !panelInUse &&
        FourParts.tallPanel(context);
    final said = confirming ? Strings.of(context).deleteEntryQuestion : _toast;
    _content
      ..colors = colors
      ..reading = !_editing;

    // A keyboard put away from outside the app (the system's back button)
    // leaves the field holding the focus. Let go of it, so the bar goes
    // back to the ordinary one with its way out.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboard > 0) {
      _keyboardUp = true;
    } else if (_keyboardUp) {
      _keyboardUp = false;
      if (_typing || _placeFocus.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) FocusManager.instance.primaryFocus?.unfocus();
        });
      }
    }
    final labels = SmTextToolbarLabels(
      cut: strings.cut,
      copy: strings.copy,
      paste: strings.paste,
      selectAll: strings.selectAll,
    );
    final minute = _minuteNow;
    final time =
        '${(minute ~/ 60).toString().padLeft(2, '0')}:'
        '${(minute % 60).toString().padLeft(2, '0')}'
        // A practice says how long it went on.
        '${_entry?.duration == null ? '' : ' · ${Strings.of(context).practiceLength(_entry!.duration!)}'}';

    // The day's entries in this entry's category, earliest first.
    final siblings = _entry == null
        ? const <Entry>[]
        : (store
              .entriesFor(_date, utcOffset: widget.utcOffset)
              .where((e) => e.categoryId == _entry!.categoryId)
              .toList()
            ..sort((a, b) => a.secondOfDay.compareTo(b.secondOfDay)));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Back takes back one thing at a time: the question, a search
        // for the phone's position, the place bar, and then leaves.
        if (confirming) {
          _setConfirming(false);
        } else if (_naming) {
          _cancelNaming();
        } else if (_tagging && !keptTags) {
          _toggleTagging();
        } else if (_locating) {
          unawaited(Locator.current.cancel());
        } else if (_editing && (_placing || _placeNotice != null)) {
          _donePlacing();
        } else if (_editing) {
          // Out of the editing without saving, as the way back was.
          _stopEditing();
        } else {
          _leave();
        }
      },
      child: ColoredBox(
        color: colors.background,
        child: SafeArea(
          child: FourParts.fitted(
            top: _Folding(
              open: _editing,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  spacing.md,
                  spacing.md,
                  spacing.md,
                  0,
                ),
                child: TopBar(
                  key: const ValueKey('entry-top-bar'),
                  leading: TopBarTitle(label: strings.gregorian(_date)),
                  // The geotag button: lit while the entry has one.
                  trailing: GlyphButton(
                    key: const ValueKey('entry-place'),
                    glyph: Glyph.place,
                    square: true,
                    lit: _place != null || _locating,
                    marked: _locating,
                    onTap: _onPlaceButton,
                  ),
                  subtitle: '${Weton.of(_date)} · $time',
                  // Touched while editing: the date and time to change.
                  onSubtitleTap: _toggleMoving,
                  subtitleKey: const ValueKey('entry-when-change'),
                  // Beside the time: the name, then the coordinates.
                  // Either gives way to the other when both are long.
                  detail: _place == null
                      ? null
                      : _PlaceBeside(
                          key: const ValueKey('entry-place-beside'),
                          place: _place!,
                        ),
                ),
              ),
            ),
            body: Stack(
              children: [
                Positioned.fill(
                  // The sheet steps back while the delete question is
                  // up. While editing, a tap anywhere on it starts
                  // writing.
                  child: AnimatedOpacity(
                    opacity: confirming ? 0.04 : 1,
                    duration: confirming ? theme.motion.medium : Toast.makeWay,
                    child: IgnorePointer(
                      ignoring: confirming,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _editing
                            ? _contentFocus.requestFocus
                            : _clearSelection,
                        child: Container(
                          key: const ValueKey('entry-sheet'),
                          margin: EdgeInsets.all(spacing.md),
                          decoration: BoxDecoration(
                            color: Color.alphaBlend(
                              category.color.withValues(alpha: 0.13),
                              colors.surface,
                            ),
                            border: Border.all(
                              color: category.color.withValues(alpha: 0.9),
                              width: 1.2,
                            ),
                            borderRadius: BorderRadius.circular(theme.radii.md),
                          ),
                          child: Stack(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // The same header strip as on the cards:
                                  // the category, and while reading a dot
                                  // for each of the day's entries in it.
                                  SizedBox(
                                    key: const ValueKey('entry-category'),
                                    height: 34,
                                    child: Padding(
                                      // Room at the right for the bin, when
                                      // it is there.
                                      padding: EdgeInsets.only(
                                        left: spacing.lg + spacing.xs,
                                        right: deletable
                                            ? _binMargin + 26 + spacing.sm
                                            : spacing.md,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              category.name.toUpperCase(),
                                              maxLines: 1,
                                              softWrap: false,
                                              overflow: TextOverflow.fade,
                                              style: theme.type.caption
                                                  .copyWith(
                                                    color: category.color,
                                                    letterSpacing: 1.2,
                                                  ),
                                            ),
                                          ),
                                          if (!_editing && siblings.length > 1)
                                            DotPicker(
                                              key: const ValueKey(
                                                'entry-picker',
                                              ),
                                              dots: [
                                                for (final sibling in siblings)
                                                  (
                                                    id: sibling.id,
                                                    color: category.color,
                                                  ),
                                              ],
                                              selected: _entry?.id,
                                              onPick: (id) => _turnTo(
                                                siblings.firstWhere(
                                                  (e) => e.id == id,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      // At the foot, room to read the last
                                      // line clear of the buttons over it.
                                      padding: EdgeInsets.fromLTRB(
                                        spacing.lg + spacing.xs,
                                        spacing.xs,
                                        spacing.lg + spacing.xs,
                                        spacing.lg + 40 + spacing.md,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          // A chart's entry is its name first,
                                          // the moment it was written under it;
                                          // any other, the moment first.
                                          if (_bazi != null) ...[
                                            SmTextField(
                                              key: const ValueKey(
                                                'entry-title',
                                              ),
                                              controller: _title,
                                              focusNode: _titleFocus,
                                              labels: labels,
                                              readOnly: !_editing,
                                              toolbar: _editing,
                                              // A long title wraps when read
                                              // and stays on one line when
                                              // written.
                                              multiline: !_editing,
                                              placeholder:
                                                  strings.titlePlaceholder,
                                              autofocus: widget.entry == null,
                                              textInputAction:
                                                  TextInputAction.next,
                                              onSubmitted: (_) =>
                                                  _contentFocus.requestFocus(),
                                              highlight: category.color,
                                              selectionStrength: 0.5,
                                              style: theme.type.title.copyWith(
                                                color: colors.textPrimary,
                                              ),
                                            ),
                                            // While reading, what the top bar
                                            // would say is here, inside.
                                            _Folding(
                                              open: !_editing,
                                              child: Padding(
                                                key: const ValueKey(
                                                  'entry-when',
                                                ),
                                                padding: EdgeInsets.only(
                                                  top: spacing.xs,
                                                  bottom: spacing.md,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '${strings.gregorian(_date)}'
                                                      ' · ${Weton.of(_date)}'
                                                      ' · $time',
                                                      style: theme.type.label
                                                          .copyWith(
                                                            color: colors
                                                                .textSecondary,
                                                          ),
                                                    ),
                                                    // The sky at that moment.
                                                    if (_skyStamp(strings)
                                                        case final stamp?)
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              top: spacing.xs,
                                                            ),
                                                        child: Text(
                                                          stamp,
                                                          key: const ValueKey(
                                                            'entry-sky-stamp',
                                                          ),
                                                          style: theme
                                                              .type
                                                              .caption
                                                              .copyWith(
                                                                color: colors
                                                                    .textFaint,
                                                              ),
                                                        ),
                                                      ),
                                                    // Under the time: where,
                                                    // if it was geotagged.
                                                    if (_entry?.place
                                                        case final place?)
                                                      _PlaceUnder(
                                                        key: const ValueKey(
                                                          'entry-place-under',
                                                        ),
                                                        place: place,
                                                        hue: category.color,
                                                        onTap: () =>
                                                            _openPlace(place),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ] else ...[
                                            // While reading, what the top bar
                                            // would say is here, inside.
                                            _Folding(
                                              open: !_editing,
                                              child: Padding(
                                                key: const ValueKey(
                                                  'entry-when',
                                                ),
                                                padding: EdgeInsets.only(
                                                  bottom: spacing.lg,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      strings.gregorian(
                                                        widget.date,
                                                      ),
                                                      style: theme.type.title
                                                          .copyWith(
                                                            color: colors
                                                                .textPrimary,
                                                          ),
                                                    ),
                                                    SizedBox(
                                                      height: spacing.xs,
                                                    ),
                                                    Text(
                                                      '${Weton.of(_date)}'
                                                      ' · $time',
                                                      style: theme.type.label
                                                          .copyWith(
                                                            color: colors
                                                                .textSecondary,
                                                          ),
                                                    ),
                                                    // The sky at that moment.
                                                    if (_skyStamp(strings)
                                                        case final stamp?)
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              top: spacing.xs,
                                                            ),
                                                        child: Text(
                                                          stamp,
                                                          key: const ValueKey(
                                                            'entry-sky-stamp',
                                                          ),
                                                          style: theme
                                                              .type
                                                              .caption
                                                              .copyWith(
                                                                color: colors
                                                                    .textFaint,
                                                              ),
                                                        ),
                                                      ),
                                                    // Under the time: where,
                                                    // if it was geotagged.
                                                    if (_entry?.place
                                                        case final place?)
                                                      _PlaceUnder(
                                                        key: const ValueKey(
                                                          'entry-place-under',
                                                        ),
                                                        place: place,
                                                        hue: category.color,
                                                        onTap: () =>
                                                            _openPlace(place),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            SmTextField(
                                              key: const ValueKey(
                                                'entry-title',
                                              ),
                                              controller: _title,
                                              focusNode: _titleFocus,
                                              labels: labels,
                                              readOnly: !_editing,
                                              toolbar: _editing,
                                              // A long title wraps when read
                                              // and stays on one line when
                                              // written.
                                              multiline: !_editing,
                                              placeholder:
                                                  strings.titlePlaceholder,
                                              autofocus: widget.entry == null,
                                              textInputAction:
                                                  TextInputAction.next,
                                              onSubmitted: (_) =>
                                                  _contentFocus.requestFocus(),
                                              highlight: category.color,
                                              selectionStrength: 0.5,
                                              style: theme.type.title.copyWith(
                                                fontSize: 17,
                                                color: colors.textPrimary,
                                              ),
                                            ),
                                          ],
                                          SizedBox(height: spacing.md),
                                          // A chart's entry: the chart, drawn
                                          // from what it was written from;
                                          // the words under it are the
                                          // writer's.
                                          if (_bazi case final bazi?) ...[
                                            BaziCard(
                                              value: bazi,
                                              hue: category.color,
                                              onOpen: _editing || _entry == null
                                                  ? null
                                                  : () => _openBazi(_entry!),
                                            ),
                                            SizedBox(height: spacing.md),
                                          ],
                                          SmTextField(
                                            key: const ValueKey(
                                              'entry-content',
                                            ),
                                            inputFormatters: const [
                                              MarkdownContinuation(),
                                            ],
                                            controller: _content,
                                            focusNode: _contentFocus,
                                            labels: labels,
                                            readOnly: !_editing,
                                            toolbar: _editing,
                                            placeholder:
                                                strings.contentPlaceholder,
                                            multiline: true,
                                            // The selection in the sheet's
                                            // own colour, and strong enough
                                            // to see against its tint.
                                            highlight: category.color,
                                            selectionStrength: 0.5,
                                            style: theme.type.body.copyWith(
                                              color: colors.textPrimary
                                                  .withValues(alpha: 0.9),
                                              height: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Deleting it: the bin at the sheet's top
                              // right, its top level with the category's
                              // name and as far in from the right as from
                              // the top (owner, 20 October 2026). It asks
                              // first; a new entry has nothing to delete.
                              if (deletable)
                                Positioned(
                                  top: _binMargin,
                                  right: _binMargin,
                                  child: GlyphButton(
                                    key: const ValueKey('entry-delete'),
                                    glyph: Glyph.delete,
                                    compact: true,
                                    tint: DeleteCardButton.red,
                                    onTap: () => _setConfirming(true),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // What the entry is for, at the sheet's bottom right: the
                // tags, and editing it or saving the edit. While typing
                // the tick is in the format bar.
                Positioned(
                  right: spacing.md * 2,
                  bottom: spacing.md * 2,
                  child: AnimatedOpacity(
                    opacity: confirming || _typing || copying ? 0 : 1,
                    duration: theme.motion.shift,
                    child: IgnorePointer(
                      ignoring: confirming || _typing || copying,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!keptTags) ...[
                            GlyphButton(
                              key: const ValueKey('entry-tags'),
                              glyph: Glyph.tag,
                              square: true,
                              lit: _tagging,
                              marked: _tags.isNotEmpty,
                              onTap: _toggleTagging,
                            ),
                            SizedBox(width: spacing.sm),
                          ],
                          _editing
                              ? GlyphButton(
                                  key: const ValueKey('entry-done'),
                                  glyph: Glyph.save,
                                  square: true,
                                  lit: true,
                                  here: true,
                                  onTap: _save,
                                )
                              : GlyphButton(
                                  key: const ValueKey('entry-edit'),
                                  glyph: Glyph.edit,
                                  square: true,
                                  lit: true,
                                  here: true,
                                  onTap: _startEditing,
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Over the sheet only while the lower panel is in use;
                // otherwise the toast has a strip of panel of its own.
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Toast(
                    hurried: _toast == null,
                    message: panelInUse || aside ? _toast : null,
                  ),
                ),
              ],
            ),
            panelAtTop: keptTags || aside,
            panel: aside
                ? _aside(theme, strings, store, category, time)
                : _panel(
                    keptTags: keptTags,
                    open: panelInUse || said != null,
                    child: !panelInUse
                        ? PanelFoot(
                            key: const ValueKey('entry-toast-strip'),
                            toast: SizedBox(
                              width: double.infinity,
                              height: _toastStrip,
                              child: Center(
                                child: Toast(
                                  hurried: _toast == null,
                                  message: said,
                                ),
                              ),
                            ),
                            // The question to delete is answered here.
                            answer: confirming
                                ? ConfirmBar(
                                    label: strings.delete,
                                    onConfirm: _delete,
                                    onCancel: () => _setConfirming(false),
                                  )
                                : null,
                          )
                        : copying
                        ? Padding(
                            key: const ValueKey('entry-copy-panel'),
                            padding: EdgeInsets.all(spacing.md),
                            child: _copyBar(strings),
                          )
                        : _editing && _moving
                        ? Builder(
                            builder: (context) => SizedBox(
                              height: _instrumentHeight(context),
                              child: _whenPanel(theme, strings),
                            ),
                          )
                        : _tagging && !keptTags
                        ? Builder(
                            builder: (context) => SizedBox(
                              height: _instrumentHeight(context),
                              child: TagPanel(
                                chosen: _tags,
                                onChanged: _setTags,
                                onNew: _startNaming,
                              ),
                            ),
                          )
                        : _place == null && _placeNotice == null
                        ? const SizedBox(width: double.infinity)
                        : _placePanel(theme, strings, store, _place),
                  ),
            bar: RoomBar(
              // Only what the keyboard brings: the format bar, a tag or a
              // place being named.
              typing:
                  _naming || _typing || _editing && _placing && _place != null
                  ? BottomBar(
                      padding: EdgeInsets.all(spacing.md).copyWith(
                        bottom:
                            spacing.md +
                            MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border(top: BorderSide(color: colors.outline)),
                      ),
                      child: AnimatedSwitcher(
                        duration: theme.motion.shift,
                        child: _naming
                            ? TagNameBar(
                                controller: _tagName,
                                focusNode: _tagFocus,
                                onDone: _doneNaming,
                                onCancel: _cancelNaming,
                              )
                            : _typing
                            ? _formatBar(theme)
                            : _placeBar(theme, strings, labels),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  // The date and the time of the entry, as wheels: changed here, saved
  // with the tick.
  Widget _whenPanel(SmThemeData theme, Strings strings) {
    return Column(
      key: const ValueKey('entry-when-panel'),
      children: [
        SizedBox(height: theme.spacing.sm),
        PanelTabs(
          listKey: const ValueKey('entry-when-tabs'),
          tabs: const [0, 1],
          shown: _whenTab,
          label: (k) => k == 0 ? strings.skyDate : strings.skyTime,
          keyOf: (k) => k == 0 ? 'entry-when-date' : 'entry-when-time',
          onChoose: (k) {
            HapticFeedback.selectionClick();
            setState(() => _whenTab = k);
          },
        ),
        Expanded(
          child: _whenTab == 0
              ? Center(
                  child: DatePicker(
                    date: _date,
                    strings: strings,
                    onChanged: (date) => setState(() => _whenDate = date),
                  ),
                )
              : Padding(
                  padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
                  child: TimePicker(
                    minuteOfDay: _minuteNow,
                    onChanged: (minute) => setState(() => _whenMinute = minute),
                  ),
                ),
        ),
      ],
    );
  }

  /// The column beside an entry being read, where the panel is tall: the
  /// day as the calendars read it (the detailed reading's rows), and under
  /// it the entry's time, place, category and tags, read only.
  Widget _aside(
    SmThemeData theme,
    Strings strings,
    JournalStore store,
    JournalCategory category,
    String time,
  ) {
    final entry = _entry!;
    final spacing = theme.spacing;
    final colors = theme.colors;
    final value = theme.type.body.copyWith(color: colors.textPrimary);
    final tags = [for (final id in entry.tags) ?store.tag(id)];

    return SizedBox(
      key: const ValueKey('entry-aside'),
      height: FourParts.roomOf(context),
      child: ReadingPanel(
        title: strings.gregorian(entry.date),
        lines: readingLines(
          entry.date,
          utcOffset: entry.utcOffset,
          strings: strings,
        ),
        after: [
          SizedBox(height: spacing.md),
          const PanelSeparator(),
          SizedBox(height: spacing.sm),
          ReadingRow(
            key: const ValueKey('entry-aside-time'),
            label: strings.skyTime.toUpperCase(),
            child: Text(time, textAlign: TextAlign.end, style: value),
          ),
          if (entry.place case final place?)
            ReadingRow(
              key: const ValueKey('entry-aside-place'),
              label: strings.baziPlace.toUpperCase(),
              // A tap opens it in the maps, as under the time.
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openPlace(place),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (place.name.isNotEmpty)
                      Text(
                        place.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: value,
                      ),
                    Text(
                      place.coordinates,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.type.label.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ReadingRow(
            key: const ValueKey('entry-aside-category'),
            label: strings.searchCategory.toUpperCase(),
            child: Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: value.copyWith(color: category.color),
            ),
          ),
          if (tags.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(top: spacing.xs),
              child: Text(
                strings.searchTags.toUpperCase(),
                style: theme.type.caption.copyWith(
                  color: colors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            // As the tag panel draws them, each on; nothing to touch.
            for (final tag in tags)
              SizedBox(
                key: ValueKey('entry-aside-tag-${tag.id}'),
                height: 36,
                child: TagMark(name: tag.name, on: true),
              ),
          ],
        ],
      ),
    );
  }

  // As tall as the reminder screen's instruments.
  static const _tagPanelHeight = 190.0;

  // How tall the tags and the date and time stand in the panel: the
  // phone's own, or on a tablet upright the standard panel's, as the
  // reminder's instruments and the main pages' panels stand.
  static double _instrumentHeight(BuildContext context) =>
      FourParts.standardOf(context) ?? _tagPanelHeight;

  // The tags kept in a tall panel: a little more than the instruments,
  // and about what the column has over the bar with the keyboard up.
  static const _keptTagsHeight = 240.0;

  /// The lower panel: what is in use folding in and out; and where the
  /// tags are kept ([keptTags]), the tags over it, always there.
  Widget _panel({
    required bool keptTags,
    required bool open,
    required Widget child,
  }) {
    if (!keptTags) return _Folding(open: open, child: child);
    return Column(
      key: const ValueKey('entry-kept-tags'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _keptTagsHeight,
          child: TagPanel(
            chosen: _tags,
            onChanged: _setTags,
            onNew: _startNaming,
          ),
        ),
        _Folding(
          open: open,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [const PanelSeparator(), child],
          ),
        ),
      ],
    );
  }

  // How far the bin stands in from the sheet's top and right: where the
  // category's name, a line of caption in the 34-point strip, begins.
  static const _binMargin = (34 - 10 * 1.2) / 2;

  // The strip of panel a toast rises with, when nothing else is there.
  static const _toastStrip = 72.0;

  /// The place panel: everything there is to say about the geotag.
  ///
  /// With a geotag: its coordinates, the note that they are rounded, and
  /// a chip for each named place nearby. With none: what a search for the
  /// phone's position is doing, or why it failed; a tap puts that away.
  Widget _placePanel(
    SmThemeData theme,
    Strings strings,
    JournalStore store,
    GeoTag? place,
  ) {
    final spacing = theme.spacing;
    final colors = theme.colors;
    final nearby = place == null ? const <GeoTag>[] : store.placesNear(place);
    final notice = _placeNotice;

    return Column(
      key: const ValueKey('place-panel'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PanelSeparator(),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: place == null && !_locating ? _donePlacing : null,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.lg,
              spacing.md,
              spacing.lg,
              spacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (place != null) ...[
                  Text(
                    place.coordinates,
                    key: const ValueKey('place-coordinates'),
                    style: theme.type.body.copyWith(color: colors.textPrimary),
                  ),
                  SizedBox(height: spacing.xs),
                ],
                if (notice != null)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: place == null ? 0 : spacing.xs,
                    ),
                    child: Text(
                      notice,
                      key: const ValueKey('place-notice'),
                      style: theme.type.label.copyWith(
                        color: colors.textPrimary.withValues(alpha: 0.9),
                        height: 1.45,
                      ),
                    ),
                  ),
                if (place != null)
                  Text(
                    strings.placePrecision,
                    key: const ValueKey('place-precision'),
                    style: theme.type.caption.copyWith(
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (nearby.isNotEmpty)
          PillRow(
            listKey: const ValueKey('place-nearby'),
            inset: spacing.lg,
            children: [
              Center(
                child: Text(
                  strings.placeNearby.toUpperCase(),
                  style: theme.type.caption.copyWith(
                    color: colors.textFaint,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              for (final known in nearby)
                // A long name is cut here; chosen, it is whole.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: BarButton(
                    key: ValueKey('nearby-${known.name}'),
                    label: known.name,
                    compact: true,
                    small: true,
                    filled: known.name == place?.name,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _placeName.text = known.name;
                    },
                  ),
                ),
            ],
          ),
        SizedBox(height: spacing.sm),
      ],
    );
  }

  /// The bar while a geotag is being named: the bin that takes the tag
  /// off, the name, and the tick.
  Widget _placeBar(
    SmThemeData theme,
    Strings strings,
    SmTextToolbarLabels labels,
  ) {
    final spacing = theme.spacing;
    final colors = theme.colors;

    return Row(
      key: const ValueKey('place-bar'),
      children: [
        GlyphButton(
          key: const ValueKey('place-remove'),
          glyph: Glyph.delete,
          square: true,
          tint: dangerColor,
          onTap: _removePlace,
        ),
        SizedBox(width: spacing.sm),
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.md,
              vertical: spacing.sm + 1,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: colors.outline),
              borderRadius: BorderRadius.circular(theme.radii.md),
            ),
            child: SmTextField(
              key: const ValueKey('place-name'),
              controller: _placeName,
              focusNode: _placeFocus,
              labels: labels,
              plain: true,
              placeholder: strings.placeNamePlaceholder,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _donePlacing(),
              style: theme.type.body.copyWith(color: colors.textPrimary),
            ),
          ),
        ),
        SizedBox(width: spacing.sm),
        GlyphButton(
          key: const ValueKey('place-done'),
          glyph: Glyph.save,
          square: true,
          lit: true,
          onTap: _donePlacing,
        ),
      ],
    );
  }

  /// The bar while typing: the format buttons in a strip that scrolls
  /// sideways, and Save as a tick at the right, where it never moves.
  ///
  /// A button is lit while the caret is inside what it marks, and tapping
  /// it then takes the mark off. The heading button also says which level.
  ///
  /// The format buttons work on the content only, so they step back while
  /// the title is being typed.
  Widget _formatBar(SmThemeData theme) {
    final spacing = theme.spacing;
    final inContent = _contentFocus.hasFocus;
    final value = _content.value;
    final formats = inContent ? Markdown.formatsAt(value) : const <Format>{};
    final heading = inContent ? Markdown.headingAt(value) : 0;

    Widget button(
      String name,
      Glyph glyph,
      bool lit,
      TextEditingValue Function(TextEditingValue) change, {
      String? badge,
    }) => Padding(
      padding: EdgeInsets.only(right: spacing.sm),
      child: GlyphButton(
        key: ValueKey('format-$name'),
        glyph: glyph,
        square: true,
        lit: lit,
        badge: badge,
        onTap: () => _format(change),
      ),
    );

    Widget inline(String name, Glyph glyph, Format format) => button(
      name,
      glyph,
      formats.contains(format),
      (v) => Markdown.toggle(v, format),
    );

    return Row(
      key: const ValueKey('format-bar'),
      children: [
        Expanded(
          child: AnimatedOpacity(
            opacity: inContent ? 1 : 0.3,
            duration: theme.motion.shift,
            child: IgnorePointer(
              ignoring: !inContent,
              // Its bar in the bar's padding below the buttons, as far
              // from them as under the colour schemes' pills.
              child: ScrollHintRoom(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: ScrollHintRoom.room),
                  child: Row(
                    children: [
                      inline('bold', Glyph.bold, Format.bold),
                      inline('italic', Glyph.italic, Format.italic),
                      inline('underline', Glyph.underline, Format.underline),
                      inline('strike', Glyph.strike, Format.strike),
                      button(
                        'list',
                        Glyph.list,
                        inContent && Markdown.listAt(value),
                        (v) => Markdown.toggleLines(v, '- '),
                      ),
                      button(
                        'footnote',
                        Glyph.footnote,
                        inContent && Markdown.footnoteAt(value),
                        Markdown.toggleFootnote,
                      ),
                      button(
                        'heading',
                        Glyph.heading,
                        heading > 0,
                        Markdown.cycleHeading,
                        badge: heading > 0 ? '$heading' : null,
                      ),
                      inline('code', Glyph.code, Format.code),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: spacing.sm),
        GlyphButton(
          key: const ValueKey('entry-save'),
          glyph: Glyph.save,
          lit: true,
          onTap: _save,
        ),
      ],
    );
  }

  /// The bar while something is selected in an entry being read: what to
  /// copy. Each button stretches the selection to the word, sentence or
  /// paragraph it is in, or to everything, and copies that.
  Widget _copyBar(Strings strings) {
    Widget unit(
      String name,
      String label,
      TextRange Function(String, int) of, {
      bool everything = false,
    }) => Flexible(
      child: BarButton(
        key: ValueKey('copy-$name'),
        label: label,
        compact: true,
        onTap: () => _copy(of, everything: everything),
      ),
    );

    return Row(
      key: const ValueKey('copy-bar'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        unit('word', strings.copyWord, Markdown.wordAt),
        unit('sentence', strings.copySentence, Markdown.sentenceAt),
        unit('paragraph', strings.copyParagraph, Markdown.paragraphAt),
        unit(
          'all',
          strings.copyAll,
          (text, _) => TextRange(start: 0, end: text.length),
          everything: true,
        ),
      ],
    );
  }

  // The field with something selected in it, while reading.
  TextEditingController? get _selectedIn {
    if (_editing) return null;
    for (final controller in [_content, _title]) {
      final selection = controller.selection;
      if (selection.isValid && !selection.isCollapsed) return controller;
    }
    return null;
  }

  void _copy(
    TextRange Function(String text, int offset) of, {
    bool everything = false,
  }) {
    final controller = _selectedIn;
    if (controller == null) return;
    HapticFeedback.selectionClick();
    final text = controller.text;
    final range = of(text, controller.selection.start);
    // Shown as selected, so it is plain what was taken.
    controller.selection = TextSelection(
      baseOffset: range.start,
      extentOffset: range.end,
    );
    // Everything means the whole entry: its title, then its content.
    Clipboard.setData(
      ClipboardData(
        text: everything
            ? [
                _title.text,
                _content.text,
              ].where((part) => part.isNotEmpty).join('\n\n')
            : range.textInside(text),
      ),
    );
    _say(Strings.of(context).copied);
  }

  // A tap on the sheet outside the words lets go of whatever is selected.
  void _clearSelection() {
    for (final controller in [_title, _content]) {
      if (!controller.selection.isCollapsed) {
        controller.selection = TextSelection.collapsed(
          offset: controller.selection.start,
        );
      }
    }
  }
}

/// Opens and closes its child's height, with a fade, as [open] changes.
class _Folding extends StatelessWidget {
  final bool open;
  final Widget child;

  const _Folding({required this.open, required this.child});

  @override
  Widget build(BuildContext context) {
    final motion = SmTheme.of(context).motion;

    return AnimatedSize(
      duration: motion.medium,
      curve: motion.curve,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: motion.medium,
        opacity: open ? 1 : 0,
        child: open ? child : const SizedBox(width: double.infinity),
      ),
    );
  }
}

/// A geotag beside the time in the top bar: a dot, the name, a dot, the
/// coordinates, on one line. The coordinates are short and are shown
/// whole; the name has what room is left and is cut with an ellipsis.
/// Only where even the coordinates do not fit are they cut too.
class _PlaceBeside extends StatelessWidget {
  final GeoTag place;

  const _PlaceBeside({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final style = theme.type.label.copyWith(color: theme.colors.textSecondary);
    final coordinates = ' · ${place.coordinates}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final needed = (TextPainter(
          text: TextSpan(text: coordinates, style: style),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout()).width.ceilToDouble();

        return Row(
          children: [
            if (place.name.isNotEmpty)
              Flexible(
                child: Text(
                  ' · ${place.name}',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            SizedBox(
              width: math.min(needed, constraints.maxWidth),
              child: Text(
                coordinates,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A geotag under the time on an entry being read: a pin, the name on up
/// to two lines, and the coordinates under it. A tap opens it in the
/// phone's maps app.
class _PlaceUnder extends StatelessWidget {
  final GeoTag place;
  final Color hue;
  final VoidCallback onTap;

  const _PlaceUnder({
    super.key,
    required this.place,
    required this.hue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(top: spacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: GlyphMark(glyph: Glyph.place, size: 12, color: hue),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (place.name.isNotEmpty)
                    Text(
                      place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.type.label.copyWith(
                        color: colors.textPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                  Text(
                    place.coordinates,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.type.label.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
