import 'dart:typed_data';

import 'package:candra/sync/git_host.dart';

/// A branch kept in memory that behaves as a real one does: commits pile
/// up, contents are named by their hash, and a commit made on an old head
/// is refused.
class FakeRepository {
  final blobs = <String, Uint8List>{};
  final commits = <({String id, String message, Map<String, String> files})>[];

  /// Counts of calls, for checking what a sync cost.
  var headReads = 0;
  var blobReads = 0;

  String? get head => commits.isEmpty ? null : commits.last.id;
  Map<String, String> get files =>
      commits.isEmpty ? const {} : commits.last.files;

  /// The text of [path] at the head, or null if it is not there.
  String? read(String path) {
    final sha = files[path];
    return sha == null ? null : String.fromCharCodes(blobs[sha]!);
  }
}

class FakeGitHost implements GitHost {
  final FakeRepository repository;

  /// Run just before the next commit is made: for slipping someone
  /// else's push in at the worst moment.
  Future<void> Function()? beforeCommit;

  /// Run just before the next blob is read: for changing a file here
  /// while a sync waits on the network.
  Future<void> Function()? beforeBlob;

  /// Thrown by every call while set: an exception, or any other thing
  /// thrown.
  Object? failure;

  FakeGitHost(this.repository);

  RemoteHead get _head => RemoteHead(
    commit: repository.head,
    tree: repository.head == null ? null : 'tree-${repository.head}',
    files: Map.of(repository.files),
  );

  void _check() {
    if (failure != null) throw failure!;
  }

  @override
  Future<String?> headCommit() async {
    _check();
    return repository.head;
  }

  @override
  Future<RemoteHead> head() async {
    _check();
    repository.headReads++;
    return _head;
  }

  @override
  Future<Uint8List> blob(String sha) async {
    _check();
    final interrupt = beforeBlob;
    beforeBlob = null;
    await interrupt?.call();
    repository.blobReads++;
    return repository.blobs[sha]!;
  }

  @override
  Future<RemoteHead> commit({
    required RemoteHead parent,
    required Map<String, Uint8List?> changes,
    required String message,
  }) async {
    _check();
    final interrupt = beforeCommit;
    beforeCommit = null;
    await interrupt?.call();
    if (parent.commit != repository.head) throw const StaleHead();

    final files = Map.of(repository.files);
    changes.forEach((path, bytes) {
      if (bytes == null) {
        files.remove(path);
      } else {
        final sha = blobSha(bytes);
        repository.blobs[sha] = bytes;
        files[path] = sha;
      }
    });
    repository.commits.add((
      id: 'commit-${repository.commits.length + 1}',
      message: message,
      files: files,
    ));
    return _head;
  }
}
