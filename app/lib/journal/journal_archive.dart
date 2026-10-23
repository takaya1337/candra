import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../reminders/reminder.dart';
import 'entry.dart';
import 'entry_file.dart';

/// What was found in a journal file.
class ArchiveContents {
  final List<JournalCategory> categories;
  final List<Entry> entries;

  /// Files that looked like entries but could not be read.
  final int unreadable;

  /// The reminders that came with it.
  final List<Reminder> reminders;

  /// The tags that came with it.
  final List<JournalTag> tags;

  const ArchiveContents({
    required this.categories,
    required this.entries,
    required this.unreadable,
    this.reminders = const [],
    this.tags = const [],
  });
}

/// The journal as one file: a zip of the journal folder exactly as it is
/// kept, `categories.json` and `entries/<year>/<month>/<day>/<category>/`,
/// plus a small note saying what made it.
///
/// Nothing in it is encrypted. Unzipped, it is the same plain Markdown the
/// app keeps.
abstract final class JournalArchive {
  static const formatVersion = 1;
  static const _note = 'candra.json';
  static const _categories = 'categories.json';
  static const _tags = 'tags.json';
  static const _reminders = 'reminders.json';

  // The category folder must be an id as the app makes them, six hex
  // digits: a folder such as `..` would otherwise be taken as one, and
  // the entry written outside its day's folder.
  static final _entryPath = RegExp(
    r'(?:^|/)entries/\d{4}/\d{2}/\d{2}/([0-9a-f]{6})/[^/]+\.md$',
  );

  /// "candra-20261011-193005.zip".
  static String nameFor(DateTime now) {
    String two(int value) => value.toString().padLeft(2, '0');
    return 'candra-${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}.zip';
  }

  /// Zips the journal folder at [journalPath].
  static Uint8List pack(String journalPath, {required String exportedAt}) {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          _note,
          '${const JsonEncoder.withIndent('  ').convert({'app': 'candra', 'format': formatVersion, 'exported': exportedAt})}\n',
        ),
      );
    final root = Directory(journalPath);
    final files = root.listSync(recursive: true).whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final name = p.posix.joinAll(
        p.split(p.relative(file.path, from: root.path)),
      );
      // Leftovers of a write that was cut short are not part of it, nor
      // the copies of a damaged file set aside before it was written
      // over (`categories.json.bad` and the like).
      if (name.endsWith('.tmp') || RegExp(r'\.bad\d*$').hasMatch(name)) {
        continue;
      }
      archive.addFile(ArchiveFile.bytes(name, file.readAsBytesSync()));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  /// Reads a journal file, or throws a [FormatException] if [bytes] is
  /// not one.
  ///
  /// A zip put together by hand is taken too, with or without a folder
  /// round everything, as long as its entries sit in the same folders. An
  /// entry's category is the folder it is in.
  static ArchiveContents unpack(List<int> bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('Not a zip file');
    }

    var categories = <JournalCategory>[];
    var reminders = <Reminder>[];
    var tags = <JournalTag>[];
    final entries = <Entry>[];
    var unreadable = 0;
    var recognised = false;

    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = file.name.replaceAll(r'\', '/');
      if (name == _categories || name.endsWith('/$_categories')) {
        recognised = true;
        try {
          categories = [
            for (final item in (jsonDecode(
              utf8.decode(file.content),
            ) as List).cast<Map<String, dynamic>>())
              JournalCategory(
                id: item['id'] as String,
                name: item['name'] as String,
                colorIndex: (item['color'] as int).clamp(
                  0,
                  categoryPalette.length - 1,
                ),
              ),
          ];
        } catch (_) {
          throw const FormatException('The list of categories is damaged');
        }
        continue;
      }
      if (name == _tags || name.endsWith('/$_tags')) {
        try {
          tags = [
            for (final item in (jsonDecode(
              utf8.decode(file.content),
            ) as List).cast<Map<String, dynamic>>())
              ?JournalTag.fromJson(item),
          ];
        } catch (_) {
          // Tags that cannot be read are left out; the entries keep
          // pointing at them, and those are simply not shown.
        }
        continue;
      }
      if (name == _reminders || name.endsWith('/$_reminders')) {
        recognised = true;
        try {
          // One by one, so that one that cannot be read leaves the rest.
          reminders = Reminder.listFrom(jsonDecode(utf8.decode(file.content)));
        } catch (_) {
          // A file that cannot be read at all is left out; the journal
          // itself is still taken.
        }
        continue;
      }
      final match = _entryPath.firstMatch(name);
      if (match == null) continue;
      recognised = true;
      Entry? entry;
      try {
        entry = EntryFile.decode(utf8.decode(file.content));
      } catch (_) {
        entry = null;
      }
      if (entry == null) {
        unreadable++;
      } else {
        entries.add(entry.copyWith(categoryId: match[1]));
      }
    }
    if (!recognised) throw const FormatException('Not a journal file');
    return ArchiveContents(
      categories: categories,
      entries: entries,
      unreadable: unreadable,
      reminders: reminders,
      tags: tags,
    );
  }
}
