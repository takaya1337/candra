import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'journal_archive.dart';
import 'journal_store.dart';

/// Getting the journal out of the app as a file, and back in.
///
/// The file is made in the app's cache and from there either handed to
/// another app through the system's share sheet or copied to wherever the
/// user points the system's file screen. Neither needs any permission.
class JournalFiles {
  const JournalFiles();

  static const _channel = MethodChannel('candra/files');

  /// Packs the journal into a fresh file in the cache and returns it.
  /// Exports made before are thrown away first.
  Future<File> pack(JournalStore store) async {
    final exports = Directory(
      p.join((await getTemporaryDirectory()).path, 'exports'),
    );
    if (exports.existsSync()) exports.deleteSync(recursive: true);
    exports.createSync(recursive: true);

    final now = DateTime.now();
    final journal = store.journalPath!;
    final exportedAt = now.toIso8601String();
    // Off the main thread: reading and squeezing every file takes a while
    // in a large journal.
    final bytes = await Isolate.run(
      () => JournalArchive.pack(journal, exportedAt: exportedAt),
    );
    return File(p.join(exports.path, JournalArchive.nameFor(now)))
      ..writeAsBytesSync(bytes);
  }

  /// Opens the share sheet for [file]. On an iPhone the file is thrown
  /// away once the sheet has closed; on Android the app it went to may
  /// still be reading it, so it stays until the next export.
  Future<void> share(File file) =>
      _channel.invokeMethod<void>('share', {'path': file.path});

  /// Asks where on the device to keep a copy of [file]. Returns false if
  /// the user backed out. Either way [file] is thrown away afterwards: the
  /// copy has been made by the time the file screen answers.
  Future<bool> saveAs(File file) async {
    try {
      return await _channel.invokeMethod<bool>('saveAs', {
            'path': file.path,
            'name': p.basename(file.path),
          }) ??
          false;
    } finally {
      try {
        if (file.existsSync()) file.deleteSync();
      } on FileSystemException {
        // Already gone, or not ours to remove: the next export clears it.
      }
    }
  }

  /// Asks for a file to import and reads it. Returns null if the user
  /// backed out; throws a [FormatException] if it is not a journal file.
  Future<ArchiveContents?> pick() async {
    final path = await _channel.invokeMethod<String>('pick');
    if (path == null) return null;
    try {
      return await Isolate.run(
        () => JournalArchive.unpack(File(path).readAsBytesSync()),
      );
    } finally {
      File(path).deleteSync();
    }
  }
}
