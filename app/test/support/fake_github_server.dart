import 'dart:convert';
import 'dart:io';

import 'package:candra/sync/git_host.dart';

/// Enough of GitHub's API, served on this machine, to put the real HTTP
/// code through its paces: one repository `me/journal`, one token `good`.
class FakeGitHubServer {
  late final HttpServer _server;

  final blobs = <String, List<int>>{};
  final trees = <String, Map<String, String>>{};
  final commits = <String, ({String? parent, String tree, String message})>{};
  String? head;
  var requests = 0;

  /// Whether the token may push.
  var mayPush = true;

  /// While set, every request is answered with it instead.
  ({int status, Map<String, String> headers, String message})? refusal;

  Uri get url => Uri.parse('http://${_server.address.host}:${_server.port}');

  Map<String, String> get files =>
      head == null ? const {} : trees[commits[head]!.tree]!;

  String? read(String path) {
    final sha = files[path];
    return sha == null ? null : utf8.decode(blobs[sha]!);
  }

  static Future<FakeGitHubServer> start() async {
    final server = FakeGitHubServer();
    server._server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server._server.listen(server._handle);
    return server;
  }

  Future<void> stop() => _server.close(force: true);

  String _store(List<int> bytes) {
    final sha = blobSha(bytes);
    blobs[sha] = bytes;
    return sha;
  }

  String _commit(String? parent, Map<String, String> files, String message) {
    final tree = 'tree${trees.length + 1}';
    trees[tree] = files;
    final id = 'commit${commits.length + 1}';
    commits[id] = (parent: parent, tree: tree, message: message);
    return id;
  }

  Future<void> _handle(HttpRequest request) async {
    requests++;
    Future<void> answer(int status, Object? body) async {
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await request.response.close();
    }

    final text = await utf8.decodeStream(request);
    final refused = refusal;
    if (refused != null) {
      refused.headers.forEach(request.response.headers.set);
      return answer(refused.status, {'message': refused.message});
    }
    final body = text.isEmpty ? null : jsonDecode(text) as Map<String, dynamic>;
    if (request.headers.value('authorization') != 'Bearer good') {
      return answer(401, {'message': 'Bad credentials'});
    }
    final path = request.uri.path;
    const repo = '/repos/me/journal';
    if (!path.startsWith(repo)) return answer(404, {'message': 'Not Found'});
    final rest = path.substring(repo.length);
    final method = request.method;

    if (rest.isEmpty) {
      return answer(200, {
        'default_branch': 'main',
        'permissions': {'push': mayPush},
      });
    }
    if (method == 'GET' && rest == '/git/ref/heads/main') {
      if (head == null) {
        return answer(409, {'message': 'Git Repository is empty.'});
      }
      return answer(200, {
        'object': {'sha': head},
      });
    }
    if (method == 'GET' && rest.startsWith('/git/commits/')) {
      final commit = commits[rest.split('/').last];
      if (commit == null) return answer(404, {'message': 'Not Found'});
      return answer(200, {
        'tree': {'sha': commit.tree},
      });
    }
    if (method == 'GET' && rest.startsWith('/git/trees/')) {
      final tree = trees[rest.split('/').last];
      if (tree == null || request.uri.queryParameters['recursive'] != '1') {
        return answer(404, {'message': 'Not Found'});
      }
      return answer(200, {
        'truncated': false,
        'tree': [
          for (final file in tree.entries)
            {'path': file.key, 'type': 'blob', 'sha': file.value},
          // A folder, as GitHub lists them too.
          {'path': 'entries', 'type': 'tree', 'sha': 'x'},
        ],
      });
    }
    if (method == 'GET' && rest.startsWith('/git/blobs/')) {
      final bytes = blobs[rest.split('/').last];
      if (bytes == null) return answer(404, {'message': 'Not Found'});
      // In lines of sixty, as GitHub sends it.
      final encoded = base64.encode(bytes);
      return answer(200, {
        'encoding': 'base64',
        'content': [
          for (var i = 0; i < encoded.length; i += 60)
            '${encoded.substring(i, (i + 60).clamp(0, encoded.length))}\n',
        ].join(),
      });
    }
    if (method == 'PUT' && rest.startsWith('/contents/')) {
      final name = rest.substring('/contents/'.length);
      final sha = _store(base64.decode(body!['content'] as String));
      head = _commit(head, {...files, name: sha}, body['message'] as String);
      return answer(201, {});
    }
    if (method == 'POST' && rest == '/git/trees') {
      if (head == null) {
        return answer(409, {'message': 'Git Repository is empty.'});
      }
      final made = Map.of(trees[body!['base_tree']]!);
      for (final item in (body['tree'] as List).cast<Map<String, dynamic>>()) {
        if (item.containsKey('content')) {
          made[item['path'] as String] = _store(
            utf8.encode(item['content'] as String),
          );
        } else if (!made.containsKey(item['path'])) {
          return answer(422, {'message': 'GitRPC::BadObjectState'});
        } else {
          made.remove(item['path']);
        }
      }
      final tree = 'tree${trees.length + 1}';
      trees[tree] = made;
      return answer(201, {'sha': tree});
    }
    if (method == 'POST' && rest == '/git/commits') {
      final id = 'commit${commits.length + 1}';
      commits[id] = (
        parent: (body!['parents'] as List).single as String,
        tree: body['tree'] as String,
        message: body['message'] as String,
      );
      return answer(201, {'sha': id});
    }
    if (method == 'PATCH' && rest == '/git/refs/heads/main') {
      final commit = commits[body!['sha']];
      if (commit == null || commit.parent != head) {
        return answer(422, {'message': 'Update is not a fast forward'});
      }
      head = body['sha'] as String;
      return answer(200, {});
    }
    return answer(404, {'message': 'Not Found'});
  }
}
