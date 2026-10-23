import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sacred_time/sacred_time.dart';
import 'package:sqlite3/sqlite3.dart';

import 'entry.dart';
import 'entry_file.dart';
import 'geo.dart';

/// Where the journal is kept.
abstract class JournalStorage {
  /// The categories in their order, or null if none were ever saved.
  List<JournalCategory>? loadCategories();

  void saveCategories(List<JournalCategory> categories);

  /// The tags, in the order they were made.
  List<JournalTag> loadTags();

  void saveTags(List<JournalTag> tags);

  /// Every entry there is, in no particular order: for the search.
  List<Entry> allEntries();

  /// The entries of one day, in no particular order.
  List<Entry> entriesOn(CivilDate date, {required Duration utcOffset});

  /// Every entry of a category, on any day.
  List<Entry> entriesIn(String categoryId);

  int countIn(String categoryId);

  /// How many entries there are in all.
  int get total;

  /// The folder the journal is kept in, if it is kept in one.
  String? get journalPath => null;

  /// Reads the journal afresh from where it is kept, after something
  /// other than the app has changed it there.
  void refresh() {}

  /// For every day from [first] to [last] (day numbers) that has entries,
  /// its categories, the one with the earliest entry first.
  Map<int, List<String>> categoriesByDay(
    int first,
    int last, {
    required Duration utcOffset,
  });

  /// Whether some entry of [date] already has [secondOfDay].
  bool taken(CivilDate date, int secondOfDay);

  /// The named places of geotagged entries within [GeoTag.nearby] of
  /// [here], nearest first, each name once.
  List<GeoTag> placesNear(GeoTag here);

  /// Writes [entry]. [previous] is the same entry as it was last written,
  /// when it has been written before. [tagNames] are written beside the
  /// tags' ids for whoever reads the file; the app never reads them.
  void put(
    Entry entry, {
    required String categoryName,
    Entry? previous,
    List<String> tagNames = const [],
  });

  void remove(Entry entry);

  void close() {}
}

/// Of [places], those with a name within [GeoTag.nearby] of [here],
/// nearest first, each name once.
List<GeoTag> nearestNamed(GeoTag here, Iterable<GeoTag> places) {
  final near =
      places
          .where(
            (p) => p.name.isNotEmpty && here.distanceTo(p) <= GeoTag.nearby,
          )
          .toList()
        ..sort((a, b) => here.distanceTo(a).compareTo(here.distanceTo(b)));
  final names = <String>{};
  return [
    for (final place in near)
      if (names.add(place.name)) place,
  ];
}

/// A journal that lasts until the app closes, in which every day starts
/// out with its placeholder entries. For tests and for trying things.
class MemoryJournalStorage extends JournalStorage {
  final _byDay = <int, List<Entry>>{};

  List<Entry> _day(CivilDate date, Duration utcOffset) => _byDay.putIfAbsent(
    date.dayNumber,
    () => sampleEntries(date, utcOffset: utcOffset),
  );

  @override
  List<GeoTag> placesNear(GeoTag here) => nearestNamed(here, [
    for (final day in _byDay.values)
      for (final entry in day) ?entry.place,
  ]);

  @override
  List<JournalCategory>? loadCategories() => standInCategories;

  @override
  void saveCategories(List<JournalCategory> categories) {}

  var _tags = <JournalTag>[];

  @override
  List<JournalTag> loadTags() => List.of(_tags);

  @override
  void saveTags(List<JournalTag> tags) => _tags = List.of(tags);

  @override
  List<Entry> allEntries() => [for (final day in _byDay.values) ...day];

  @override
  List<Entry> entriesOn(CivilDate date, {required Duration utcOffset}) =>
      List.of(_day(date, utcOffset));

  @override
  List<Entry> entriesIn(String categoryId) => [
    for (final day in _byDay.values)
      for (final entry in day)
        if (entry.categoryId == categoryId) entry,
  ];

  @override
  int countIn(String categoryId) => entriesIn(categoryId).length;

  @override
  int get total => _byDay.values.fold(0, (sum, day) => sum + day.length);

  @override
  Map<int, List<String>> categoriesByDay(
    int first,
    int last, {
    required Duration utcOffset,
  }) {
    final byDay = <int, List<String>>{};
    for (var day = first; day <= last; day++) {
      final entries = List.of(_day(CivilDate.fromDayNumber(day), utcOffset))
        ..sort((a, b) => a.secondOfDay.compareTo(b.secondOfDay));
      if (entries.isEmpty) continue;
      byDay[day] = {for (final entry in entries) entry.categoryId}.toList();
    }
    return byDay;
  }

  @override
  bool taken(CivilDate date, int secondOfDay) =>
      (_byDay[date.dayNumber] ?? const []).any(
        (e) => e.secondOfDay == secondOfDay,
      );

  @override
  void put(
    Entry entry, {
    required String categoryName,
    Entry? previous,
    List<String> tagNames = const [],
  }) {
    final day = _day(entry.date, entry.utcOffset);
    final index = day.indexWhere((e) => e.id == (previous ?? entry).id);
    if (index < 0) {
      day.add(entry);
    } else {
      day[index] = entry;
    }
  }

  @override
  void remove(Entry entry) =>
      _byDay[entry.date.dayNumber]?.removeWhere((e) => e.id == entry.id);
}

/// The journal as files, which is where it truly lives:
///
///     journal/categories.json
///     journal/entries/2026/10/11/3fa9c1/193005.md
///
/// one Markdown file per entry (see [EntryFile]), foldered by year, month,
/// day and category id. What a category is called is in `categories.json`
/// alone, and in each entry for whoever reads the files. That folder is the whole journal: copy it and nothing
/// is missing.
///
/// Beside it sits `index.db`, a SQLite index of those files that answers
/// "what is on this day" and "how much is in this category" without
/// opening them. It holds nothing the files do not, and is rebuilt from
/// them whenever it is missing, out of date, or was left half-written.
class FileJournalStorage extends JournalStorage {
  static const _indexVersion = 6;

  final Directory _journal;
  final File _dirty;
  final Database _index;

  FileJournalStorage._(this._journal, this._dirty, this._index);

  /// Opens the journal kept under [root], making it if it is not there.
  factory FileJournalStorage.open(Directory root) {
    final journal = Directory(p.join(root.path, 'journal'))
      ..createSync(recursive: true);
    final storage = FileJournalStorage._(
      journal,
      File(p.join(root.path, 'index.dirty')),
      sqlite3.open(p.join(root.path, 'index.db')),
    );
    storage._prepareIndex();
    return storage;
  }

  Directory get _entries => Directory(p.join(_journal.path, 'entries'));
  File get _categories => File(p.join(_journal.path, 'categories.json'));
  File get _tags => File(p.join(_journal.path, 'tags.json'));

  File _fileOf(Entry entry) =>
      File(p.join(_entries.path, EntryFile.pathOf(entry)));

  // The index.

  void _prepareIndex() {
    // An index made by an older version is thrown away and made again:
    // the files are the truth, and it is only ever worked out from them.
    if (_index.userVersion != _indexVersion) {
      _index.execute('DROP TABLE IF EXISTS entries');
    }
    _index.execute('''
      CREATE TABLE IF NOT EXISTS entries (
        day INTEGER NOT NULL,
        second INTEGER NOT NULL,
        utc_offset INTEGER NOT NULL,
        category TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        place TEXT NOT NULL,
        duration INTEGER,
        tags TEXT NOT NULL,
        bazi TEXT,
        moment TEXT,
        PRIMARY KEY (day, second)
      ) WITHOUT ROWID
    ''');
    _index.execute(
      'CREATE INDEX IF NOT EXISTS entries_by_category ON entries (category)',
    );
    if (_index.userVersion != _indexVersion || _dirty.existsSync()) {
      rebuildIndex();
    }
  }

  /// Throws the index away and reads every file again.
  void rebuildIndex() {
    _index.execute('BEGIN');
    _index.execute('DELETE FROM entries');
    if (_entries.existsSync()) {
      for (final file in _entries.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.md')) continue;
        final entry = EntryFile.decode(file.readAsStringSync());
        // The folder decides the category, should the two ever disagree.
        if (entry != null) {
          _indexPut(
            entry.copyWith(categoryId: p.basename(p.dirname(file.path))),
          );
        }
      }
    }
    _index.execute('COMMIT');
    _index.userVersion = _indexVersion;
    if (_dirty.existsSync()) _dirty.deleteSync();
  }

  void _indexPut(Entry entry) => _index.execute(
    'INSERT OR REPLACE INTO entries VALUES '
    '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [
      entry.date.dayNumber,
      entry.secondOfDay,
      entry.utcOffset.inMinutes,
      entry.categoryId,
      entry.title,
      entry.content,
      entry.place?.latitude,
      entry.place?.longitude,
      entry.place?.name ?? '',
      entry.duration?.inSeconds,
      entry.tags.join(','),
      entry.bazi,
      // Kept so an entry read back from the index and saved again keeps
      // it too.
      entry.moment.isEmpty ? null : jsonEncode(entry.moment),
    ],
  );

  void _indexRemove(Entry entry) => _index.execute(
    'DELETE FROM entries WHERE day = ? AND second = ?',
    [entry.date.dayNumber, entry.secondOfDay],
  );

  List<Entry> _select(String where, List<Object?> parameters) => [
    for (final row in _index.select(
      'SELECT * FROM entries WHERE $where',
      parameters,
    ))
      Entry(
        id: Entry.idFor(
          CivilDate.fromDayNumber(row['day'] as int),
          row['second'] as int,
        ),
        date: CivilDate.fromDayNumber(row['day'] as int),
        minuteOfDay: (row['second'] as int) ~/ 60,
        second: (row['second'] as int) % 60,
        utcOffset: Duration(minutes: row['utc_offset'] as int),
        categoryId: row['category'] as String,
        title: row['title'] as String,
        content: row['content'] as String,
        place: row['latitude'] == null
            ? null
            : GeoTag.rounded(
                row['latitude'] as double,
                row['longitude'] as double,
                name: row['place'] as String,
              ),
        duration: row['duration'] == null
            ? null
            : Duration(seconds: row['duration'] as int),
        tags: [
          for (final id in (row['tags'] as String).split(','))
            if (id.isNotEmpty) id,
        ],
        bazi: row['bazi'] as String?,
        moment: row['moment'] == null
            ? const {}
            : {
                for (final MapEntry(:key, :value)
                    in (jsonDecode(row['moment'] as String) as Map).entries)
                  '$key': value == null ? null : '$value',
              },
      ),
  ];

  @override
  List<GeoTag> placesNear(GeoTag here) => nearestNamed(here, [
    // A box a little wider than the reach, then measured properly.
    for (final row in _index.select(
      "SELECT DISTINCT latitude, longitude, place FROM entries "
      "WHERE place != '' AND latitude BETWEEN ? AND ? "
      'AND longitude BETWEEN ? AND ?',
      [
        here.latitude - 0.01,
        here.latitude + 0.01,
        here.longitude - 0.02,
        here.longitude + 0.02,
      ],
    ))
      ?GeoTag.rounded(
        row['latitude'] as double,
        row['longitude'] as double,
        name: row['place'] as String,
      ),
  ]);

  // Files and index are changed together. A mark is left on disk for as
  // long as that takes: found there at the next start, it means the two
  // may disagree, and the index is rebuilt.
  void _change(void Function() change) {
    _dirty.writeAsStringSync('');
    change();
    _dirty.deleteSync();
  }

  // Written beside its place and then moved into it, so a file is never
  // seen half-written.
  void _write(File file, String text) {
    file.parent.createSync(recursive: true);
    final draft = File('${file.path}.tmp')
      ..writeAsStringSync(text, flush: true);
    draft.renameSync(file.path);
  }

  // Deletes [file] and any folders it leaves empty, up to the entries
  // folder.
  void _delete(File file) {
    if (file.existsSync()) file.deleteSync();
    var folder = file.parent;
    while (p.isWithin(_entries.path, folder.path) &&
        folder.existsSync() &&
        folder.listSync().isEmpty) {
      folder.deleteSync();
      folder = folder.parent;
    }
  }

  // Categories.

  @override
  List<JournalCategory>? loadCategories() {
    if (!_categories.existsSync()) return null;
    final list = jsonDecode(_categories.readAsStringSync()) as List;
    return [
      for (final item in list.cast<Map<String, dynamic>>())
        JournalCategory(
          id: item['id'] as String,
          name: item['name'] as String,
          colorIndex: item['color'] as int,
        ),
    ];
  }

  @override
  void saveCategories(List<JournalCategory> categories) => _write(
    _categories,
    '${const JsonEncoder.withIndent('  ').convert([
      for (final category in categories) {'id': category.id, 'name': category.name, 'color': category.colorIndex},
    ])}\n',
  );

  @override
  List<JournalTag> loadTags() {
    if (!_tags.existsSync()) return [];
    try {
      final list = jsonDecode(_tags.readAsStringSync()) as List;
      return [
        for (final item in list.cast<Map<String, dynamic>>())
          ?JournalTag.fromJson(item),
      ];
    } catch (_) {
      // A file that cannot be read is left alone until a tag is saved.
      return [];
    }
  }

  @override
  void saveTags(List<JournalTag> tags) => _write(
    _tags,
    '${const JsonEncoder.withIndent('  ').convert([for (final tag in tags) tag.toJson()])}\n',
  );

  @override
  List<Entry> allEntries() => _select('1', const []);

  // Entries.

  @override
  String get journalPath => _journal.path;

  @override
  void refresh() => rebuildIndex();

  @override
  int get total =>
      _index.select('SELECT COUNT(*) AS n FROM entries').first['n'] as int;

  @override
  List<Entry> entriesOn(CivilDate date, {required Duration utcOffset}) =>
      _select('day = ?', [date.dayNumber]);

  @override
  List<Entry> entriesIn(String categoryId) =>
      _select('category = ?', [categoryId]);

  @override
  int countIn(String categoryId) =>
      _index.select('SELECT COUNT(*) AS n FROM entries WHERE category = ?', [
            categoryId,
          ]).first['n']
          as int;

  @override
  Map<int, List<String>> categoriesByDay(
    int first,
    int last, {
    required Duration utcOffset,
  }) {
    final byDay = <int, List<String>>{};
    for (final row in _index.select(
      'SELECT day, category, MIN(second) AS earliest FROM entries '
      'WHERE day BETWEEN ? AND ? GROUP BY day, category '
      'ORDER BY day, earliest',
      [first, last],
    )) {
      (byDay[row['day'] as int] ??= []).add(row['category'] as String);
    }
    return byDay;
  }

  @override
  bool taken(CivilDate date, int secondOfDay) => _index.select(
    'SELECT 1 FROM entries WHERE day = ? AND second = ?',
    [date.dayNumber, secondOfDay],
  ).isNotEmpty;

  @override
  void put(
    Entry entry, {
    required String categoryName,
    Entry? previous,
    List<String> tagNames = const [],
  }) => _change(() {
    final file = _fileOf(entry);
    _write(
      file,
      EntryFile.encode(entry, categoryName: categoryName, tagNames: tagNames),
    );
    if (previous != null) {
      // Moved to another category, so to another folder.
      final old = _fileOf(previous);
      if (old.path != file.path) _delete(old);
      _indexRemove(previous);
    }
    _indexPut(entry);
  });

  @override
  void remove(Entry entry) => _change(() {
    _delete(_fileOf(entry));
    _indexRemove(entry);
  });

  @override
  void close() => _index.close();
}
