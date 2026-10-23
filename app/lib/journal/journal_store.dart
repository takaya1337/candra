import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';

import 'entry.dart';
import 'geo.dart';
import 'journal_storage.dart';

/// The journal's categories and entries, and every rule about them.
///
/// Where they are kept is the [JournalStorage]'s business: files on the
/// device, or memory for tests.
class JournalStore extends ChangeNotifier {
  /// There can never be more categories than there are colours.
  static const maxCategories = 24;

  static final _random = Random.secure();

  final JournalStorage _storage;
  late final List<JournalCategory> _categories;
  late final List<JournalTag> _tags = _storage.loadTags();

  // The days read so far. Dropped whenever anything changes.
  final _days = <int, List<Entry>>{};

  // Which categories have entries on which day, for the months asked
  // about so far (as year * 12 + month). Dropped with the days.
  final _marks = <int, List<String>>{};
  final _markedMonths = <int>{};

  /// Gives a new entry the moment it is first saved, in every calendar
  /// (`MomentStamp`), from its geotag if it has one; set by the app, none
  /// in tests unless they set it.
  Map<String, String?> Function(GeoTag? geotag)? stamp;

  /// Goes up by one with every change, for whoever keeps something worked
  /// out from the journal.
  int get revision => _revision;
  var _revision = 0;

  JournalStore([JournalStorage? storage])
    : _storage = storage ?? MemoryJournalStorage() {
    final saved = _storage.loadCategories();
    _categories = [...?saved];
    // A journal never opened before starts with a few categories.
    if (saved == null) {
      for (final (name, colorIndex) in startingCategories) {
        _categories.add(
          JournalCategory(id: _newId(), name: name, colorIndex: colorIndex),
        );
      }
      _storage.saveCategories(_categories);
    }
  }

  @override
  void dispose() {
    _storage.close();
    super.dispose();
  }

  void _changed({bool categories = false}) {
    _revision++;
    _days.clear();
    _marks.clear();
    _markedMonths.clear();
    if (categories) _storage.saveCategories(_categories);
    notifyListeners();
  }

  // Categories.

  List<JournalCategory> get categories => List.unmodifiable(_categories);

  bool get canAddCategory => _categories.length < maxCategories;

  JournalCategory? category(String? id) {
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  /// The category that has palette colour [colorIndex], if any.
  JournalCategory? ownerOf(int colorIndex) {
    for (final category in _categories) {
      if (category.colorIndex == colorIndex) return category;
    }
    return null;
  }

  /// The first palette colour no category has.
  int get freeColor =>
      Iterable<int>.generate(maxCategories)
          .firstWhere((i) => ownerOf(i) == null);

  // A category's id is six random hex digits: the name of its folders, and
  // nothing a person is meant to read. What the category is called can
  // then change freely without a single file having to move.
  String _newId() {
    while (true) {
      final id = _random.nextInt(0x1000000).toRadixString(16).padLeft(6, '0');
      if (category(id) == null) return id;
    }
  }

  /// Adds a category, or returns null at the limit. A colour another
  /// category already has is taken from it; that one gets [ownerTo], or
  /// the first free colour.
  JournalCategory? addCategory(String name, {int? colorIndex, int? ownerTo}) {
    if (!canAddCategory) return null;
    final color = colorIndex ?? freeColor;
    final owner = ownerOf(color);
    if (owner != null) {
      _replace(owner.copyWith(colorIndex: _freeOr(ownerTo, null)));
    }
    final added = JournalCategory(id: _newId(), name: name, colorIndex: color);
    _categories.add(added);
    _changed(categories: true);
    return added;
  }

  void renameCategory(String id, String name) {
    final renamed = category(id)!.copyWith(name: name);
    if (renamed.name == category(id)!.name) return;
    _replace(renamed);
    // Every entry carries its category's name, for whoever reads the
    // files; write them again under the new one.
    for (final entry in _storage.entriesIn(id)) {
      _storage.put(
        entry,
        categoryName: name,
        previous: entry,
        tagNames: _tagNames(entry),
      );
    }
    _changed(categories: true);
  }

  /// Gives category [id] the palette colour [colorIndex]. If another
  /// category has it, that one gets [ownerTo], or failing that the colour
  /// [id] is giving up, so the two trade.
  void recolorCategory(String id, int colorIndex, {int? ownerTo}) {
    final target = category(id)!;
    if (target.colorIndex == colorIndex) return;
    final owner = ownerOf(colorIndex);
    if (owner != null) {
      _replace(owner.copyWith(colorIndex: _freeOr(ownerTo, target.colorIndex)));
    }
    _replace(target.copyWith(colorIndex: colorIndex));
    _changed(categories: true);
  }

  // [wanted] if no category has it, else [fallback], else any free colour.
  int _freeOr(int? wanted, int? fallback) =>
      wanted != null && ownerOf(wanted) == null
      ? wanted
      : fallback ?? freeColor;

  /// How many entries, on any day, are in category [id].
  int entryCount(String id) => _storage.countIn(id);

  /// Removes category [id], and every entry in it.
  void deleteCategory(String id) {
    _storage.entriesIn(id).forEach(_storage.remove);
    _categories.removeWhere((c) => c.id == id);
    _changed(categories: true);
  }

  void _replace(JournalCategory changed) {
    _categories[_categories.indexWhere((c) => c.id == changed.id)] = changed;
  }

  // Entries.

  List<Entry> entriesFor(CivilDate date, {required Duration utcOffset}) =>
      List.unmodifiable(_day(date, utcOffset));

  /// A day's entries grouped into one plane per category.
  List<JournalPlane> planesFor(CivilDate date, {required Duration utcOffset}) =>
      planesOf(_day(date, utcOffset), _categories);

  List<Entry> _day(CivilDate date, Duration utcOffset) => _days.putIfAbsent(
    date.dayNumber,
    () => _storage.entriesOn(date, utcOffset: utcOffset),
  );

  /// The categories with entries on [date], the one with the earliest
  /// entry first: the day's dots on the calendar.
  List<JournalCategory> marksOn(CivilDate date, {required Duration utcOffset}) {
    _markMonth(date.year, date.month, utcOffset);
    return [
      for (final id in _marks[date.dayNumber] ?? const <String>[])
        ?category(id),
    ];
  }

  /// The categories with entries in a month, the one whose first entry of
  /// the month is earliest first: the month's dots on the year grid.
  List<JournalCategory> marksIn(
    int year,
    int month, {
    required Duration utcOffset,
  }) {
    _markMonth(year, month, utcOffset);
    final first = CivilDate(year, month, 1).dayNumber;
    final ids = <String>{};
    for (var day = 0; day < CivilDate.daysInMonth(year, month); day++) {
      ids.addAll(_marks[first + day] ?? const []);
    }
    return [for (final id in ids) ?category(id)];
  }

  // Reads a whole month's marks at once, the first time any of it is
  // asked for.
  void _markMonth(int year, int month, Duration utcOffset) {
    if (!_markedMonths.add(year * 12 + month)) return;
    final first = CivilDate(year, month, 1).dayNumber;
    _marks.addAll(
      _storage.categoriesByDay(
        first,
        first + CivilDate.daysInMonth(year, month) - 1,
        utcOffset: utcOffset,
      ),
    );
  }

  /// Saves [entry] and returns it as saved.
  ///
  /// An entry with no id is new. It is named after its date and time; if
  /// another entry of that day already has that second, it takes the next
  /// one free.
  ///
  /// [previous] is the entry as it was last saved, when the caller has it.
  /// Two entries of different categories can share a second, and so an
  /// id, when they were written on two devices; without it the one in the
  /// same category is taken for the one being edited.
  Entry save(Entry entry, {Entry? previous}) =>
      _save(entry, stamped: true, previous: previous);

  // [stamped]: a new entry takes the moment it is first saved. Not when
  // an entry is only moving: one from before records were kept stays
  // without, rather than taking a moment it was not made at.
  Entry _save(Entry entry, {required bool stamped, Entry? previous}) {
    final name = category(entry.categoryId)?.name ?? entry.categoryId;
    if (entry.id.isNotEmpty) {
      final same = _day(
        entry.date,
        entry.utcOffset,
      ).where((e) => e.id == entry.id);
      previous ??=
          same.where((e) => e.categoryId == entry.categoryId).firstOrNull ??
          same.firstOrNull;
      _storage.put(
        entry,
        categoryName: name,
        previous: previous,
        tagNames: _tagNames(entry),
      );
      _changed();
      return entry;
    }
    var second = entry.secondOfDay;
    while (_storage.taken(entry.date, second)) {
      second = (second + 1) % Duration.secondsPerDay;
    }
    // A new entry takes the moment it was first saved.
    final withMoment = stamped && entry.moment.isEmpty && stamp != null
        ? entry.copyWith(moment: stamp!(entry.place))
        : entry;
    final saved = withMoment.at(second);
    _storage.put(saved, categoryName: name, tagNames: _tagNames(saved));
    _changed();
    return saved;
  }

  /// Moves [entry] to [date] at [secondOfDay] (its date and time
  /// corrected): the old file goes, the new one is named for the new
  /// moment (the next second free if that one is taken), and everything
  /// else, its moment record and its unchanging id among it, goes with
  /// it.
  ///
  /// [previous] is the entry as it was last saved, when [entry] carries
  /// other edits too. Its file is the one removed: an edit that also
  /// changes the category names a folder where no file is yet, and
  /// removing that would leave the real one behind.
  Entry move(Entry entry, CivilDate date, int secondOfDay, {Entry? previous}) {
    _storage.remove(previous ?? entry);
    final moved = Entry(
      id: '',
      date: date,
      minuteOfDay: secondOfDay ~/ 60,
      second: secondOfDay % 60,
      utcOffset: entry.utcOffset,
      categoryId: entry.categoryId,
      title: entry.title,
      content: entry.content,
      place: entry.place,
      duration: entry.duration,
      tags: entry.tags,
      bazi: entry.bazi,
      moment: entry.moment,
    );
    return _save(moved, stamped: false);
  }

  void delete(Entry entry) {
    _storage.remove(entry);
    _changed();
  }

  /// Reads everything afresh from storage: for after a sync has changed
  /// the files underneath.
  void reload() {
    _storage.refresh();
    _categories
      ..clear()
      ..addAll(_storage.loadCategories() ?? const []);
    _tags
      ..clear()
      ..addAll(_storage.loadTags());
    _changed();
  }

  // Tags.

  /// Every tag, in the order they were made.
  List<JournalTag> get tags => List.unmodifiable(_tags);

  JournalTag? tag(String id) {
    for (final tag in _tags) {
      if (tag.id == id) return tag;
    }
    return null;
  }

  /// The names of an entry's tags that still exist, for its file.
  List<String> _tagNames(Entry entry) => [
    for (final id in entry.tags) ?tag(id)?.name,
  ];

  /// A tag called [name]: the one there is, if a tag of that name exists
  /// already, or a new one. Null for a name with nothing in it.
  JournalTag? addTag(String name) {
    final trimmed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return null;
    for (final tag in _tags) {
      if (tag.name.toLowerCase() == trimmed.toLowerCase()) return tag;
    }
    String id;
    do {
      id = _random.nextInt(0x1000000).toRadixString(16).padLeft(6, '0');
    } while (tag(id) != null);
    final added = JournalTag(id: id, name: trimmed);
    _tags.add(added);
    _storage.saveTags(_tags);
    _changed();
    return added;
  }

  /// How many entries carry tag [id].
  int countTagged(String id) =>
      _storage.allEntries().where((e) => e.tags.contains(id)).length;

  /// Deletes tag [id], and takes it off every entry that has it. (The
  /// reminders' own are the reminder store's to take off.)
  void deleteTag(String id) {
    for (final entry in _storage.allEntries()) {
      if (!entry.tags.contains(id)) continue;
      final kept = entry.copyWith(
        tags: [
          for (final t in entry.tags)
            if (t != id) t,
        ],
      );
      _storage.put(
        kept,
        categoryName: category(kept.categoryId)?.name ?? kept.categoryId,
        previous: entry,
        tagNames: _tagNames(kept),
      );
    }
    _tags.removeWhere((t) => t.id == id);
    _storage.saveTags(_tags);
    _changed();
  }

  /// Every entry there is, for the search.
  List<Entry> allEntries() => _storage.allEntries();

  // Export and import.

  /// The folder the journal is kept in, or null when it is only in memory.
  String? get journalPath => _storage.journalPath;

  /// The named places written from before, close to [here]: offered as
  /// the name of a new geotag made there.
  List<GeoTag> placesNear(GeoTag here) => _storage.placesNear(here);

  /// How many entries there are in all.
  int get entryTotal => _storage.total;

  /// Adds what was read from a journal file to this journal. Nothing here
  /// is removed or overwritten.
  ///
  ///  * A category already here, by its id, stays as it is. One that is
  ///    not is added, with its colour if that is free and another if not.
  ///    A category here with the same name and nothing in it gives way to
  ///    the one coming in, so a fresh journal does not end up with two of
  ///    each starting category.
  ///  * An entry already here, the same in every way its file is read
  ///    back ([Entry.sameAs]: its moment, category, title, content, geotag
  ///    and duration), is left alone. One whose second is taken by an entry
  ///    that differs in any of those, a geotag alone included, is put at
  ///    the next free second, so both are kept: nothing is ever dropped for
  ///    looking alike.
  ///
  /// Throws [TooManyCategories] before changing anything if the two
  /// together would be more than [maxCategories].
  Future<MergeResult> merge(
    List<JournalCategory> categories,
    List<Entry> entries, {
    List<JournalTag> tags = const [],
    void Function(int done, int total)? onProgress,
  }) async {
    // Tags: one here by its id stays; one here by its name takes in the
    // one coming (its entries are pointed at it); any other is added.
    // Only worked out here: they are kept after the check on the
    // categories below, so that a merge turned away changes nothing.
    final tagIds = <String, String>{};
    final newTags = <JournalTag>[];
    for (final incoming in tags) {
      if (tag(incoming.id) != null || newTags.any((t) => t.id == incoming.id)) {
        continue;
      }
      final twin = [..._tags, ...newTags]
          .where((t) => t.name.toLowerCase() == incoming.name.toLowerCase())
          .firstOrNull;
      if (twin != null) {
        tagIds[incoming.id] = twin.id;
      } else {
        newTags.add(incoming);
      }
    }
    entries = [
      for (final entry in entries)
        tagIds.isEmpty
            ? entry
            : entry.copyWith(
                tags: {for (final t in entry.tags) tagIds[t] ?? t}.toList(),
              ),
    ];

    // Categories that entries point at but the file does not list are
    // named after their folder.
    final incoming = [
      ...categories,
      for (final id in {for (final entry in entries) entry.categoryId})
        if (!categories.any((c) => c.id == id))
          JournalCategory(id: id, name: id, colorIndex: 0),
    ];

    // Which of ours each one becomes, or null for a new one.
    final giveWay = <String, JournalCategory>{};
    for (final category in incoming) {
      if (this.category(category.id) != null) continue;
      final twin = _categories
          .where(
            (c) =>
                c.name == category.name &&
                !giveWay.containsValue(c) &&
                !incoming.any((i) => i.id == c.id) &&
                _storage.countIn(c.id) == 0,
          )
          .firstOrNull;
      if (twin != null) giveWay[category.id] = twin;
    }
    final added = incoming
        .where((c) => category(c.id) == null && giveWay[c.id] == null)
        .length;
    if (_categories.length + added > maxCategories) {
      throw TooManyCategories(_categories.length + added);
    }

    _tags.addAll(newTags);
    _storage.saveTags(_tags);

    var newCategories = 0;
    for (final category in incoming) {
      if (this.category(category.id) != null) continue;
      final twin = giveWay[category.id];
      if (twin != null) {
        // Takes the empty one's place, and its colour.
        _categories[_categories.indexOf(twin)] = JournalCategory(
          id: category.id,
          name: category.name,
          colorIndex: twin.colorIndex,
        );
        continue;
      }
      _categories.add(
        JournalCategory(
          id: category.id,
          name: category.name,
          colorIndex: ownerOf(category.colorIndex) == null
              ? category.colorIndex
              : freeColor,
        ),
      );
      newCategories++;
    }
    _storage.saveCategories(_categories);

    var newEntries = 0;
    var same = 0;
    var moved = 0;
    final days = <int, List<Entry>>{};
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final day = days.putIfAbsent(
        entry.date.dayNumber,
        () => _storage.entriesOn(entry.date, utcOffset: entry.utcOffset),
      );
      final name = category(entry.categoryId)!.name;
      final here = day
          .where((e) => e.secondOfDay == entry.secondOfDay)
          .firstOrNull;
      if (here == null) {
        final saved = entry.at(entry.secondOfDay);
        _storage.put(saved, categoryName: name, tagNames: _tagNames(saved));
        day.add(saved);
        newEntries++;
      } else if (here.sameAs(entry)) {
        same++;
      } else {
        var second = entry.secondOfDay;
        while (day.any((e) => e.secondOfDay == second)) {
          second = (second + 1) % Duration.secondsPerDay;
        }
        final saved = entry.at(second);
        _storage.put(saved, categoryName: name, tagNames: _tagNames(saved));
        day.add(saved);
        newEntries++;
        moved++;
      }
      // Lets the screen draw now and then.
      if (i % 100 == 99) {
        onProgress?.call(i + 1, entries.length);
        await Future<void>.delayed(Duration.zero);
      }
    }
    _changed();
    return MergeResult(
      tagIds: tagIds,
      entries: newEntries,
      categories: newCategories,
      alreadyHere: same,
      moved: moved,
    );
  }

  /// Deletes every entry of category [categoryId] on [date]: a whole card.
  void deleteCard(
    CivilDate date,
    String categoryId, {
    required Duration utcOffset,
  }) {
    _day(date, utcOffset)
        .where((e) => e.categoryId == categoryId)
        .toList()
        .forEach(_storage.remove);
    _changed();
  }
}

/// What a [JournalStore.merge] did.
class MergeResult {
  /// Entries and categories added.
  final int entries;
  final int categories;

  /// Entries that were here already, the same in every way.
  final int alreadyHere;

  /// Of the entries added, those put at another second because theirs was
  /// taken by a different entry.
  final int moved;

  /// Tags that came in under another id and were found here by name: the
  /// id they came with, and the one here they became. The reminders that
  /// came with them are pointed the same way.
  final Map<String, String> tagIds;

  const MergeResult({
    this.tagIds = const {},
    required this.entries,
    required this.categories,
    required this.alreadyHere,
    required this.moved,
  });
}

/// Thrown by [JournalStore.merge] when the journal and the file together
/// have more categories than there can be.
class TooManyCategories implements Exception {
  final int count;

  const TooManyCategories(this.count);
}

/// Gives the subtree the [JournalStore]. Widgets that read it rebuild when
/// anything in the journal changes.
class JournalScope extends InheritedNotifier<JournalStore> {
  const JournalScope({
    super.key,
    required JournalStore super.notifier,
    required super.child,
  });

  static JournalStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<JournalScope>()!.notifier!;
}
