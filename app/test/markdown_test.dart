import 'package:candra/journal/markdown.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_design/sm_design.dart';

void main() {
  const colors = SmThemeData.dusk;
  const base = TextStyle(fontSize: 14);

  // A value with the selection marked by [ and ], or the caret by |.
  TextEditingValue value(String marked) {
    final caret = marked.indexOf('|');
    if (caret >= 0) {
      return TextEditingValue(
        text: marked.replaceFirst('|', ''),
        selection: TextSelection.collapsed(offset: caret),
      );
    }
    final start = marked.indexOf('[');
    final end = marked.indexOf(']') - 1;
    return TextEditingValue(
      text: marked.replaceFirst('[', '').replaceFirst(']', ''),
      selection: TextSelection(baseOffset: start, extentOffset: end),
    );
  }

  String show(TextEditingValue v) {
    final s = v.selection;
    return s.isCollapsed
        ? '${v.text.substring(0, s.start)}|${v.text.substring(s.start)}'
        : '${v.text.substring(0, s.start)}[${v.text.substring(s.start, s.end)}]'
              '${v.text.substring(s.end)}';
  }

  // Every leaf of a span, with its resolved style.
  List<(String, TextStyle)> leaves(InlineSpan span, [TextStyle? inherited]) {
    final out = <(String, TextStyle)>[];
    if (span is! TextSpan) return out;
    final style = (inherited ?? const TextStyle()).merge(span.style);
    if (span.text != null) out.add((span.text!, style));
    for (final child in span.children ?? const <InlineSpan>[]) {
      out.addAll(leaves(child, style));
    }
    return out;
  }

  TextStyle styleOf(String text, String piece, {bool showMarks = true}) =>
      leaves(
        Markdown.span(text, base, colors: colors.colors, showMarks: showMarks),
      ).firstWhere((leaf) => leaf.$1 == piece).$2;

  group('showing', () {
    test('the spans spell out exactly the text, whatever is in it', () {
      for (final text in [
        'plain',
        '**bold** and *italic* and ~~struck~~ and `code`',
        '# Heading\n- item\n> quote\n\nlast',
        'a * b * c and snake_case_name and 2*3*4',
        '**unclosed and `also',
        '',
        '***both***',
      ]) {
        for (final showMarks in [true, false]) {
          final span = Markdown.span(
            text,
            base,
            colors: colors.colors,
            showMarks: showMarks,
          );
          expect(span.toPlainText(), text);
        }
      }
    });

    test('each kind gets its look', () {
      const text = '**bold** *lean* _also_ ~~gone~~ `code`';
      expect(styleOf(text, 'bold').fontWeight, FontWeight.w700);
      expect(styleOf(text, 'lean').fontStyle, FontStyle.italic);
      expect(styleOf(text, 'also').fontStyle, FontStyle.italic);
      expect(styleOf(text, 'gone').decoration, TextDecoration.lineThrough);
      expect(styleOf(text, 'code').backgroundColor, isNotNull);
      // One inside another.
      final both = styleOf('***both***', 'both');
      expect(both.fontWeight, FontWeight.w700);
      expect(both.fontStyle, FontStyle.italic);
      // Marks inside code are only characters.
      expect(styleOf('`**not bold**`', '**not bold**').fontWeight, isNull);
    });

    test('stray marks are left as they are', () {
      const text = 'a * b * c, snake_case_name, 2*3*4';
      expect(
        leaves(
          Markdown.span(text, base, colors: colors.colors, showMarks: true),
        ).every((leaf) => leaf.$2.fontStyle != FontStyle.italic),
        isTrue,
      );
    });

    test('headings, lists and quotes', () {
      const text = '# Big\n### Small\n- item\n> said';
      expect(styleOf(text, 'Big').fontSize, greaterThan(14 * 1.3));
      expect(styleOf(text, 'Small').fontSize, greaterThan(14));
      expect(styleOf(text, 'Big').fontWeight, FontWeight.w700);
      expect(styleOf(text, '- ').color, colors.colors.accent);
      expect(styleOf(text, 'said').fontStyle, FontStyle.italic);
      // A preview keeps headings at the size of everything else.
      final flat = leaves(
        Markdown.span(
          text,
          base,
          colors: colors.colors,
          showMarks: false,
          flat: true,
        ),
      ).firstWhere((leaf) => leaf.$1 == 'Big').$2;
      expect(flat.fontSize, 14);
    });

    test('marks are faint while writing and take no room while reading', () {
      expect(styleOf('**b**', '**').color, colors.colors.textFaint);
      expect(styleOf('**b**', '**').fontSize, 14);
      expect(styleOf('**b**', '**', showMarks: false).fontSize, lessThan(0.1));
      expect(styleOf('# H', '# ', showMarks: false).fontSize, lessThan(0.1));
      // The bullet's dash is the bullet: it stays.
      expect(styleOf('- item', '- ', showMarks: false).fontSize, 14);
    });
  });

  group('the format buttons', () {
    String bold(String marked) =>
        show(Markdown.toggleInline(value(marked), '**'));
    String italic(String marked) =>
        show(Markdown.toggleInline(value(marked), '*'));

    test('wrap the selection, and unwrap it again', () {
      expect(bold('some [words] here'), 'some **[words]** here');
      expect(bold('some **[words]** here'), 'some [words] here');
      expect(bold('some [**words**] here'), 'some [words] here');
      expect(
        show(Markdown.toggleInline(value('a [b] c'), '~~')),
        'a ~~[b]~~ c',
      );
      expect(show(Markdown.toggleInline(value('a [b] c'), '`')), 'a `[b]` c');
    });

    test('with nothing selected put down an empty pair, caret between', () {
      expect(bold('here|'), 'here**|**');
      // Pressed again straight away, it takes the pair back.
      expect(bold('here**|**'), 'here|');
    });

    test('italic and bold share a character without confusing each other', () {
      expect(italic('**[x]**'), '***[x]***');
      expect(italic('***[x]***'), '**[x]**');
      expect(bold('***[x]***'), '*[x]*');
      expect(bold('*[x]*'), '***[x]***');
    });

    test('list and quote mark every line the selection touches', () {
      String list(String marked) =>
          show(Markdown.toggleLines(value(marked), '- '));
      expect(list('one|'), '- one|');
      expect(list('- one|'), 'one|');
      expect(list('a\n[b\nc]\nd'), 'a\n[- b\n- c]\nd');
      expect(list('a\n[- b\nc]\nd'), 'a\n[- b\n- c]\nd');
      expect(list('a\n[- b\n- c]\nd'), 'a\n[b\nc]\nd');
      // One block mark replaces another.
      expect(show(Markdown.toggleLines(value('- item|'), '> ')), '> item|');
      expect(list('# Title|'), '- Title|');
    });

    test('heading steps through the three levels and back to none', () {
      String heading(String marked) =>
          show(Markdown.cycleHeading(value(marked)));
      expect(heading('Title|'), '# Title|');
      expect(heading('# Title|'), '## Title|');
      expect(heading('## Title|'), '### Title|');
      expect(heading('### Title|'), 'Title|');
      expect(heading('before\nTi|tle\nafter'), 'before\n# Ti|tle\nafter');
      expect(heading('- item|'), '# item|');
    });
  });

  group('what the caret is inside', () {
    test('each format, and several at once', () {
      expect(Markdown.formatsAt(value('a **bo|ld** b')), {Format.bold});
      expect(Markdown.formatsAt(value('a *le|an* b')), {Format.italic});
      expect(Markdown.formatsAt(value('a <u>un|der</u> b')), {
        Format.underline,
      });
      expect(Markdown.formatsAt(value('a ~~go|ne~~ b')), {Format.strike});
      expect(Markdown.formatsAt(value('a `co|de` b')), {Format.code});
      expect(Markdown.formatsAt(value('***bo|th***')), {
        Format.bold,
        Format.italic,
      });
      expect(Markdown.formatsAt(value('*a **ne|st** b*')), {
        Format.bold,
        Format.italic,
      });
      expect(Markdown.formatsAt(value('pla|in **bold**')), isEmpty);
      // A selection counts only if all of it is inside.
      expect(Markdown.formatsAt(value('**[bold]**')), {Format.bold});
      expect(Markdown.formatsAt(value('**bo[ld** pl]ain')), isEmpty);
    });

    test('tapping a format the caret is inside takes it off', () {
      String off(String marked, Format format) =>
          show(Markdown.toggle(value(marked), format));
      expect(off('a **bo|ld** b', Format.bold), 'a bo|ld b');
      expect(off('a <u>un|der</u> b', Format.underline), 'a un|der b');
      expect(off('a `co|de` b', Format.code), 'a co|de b');
      // One of two: the other stays.
      expect(off('***bo|th***', Format.bold), '*bo|th*');
      expect(off('***bo|th***', Format.italic), '**bo|th**');
      // The inner of two nested.
      expect(off('*a **ne|st** b*', Format.bold), '*a ne|st b*');
    });

    test('tapping one it is not inside marks the word, or opens a pair', () {
      String on(String marked, Format format) =>
          show(Markdown.toggle(value(marked), format));
      expect(on('a wo|rd b', Format.bold), 'a **wo|rd** b');
      expect(on('a word| b', Format.bold), 'a word**|** b');
      expect(on('a [word] b', Format.underline), 'a <u>[word]</u> b');
    });

    test('headings, lists and footnotes', () {
      expect(Markdown.headingAt(value('## Ti|tle')), 2);
      expect(Markdown.headingAt(value('Ti|tle')), 0);
      expect(Markdown.headingAt(value('# One\ntw|o')), 0);
      expect(Markdown.listAt(value('- it|em')), isTrue);
      expect(Markdown.listAt(value('it|em')), isFalse);
      expect(Markdown.footnoteAt(value('smoke[^|1] rose')), isTrue);
      expect(Markdown.footnoteAt(value('smo|ke[^1] rose')), isFalse);
      expect(Markdown.footnoteAt(value('text[^1]\n\n[^1]: wh|y')), isTrue);
    });
  });

  group('footnotes', () {
    test('are numbered as they are added, and go mark and line together', () {
      var v = Markdown.toggleFootnote(value('First|'));
      expect(v.text, 'First[^1]\n\n[^1]: ');
      v = Markdown.toggleFootnote(
        TextEditingValue(
          text: '${v.text}why',
          selection: const TextSelection.collapsed(offset: 5),
        ),
      );
      expect(v.text, 'First[^2][^1]\n\n[^1]: why\n\n[^2]: ');

      // Taking the first away leaves the second whole.
      final without = Markdown.toggleFootnote(
        TextEditingValue(
          text: v.text,
          selection: TextSelection.collapsed(
            offset: v.text.indexOf('[^1]') + 2,
          ),
        ),
      );
      expect(without.text, 'First[^2]\n\n[^2]: ');
    });

    test('are shown small, in the accent colour', () {
      const text = 'smoke[^1]\n\n[^1]: from the second stick';
      expect(styleOf(text, '[^1]').color, colors.colors.accent);
      expect(styleOf(text, '[^1]').fontSize, lessThan(14));
      expect(styleOf(text, 'from the second stick').fontSize, lessThan(14));
      // And the text is still exactly what was written.
      expect(
        Markdown.span(
          text,
          base,
          colors: colors.colors,
          showMarks: false,
        ).toPlainText(),
        text,
      );
    });
  });

  group('parts of a text', () {
    const text =
        'Three flowers, incense. The air was still! Was it?\n'
        'A second paragraph here.';
    String part(TextRange range) => range.textInside(text);

    test('the word, the sentence and the paragraph round a place', () {
      final at = text.indexOf('air');
      expect(part(Markdown.wordAt(text, at)), 'air');
      expect(part(Markdown.sentenceAt(text, at)), 'The air was still!');
      expect(
        part(Markdown.paragraphAt(text, at)),
        'Three flowers, incense. The air was still! Was it?',
      );
      expect(part(Markdown.sentenceAt(text, 2)), 'Three flowers, incense.');
      expect(
        part(Markdown.sentenceAt(text, text.indexOf('Was it'))),
        'Was it?',
      );
      final second = text.indexOf('second');
      expect(
        part(Markdown.sentenceAt(text, second)),
        'A second paragraph here.',
      );
      expect(
        part(Markdown.paragraphAt(text, second)),
        'A second paragraph here.',
      );
      // A word keeps its punctuation out only where there is a space.
      expect(part(Markdown.wordAt(text, text.indexOf('incense'))), 'incense.');
    });
  });

  group('Enter', () {
    String enter(String before) {
      final old = value(before);
      final at = old.selection.start;
      return show(
        const MarkdownContinuation().formatEditUpdate(
          old,
          TextEditingValue(
            text: old.text.replaceRange(at, at, '\n'),
            selection: TextSelection.collapsed(offset: at + 1),
          ),
        ),
      );
    }

    test('carries a list or a quote on to the next line', () {
      expect(enter('- one|'), '- one\n- |');
      expect(enter('> said|'), '> said\n> |');
      expect(enter('intro\n  - nested|'), 'intro\n  - nested\n  - |');
    });

    test('on an empty item ends the list', () {
      expect(enter('- one\n- |'), '- one\n|');
    });

    test('does nothing special anywhere else', () {
      expect(enter('plain|'), 'plain\n|');
      expect(enter('# Title|'), '# Title\n|');
    });
  });
}
