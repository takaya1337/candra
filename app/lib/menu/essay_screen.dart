import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import '../house.dart';
import '../journal/markdown.dart';
import '../parts.dart';
import '../routes.dart';
import '../strings.dart';

/// The owner's essay on why the app is free, as written: the copy in
/// `assets/stance/`, kept the same as `docs/provenance/` (a test holds the
/// two together). One file a language, `why-this-app-is-free.<code>.md`;
/// a language without its own file reads the English.
abstract final class Stance {
  static String asset(AppLanguage language) =>
      'assets/stance/why-this-app-is-free.${language.code.toLowerCase()}.md';

  static const english = 'assets/stance/why-this-app-is-free.en.md';

  /// The essay in [language], or in English where it has none.
  static Future<String> load(AppLanguage language) async {
    try {
      return await rootBundle.loadString(asset(language));
    } on FlutterError {
      return rootBundle.loadString(english);
    }
  }

  /// The essay's own title: its first `# ` line.
  static String titleOf(String text) {
    for (final line in text.split('\n')) {
      if (line.startsWith('# ')) return line.substring(2).trim();
    }
    return '';
  }
}

/// One stretch of the essay, as it is laid out.
sealed class EssayBlock {
  const EssayBlock();
}

/// The quotation at the head, and who said it.
class Epigraph extends EssayBlock {
  final String words;
  final String source;
  const Epigraph(this.words, this.source);
}

class Rule extends EssayBlock {
  const Rule();
}

class Heading extends EssayBlock {
  final String text;

  /// `##` for the parts of the essay, `###` for the sources.
  final int level;
  const Heading(this.text, this.level);
}

class Paragraph extends EssayBlock {
  final String text;
  const Paragraph(this.text);
}

class Bullet extends EssayBlock {
  final String text;
  const Bullet(this.text);
}

/// A paragraph that is nothing but bold, `**Author, 2026**`: the essay
/// signed, standing to the right, apart from what it closes.
class Signature extends EssayBlock {
  final String text;
  const Signature(this.text);
}

/// The essay's Markdown as blocks. The title (`# `) is left out: it is the
/// screen's title.
List<EssayBlock> parseEssay(String text) {
  final blocks = <EssayBlock>[];
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  final paragraph = <String>[];
  final quote = <String>[];

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    final joined = paragraph.join(' ').trim();
    paragraph.clear();
    final signed = RegExp(r'^\*\*\s*(.+?)\s*\*\*$').firstMatch(joined);
    blocks.add(signed != null ? Signature(signed[1]!) : Paragraph(joined));
  }

  void flushQuote() {
    if (quote.isEmpty) return;
    // A blank `>` line parts the words from who said them.
    final gap = quote.indexWhere((line) => line.trim().isEmpty);
    final words = (gap < 0 ? quote : quote.sublist(0, gap)).join(' ').trim();
    final source = gap < 0 ? '' : quote.sublist(gap + 1).join(' ').trim();
    blocks.add(Epigraph(words, source));
    quote.clear();
  }

  for (final raw in lines) {
    final line = raw.trimRight();
    if (line.startsWith('>')) {
      flushParagraph();
      quote.add(line.replaceFirst(RegExp(r'^> ?'), ''));
      continue;
    }
    flushQuote();
    if (line.trim().isEmpty) {
      flushParagraph();
    } else if (line.trim() == '---') {
      flushParagraph();
      blocks.add(const Rule());
    } else if (line.startsWith('# ')) {
      flushParagraph();
    } else if (RegExp(r'^#{2,3} ').hasMatch(line)) {
      flushParagraph();
      final level = line.indexOf(' ');
      blocks.add(Heading(line.substring(level + 1).trim(), level));
    } else if (line.startsWith('- ')) {
      flushParagraph();
      blocks.add(Bullet(line.substring(2).trim()));
    } else {
      paragraph.add(line.trim());
    }
  }
  flushQuote();
  flushParagraph();
  return blocks;
}

/// Opens the essay.
Future<void> pushEssay(BuildContext context) =>
    Navigator.of(context)
        .push(fadeRoute<void>(context, (context) => const EssayScreen()));

/// The essay, to be read: the title in the top bar, the essay in the body,
/// and the way back in the bar. No lower panel: nothing stands between the
/// reader and it, as when an entry is read.
class EssayScreen extends StatefulWidget {
  const EssayScreen({super.key});

  @override
  State<EssayScreen> createState() => _EssayScreenState();
}

class _EssayScreenState extends State<EssayScreen> {
  Future<String>? _text;
  AppLanguage? _language;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Strings.of(context).language;
    if (language != _language) {
      _language = language;
      _text = Stance.load(language);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: FutureBuilder<String>(
          future: _text,
          builder: (context, snapshot) {
            final text = snapshot.data ?? '';
            return FourParts.fitted(
              top: Padding(
                padding: EdgeInsets.fromLTRB(
                  spacing.md,
                  spacing.md,
                  spacing.md,
                  spacing.sm,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TopBarTitle(label: Stance.titleOf(text)),
                ),
              ),
              body: SingleChildScrollView(
                key: const ValueKey('essay-body'),
                padding: EdgeInsets.fromLTRB(
                  spacing.md,
                  spacing.sm,
                  spacing.md,
                  spacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final block in parseEssay(text)) _block(theme, block),
                  ],
                ),
              ),
              bar: const RoomBar(),
            );
          },
        ),
      ),
    );
  }

  Widget _block(SmThemeData theme, EssayBlock block) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    final prose = theme.type.body.copyWith(
      color: colors.textPrimary,
      height: 1.6,
    );
    Widget styled(String text, TextStyle style, {TextAlign? align}) =>
        Text.rich(
          Markdown.span(text, style, colors: colors, showMarks: false),
          textAlign: align,
        );

    return switch (block) {
      Epigraph(:final words, :final source) => Padding(
        key: const ValueKey('essay-epigraph'),
        padding: EdgeInsets.only(top: spacing.md, bottom: spacing.md),
        child: Container(
          padding: EdgeInsets.only(left: spacing.md),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: colors.accent.withValues(alpha: 0.6),
                width: 2,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              styled(
                words,
                prose.copyWith(
                  fontStyle: FontStyle.italic,
                  color: colors.textSecondary,
                ),
              ),
              if (source.isNotEmpty) ...[
                SizedBox(height: spacing.sm),
                styled(
                  source,
                  theme.type.label.copyWith(color: colors.textFaint),
                  align: TextAlign.right,
                ),
              ],
            ],
          ),
        ),
      ),
      Rule() => Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.lg),
        child: Center(
          child: Container(width: 48, height: 1, color: colors.outline),
        ),
      ),
      Heading(:final text, level: 2) => Padding(
        padding: EdgeInsets.only(bottom: spacing.md),
        child: Text(
          text,
          style: theme.type.title.copyWith(
            fontSize: 17,
            color: colors.textPrimary,
          ),
        ),
      ),
      Heading(:final text) => Padding(
        key: const ValueKey('essay-sources'),
        padding: EdgeInsets.only(top: spacing.lg, bottom: spacing.sm),
        child: Text(
          text.toUpperCase(),
          style: theme.type.caption.copyWith(
            color: colors.accent,
            letterSpacing: 1.2,
          ),
        ),
      ),
      Paragraph(:final text) => Padding(
        padding: EdgeInsets.only(bottom: spacing.md),
        child: styled(text, prose),
      ),
      Bullet(:final text) => Padding(
        padding: EdgeInsets.only(bottom: spacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '–  ',
              style: theme.type.label.copyWith(
                color: colors.accent,
                height: 1.5,
              ),
            ),
            Expanded(
              child: styled(
                text,
                theme.type.label.copyWith(
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
      // Set well apart from the last paragraph, and to the right, as a
      // letter is signed.
      Signature(:final text) => Padding(
        key: const ValueKey('essay-signature'),
        padding: EdgeInsets.only(top: spacing.xl, bottom: spacing.lg),
        child: Text(
          text,
          textAlign: TextAlign.right,
          style: prose.copyWith(
            fontStyle: FontStyle.italic,
            color: colors.textPrimary,
          ),
        ),
      ),
    };
  }
}
