import 'dart:io';

import 'package:candra/first_run.dart';
import 'package:candra/sync/sync_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the Keychain.
class FakeSecrets implements SecretStore {
  FakeSecrets([this.secret]);

  String? secret;
  var deletes = 0;
  bool fails = false;

  @override
  Future<String?> read() async => secret;

  @override
  Future<void> write(String value) async => secret = value;

  @override
  Future<void> delete() async {
    deletes++;
    if (fails) throw Exception('locked');
    secret = null;
  }
}

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('first_run');
  });
  tearDown(() => root.deleteSync(recursive: true));

  Future<SharedPreferences> preferences([
    Map<String, Object> values = const {},
  ]) {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test(
    'a fresh install on an iPhone throws away a token left behind',
    () async {
      final prefs = await preferences();
      final secrets = FakeSecrets('left over');
      await FirstRun.clearLeftovers(
        preferences: prefs,
        root: root,
        secrets: secrets,
        iOS: true,
      );
      expect(secrets.secret, isNull);
      expect(prefs.getBool(FirstRun.installedKey), isTrue);
    },
  );

  test('only the first launch deletes anything', () async {
    final prefs = await preferences({FirstRun.installedKey: true});
    final secrets = FakeSecrets('kept');
    await FirstRun.clearLeftovers(
      preferences: prefs,
      root: root,
      secrets: secrets,
      iOS: true,
    );
    expect(secrets.secret, 'kept');
    expect(secrets.deletes, 0);
  });

  test('an install being updated with sync set up keeps its token', () async {
    File('${root.path}/sync.json').writeAsStringSync('{}');
    final prefs = await preferences();
    final secrets = FakeSecrets('kept');
    await FirstRun.clearLeftovers(
      preferences: prefs,
      root: root,
      secrets: secrets,
      iOS: true,
    );
    expect(secrets.secret, 'kept');
    expect(secrets.deletes, 0);
    expect(prefs.getBool(FirstRun.installedKey), isTrue);
  });

  test('Android deletes nothing: its storage goes with the app', () async {
    final prefs = await preferences();
    final secrets = FakeSecrets('kept');
    await FirstRun.clearLeftovers(
      preferences: prefs,
      root: root,
      secrets: secrets,
      iOS: false,
    );
    expect(secrets.deletes, 0);
    expect(prefs.getBool(FirstRun.installedKey), isTrue);
  });

  test('a delete that fails is tried again on the next launch', () async {
    final prefs = await preferences();
    final secrets = FakeSecrets('left over')..fails = true;
    await FirstRun.clearLeftovers(
      preferences: prefs,
      root: root,
      secrets: secrets,
      iOS: true,
    );
    expect(prefs.getBool(FirstRun.installedKey), isNull);
    secrets.fails = false;
    await FirstRun.clearLeftovers(
      preferences: prefs,
      root: root,
      secrets: secrets,
      iOS: true,
    );
    expect(secrets.secret, isNull);
    expect(prefs.getBool(FirstRun.installedKey), isTrue);
  });
}
