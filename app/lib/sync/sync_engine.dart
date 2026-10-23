import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../journal/entry.dart';
import '../journal/entry_file.dart';
import 'git_host.dart';

/// What one device remembers between syncs.
///
/// [files] is the branch as it stood at [commit]. For nearly every file
/// that is also what this device and the branch last agreed on; the few
/// that were left in conflict are in [agreed], with what the two last did
/// agree on (null for "not there").
class SyncState {
  final String? commit;
  final String? tree;
  final Map<String, String> files;
  final Map<String, String?> agreed;

  const SyncState({
    this.commit,
    this.tree,
    this.files = const {},
    this.agreed = const {},
  });

  /// What this device and the branch last agreed [path] was.
  String? base(String path) =>
      agreed.containsKey(path) ? agreed[path] : files[path];

  Map<String, dynamic> toJson() => {
    'commit': commit,
    'tree': tree,
    'files': files,
    'agreed': agreed,
  };

  factory SyncState.fromJson(Map<String, dynamic> json) => SyncState(
    commit: json['commit'] as String?,
    tree: json['tree'] as String?,
    files: (json['files'] as Map? ?? const {}).cast<String, String>(),
    agreed: (json['agreed'] as Map? ?? const {}).cast<String, String?>(),
  );
}

/// What to do with a file changed on both sides.
enum Keep { mine, theirs, both }

/// A file changed on this device and on the branch since they last
/// agreed, in different ways. Null bytes mean that side deleted it.
class Conflict {
  final String path;
  final Uint8List? mine;
  final Uint8List? theirs;

  const Conflict({required this.path, this.mine, this.theirs});

  /// Keeping both only makes sense when there are two to keep, and only
  /// when the branch's copy reads as an entry that can be moved to a
  /// second of its own. Anything else would be overwritten on the branch.
  bool get canKeepBoth =>
      mine != null &&
      theirs != null &&
      SyncEngine._entryPath.hasMatch(path) &&
      SyncEngine._decode(theirs!) != null;
}

/// What a sync did.
class SyncResult {
  final SyncState state;

  /// Files brought in from the branch, and files sent to it.
  final int pulled;
  final int pushed;

  /// What is left for the user to decide. Everything else was synced.
  final List<Conflict> conflicts;

  const SyncResult({
    required this.state,
    required this.pulled,
    required this.pushed,
    required this.conflicts,
    this.changedHere = false,
  });

  /// Whether files in the journal folder were changed, by any attempt
  /// this sync made.
  final bool changedHere;
}

/// Brings a journal folder and a branch into line with each other.
///
/// Every file is looked at three ways: as it is here, as it is on the
/// branch, and as the two last agreed it was. Changed on one side only,
/// the change goes to the other, deletions included. Changed on both
/// sides in different ways, it is a [Conflict], left exactly as it is on
/// both sides until the caller says which to keep.
///
/// The two lists, `categories.json` and `reminders.json`, are never in
/// conflict: they are merged item by item.
class SyncEngine {
  final Directory journal;
  final GitHost host;

  /// Named in each commit's message.
  final String device;

  SyncEngine({required this.journal, required this.host, this.device = ''});

  static const _lists = {'categories.json', 'reminders.json', 'tags.json'};

  // Only the journal's own files are synced. Whatever else is in the
  // repository (a README, the file that started it) is left alone there
  // and never brought here.
  static bool _ours(String path) =>
      _lists.contains(path) || path.startsWith('entries/');
  static final _entryPath = RegExp(
    r'^entries/(\d{4})/(\d{2})/(\d{2})/([^/]+)/(\d{6})\.md$',
  );

  // The names of files' contents, kept while they have not been touched.
  final _known = <String, (DateTime, int, String)>{};

  /// Set whenever a sync writes or deletes a file in the journal folder,
  /// whether or not that sync then goes through; the caller clears it once
  /// it has read the journal afresh. A sync that fails after pulling some
  /// files has still changed them, and the next one may have nothing left
  /// to pull.
  bool wroteHere = false;
  bool _wroteNow = false;

  File _file(String path) =>
      File(p.joinAll([journal.path, ...path.split('/')]));

  Map<String, String> _scan() {
    final found = <String, String>{};
    if (!journal.existsSync()) return found;
    for (final file in journal.listSync(recursive: true)) {
      if (file is! File || file.path.endsWith('.tmp')) continue;
      final path = p.posix.joinAll(
        p.split(p.relative(file.path, from: journal.path)),
      );
      if (!_ours(path)) continue;
      final stat = file.statSync();
      final known = _known[path];
      if (known != null && known.$1 == stat.modified && known.$2 == stat.size) {
        found[path] = known.$3;
        continue;
      }
      final sha = blobSha(file.readAsBytesSync());
      _known[path] = (stat.modified, stat.size, sha);
      found[path] = sha;
    }
    return found;
  }

  void _write(String path, List<int> bytes) {
    wroteHere = _wroteNow = true;
    final file = _file(path);
    file.parent.createSync(recursive: true);
    File('${file.path}.tmp')
      ..writeAsBytesSync(bytes, flush: true)
      ..renameSync(file.path);
  }

  void _delete(String path) {
    wroteHere = _wroteNow = true;
    final file = _file(path);
    if (file.existsSync()) file.deleteSync();
    var folder = file.parent;
    while (p.isWithin(journal.path, folder.path) &&
        folder.existsSync() &&
        folder.listSync().isEmpty) {
      folder.deleteSync();
      folder = folder.parent;
    }
  }

  /// Syncs once. [resolutions] says what to keep for conflicts reported
  /// by an earlier sync, by path.
  Future<SyncResult> sync(
    SyncState state, {
    Map<String, Keep> resolutions = const {},
  }) async {
    _wroteNow = false;
    for (var attempt = 0; ; attempt++) {
      // What each file here was made from, for those an attempt wrote
      // from the branch's copy (null for a deletion).
      final written = <String, String?>{};
      try {
        final result = await _sync(state, resolutions, written);
        return SyncResult(
          state: result.state,
          pulled: result.pulled,
          pushed: result.pushed,
          conflicts: result.conflicts,
          changedHere: _wroteNow,
        );
      } on StaleHead {
        // Someone pushed while we were at it. What was pulled so far is
        // sound; look again from where the branch now stands. A file
        // pulled is now agreed as the copy it was pulled from, or the next
        // attempt would take a further change on the branch for a
        // conflict. A choice already carried out is not carried out again.
        if (attempt == 3) rethrow;
        state = SyncState(
          commit: state.commit,
          tree: state.tree,
          files: state.files,
          agreed: {...state.agreed, ...written},
        );
        resolutions = {
          for (final choice in resolutions.entries)
            if (!written.containsKey(choice.key)) choice.key: choice.value,
        };
      }
    }
  }

  Future<SyncResult> _sync(
    SyncState state,
    Map<String, Keep> resolutions,
    Map<String, String?> written,
  ) async {
    final local = _scan();
    final headCommit = await host.headCommit();
    final RemoteHead remote;
    if (headCommit != null && headCommit == state.commit) {
      remote = RemoteHead(
        commit: state.commit,
        tree: state.tree,
        files: state.files,
      );
    } else {
      final head = await host.head();
      remote = RemoteHead(
        commit: head.commit,
        tree: head.tree,
        files: {
          for (final file in head.files.entries)
            if (_ours(file.key)) file.key: file.value,
        },
      );
    }

    final toPush = <String, Uint8List?>{};
    final agreed = <String, String?>{};
    final conflicts = <Conflict>[];
    // What is here once this sync is done, for finding free seconds.
    final here = {...local.keys};
    var pulled = 0;

    Future<Uint8List?> theirs(String path) async {
      final sha = remote.files[path];
      return sha == null ? null : host.blob(sha);
    }

    Uint8List? mine(String path) =>
        local.containsKey(path) ? _file(path).readAsBytesSync() : null;

    // What is in the file now, and its name; nulls for not there.
    (Uint8List?, String?) now(String path) {
      final file = _file(path);
      if (!file.existsSync()) return (null, null);
      final bytes = file.readAsBytesSync();
      return (bytes, blobSha(bytes));
    }

    void stillToSettle(String path, Uint8List? mine, Uint8List? theirs) {
      conflicts.add(Conflict(path: path, mine: mine, theirs: theirs));
      // Still to be settled: remember what was last agreed.
      agreed[path] = state.base(path);
    }

    Future<void> takeTheirs(String path) async {
      final bytes = await theirs(path);
      // The file may have been saved here while this sync waited on the
      // network. Then it is no longer what was looked at, and taking the
      // branch's copy would lose what was just written.
      final (current, sha) = now(path);
      if (sha == remote.files[path]) {
        // Made the same as the branch's meanwhile: nothing to take.
        sha == null ? here.remove(path) : here.add(path);
        written[path] = sha;
        return;
      }
      if (sha != local[path]) {
        stillToSettle(path, current, bytes);
        return;
      }
      if (bytes == null) {
        _delete(path);
        here.remove(path);
      } else {
        _write(path, bytes);
        here.add(path);
      }
      written[path] = remote.files[path];
      pulled++;
    }

    void sendMine(String path) => toPush[path] = mine(path);

    for (final path in {
      ...state.files.keys,
      ...local.keys,
      ...remote.files.keys,
    }) {
      final b = state.base(path);
      final l = local[path];
      final r = remote.files[path];
      if (l == r) continue;

      if (r == b) {
        sendMine(path);
      } else if (l == b) {
        await takeTheirs(path);
      } else if (_lists.contains(path) && l != null && r != null) {
        // The lists are merged item by item, never fought over.
        final merged = _mergeList(
          path,
          base: b == null ? null : await host.blob(b),
          mine: mine(path)!,
          theirs: (await theirs(path))!,
          here: here,
          firstMeeting: state.commit == null,
        );
        if (now(path).$2 != l) {
          // Changed here meanwhile: merged next time, from what was
          // last agreed.
          agreed[path] = b;
          continue;
        }
        if (blobSha(merged) != l) {
          _write(path, merged);
          written[path] = r;
          pulled++;
        }
        if (blobSha(merged) != r) toPush[path] = merged;
      } else if (await _sameEntry(path, mine(path), await theirs(path))) {
        // Changed on both sides into the same entry, the two files apart
        // only in what is written for searching (the calendar lines, the
        // category's name): no conflict. This device takes the branch's
        // file, so the two agree byte for byte again.
        await takeTheirs(path);
      } else {
        switch (resolutions[path]) {
          case Keep.mine:
            sendMine(path);
          case Keep.theirs:
            await takeTheirs(path);
          case Keep.both:
            final theirBytes = await theirs(path);
            final moved = theirBytes == null
                ? null
                : _beside(path, theirBytes, {...here, ...remote.files.keys});
            if (moved == null) {
              // The branch's copy cannot be set beside as an entry of its
              // own, so keeping both would overwrite it there. It stays a
              // conflict, for mine or theirs.
              stillToSettle(path, mine(path), theirBytes);
              continue;
            }
            _write(moved.$1, moved.$2);
            here.add(moved.$1);
            toPush[moved.$1] = moved.$2;
            written[path] = r;
            pulled++;
            sendMine(path);
          case null:
            stillToSettle(path, mine(path), await theirs(path));
        }
      }
    }

    var head = remote;
    if (toPush.isNotEmpty) {
      head = await host.commit(
        parent: remote,
        changes: toPush,
        message:
            'Candra sync${device.isEmpty ? '' : ' from $device'}: '
            '${toPush.length} file${toPush.length == 1 ? '' : 's'}',
      );
    }

    // The branch as it now stands: as it was, with what was pushed.
    final files = {...remote.files};
    toPush.forEach((path, bytes) {
      if (bytes == null) {
        files.remove(path);
      } else {
        files[path] = blobSha(bytes);
      }
    });
    return SyncResult(
      state: SyncState(
        commit: head.commit,
        tree: head.tree,
        files: files,
        agreed: agreed,
      ),
      pulled: pulled,
      pushed: toPush.length,
      conflicts: conflicts,
    );
  }

  // Whether two versions of an entry file are one entry: equal in every
  // field the app reads back (Entry.sameAs). Only entry files can be; a
  // side that deleted it, or a file that does not read as an entry, is
  // never the same as anything.
  Future<bool> _sameEntry(String path, Uint8List? a, Uint8List? b) async {
    if (a == null || b == null || !path.startsWith('entries/')) return false;
    final first = _decode(a, allowMalformed: true);
    final second = _decode(b, allowMalformed: true);
    return first != null && second != null && first.sameAs(second);
  }

  // The entry [bytes] hold, or null if they do not read as one: not UTF-8
  // (unless [allowMalformed]), or not an entry, or one with a date that
  // cannot be.
  static Entry? _decode(Uint8List bytes, {bool allowMalformed = false}) {
    try {
      return EntryFile.decode(
        utf8.decode(bytes, allowMalformed: allowMalformed),
      );
    } catch (_) {
      return null;
    }
  }

  // An entry as it would be at the next second free on its day, so that
  // it can sit beside the one that has its second. Null if [bytes] is not
  // an entry.
  (String, Uint8List)? _beside(
    String path,
    Uint8List bytes,
    Set<String> taken,
  ) {
    final match = _entryPath.firstMatch(path);
    if (match == null) return null;
    final entry = _decode(bytes);
    if (entry == null) return null;
    final text = utf8.decode(bytes);

    final day = 'entries/${match[1]}/${match[2]}/${match[3]}/';
    final seconds = {
      for (final other in taken)
        if (other.startsWith(day))
          ?int.tryParse(p.posix.basenameWithoutExtension(other)),
    };
    String stamp(int second) =>
        '${(second ~/ 3600).toString().padLeft(2, '0')}'
        '${(second ~/ 60 % 60).toString().padLeft(2, '0')}'
        '${(second % 60).toString().padLeft(2, '0')}';
    var second = entry.secondOfDay;
    while (seconds.contains(int.parse(stamp(second)))) {
      second = (second + 1) % Duration.secondsPerDay;
    }
    final name = RegExp(
      r'^category_name: (.*)$',
      multiLine: true,
    ).firstMatch(text)?[1];
    final moved = entry.copyWith(categoryId: match[4]).at(second);
    return (
      '$day${match[4]}/${stamp(second)}.md',
      Uint8List.fromList(
        utf8.encode(
          EntryFile.encode(moved, categoryName: name ?? moved.categoryId),
        ),
      ),
    );
  }

  // Merges a list of things with ids, each looked at three ways like the
  // files themselves. Where both sides changed the same one, ours stays.
  Uint8List _mergeList(
    String path, {
    required Uint8List? base,
    required Uint8List mine,
    required Uint8List theirs,
    required Set<String> here,
    required bool firstMeeting,
  }) {
    List<Map<String, dynamic>> read(Uint8List? bytes) {
      if (bytes == null) return const [];
      try {
        return (jsonDecode(utf8.decode(bytes)) as List)
            .cast<Map<String, dynamic>>();
      } catch (_) {
        return const [];
      }
    }

    String key(Map<String, dynamic> item) => jsonEncode(item);
    final b = {for (final item in read(base)) '${item['id']}': item};
    final m = read(mine);
    final t = {for (final item in read(theirs)) '${item['id']}': item};
    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final item in m) {
      final id = '${item['id']}';
      seen.add(id);
      final was = b[id];
      final their = t[id];
      if (their == null) {
        // Gone from the branch: deleted there, unless it was never there
        // or we have changed it since.
        if (was == null || key(was) != key(item)) merged.add(item);
      } else if (was != null && key(was) == key(item)) {
        merged.add(their);
      } else {
        merged.add(item);
      }
    }
    for (final item in t.values) {
      final id = '${item['id']}';
      if (seen.contains(id)) continue;
      // New on the branch, unless we deleted it and it has not changed.
      final was = b[id];
      if (was == null || key(was) != key(item)) merged.add(item);
    }

    if (path == 'categories.json') {
      _settleCategories(merged, t, here, firstMeeting);
    }
    return Uint8List.fromList(
      utf8.encode('${const JsonEncoder.withIndent('  ').convert(merged)}\n'),
    );
  }

  // Two things only categories need. A device meeting the branch for the
  // first time has starting categories of its own with nothing in them:
  // one of those gives way to a category of the same name already on the
  // branch. And no two categories may be left with one colour.
  void _settleCategories(
    List<Map<String, dynamic>> categories,
    Map<String, Map<String, dynamic>> theirs,
    Set<String> here,
    bool firstMeeting,
  ) {
    if (firstMeeting) {
      bool used(String id) => here.any((path) => path.contains('/$id/'));
      categories.removeWhere((category) {
        final id = '${category['id']}';
        return !theirs.containsKey(id) &&
            !used(id) &&
            theirs.values.any((other) => other['name'] == category['name']);
      });
    }
    final taken = <int>{};
    for (final category in categories) {
      var color = category['color'] is int ? category['color'] as int : 0;
      if (taken.contains(color)) {
        color = Iterable<int>.generate(categoryPalette.length)
            .firstWhere((i) => !taken.contains(i), orElse: () => color);
        category['color'] = color;
      }
      taken.add(color);
    }
  }
}
