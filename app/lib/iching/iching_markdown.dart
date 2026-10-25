import 'package:sacred_time/sacred_time.dart';

import '../strings.dart';
import 'iching_pack.dart';
import 'iching_reading_screen.dart';

// A page of the reading card as markdown, for the copy button beside the
// page's name (owner, 25 October 2026: each page on its own, never the
// whole card at once). It holds what the page holds, the parts that fold
// open included, and from a cast only the lines the page reads.

/// The lines a page reads: every one in the library; from a cast, those
/// that change, and the seventh text (用九, 用六) when all six do; none
/// where the card shows what the cast becomes.
List<int> ichingLinesRead(
  Hexagram hexagram,
  YijingCast? cast, {
  required bool becomes,
}) {
  if (cast == null) {
    return [for (var i = 0; i < hexagram.lines.length; i++) i];
  }
  if (becomes) return const [];
  final changing = cast.changing;
  return [
    for (var i = 0; i < hexagram.lines.length; i++)
      if (i < 6 ? changing.contains(i) : changing.length == 6) i,
  ];
}

/// The [page] of [hexagram] as markdown.
String ichingPageMarkdown({
  required ReadingPage page,
  required Hexagram hexagram,
  required IchingPack pack,
  required Strings strings,
  YijingCast? cast,
  bool becomes = false,
}) {
  final out = StringBuffer();
  void block(String? text) {
    if (text == null || text.trim().isEmpty) return;
    out
      ..writeln(text.trim())
      ..writeln();
  }

  final reading = hexagram.readIn(strings.language)?.reading;
  // Our notes are drafts, kept back with the pages that hold them.
  final notes = IchingDrafts.shown.value ? reading : null;
  final year = strings.ichingTranslatorYear(page);
  final lines = ichingLinesRead(hexagram, cast, becomes: becomes);
  final allChange = cast != null && cast.changing.length == 6;

  // The lines' part, the same on Main and the translators' pages.
  void linesPart(void Function(int i) each) {
    block('## ${strings.ichingLines}');
    if (becomes) {
      block('*${strings.ichingBecomesLines}*');
    } else if (lines.isEmpty) {
      block('*${strings.ichingNoLineChanges}*');
    }
    for (final i in lines) {
      final changes = cast != null && i < 6;
      block(
        '### ${hexagram.lines[i].label}'
        '${changes ? ' · ${strings.ichingChanges}' : ''}',
      );
      if (i == 6 && allChange) block('*${strings.ichingAllChange}*');
      each(i);
    }
  }

  switch (page) {
    case ReadingPage.main:
      final sound = hexagram.sound;
      block(
        '# ${hexagram.number} ${hexagram.symbol} ${hexagram.name} '
        '${hexagram.spoken}${reading == null ? '' : ' · ${reading.name}'}',
      );
      if (reading == null) block('*${strings.ichingNotYet}*');
      // One of the hexagram's texts: the Chinese, its sound, our English.
      void told(String text, String? said, String? english) {
        block(text);
        if (said != null) block('*$said*');
        block(english);
      }

      block('## ${strings.ichingJudgment}');
      told(hexagram.judgment, sound?.judgment, reading?.judgment);
      if (notes != null) {
        block(notes.judgmentNote);
        block(
          '**${strings.ichingAsRead(notes.traditionBy)}.** '
          '${notes.tradition}',
        );
      }
      block('## ${strings.ichingImage}');
      told(hexagram.image, sound?.image, reading?.image);
      if (notes != null) {
        block('**${_capital(strings.ichingLater)}.** ${notes.imageNote}');
      }
      linesPart((i) {
        told(hexagram.lines[i].text, sound?.line(i), reading?.lines[i].text);
        block(notes?.lines[i].note);
      });
    case ReadingPage.wilhelm || ReadingPage.legge:
      final text = page == ReadingPage.wilhelm
          ? hexagram.wilhelm
          : hexagram.legge;
      final german = page == ReadingPage.wilhelm;
      block(
        '# ${hexagram.number} ${hexagram.name} · '
        '${strings.ichingPage(page)} ($year)',
      );
      if (text == null) {
        block('*${strings.ichingTranslatorNotYet(page)}*');
        break;
      }
      block('**${text.name}**');
      block('## ${german ? 'Das Urteil' : 'The Text'}');
      block(text.judgment);
      block('## ${german ? 'Das Bild' : 'The Symbolism'}');
      block(text.image);
      linesPart((i) => block(text.lines[i]));
      block('*${text.source}*');
    case ReadingPage.notes:
      block(
        '# ${hexagram.number} ${hexagram.name} · '
        '${strings.ichingPage(page)}',
      );
      block(
        strings.ichingBelowAbove(hexagram.lowerTrigram, hexagram.upperTrigram),
      );
      if (reading != null) {
        block('## ${hexagram.name} · ${reading.name}');
        block(reading.nameNote);
        for (final essay in reading.essays) {
          block('## ${essay.title}');
          block(essay.text);
        }
      }
      if (hexagram.soundNotes.isNotEmpty) {
        block('## ${strings.ichingPinyin}');
        block([for (final each in hexagram.soundNotes) '- $each'].join('\n'));
      }
    case ReadingPage.readings:
      block(
        '# ${hexagram.number} ${hexagram.name} · '
        '${strings.ichingPage(page)}',
      );
      final readings = reading?.readings ?? const [];
      if (readings.isEmpty) block('*${strings.ichingNoReadings}*');
      for (final each in readings) {
        block('## ${each.title}');
        block(each.text);
      }
    case ReadingPage.credit:
      block(
        '# ${hexagram.number} ${hexagram.name} · '
        '${strings.ichingPage(page)}',
      );
      block('${pack.licence} (${pack.licenceUrl})');
      for (final line in pack.credit) {
        block(line);
      }
  }
  return '${out.toString().trimRight()}\n';
}

String _capital(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
