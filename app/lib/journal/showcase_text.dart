import 'dart:convert';

import '../strings.dart';

/// The showcase samples' words, in English and Indonesian, read from
/// `assets/samples/showcase-strings.json`, which the owner fills:
/// `{"<key>": {"en": "...", "id": "..."}}`, and a `_note` on how.
///
/// An Indonesian text left empty falls back to the English; [missing]
/// names those, and `tool/store_screenshots.sh` refuses to take the
/// Indonesian screenshots while there are any.
class ShowcaseText {
  /// Where the file is, as an asset and from the app's folder.
  static const asset = 'assets/samples/showcase-strings.json';

  final Map<String, ({String en, String id})> _texts;

  /// The language the texts are read in.
  final AppLanguage language;

  ShowcaseText._(this._texts, this.language);

  /// Reads the file's [source]. Throws [FormatException] if it is not
  /// shaped as above.
  factory ShowcaseText.parse(String source, AppLanguage language) {
    final json = jsonDecode(source);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('showcase strings: not an object');
    }
    final texts = <String, ({String en, String id})>{};
    for (final MapEntry(:key, :value) in json.entries) {
      if (key.startsWith('_')) continue;
      if (value is! Map ||
          value['en'] is! String ||
          (value['en'] as String).isEmpty ||
          value['id'] is! String) {
        throw FormatException('showcase strings: "$key" needs "en" and "id"');
      }
      texts[key] = (en: value['en'] as String, id: value['id'] as String);
    }
    return ShowcaseText._(texts, language);
  }

  /// Every key in the file.
  Iterable<String> get keys => _texts.keys;

  /// The keys whose Indonesian is still empty.
  List<String> get missing => [
    for (final MapEntry(:key, :value) in _texts.entries)
      if (value.id.trim().isEmpty) key,
  ];

  /// The keys asked for so far, to check the file has every one.
  final Set<String> asked = {};

  /// The text of [key] in [language], with each `{name}` in it replaced
  /// by [fill]'s value. Throws [ArgumentError] for a key not in the file.
  String call(String key, [Map<String, Object> fill = const {}]) {
    asked.add(key);
    final text = _texts[key];
    if (text == null) throw ArgumentError.value(key, 'key', 'not in $asset');
    var out = language == AppLanguage.id && text.id.trim().isNotEmpty
        ? text.id
        : text.en;
    for (final MapEntry(:key, :value) in fill.entries) {
      out = out.replaceAll('{$key}', '$value');
    }
    return out;
  }
}
