import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

/// The ways a run of words within a line can be marked.
enum Format {
  bold('**', '**'),
  italic('*', '*'),
  underline('<u>', '</u>'),
  strike('~~', '~~'),
  highlight('==', '=='),
  code('`', '`');

  /// What stands before and after the words.
  final String open;
  final String close;

  const Format(this.open, this.close);
}

/// A marked run found in a text: where it starts and ends, marks included,
/// and how long the marks at each end are.
typedef _Run = ({Set<Format> formats, int start, int end, int open, int close});

/// The Markdown an entry's content is written in, kept small on purpose:
///
///     **bold**   *italic* or _italic_   <u>underlined</u>
///     ~~struck~~   `code`   a footnote[^1]
///     # heading (one to three #)
///     - list item
///     - [ ] to do, - [x] done
///     1. numbered item
///     > quote
///     ---   (a divider, on a line of its own)
///     ==highlighted==   [a link](https://...)   https://...
///     [[2026-10-25]]   (a link to a day)
///     [those words](/entries/2026/10/25)   (a day, by words of one's own:
///                      its folder, as the journal's repository has it)
///     [Evening offering](/entries/2026/10/11/3fa9c1/193005.md)
///                      (a link to an entry, by its file from the journal's
///                      root, as the journal's repository has it)
///     [^1]: what the footnote says
///
/// The text itself is never changed for display. The marks stay in it,
/// drawn faintly while writing and shrunk to nothing while reading, so
/// what is selected and copied is always the Markdown as written.
abstract final class Markdown {
  static final _heading = RegExp(r'^(#{1,3}) +');
  static final _bullet = RegExp(r'^(\s*)([-*]) +');
  static final _check = RegExp(r'^(\s*)([-*] +)\[([ xX])\] ');
  static final _numbered = RegExp(r'^(\s*)(\d{1,4})\. ');
  static final _divider = RegExp(r'^\s*(?:-{3,}|\*{3,}|_{3,})\s*$');
  // A day, a link with its words, or an address on its own.
  static final _link = RegExp(
    r'\[\[(\d{4}-\d{2}-\d{2})\]\]'
    r'|\[([^\]\[]+)\]\(([^)\s]+)\)'
    r"|(https?://[^\s<>()\[\]]*[^\s<>()\[\].,;:!?'\x22])",
  );
  static final _quote = RegExp(r'^> ?');
  static final _note = RegExp(r'^\[\^([^\]\s]+)\]: ?');
  static final _noteRef = RegExp(r'\[\^([^\]\s]+)\](?!:)');

  // Code first, so that marks inside it are left alone; then the pairs;
  // last a footnote's mark, which has nothing inside it.
  static final _inline = RegExp(
    r'(`)(.+?)`'
    r'|(\*\*\*)(?!\s)(.+?)(?<!\s)\*\*\*'
    r'|(\*\*)(?!\s)(.+?)(?<!\s)\*\*'
    r'|(~~)(?!\s)(.+?)(?<!\s)~~'
    r'|(<u>)(.+?)</u>'
    r'|(==)(?!\s)(.+?)(?<!\s)=='
    r'|(?<![*\w])(\*)(?![\s*])(.+?)(?<![\s*])\*(?!\*)'
    r'|(?<!\w)(_)(?![\s_])(.+?)(?<![\s_])_(?!\w)'
    r'|(\[\^[^\]\s]+\])()(?!:)',
  );
  static const _groups = [1, 3, 5, 7, 9, 11, 13, 15, 17];

  // What each opening mark means, and what closes it.
  static (Set<Format>, String) _meaning(String sign) => switch (sign) {
    '`' => ({Format.code}, '`'),
    '***' => ({Format.bold, Format.italic}, '***'),
    '**' => ({Format.bold}, '**'),
    '~~' => ({Format.strike}, '~~'),
    '<u>' => ({Format.underline}, '</u>'),
    '==' => ({Format.highlight}, '=='),
    _ => ({Format.italic}, sign),
  };

  /// [text] as styled spans. The spans' text, joined, is exactly [text].
  ///
  /// With [showMarks] the Markdown marks are drawn faintly; without, they
  /// take up no room. [flat] keeps headings at the size of the rest, for
  /// previews.
  ///
  /// With [decorated] the checklists' boxes are drawn, not written: their
  /// characters take their places unseen, for [MarkdownDecorations] to
  /// draw over.
  ///
  /// [finds] says whether a link to an entry finds it; one that does not is
  /// drawn faint, its line broken (owner, 27 October 2026: "honest when it
  /// cant resolve"). Without it every link is drawn as found.
  static TextSpan span(
    String text,
    TextStyle base, {
    required SmColors colors,
    required bool showMarks,
    bool flat = false,
    bool decorated = false,
    bool Function(String address)? finds,
  }) {
    final asked = _finds;
    _finds = finds;
    try {
      return _span(
        text,
        base,
        colors: colors,
        showMarks: showMarks,
        flat: flat,
        decorated: decorated,
      );
    } finally {
      _finds = asked;
    }
  }

  // Whether a link to an entry finds it, for the span being made.
  static bool Function(String address)? _finds;

  static TextSpan _span(
    String text,
    TextStyle base, {
    required SmColors colors,
    required bool showMarks,
    bool flat = false,
    bool decorated = false,
  }) {
    final mark = showMarks
        ? TextStyle(color: colors.textFaint, fontWeight: FontWeight.w400)
        : const TextStyle(
            color: Color(0x00000000),
            fontSize: 0.01,
            letterSpacing: 0,
          );
    final small = base.fontSize == null ? null : base.fontSize! * 0.82;
    final noteMark = TextStyle(color: colors.accent, fontSize: small);
    final children = <InlineSpan>[];
    final lines = text.split('\n');

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      var style = const TextStyle();

      // A divider: drawn as a rule across the page where decorated; its
      // dashes faint otherwise.
      if (_divider.hasMatch(line)) {
        children.add(
          TextSpan(
            text: line,
            style: decorated
                ? const TextStyle(color: Color(0x00000000))
                : TextStyle(color: colors.textFaint),
          ),
        );
        if (i < lines.length - 1) children.add(const TextSpan(text: '\n'));
        continue;
      }

      final heading = _heading.firstMatch(line);
      final check = _check.firstMatch(line);
      final numbered = _numbered.firstMatch(line);
      final bullet = _bullet.firstMatch(line);
      final quote = _quote.firstMatch(line);
      final note = _note.firstMatch(line);
      if (heading != null) {
        final level = heading[1]!.length;
        children.add(TextSpan(text: heading[0], style: mark));
        line = line.substring(heading.end);
        style = TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: flat || base.fontSize == null
              ? null
              : base.fontSize! * const [1.35, 1.2, 1.08][level - 1],
          color: colors.textPrimary,
        );
      } else if (note != null) {
        // What a footnote says: its mark in the accent colour, the rest
        // set back a little.
        children.add(TextSpan(text: note[0], style: noteMark));
        line = line.substring(note.end);
        style = TextStyle(color: colors.textSecondary, fontSize: small);
      } else if (check != null) {
        // A checklist item: the dash is a mark, and the brackets with what
        // is between them are its box, in the accent; a done item's words
        // struck and set back.
        final done = check[3] != ' ';
        if (decorated) {
          // The box is drawn: its characters keep its room, unseen and a
          // little larger than the words, so it is easy to touch.
          final room = TextStyle(
            color: const Color(0x00000000),
            fontSize: base.fontSize == null ? null : base.fontSize! * 1.3,
          );
          children
            ..add(TextSpan(text: check[1]))
            ..add(TextSpan(text: check[2], style: _unseenFlat))
            ..add(TextSpan(text: '[${check[3]}]', style: room))
            ..add(const TextSpan(text: ' '));
        } else {
          final box = TextStyle(
            color: colors.accent,
            fontWeight: FontWeight.w700,
          );
          children
            ..add(TextSpan(text: check[1]))
            ..add(TextSpan(text: check[2], style: mark))
            ..add(TextSpan(text: '[', style: box))
            ..add(
              TextSpan(
                text: check[3],
                style: box.copyWith(
                  backgroundColor: colors.accent.withValues(
                    alpha: done ? 0.3 : 0.14,
                  ),
                ),
              ),
            )
            ..add(TextSpan(text: '] ', style: box));
        }
        line = line.substring(check.end);
        if (done) {
          style = TextStyle(
            color: colors.textSecondary,
            decoration: TextDecoration.lineThrough,
          );
        }
      } else if (numbered != null) {
        // The number is the bullet: it stays, in the accent colour.
        children
          ..add(TextSpan(text: numbered[1]))
          ..add(
            TextSpan(
              text: line.substring(numbered[1]!.length, numbered.end),
              style: TextStyle(color: colors.accent),
            ),
          );
        line = line.substring(numbered.end);
      } else if (bullet != null) {
        // The dash is the bullet: it stays, in the accent colour.
        children
          ..add(TextSpan(text: bullet[1]))
          ..add(
            TextSpan(
              text: line.substring(bullet[1]!.length, bullet.end),
              style: TextStyle(color: colors.accent),
            ),
          );
        line = line.substring(bullet.end);
      } else if (quote != null) {
        children.add(
          TextSpan(
            text: quote[0],
            style: TextStyle(color: colors.accent.withValues(alpha: 0.7)),
          ),
        );
        line = line.substring(quote.end);
        style = TextStyle(
          fontStyle: FontStyle.italic,
          color: colors.textSecondary,
        );
      }

      children.add(
        TextSpan(
          style: style,
          children: _inlineSpans(line, mark, noteMark, colors),
        ),
      );
      if (i < lines.length - 1) children.add(const TextSpan(text: '\n'));
    }
    return TextSpan(style: base, children: children);
  }

  // Characters that keep no room and show nothing.
  static const _unseenFlat = TextStyle(
    color: Color(0x00000000),
    fontSize: 0.01,
    height: 0.01,
    letterSpacing: 0,
  );

  // The links first, so that an address is never read as marks; the
  // rest of the words between them as [_marked].
  static List<InlineSpan> _inlineSpans(
    String text,
    TextStyle mark,
    TextStyle noteMark,
    SmColors colors,
  ) {
    final linked = TextStyle(
      color: colors.accent,
      decoration: TextDecoration.underline,
      decorationColor: colors.accent.withValues(alpha: 0.6),
    );
    final spans = <InlineSpan>[];
    var from = 0;
    for (final link in _link.allMatches(text)) {
      if (link.start > from) {
        spans.addAll(
          _marked(text.substring(from, link.start), mark, noteMark, colors),
        );
      }
      from = link.end;
      if (link[1] != null) {
        // A day: its date, the brackets marks.
        spans
          ..add(TextSpan(text: '[[', style: mark))
          ..add(TextSpan(text: link[1], style: linked))
          ..add(TextSpan(text: ']]', style: mark));
      } else if (link[2] != null) {
        // Words that link: they show, the address is a mark. A link to an
        // entry that is not where it says is faint, its line broken.
        final address = link[3]!;
        final lost =
            entryAddress(address) != null && !(_finds?.call(address) ?? true);
        spans
          ..add(TextSpan(text: '[', style: mark))
          ..add(
            TextSpan(
              style: lost
                  ? TextStyle(
                      color: colors.textFaint,
                      decoration: TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.dashed,
                      decorationColor: colors.textFaint,
                    )
                  : linked,
              children: _marked(link[2]!, mark, noteMark, colors),
            ),
          )
          ..add(TextSpan(text: '](${link[3]})', style: mark));
      } else {
        spans.add(TextSpan(text: link[4], style: linked));
      }
    }
    if (from < text.length) {
      spans.addAll(_marked(text.substring(from), mark, noteMark, colors));
    }
    return spans;
  }

  static List<InlineSpan> _marked(
    String text,
    TextStyle mark,
    TextStyle noteMark,
    SmColors colors,
  ) {
    final spans = <InlineSpan>[];
    var from = 0;
    for (final match in _inline.allMatches(text)) {
      if (match.start > from) {
        spans.add(TextSpan(text: text.substring(from, match.start)));
      }
      // Each kind has its own pair of groups: the mark, then the inside.
      final group = _groups.firstWhere((g) => match[g] != null);
      final sign = match[group]!;
      final inside = match[group + 1]!;
      from = match.end;
      if (sign.startsWith('[^')) {
        spans.add(TextSpan(text: sign, style: noteMark));
        continue;
      }
      final (formats, close) = _meaning(sign);
      final style = TextStyle(
        fontWeight: formats.contains(Format.bold) ? FontWeight.w700 : null,
        fontStyle: formats.contains(Format.italic) ? FontStyle.italic : null,
        decoration: formats.contains(Format.strike)
            ? TextDecoration.lineThrough
            : formats.contains(Format.underline)
            ? TextDecoration.underline
            : null,
        color: formats.contains(Format.code)
            ? colors.accent
            : formats.contains(Format.strike)
            ? colors.textSecondary
            : null,
        backgroundColor: formats.contains(Format.code)
            ? colors.accent.withValues(alpha: 0.12)
            : formats.contains(Format.highlight)
            ? colors.accent.withValues(alpha: 0.3)
            : null,
      );
      spans
        ..add(TextSpan(text: sign, style: mark))
        ..add(
          TextSpan(
            style: style,
            // Marks inside code are only characters.
            children: formats.contains(Format.code)
                ? [TextSpan(text: inside)]
                : _inlineSpans(inside, mark, noteMark, colors),
          ),
        )
        ..add(TextSpan(text: close, style: mark));
    }
    if (from < text.length) spans.add(TextSpan(text: text.substring(from)));
    return spans;
  }

  // Finding out what is marked, and changing it: for the format buttons.

  static TextSelection _selectionOf(TextEditingValue value) =>
      value.selection.isValid
      ? value.selection
      : TextSelection.collapsed(offset: value.text.length);

  // The start and end of the line [offset] is in.
  static (int, int) _lineAt(String text, int offset) {
    final start = offset == 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;
    final next = text.indexOf('\n', offset);
    return (start, next < 0 ? text.length : next);
  }

  // Every marked run in [text], which starts at [at] in the whole; runs
  // inside runs included.
  static List<_Run> _runs(String text, int at) {
    final found = <_Run>[];
    for (final match in _inline.allMatches(text)) {
      final group = _groups.firstWhere((g) => match[g] != null);
      final sign = match[group]!;
      if (sign.startsWith('[^')) continue;
      final (formats, close) = _meaning(sign);
      found.add((
        formats: formats,
        start: at + match.start,
        end: at + match.end,
        open: sign.length,
        close: close.length,
      ));
      if (!formats.contains(Format.code)) {
        found.addAll(_runs(match[group + 1]!, at + match.start + sign.length));
      }
    }
    return found;
  }

  // The marked runs that the selection lies wholly within.
  static List<_Run> _around(TextEditingValue value) {
    final selection = _selectionOf(value);
    final (start, end) = _lineAt(value.text, selection.start);
    if (selection.end > end) return const [];
    return [
      for (final run in _runs(value.text.substring(start, end), start))
        if (run.start <= selection.start && selection.end <= run.end) run,
    ];
  }

  /// The formats the caret, or the whole of the selection, is inside.
  static Set<Format> formatsAt(TextEditingValue value) => {
    for (final run in _around(value)) ...run.formats,
  };

  /// The level of heading the line of the caret is, 0 for none.
  static int headingAt(TextEditingValue value) {
    final (start, end) = _lineAt(value.text, _selectionOf(value).start);
    return _heading.firstMatch(value.text.substring(start, end))?[1]!.length ??
        0;
  }

  /// Whether the line of the caret is a list item (not a checklist's).
  static bool listAt(TextEditingValue value) {
    final (start, end) = _lineAt(value.text, _selectionOf(value).start);
    final line = value.text.substring(start, end);
    return _bullet.hasMatch(line) && !_check.hasMatch(line);
  }

  /// Whether the line of the caret is a checklist item.
  static bool checklistAt(TextEditingValue value) {
    final (start, end) = _lineAt(value.text, _selectionOf(value).start);
    return _check.hasMatch(value.text.substring(start, end));
  }

  /// Makes every line the selection touches a checklist item, not done;
  /// or, if they all are already, plain lines again.
  static TextEditingValue toggleChecklist(TextEditingValue value) =>
      _mapLines(value, (lines) {
        final all = lines.every(_check.hasMatch);
        return [
          for (final line in lines)
            all
                ? line.substring(_check.firstMatch(line)!.end)
                : _bare(line, '- [ ] '),
        ];
      });

  /// Ticks the checklist item whose box is at [offset] in [text], or
  /// unticks it; null where there is no box at [offset]. The box is the
  /// dash and the brackets, and the touch may fall a character either
  /// side of them.
  static String? tickAt(String text, int offset) {
    var at = 0;
    for (final line in text.split('\n')) {
      final check = _check.firstMatch(line);
      if (check != null) {
        final from = at + check[1]!.length;
        final to = at + check.end;
        if (offset >= from - 1 && offset <= to) {
          final mark = at + check[1]!.length + check[2]!.length + 1;
          final done = check[3] != ' ';
          return text.replaceRange(mark, mark + 1, done ? ' ' : 'x');
        }
      }
      at += line.length + 1;
    }
    return null;
  }

  /// The link at [offset] in [text], if one is there: the address of a
  /// link or of an address written out, or the day of a day's link
  /// (`yyyy-mm-dd`).
  static ({String? url, String? day})? linkAt(String text, int offset) {
    var at = 0;
    for (final line in text.split('\n')) {
      if (offset >= at && offset <= at + line.length) {
        for (final link in _link.allMatches(line)) {
          if (offset < at + link.start || offset > at + link.end) continue;
          if (link[1] != null) return (url: null, day: link[1]);
          // A day by words of one's own: its folder.
          final folder = _dayAddress.firstMatch(link[3] ?? '');
          if (folder != null) {
            return (url: null, day: '${folder[1]}-${folder[2]}-${folder[3]}');
          }
          return (url: link[3] ?? link[4], day: null);
        }
        return null;
      }
      at += line.length + 1;
    }
    return null;
  }

  /// Where each divider is in [text].
  static List<TextRange> dividers(String text) {
    final found = <TextRange>[];
    var at = 0;
    for (final line in text.split('\n')) {
      if (_divider.hasMatch(line)) {
        found.add(TextRange(start: at, end: at + line.length));
      }
      at += line.length + 1;
    }
    return found;
  }

  /// Whether the line of the caret is a numbered item.
  static bool numberedAt(TextEditingValue value) {
    final (start, end) = _lineAt(value.text, _selectionOf(value).start);
    return _numbered.hasMatch(value.text.substring(start, end));
  }

  /// Numbers every line the selection touches, from 1 or on from a
  /// numbered line just above; or, if they all are numbered already,
  /// plain lines again.
  static TextEditingValue toggleNumbered(TextEditingValue value) {
    final text = value.text;
    final start = _selectionOf(value).start;
    final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
    var first = 1;
    if (lineStart > 0) {
      final above = text.substring(
        text.lastIndexOf('\n', lineStart - 2) + 1,
        lineStart - 1,
      );
      final number = _numbered.firstMatch(above);
      if (number != null) first = int.parse(number[2]!) + 1;
    }
    return _mapLines(value, (lines) {
      final all = lines.every(_numbered.hasMatch);
      return [
        for (final (i, line) in lines.indexed)
          all
              ? line.substring(_numbered.firstMatch(line)!.end)
              : _bare(line.replaceFirst(_numbered, ''), '${first + i}. '),
      ];
    });
  }

  /// Puts a divider at the caret, on a line of its own, the caret on the
  /// line after it.
  static TextEditingValue insertDivider(TextEditingValue value) =>
      _onItsOwnLine(value, '---');

  static final _dayAddress = RegExp(r'^/entries/(\d{4})/(\d{2})/(\d{2})/?$');
  static final _entryAddress = RegExp(
    r'^/entries/(\d{4})/(\d{2})/(\d{2})/([^/]+)/(\d{2})(\d{2})(\d{2})\.md$',
  );

  /// What a link to an entry points at, read from its address: the day,
  /// the category's id and the moment; null for any other address.
  static ({
    int year,
    int month,
    int day,
    String category,
    int hour,
    int minute,
    int second,
  })?
  entryAddress(String address) {
    final m = _entryAddress.firstMatch(address);
    if (m == null) return null;
    int n(int g) => int.parse(m[g]!);
    return (
      year: n(1),
      month: n(2),
      day: n(3),
      category: m[4]!,
      hour: n(5),
      minute: n(6),
      second: n(7),
    );
  }

  /// A link to the entry at [path] (below the entries folder, as
  /// `EntryFile.pathOf` has it), at the caret: on the words selected, as
  /// they were written (owner, 28 October 2026), or with nothing selected
  /// its words [title].
  static TextEditingValue insertEntryLink(
    TextEditingValue value,
    String title,
    String path,
  ) {
    final text = value.text;
    final selection = _selectionOf(value);
    final chosen = text.substring(selection.start, selection.end);
    final words = (chosen.trim().isNotEmpty ? chosen : title)
        .replaceAll(RegExp(r'[\[\]\n]'), ' ')
        .trim();
    final link = '[$words](/entries/$path)';
    return TextEditingValue(
      text: text.replaceRange(selection.start, selection.end, link),
      selection: TextSelection.collapsed(offset: selection.start + link.length),
    );
  }

  /// Puts a link to the day [iso] (`yyyy-mm-dd`) at the caret: on the
  /// words selected, as they were written, by the day's folder; with
  /// nothing selected, as the day itself.
  static TextEditingValue insertDay(TextEditingValue value, String iso) {
    final text = value.text;
    final selection = _selectionOf(value);
    final chosen = text.substring(selection.start, selection.end);
    final link = chosen.trim().isEmpty
        ? '[[$iso]]'
        : '[${chosen.replaceAll(RegExp(r'[\[\]\n]'), ' ')}]'
              '(/entries/${iso.replaceAll('-', '/')})';
    final whole = text.replaceRange(selection.start, selection.end, link);
    return TextEditingValue(
      text: whole,
      selection: TextSelection.collapsed(offset: selection.start + link.length),
    );
  }

  /// Makes the selection the words of a link, the caret where its address
  /// goes; with nothing selected, an empty link, the caret where its
  /// words go.
  static TextEditingValue toggleLink(TextEditingValue value) {
    final text = value.text;
    final selection = _selectionOf(value);
    final words = text.substring(selection.start, selection.end);
    final link = '[$words]()';
    return TextEditingValue(
      text: text.replaceRange(selection.start, selection.end, link),
      selection: TextSelection.collapsed(
        offset: words.isEmpty
            ? selection.start + 1
            : selection.start + link.length - 1,
      ),
    );
  }

  static TextEditingValue _onItsOwnLine(TextEditingValue value, String line) {
    final text = value.text;
    final at = _selectionOf(value).start.clamp(0, text.length);
    final before = text.substring(0, at);
    final after = text.substring(at);
    final lead = before.isEmpty || before.endsWith('\n') ? '' : '\n';
    final tail = after.startsWith('\n') ? '' : '\n';
    final whole = '$before$lead$line$tail$after';
    return TextEditingValue(
      text: whole,
      selection: TextSelection.collapsed(
        offset: before.length + lead.length + line.length + 1,
      ),
    );
  }

  /// Where each checklist box is in [text]: its three characters, the
  /// brackets and what is between them; and whether it is ticked.
  static List<(TextRange, bool)> boxes(String text) {
    final found = <(TextRange, bool)>[];
    var at = 0;
    for (final line in text.split('\n')) {
      final check = _check.firstMatch(line);
      if (check != null) {
        final start = at + check[1]!.length + check[2]!.length;
        found.add((TextRange(start: start, end: start + 3), check[3] != ' '));
      }
      at += line.length + 1;
    }
    return found;
  }

  // The footnote the caret is on: its name, whether the caret is on its
  // mark in the text or on the line that says what it is.
  static String? _noteAt(TextEditingValue value) {
    final text = value.text;
    final selection = _selectionOf(value);
    final (start, end) = _lineAt(text, selection.start);
    final line = text.substring(start, end);
    final said = _note.firstMatch(line);
    if (said != null) return said[1];
    for (final ref in _noteRef.allMatches(line)) {
      // Inside the mark, or just after it; just before it is still the
      // text that leads up to it.
      if (start + ref.start < selection.start &&
          selection.end <= start + ref.end) {
        return ref[1];
      }
    }
    return null;
  }

  /// Whether the caret is on a footnote.
  static bool footnoteAt(TextEditingValue value) => _noteAt(value) != null;

  /// Marks the selection with [format], or takes the mark off if the
  /// selection is already inside one.
  ///
  /// With nothing selected, the word the caret is in the middle of is
  /// marked; at the edge of a word or in open space, an empty pair of
  /// marks is put down with the caret between, ready to type into.
  static TextEditingValue toggle(TextEditingValue value, Format format) {
    final text = value.text;
    var selection = _selectionOf(value);

    // Already marked: take the marks of the innermost run off.
    final marked = _around(value).where((run) => run.formats.contains(format));
    if (marked.isNotEmpty) {
      final run = marked.last;
      // A run that is two things at once keeps the other.
      final left = run.formats.length > 1
          ? (format == Format.bold ? '*' : '**')
          : '';
      final inside = text.substring(run.start + run.open, run.end - run.close);
      final shift = run.open - left.length;
      int moved(int offset) => (offset - shift).clamp(
        run.start + left.length,
        run.start + left.length + inside.length,
      );
      return TextEditingValue(
        text: text.replaceRange(run.start, run.end, '$left$inside$left'),
        selection: TextSelection(
          baseOffset: moved(selection.start),
          extentOffset: moved(selection.end),
        ),
      );
    }
    // An empty pair just put down, the caret still between its halves.
    if (selection.isCollapsed &&
        text.substring(0, selection.start).endsWith(format.open) &&
        text.substring(selection.start).startsWith(format.close) &&
        _holds(text, selection.start, format)) {
      final at = selection.start - format.open.length;
      return TextEditingValue(
        text: text.replaceRange(at, selection.start + format.close.length, ''),
        selection: TextSelection.collapsed(offset: at),
      );
    }

    // The caret in the middle of a word takes the whole word.
    final wasCollapsed = selection.isCollapsed;
    if (wasCollapsed) {
      var start = selection.start;
      var end = selection.start;
      while (start > 0 && _wordy(text[start - 1])) {
        start--;
      }
      while (end < text.length && _wordy(text[end])) {
        end++;
      }
      if (start < selection.start && selection.start < end) {
        selection = TextSelection(baseOffset: start, extentOffset: end);
      }
    }
    final inside = text.substring(selection.start, selection.end);
    final n = format.open.length;
    return TextEditingValue(
      text: text.replaceRange(
        selection.start,
        selection.end,
        '${format.open}$inside${format.close}',
      ),
      selection: wasCollapsed && inside.isNotEmpty
          // The caret stays where it was in the word.
          ? TextSelection.collapsed(offset: value.selection.start + n)
          : TextSelection(
              baseOffset: selection.start + n,
              extentOffset: selection.end + n,
            ),
    );
  }

  static bool _wordy(String char) =>
      RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(char);

  // Whether the stars round [at] really are [format]'s empty pair: four
  // are bold's, two are italic's.
  static bool _holds(String text, int at, Format format) {
    if (format != Format.bold && format != Format.italic) return true;
    var before = 0;
    while (at - before > 0 && text[at - before - 1] == '*') {
      before++;
    }
    var after = 0;
    while (at + after < text.length && text[at + after] == '*') {
      after++;
    }
    final run = before < after ? before : after;
    return format == Format.italic ? run.isOdd : run >= 2;
  }

  /// [toggle], by the mark itself: `**`, `*`, `~~`, `` ` `` or `<u>`.
  static TextEditingValue toggleInline(TextEditingValue value, String sign) =>
      toggle(value, Format.values.firstWhere((f) => f.open == sign));

  /// Puts a footnote at the caret: its mark in the text, and at the foot
  /// of the page a line for what it says, with the caret on it. On a
  /// footnote already, takes it away, mark and line both.
  static TextEditingValue toggleFootnote(TextEditingValue value) {
    final text = value.text;
    final selection = _selectionOf(value);
    final on = _noteAt(value);
    if (on != null) {
      final name = RegExp.escape(on);
      final without = text
          .replaceAll(RegExp('\\n*^\\[\\^$name\\]: ?.*\$', multiLine: true), '')
          .replaceAll(RegExp('\\[\\^$name\\](?!:)'), '');
      return TextEditingValue(
        text: without,
        selection: TextSelection.collapsed(
          offset: selection.start.clamp(0, without.length),
        ),
      );
    }
    // The next number not in use.
    var number = 1;
    while (text.contains('[^$number]')) {
      number++;
    }
    final mark = '[^$number]';
    final marked = text.replaceRange(selection.end, selection.end, mark);
    final gap = marked.isEmpty || marked.endsWith('\n\n')
        ? ''
        : marked.endsWith('\n')
        ? '\n'
        : '\n\n';
    final whole = '$marked$gap$mark: ';
    return TextEditingValue(
      text: whole,
      selection: TextSelection.collapsed(offset: whole.length),
    );
  }

  /// Starts every line the selection touches with [prefix], or takes it
  /// off if they all have it already.
  static TextEditingValue toggleLines(TextEditingValue value, String prefix) =>
      _mapLines(value, (lines) {
        // A checklist item is not a plain list item.
        bool has(String line) =>
            line.startsWith(prefix) && !_check.hasMatch(line);
        final all = lines.every(has);
        return [
          for (final line in lines)
            all ? line.substring(prefix.length) : _bare(line, prefix),
        ];
      });

  // [line] starting with [prefix], in place of any other block mark.
  static String _bare(String line, String prefix) {
    if (line.startsWith(prefix) && !_check.hasMatch(line)) return line;
    final other =
        _check.firstMatch(line) ??
        _numbered.firstMatch(line) ??
        _heading.firstMatch(line) ??
        _bullet.firstMatch(line) ??
        _quote.firstMatch(line);
    return '$prefix${other == null ? line : line.substring(other.end)}';
  }

  /// Steps the lines the selection touches through the headings: none,
  /// `#`, `##`, `###`, and back to none.
  static TextEditingValue cycleHeading(TextEditingValue value) =>
      _mapLines(value, (lines) {
        final level = _heading.firstMatch(lines.first)?[1]!.length ?? 0;
        final next = (level + 1) % 4;
        return [
          for (final line in lines)
            next == 0
                ? line.replaceFirst(_heading, '')
                : _bare(line.replaceFirst(_heading, ''), '${'#' * next} '),
        ];
      });

  static TextEditingValue _mapLines(
    TextEditingValue value,
    List<String> Function(List<String> lines) change,
  ) {
    final text = value.text;
    final selection = _selectionOf(value);
    final from = selection.start == 0
        ? 0
        : text.lastIndexOf('\n', selection.start - 1) + 1;
    final nextBreak = text.indexOf('\n', selection.end);
    final to = nextBreak < 0 ? text.length : nextBreak;

    final before = text.substring(from, to);
    final after = change(before.split('\n')).join('\n');
    final grown = after.length - before.length;
    return TextEditingValue(
      text: text.replaceRange(from, to, after),
      // The caret keeps its place in the words; a selection takes in the
      // whole of the lines changed.
      selection: selection.isCollapsed
          ? TextSelection.collapsed(
              offset: (selection.start + grown).clamp(
                from,
                from + after.length,
              ),
            )
          : TextSelection(baseOffset: from, extentOffset: from + after.length),
    );
  }

  // Parts of a text, for copying.

  /// The word, sentence or paragraph round [offset] in [text], as where it
  /// starts and ends.
  static TextRange wordAt(String text, int offset) {
    var start = offset.clamp(0, text.length);
    var end = start;
    while (start > 0 && !_space(text[start - 1])) {
      start--;
    }
    while (end < text.length && !_space(text[end])) {
      end++;
    }
    return TextRange(start: start, end: end);
  }

  static TextRange paragraphAt(String text, int offset) {
    final (start, end) = _lineAt(text, offset.clamp(0, text.length));
    return TextRange(start: start, end: end);
  }

  static TextRange sentenceAt(String text, int offset) {
    final paragraph = paragraphAt(text, offset);
    final at = offset.clamp(paragraph.start, paragraph.end);
    // A sentence ends at a full stop, question or exclamation mark that
    // is followed by a space or by the end of the paragraph.
    var start = paragraph.start;
    var end = paragraph.end;
    for (final stop in RegExp(
      r'[.!?]+(?=\s|$)',
    ).allMatches(text.substring(paragraph.start, paragraph.end))) {
      final after = paragraph.start + stop.end;
      if (after <= at && after < paragraph.end) {
        start = after;
      } else {
        end = after;
        break;
      }
    }
    while (start < end && _space(text[start])) {
      start++;
    }
    return TextRange(start: start, end: end);
  }

  static bool _space(String char) => char.trim().isEmpty;
}

/// A text controller that shows its text as Markdown (see [Markdown]).
class MarkdownController extends TextEditingController {
  MarkdownController({super.text});

  /// Set by whoever builds the field, before it builds.
  SmColors? colors;

  /// While true the marks are hidden, not just faint.
  bool reading = false;

  /// Whether the checklists' boxes are drawn ([MarkdownDecorations])
  /// rather than written.
  bool decorated = false;

  /// Whether a link to an entry finds it ([Markdown.span]).
  bool Function(String address)? finds;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final colors = this.colors;
    if (colors == null || style == null) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    return Markdown.span(
      text,
      style,
      colors: colors,
      showMarks: !reading,
      decorated: decorated,
      finds: finds,
    );
  }
}

/// Carries a list or a quote on to the next line when Enter is pressed at
/// the end of one, and ends it when Enter is pressed on an empty item.
class MarkdownContinuation extends TextInputFormatter {
  const MarkdownContinuation();

  static final _carried = RegExp(
    r'^(\s*[-*] +\[[ xX]\] |\s*\d{1,4}\. |\s*[-*] +|> ?)',
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final caret = newValue.selection;
    // Only a single line break typed at the caret.
    if (!caret.isCollapsed ||
        !oldValue.selection.isCollapsed ||
        newValue.text.length != oldValue.text.length + 1 ||
        caret.start < 1 ||
        newValue.text[caret.start - 1] != '\n' ||
        oldValue.selection.start != caret.start - 1) {
      return newValue;
    }
    final text = newValue.text;
    final breakAt = caret.start - 1;
    final lineStart = breakAt == 0
        ? 0
        : text.lastIndexOf('\n', breakAt - 1) + 1;
    final line = text.substring(lineStart, breakAt);
    // A checklist item carries on as one not yet done.
    final own = _carried.firstMatch(line)?[0];
    if (own == null) return newValue;
    // A checklist carries on not done; a numbered item as the next number.
    final prefix = own
        .replaceFirst(RegExp(r'\[[xX]\]'), '[ ]')
        .replaceFirstMapped(
          RegExp(r'\d{1,4}'),
          (m) => '${int.parse(m[0]!) + 1}',
        );

    if (line.trim() == own.trim()) {
      // An empty item: Enter ends the list, leaving a plain empty line.
      return TextEditingValue(
        text: text.replaceRange(lineStart, caret.start, ''),
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }
    return TextEditingValue(
      text: text.replaceRange(caret.start, caret.start, prefix),
      selection: TextSelection.collapsed(offset: caret.start + prefix.length),
    );
  }
}
