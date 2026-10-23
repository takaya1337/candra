import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The iPhone's permission prompts are the ones in the owner's file
/// (`ios.permission.*` in assets/samples/showcase-strings.json): the
/// English in Info.plist, the Indonesian, once written, in
/// id.lproj/InfoPlist.strings. tool/permission_strings.sh writes them.
void main() {
  final texts = jsonDecode(
    File('assets/samples/showcase-strings.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  const prefix = 'ios.permission.';
  final prompts = {
    for (final MapEntry(:key, :value) in texts.entries)
      if (key.startsWith(prefix))
        key.substring(prefix.length): value as Map<String, dynamic>,
  };
  const fix = 'Run app/tool/permission_strings.sh.';

  test('every prompt the app asks with is in the file', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final asked = RegExp(r'<key>(NS\w+UsageDescription)</key>')
        .allMatches(plist)
        .map((m) => m[1]!)
        .toSet();
    expect(prompts.keys.toSet(), asked);
  });

  test('the English in Info.plist is the file\'s', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    for (final MapEntry(key: name, value: text) in prompts.entries) {
      final written = RegExp(
        '<key>$name</key>\\s*<string>(.*?)</string>',
        dotAll: true,
      ).firstMatch(plist)![1]!;
      final english = (text['en'] as String)
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');
      expect(written, english, reason: '$name. $fix');
    }
  });

  test('the Indonesian, where written, is in id.lproj', () {
    final strings = File('ios/Runner/id.lproj/InfoPlist.strings')
        .readAsStringSync();
    for (final MapEntry(key: name, value: text) in prompts.entries) {
      final indonesian = (text['id'] as String).trim();
      if (indonesian.isEmpty) {
        expect(strings, isNot(contains('"$name" =')), reason: fix);
      } else {
        final quoted = indonesian
            .replaceAll(r'\', r'\\')
            .replaceAll('"', r'\"');
        expect(strings, contains('"$name" = "$quoted";'), reason: fix);
      }
    }
  });
}
