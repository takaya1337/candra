import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'git_host.dart';

/// A branch of a repository on GitHub, reached over GitHub's own HTTPS
/// API with a personal access token.
///
/// Nothing git has to be on the phone for this: files are sent and
/// fetched as git objects through the API, and what ends up on GitHub is
/// an ordinary repository with ordinary history.
class GitHubHost implements GitHost {
  final String owner;
  final String repository;
  final String token;

  /// The branch to keep in step with; found out by [connect] when not
  /// given.
  String? branch;

  /// Where the API is: GitHub's, unless a test says otherwise.
  final Uri api;
  final HttpClient _client;

  GitHubHost({
    required this.owner,
    required this.repository,
    required this.token,
    this.branch,
    Uri? api,
    HttpClient? client,
  }) : api = api ?? Uri.parse('https://api.github.com'),
       _client = client ?? HttpClient()
         ..connectionTimeout = const Duration(seconds: 15);

  /// As many files as go into one request when a commit is put together.
  static const _perTree = 100;

  String get _repo => '/repos/$owner/$repository';

  /// Makes sure the repository is there and the token may write to it, and
  /// settles on its default branch. Throws as any other call does.
  Future<void> connect() async {
    final info = await _send('GET', _repo) as Map<String, dynamic>;
    final permissions = info['permissions'];
    if (permissions is Map && permissions['push'] == false) {
      throw const SyncDenied();
    }
    branch ??= info['default_branch'] as String? ?? 'main';
  }

  Future<String> get _branch async {
    if (branch == null) await connect();
    return branch!;
  }

  // One call to the API. Returns the decoded answer; [quiet] lists the
  // statuses that are answers too, returned as their number.
  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    Set<int> quiet = const {},
    bool recursive = false,
  }) async {
    final HttpClientResponse response;
    final String text;
    try {
      final request = await _client.openUrl(
        method,
        api.replace(
          path: '${api.path}$path'.replaceAll('//', '/'),
          query: recursive ? 'recursive=1' : null,
        ),
      );
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'candra')
        ..set('X-GitHub-Api-Version', '2022-11-28');
      if (body != null) {
        final bytes = utf8.encode(jsonEncode(body));
        request.headers.contentType = ContentType.json;
        request.contentLength = bytes.length;
        request.add(bytes);
      }
      response = await request.close().timeout(const Duration(seconds: 60));
      text = await utf8.decodeStream(response);
    } on SocketException {
      throw const SyncOffline();
    } on HandshakeException {
      throw const SyncOffline();
    } on TimeoutException {
      throw const SyncOffline();
    } on HttpException {
      throw const SyncOffline();
    }

    final status = response.statusCode;
    if (quiet.contains(status)) return status;
    if (status >= 200 && status < 300) {
      return text.isEmpty ? null : jsonDecode(text);
    }
    if (status == 401 || status == 403) throw const SyncDenied();
    if (status == 404) throw const SyncNotFound();
    String message = 'GitHub answered $status';
    try {
      message = '${(jsonDecode(text) as Map)['message'] ?? message}';
    } catch (_) {}
    throw SyncFailed(message);
  }

  @override
  Future<String?> headCommit() async {
    // 404: no such branch yet. 409: a repository with nothing in it.
    final answer = await _send(
      'GET',
      '$_repo/git/ref/heads/${await _branch}',
      quiet: {404, 409},
    );
    if (answer is int) return null;
    return ((answer as Map)['object'] as Map)['sha'] as String;
  }

  @override
  Future<RemoteHead> head() async {
    final commit = await headCommit();
    if (commit == null) return const RemoteHead();
    final tree =
        (((await _send('GET', '$_repo/git/commits/$commit')) as Map)['tree']
                as Map)['sha']
            as String;
    final listing =
        await _send('GET', '$_repo/git/trees/$tree', recursive: true) as Map;
    return RemoteHead(commit: commit, tree: tree, files: _files(listing));
  }

  Map<String, String> _files(Map<dynamic, dynamic> listing) {
    if (listing['truncated'] == true) {
      throw const SyncFailed(
        'The journal on GitHub has more files than GitHub will list at once.',
      );
    }
    return {
      for (final item in (listing['tree'] as List).cast<Map<String, dynamic>>())
        if (item['type'] == 'blob')
          item['path'] as String: item['sha'] as String,
    };
  }

  @override
  Future<Uint8List> blob(String sha) async {
    final answer = await _send('GET', '$_repo/git/blobs/$sha') as Map;
    // GitHub breaks the base64 into lines.
    return base64.decode((answer['content'] as String).replaceAll('\n', ''));
  }

  @override
  Future<RemoteHead> commit({
    required RemoteHead parent,
    required Map<String, Uint8List?> changes,
    required String message,
  }) async {
    final branch = await _branch;
    var onto = parent;
    if (onto.commit == null) {
      // Git objects cannot be made in a repository that has none. One
      // small file through the ordinary contents API gets it started.
      await _send(
        'PUT',
        '$_repo/contents/.candra',
        body: {
          'message': 'Start a Candra journal',
          'content': base64.encode(utf8.encode('A Candra journal.\n')),
        },
        quiet: {422},
      );
      onto = await head();
      if (onto.commit == null) {
        throw const SyncFailed('Could not start the repository.');
      }
    }

    var tree = onto.tree!;
    final paths = changes.keys.toList();
    for (var from = 0; from < paths.length; from += _perTree) {
      final answer = await _send(
        'POST',
        '$_repo/git/trees',
        body: {
          'base_tree': tree,
          'tree': [
            for (final path in paths.skip(from).take(_perTree))
              if (changes[path] == null)
                {'path': path, 'mode': '100644', 'type': 'blob', 'sha': null}
              else
                {
                  'path': path,
                  'mode': '100644',
                  'type': 'blob',
                  'content': utf8.decode(changes[path]!),
                },
          ],
        },
      ) as Map;
      tree = answer['sha'] as String;
    }

    final made = await _send(
      'POST',
      '$_repo/git/commits',
      body: {
        'message': message,
        'tree': tree,
        'parents': [onto.commit],
      },
    ) as Map;
    final commit = made['sha'] as String;

    // Refused unless the branch is still where we thought it was.
    final moved = await _send(
      'PATCH',
      '$_repo/git/refs/heads/$branch',
      body: {'sha': commit, 'force': false},
      quiet: {409, 422},
    );
    if (moved is int) throw const StaleHead();
    return RemoteHead(commit: commit, tree: tree);
  }
}
