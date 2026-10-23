import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The name git gives a file's contents: the SHA-1 of a short header and
/// the bytes. Two files are the same exactly when this is.
String blobSha(List<int> bytes) => sha1.convert([
  ...utf8.encode('blob ${bytes.length}\u0000'),
  ...bytes,
]).toString();

/// Where a branch stands: its latest commit, and every file in it by path
/// with the name of its contents. All null and empty for a repository
/// with nothing in it yet.
class RemoteHead {
  final String? commit;
  final String? tree;
  final Map<String, String> files;

  const RemoteHead({this.commit, this.tree, this.files = const {}});
}

/// A branch of a git repository somewhere else, as far as syncing needs
/// it.
abstract class GitHost {
  /// The branch's latest commit, or null if there is none yet. Cheap: for
  /// finding out whether anything has changed.
  Future<String?> headCommit();

  /// The branch as it stands.
  Future<RemoteHead> head();

  /// The contents named [sha].
  Future<Uint8List> blob(String sha);

  /// Adds a commit on top of [parent] that writes each path in [changes],
  /// or deletes it where the bytes are null, and moves the branch to it.
  /// Returns the new head.
  ///
  /// Throws [StaleHead] if the branch is no longer at [parent]: someone
  /// else got there first, and the whole sync has to be thought through
  /// again.
  Future<RemoteHead> commit({
    required RemoteHead parent,
    required Map<String, Uint8List?> changes,
    required String message,
  });
}

/// The branch moved while a commit was being made.
class StaleHead implements Exception {
  const StaleHead();
}

/// The host would not let us in: a wrong or expired token, or one without
/// the right to this repository.
class SyncDenied implements Exception {
  const SyncDenied();
}

/// The host has had too many requests for now. The token is fine; it is
/// worth trying again from [until], when the host said when that is.
class SyncRateLimited implements Exception {
  final DateTime? until;

  const SyncRateLimited([this.until]);
}

/// The repository or the branch is not there.
class SyncNotFound implements Exception {
  const SyncNotFound();
}

/// The host could not be reached.
class SyncOffline implements Exception {
  const SyncOffline();
}

/// Anything else that went wrong, in the host's own words.
class SyncFailed implements Exception {
  final String message;

  const SyncFailed(this.message);

  @override
  String toString() => message;
}
