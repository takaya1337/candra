import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

/// The ways a run of words within a line can be marked.
enum Format {
  bold('**', '**'),
  italic('*', '*'),
  underline('<u>', '</u>'),
  strike('~~', '~~'),
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
///     > quote
///     [^1]: what the footnote says
///
/// The text itself is never changed for display. The marks stay in it,
/// drawn faintly while writing and shrunk to nothing while reading, so
/// what is selected and copied is always the Markdown as written.
abstract final class Markdown {
  static final _heading = RegExp(r'^(#{1,3}) +');
  static final _bullet = RegExp(r'^(\s*)([-*]) +');
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
    r'|(?<![*\w])(\*)(?![\s*])(.+?)(?<![\s*])\*(?!\*)'
    r'|(?<!\w)(_)(?![\s_])(.+?)(?<![\s_])_(?!\w)'
    r'|(\[\^[^\]\s]+\])()(?!:)',
  );
  static const _groups = [1, 3, 5, 7, 9, 11, 13, 15];

  // What each opening mark means, and what closes it.
  static (Set<Format>, String) _meaning(String sign) => switch (sign) {
    '`' => ({Format.code}, '`'),
    '***' => ({Format.bold, Format.italic}, '***'),
    '**' => ({Format.bold}, '**'),
    '~~' => ({Format.strike}, '~~'),
    '<u>' => ({Format.underline}, '</u>'),
    _ => ({Format.italic}, sign),
  };

  /// [text] as styled spans. The spans' text, joined, is exactly [text].
  ///
  /// With [showMarks] the Markdown marks are drawn faintly; without, they
  /// take up no room. [flat] keeps headings at the size of the rest, for
  /// previews.
  static TextSpan span(
    String text,
    TextStyle base, {
    required SmColors colors,
    required bool showMarks,
    bool flat = false,
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

      final heading = _heading.firstMatch(line);
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

  static List<InlineSpan> _inlineSpans(
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

  /// Whether the line of the caret is a list item.
  static bool listAt(TextEditingValue value) {
    final (start, end) = _lineAt(value.text, _selectionOf(value).start);
    return _bullet.hasMatch(value.text.substring(start, end));
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
        final all = lines.every((line) => line.startsWith(prefix));
        return [
          for (final line in lines)
            all ? line.substring(prefix.length) : _bare(line, prefix),
        ];
      });

  // [line] starting with [prefix], in place of any other block mark.
  static String _bare(String line, String prefix) {
    if (line.startsWith(prefix)) return line;
    final other =
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
    return Markdown.span(text, style, colors: colors, showMarks: !reading);
  }
}

/// Carries a list or a quote on to the next line when Enter is pressed at
/// the end of one, and ends it when Enter is pressed on an empty item.
class MarkdownContinuation extends TextInputFormatter {
  const MarkdownContinuation();

  static final _carried = RegExp(r'^(\s*[-*] +|> ?)');

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
    final prefix = _carried.firstMatch(line)?[0];
    if (prefix == null) return newValue;

    if (line.length == prefix.length) {
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
