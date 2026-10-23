import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../journal/journal_store.dart';
import '../reminders/reminder_store.dart';
import 'git_host.dart';
import 'github_host.dart';
import 'sync_engine.dart';

/// Where the token is kept.
abstract class SecretStore {
  Future<String?> read();
  Future<void> write(String secret);
  Future<void> delete();
}

/// Keeps the token encrypted with a key held by the phone's own hardware
/// keystore, which never gives the key out.
class PhoneSecretStore implements SecretStore {
  const PhoneSecretStore();

  // On an iPhone the token is kept for this phone alone: it is not
  // synced through iCloud Keychain and does not travel in a backup to
  // another device.
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  static const _key = 'github_token';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String secret) => _storage.write(key: _key, value: secret);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

/// Keeps it only as long as the app runs. For tests.
class MemorySecretStore implements SecretStore {
  String? secret;

  @override
  Future<String?> read() async => secret;

  @override
  Future<void> write(String secret) async => this.secret = secret;

  @override
  Future<void> delete() async => secret = null;
}

/// Where syncing stands.
enum SyncPhase {
  /// Not set up.
  off,

  /// Set up, and in step as far as is known.
  idle,
  syncing,

  /// In step but for some entries changed on both sides, which wait for
  /// the user.
  conflicts,

  /// The last attempt did not go through; see [SyncController.problem].
  failed,
}

/// Why a sync did not go through.
enum SyncProblem {
  offline,
  denied,
  notFound,

  /// GitHub has had too many requests for now; see
  /// [SyncController.retryAfter].
  rateLimited,

  /// What this device remembers of the repository could not be read. Sync
  /// stays set up but stopped, the token kept, until it is turned off and
  /// set up again.
  damaged,
  other,
}

/// Keeps the journal in step with a GitHub repository.
///
/// Once connected it syncs by itself: when the app starts, when it comes
/// back to the front, and a few seconds after anything in the journal or
/// the reminders changes. [syncNow] does it on demand. Entries changed on
/// two devices are never settled silently: they are held in [conflicts]
/// until the user has chosen, and [resolve] carries the choices out.
class SyncController extends ChangeNotifier with WidgetsBindingObserver {
  final Directory root;
  final JournalStore journal;
  final ReminderStore reminders;
  final SecretStore secrets;

  /// How long after the last change a sync starts.
  final Duration settle;

  /// Makes the host for a repository; replaced in tests.
  final GitHost Function(String owner, String repository, String token) hostFor;

  SyncController({
    required this.root,
    required this.journal,
    required this.reminders,
    this.secrets = const PhoneSecretStore(),
    this.settle = const Duration(seconds: 4),
    GitHost Function(String owner, String repository, String token)? hostFor,
  }) : hostFor =
           hostFor ??
           ((owner, repository, token) =>
               GitHubHost(owner: owner, repository: repository, token: token)) {
    // From the first moment, so that nothing written is missed.
    journal.addListener(_touched);
    reminders.addListener(_touched);
  }

  /// "owner/name", or null when sync is off.
  String? get repository => _repository;
  String? _repository;

  SyncPhase get phase => _phase;
  var _phase = SyncPhase.off;

  /// Set while [phase] is failed; with [detail] when the host said why.
  SyncProblem? get problem => _problem;
  SyncProblem? _problem;
  String? get detail => _detail;
  String? _detail;

  DateTime? get lastSynced => _lastSynced;
  DateTime? _lastSynced;

  List<Conflict> get conflicts => List.unmodifiable(_conflicts);
  var _conflicts = <Conflict>[];

  /// While [problem] is rateLimited: when GitHub said to try again, if it
  /// did.
  DateTime? get retryAfter => _retryAfter;
  DateTime? _retryAfter;

  /// Whether something wants the user's attention. Being offline or held
  /// back by the rate limit mends itself, and does not.
  bool get needsAttention =>
      _phase == SyncPhase.conflicts ||
      (_phase == SyncPhase.failed &&
          _problem != SyncProblem.offline &&
          _problem != SyncProblem.rateLimited);

  var _state = const SyncState();
  SyncEngine? _engine;
  Timer? _timer;
  bool _running = false;
  bool _again = false;

  // Choices asked for while a sync was running, for the one after it.
  final _pending = <String, Keep>{};

  // True while the stores are being reloaded after a sync, so that their
  // announcing it does not set off another.
  bool _applying = false;

  File get _file => File('${root.path}/sync.json');

  /// Reads what was set up before, and if anything was, syncs.
  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    if (!_file.existsSync()) return;
    final String repository;
    final SyncState state;
    final DateTime? lastSynced;
    try {
      final saved =
          jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
      repository = saved['repository'] as String;
      if (repositoryFrom(repository) != repository) {
        throw FormatException('Not a repository', repository);
      }
      state = SyncState.fromJson(saved['state'] as Map<String, dynamic>);
      final at = saved['lastSynced'] as String?;
      lastSynced = at == null ? null : DateTime.tryParse(at);
    } catch (_) {
      // Sync was set up here, but what it remembers cannot be read. It is
      // not taken for never set up: that would hide it, and a sync from
      // nothing would raise every file as a conflict. It waits, and says
      // so, until it is turned off and set up again.
      _problem = SyncProblem.damaged;
      _detail = null;
      _phase = SyncPhase.failed;
      notifyListeners();
      return;
    }
    try {
      final token = await secrets.read();
      if (token == null) return;
      _state = state;
      _lastSynced = lastSynced;
      _open(repository, token);
      _phase = SyncPhase.idle;
      notifyListeners();
      unawaited(syncNow());
    } catch (_) {
      // Without the token there is nothing to sync with.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    journal.removeListener(_touched);
    reminders.removeListener(_touched);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _open(String repository, String token) {
    final parts = repository.split('/');
    _repository = repository;
    _engine = SyncEngine(
      journal: Directory(journal.journalPath!),
      host: hostFor(parts[0], parts[1], token),
      device: Platform.operatingSystem,
    );
  }

  // Written whole beside it and then put in its place, so that the app
  // stopped halfway never leaves half a file.
  void _save() {
    File('${_file.path}.tmp')
      ..writeAsStringSync(
        jsonEncode({
          'repository': _repository,
          'state': _state.toJson(),
          'lastSynced': _lastSynced?.toIso8601String(),
        }),
        flush: true,
      )
      ..renameSync(_file.path);
  }

  /// "owner/name" out of whatever was typed or pasted, or null if it is
  /// not one: a bare name, a web address and a git address all do.
  static String? repositoryFrom(String typed) {
    final match = RegExp(
      r'^(?:https?://github\.com/|git@github\.com:)?([\w.-]+)/([\w.-]+?)(?:\.git)?/?$',
    ).firstMatch(typed.trim());
    return match == null ? null : '${match[1]}/${match[2]}';
  }

  /// Sets sync up with [repository] and [token], and syncs for the first
  /// time. Returns what went wrong, or null if nothing did; on a failure
  /// nothing is kept.
  Future<SyncProblem?> connect(String repository, String token) async {
    final name = repositoryFrom(repository);
    if (name == null || journal.journalPath == null) {
      return SyncProblem.notFound;
    }
    final parts = name.split('/');
    final host = hostFor(parts[0], parts[1], token.trim());
    try {
      if (host is GitHubHost) await host.connect();
      await host.headCommit();
    } on Exception catch (error) {
      return _problemOf(error);
    }
    await secrets.write(token.trim());
    _state = const SyncState();
    _lastSynced = null;
    _open(name, token.trim());
    _phase = SyncPhase.idle;
    _save();
    notifyListeners();
    await syncNow();
    return null;
  }

  /// Stops syncing on this device and forgets the token. The journal
  /// here and the repository are both left as they are.
  Future<void> disconnect() async {
    _timer?.cancel();
    await secrets.delete();
    if (_file.existsSync()) _file.deleteSync();
    _repository = null;
    _engine = null;
    _state = const SyncState();
    _conflicts = [];
    _pending.clear();
    _problem = null;
    _detail = null;
    _retryAfter = null;
    _lastSynced = null;
    _phase = SyncPhase.off;
    notifyListeners();
  }

  void _touched() {
    if (_applying || _engine == null) return;
    _timer?.cancel();
    _timer = Timer(settle, syncNow);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_engine == null) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(syncNow());
    } else if (state == AppLifecycleState.paused &&
        (_timer?.isActive ?? false)) {
      // Leaving with a change still waiting its few seconds: send it
      // now, while the app is still allowed to.
      unawaited(syncNow());
    }
  }

  /// Carries out the user's choices for the conflicts, and syncs.
  Future<void> resolve(Map<String, Keep> choices) => syncNow(choices);

  /// Syncs now. Asked for while a sync is running, it runs once more when
  /// that one is done, with any [resolutions] asked for meanwhile.
  Future<void> syncNow([Map<String, Keep> resolutions = const {}]) async {
    final engine = _engine;
    if (engine == null) return;
    if (_running) {
      _pending.addAll(resolutions);
      _again = true;
      return;
    }
    final choices = {..._pending, ...resolutions};
    _pending.clear();
    _timer?.cancel();
    _running = true;
    _phase = SyncPhase.syncing;
    notifyListeners();
    try {
      final result = await engine.sync(_state, resolutions: choices);
      _state = result.state;
      _conflicts = result.conflicts;
      _lastSynced = DateTime.now();
      _problem = null;
      _detail = null;
      _retryAfter = null;
      _save();
      _phase = _conflicts.isEmpty ? SyncPhase.idle : SyncPhase.conflicts;
    } catch (error) {
      _fail(error);
    }
    try {
      // Whatever was written here, by this sync or by one that failed
      // partway, is read afresh, or it would not be seen. Until that has
      // been done once, every sync tries it again.
      if (engine.wroteHere) {
        _applying = true;
        try {
          journal.reload();
          reminders.reload();
        } finally {
          _applying = false;
        }
        engine.wroteHere = false;
      }
    } catch (error) {
      _fail(error);
    } finally {
      _running = false;
      notifyListeners();
    }
    if (_again) {
      _again = false;
      await syncNow();
    }
  }

  void _fail(Object error) {
    _problem = _problemOf(error);
    _detail = error is SyncFailed ? error.message : null;
    _retryAfter = error is SyncRateLimited ? error.until : null;
    _phase = SyncPhase.failed;
  }

  static SyncProblem _problemOf(Object error) => switch (error) {
    SyncOffline() => SyncProblem.offline,
    SyncDenied() => SyncProblem.denied,
    SyncNotFound() => SyncProblem.notFound,
    SyncRateLimited() => SyncProblem.rateLimited,
    _ => SyncProblem.other,
  };
}

/// Gives the subtree the [SyncController], where there is one.
class SyncScope extends InheritedNotifier<SyncController> {
  const SyncScope({super.key, required super.notifier, required super.child});

  static SyncController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SyncScope>()?.notifier;
}
