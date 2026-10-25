import 'dart:convert';

import 'package:flutter/services.dart';

import '../strings.dart';

/// A line of a hexagram as we have rendered it, with what it meant.
typedef LineReading = ({String text, String note});

/// A headed paragraph.
typedef Essay = ({String title, String text});

/// What we have written for a hexagram in one language.
class HexagramReading {
  final String name;
  final String nameNote;
  final String judgment;
  final String judgmentNote;

  /// The judgment as the commentators read it, and whose reading it is.
  final String tradition;
  final String traditionBy;
  final String image;
  final String imageNote;
  final List<LineReading> lines;
  final List<Essay> essays;
  final List<Essay> readings;

  const HexagramReading({
    required this.name,
    required this.nameNote,
    required this.judgment,
    required this.judgmentNote,
    required this.tradition,
    required this.traditionBy,
    required this.image,
    required this.imageNote,
    required this.lines,
    required this.essays,
    required this.readings,
  });

  factory HexagramReading.parse(Map<String, dynamic> json) {
    List<Essay> essays(String key) => [
      for (final e in (json[key] as List).cast<Map<String, dynamic>>())
        (title: e['title'] as String, text: e['text'] as String),
    ];
    return HexagramReading(
      name: json['name'] as String,
      nameNote: json['nameNote'] as String,
      judgment: json['judgment'] as String,
      judgmentNote: json['judgmentNote'] as String,
      tradition: json['tradition'] as String,
      traditionBy: json['traditionBy'] as String,
      image: json['image'] as String,
      imageNote: json['imageNote'] as String,
      lines: [
        for (final l in (json['lines'] as List).cast<Map<String, dynamic>>())
          (text: l['text'] as String, note: l['note'] as String),
      ],
      essays: essays('essays'),
      readings: essays('readings'),
    );
  }
}

/// The Chinese of a hexagram as it sounds: pinyin with its tone marks, a
/// syllable to a character (`pinyin` in `docs/iching/pack/SCHEMA.md`).
/// Each part is there only once it has been written.
class HexagramSound {
  final String? name;
  final String? judgment;
  final String? image;

  /// The lines from the bottom up, as many as the hexagram has, or none.
  final List<String> lines;

  const HexagramSound({
    this.name,
    this.judgment,
    this.image,
    this.lines = const [],
  });

  factory HexagramSound.parse(Map<String, dynamic> json) => HexagramSound(
    name: json['name'] as String?,
    judgment: json['judgment'] as String?,
    image: json['image'] as String?,
    lines: (json['lines'] as List?)?.cast<String>() ?? const [],
  );

  /// The sound of line [i], or null where it is not written.
  String? line(int i) => i < lines.length ? lines[i] : null;
}

/// A translator's text of a hexagram, as he wrote it (`wilhelm` and
/// `legge` in `docs/iching/pack/SCHEMA.md`): his name for it, his
/// judgment and Image, his lines with his own headings, and where it is
/// taken from. His translation only, none of his commentary.
class TranslatorText {
  final String name;
  final String judgment;
  final String image;

  /// The lines from the bottom up, as many as the hexagram has.
  final List<String> lines;
  final String source;

  const TranslatorText({
    required this.name,
    required this.judgment,
    required this.image,
    required this.lines,
    required this.source,
  });

  factory TranslatorText.parse(Map<String, dynamic> json) => TranslatorText(
    name: json['name'] as String,
    judgment: json['judgment'] as String,
    image: json['image'] as String,
    lines: (json['lines'] as List).cast<String>(),
    source: json['source'] as String,
  );
}

/// One of the sixty-four: the Chinese always, and our reading of it in
/// the languages we have finished.
class Hexagram {
  final int number;
  final String symbol;
  final String name;

  /// The name's pinyin, plain (`Qian`); [sound] has it with its tones.
  final String pinyin;
  final String lower;
  final String upper;

  /// The six lines from the bottom up, whole (true) or broken.
  final List<bool> figure;
  final String judgment;
  final String image;

  /// The line statements from the bottom up; the first two hexagrams
  /// have a seventh, for when all six lines change.
  final List<({String label, String text})> lines;
  final Map<AppLanguage, HexagramReading> readings;

  /// The Chinese as it sounds, with its tone marks, where it has been
  /// written; and why a character is read as it is where that is not
  /// today's common reading.
  final HexagramSound? sound;
  final List<String> soundNotes;

  /// Wilhelm's German (1924) and Legge's English (1882), where the pack
  /// has them yet.
  final TranslatorText? wilhelm;
  final TranslatorText? legge;

  const Hexagram({
    required this.number,
    required this.symbol,
    required this.name,
    required this.pinyin,
    required this.lower,
    required this.upper,
    required this.figure,
    required this.judgment,
    required this.image,
    required this.lines,
    required this.readings,
    this.sound,
    this.soundNotes = const [],
    this.wilhelm,
    this.legge,
  });

  /// The name's pinyin, with its tone marks where they are written.
  String get spoken => sound?.name ?? pinyin;

  /// Our reading in [language] exactly, or null where there is none.
  HexagramReading? reading(AppLanguage language) => readings[language];

  /// What is read in [language]: its own reading where there is one, else
  /// the English, with [borrowed] set so the page can say so; null while
  /// not even the English is finished.
  ({HexagramReading reading, bool borrowed})? readIn(AppLanguage language) {
    if (readings[language] case final own?) {
      return (reading: own, borrowed: false);
    }
    if (readings[AppLanguage.en] case final english?) {
      return (reading: english, borrowed: true);
    }
    return null;
  }

  /// The trigrams it is made of, below and above.
  Trigram get lowerTrigram => Trigram.named(lower);
  Trigram get upperTrigram => Trigram.named(upper);
}

/// One of the eight trigrams, in the order of their signs in Unicode
/// (☰ to ☷), which is the order of 邵雍's 先天 sequence.
enum Trigram {
  qian('☰', '乾', [true, true, true]),
  dui('☱', '兌', [true, true, false]),
  li('☲', '離', [true, false, true]),
  zhen('☳', '震', [true, false, false]),
  xun('☴', '巽', [false, true, true]),
  kan('☵', '坎', [false, true, false]),
  gen('☶', '艮', [false, false, true]),
  kun('☷', '坤', [false, false, false]);

  final String sign;
  final String name;

  /// Its three lines from the bottom up, whole (true) or broken.
  final List<bool> lines;

  const Trigram(this.sign, this.name, this.lines);

  static Trigram named(String name) =>
      values.firstWhere((trigram) => trigram.name == name);
}

/// The Yijing as the app ships it: our text pack, released under CC
/// BY-SA 4.0, version 2 (`docs/iching/pack/SCHEMA.md`, built by
/// `docs/iching/tool/build_pack.py`). Every hexagram has its Chinese; one
/// not yet worked has no reading in any language.
class IchingPack {
  final List<Hexagram> hexagrams;
  final String licence;
  final String licenceUrl;
  final List<String> credit;

  const IchingPack({
    required this.hexagrams,
    required this.licence,
    required this.licenceUrl,
    required this.credit,
  });

  static const asset = 'assets/iching/pack.v2.json';

  static Future<IchingPack>? _loading;
  static IchingPack? _ready;

  /// The pack once it has been read, or null before: a page opened after
  /// the first draws its text at once, with no empty frame.
  static IchingPack? get ready => _ready;

  /// The pack, read from the app's assets once and kept: every page of
  /// the I Ching, and the cast's card in an entry, reads the same.
  static Future<IchingPack> load() {
    if (_ready case final pack?) return Future.value(pack);
    return _loading ??= rootBundle.loadString(asset).then((source) {
      return _ready = IchingPack.parse(source);
    });
  }

  /// Puts [pack] in the place of the one read from the assets; for tests,
  /// which read the file themselves.
  static void use(IchingPack pack) => _ready = pack;

  factory IchingPack.parse(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    if (json['version'] != 2) {
      throw FormatException('not a version 2 pack: ${json['version']}');
    }
    return IchingPack(
      licence: json['licence'] as String,
      licenceUrl: json['licenceUrl'] as String,
      credit: (json['credit'] as List).cast<String>(),
      hexagrams: [
        for (final h
            in (json['hexagrams'] as List).cast<Map<String, dynamic>>())
          Hexagram(
            number: h['n'] as int,
            symbol: h['symbol'] as String,
            name: h['name'] as String,
            pinyin: h['pinyin'] as String,
            lower: h['lower'] as String,
            upper: h['upper'] as String,
            figure: [
              for (final bit in (h['bits'] as String).split('')) bit == '1',
            ],
            judgment: h['judgment'] as String,
            image: h['image'] as String,
            lines: [
              for (final l in (h['lines'] as List).cast<Map<String, dynamic>>())
                (label: l['label'] as String, text: l['text'] as String),
            ],
            readings: {
              if (h['en'] != null)
                AppLanguage.en: HexagramReading.parse(
                  h['en'] as Map<String, dynamic>,
                ),
              if (h['id'] != null)
                AppLanguage.id: HexagramReading.parse(
                  h['id'] as Map<String, dynamic>,
                ),
            },
            sound: h['pinyinTones'] == null
                ? null
                : HexagramSound.parse(h['pinyinTones'] as Map<String, dynamic>),
            soundNotes: (h['pinyinNotes'] as List?)?.cast<String>() ?? const [],
            wilhelm: h['wilhelm'] == null
                ? null
                : TranslatorText.parse(h['wilhelm'] as Map<String, dynamic>),
            legge: h['legge'] == null
                ? null
                : TranslatorText.parse(h['legge'] as Map<String, dynamic>),
          ),
      ],
    );
  }

  /// The hexagram [lower] and [upper] make.
  Hexagram made(Trigram lower, Trigram upper) =>
      of([...lower.lines, ...upper.lines]);

  /// The hexagram with these six lines, bottom up.
  Hexagram of(List<bool> figure) => hexagrams.firstWhere((hexagram) {
    for (var i = 0; i < 6; i++) {
      if (hexagram.figure[i] != figure[i]) return false;
    }
    return true;
  });
}
