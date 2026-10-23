import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import '../house.dart';
import '../journal/markdown.dart';
import '../parts.dart';
import '../routes.dart';
import 'menu_screen.dart';

/// The privacy policy, in the app as it is published (owner, 22 October
/// 2026): the copies in `assets/privacy/` are kept the same as
/// `docs/store/<store>/en/privacy-policy.md`, which a test holds them to.
/// The one for the phone the app is on: Android's, or the iPhone's.
abstract final class Policy {
  static const android = 'assets/privacy/android.md';
  static const ios = 'assets/privacy/ios.md';

  /// This phone's policy.
  static String get asset =>
      defaultTargetPlatform == TargetPlatform.iOS ? ios : android;

  static Future<String> load() => rootBundle.loadString(asset);
}

/// One stretch of the policy, as it is laid out.
sealed class PolicyBlock {
  const PolicyBlock();
}

class PolicyTitle extends PolicyBlock {
  final String text;
  const PolicyTitle(this.text);
}

class PolicyHeading extends PolicyBlock {
  final String text;
  const PolicyHeading(this.text);
}

class PolicyParagraph extends PolicyBlock {
  final String text;
  const PolicyParagraph(this.text);
}

/// A list item: `- ` (with no [number]) or `1. `.
class PolicyItem extends PolicyBlock {
  final String text;
  final int? number;
  const PolicyItem(this.text, {this.number});
}

/// A table: its rows of cells, the heading row left out.
class PolicyTable extends PolicyBlock {
  final List<List<String>> rows;
  const PolicyTable(this.rows);
}

/// The policy's Markdown as blocks. Lines wrapped in the file are joined
/// again; a list item's indented lines are its own.
List<PolicyBlock> parsePolicy(String text) {
  final blocks = <PolicyBlock>[];
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  final words = <String>[];
  PolicyBlock Function(String text)? making;
  // Whether the lines being gathered are a list item's.
  var item = false;
  final table = <List<String>>[];

  void flush() {
    if (words.isNotEmpty && making != null) {
      blocks.add(making!(words.join(' ').trim()));
    }
    words.clear();
    making = null;
    item = false;
    if (table.isNotEmpty) {
      // The first row names the columns.
      blocks.add(PolicyTable(table.skip(1).toList()));
      table.clear();
    }
  }

  final numbered = RegExp(r'^(\d+)\. +');
  for (final raw in lines) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) {
      flush();
    } else if (line.startsWith('|')) {
      if (table.isEmpty) flush();
      // The row under the heading row is only dashes.
      if (RegExp(r'^\|[\s:|-]+\|$').hasMatch(line)) continue;
      table.add([
        for (final cell in line.substring(1, line.length - 1).split('|'))
          cell.trim(),
      ]);
    } else if (line.startsWith('# ')) {
      flush();
      blocks.add(PolicyTitle(line.substring(2).trim()));
    } else if (RegExp(r'^#{2,3} ').hasMatch(line)) {
      flush();
      blocks.add(PolicyHeading(line.substring(line.indexOf(' ') + 1).trim()));
    } else if (line.startsWith('- ')) {
      flush();
      making = PolicyItem.new;
      item = true;
      words.add(line.substring(2).trim());
    } else if (numbered.hasMatch(line)) {
      flush();
      final number = int.parse(numbered.firstMatch(line)![1]!);
      making = (text) => PolicyItem(text, number: number);
      item = true;
      words.add(line.replaceFirst(numbered, '').trim());
    } else if (item && line.startsWith(' ')) {
      words.add(line.trim());
    } else {
      // A line at the margin after a list item starts a paragraph.
      if (item) flush();
      making ??= PolicyParagraph.new;
      words.add(line.trim());
    }
  }
  flush();
  return blocks;
}

/// Opens the privacy policy.
Future<void> pushPolicy(BuildContext context) =>
    Navigator.of(context)
        .push(fadeRoute<void>(context, (context) => const PolicyScreen()));

/// The privacy policy, to be read as the essay is: its title at the top,
/// the policy in the body, the house's bar. No lower panel.
class PolicyScreen extends StatefulWidget {
  const PolicyScreen({super.key});

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  late final Future<String> _text = Policy.load();

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
            final blocks = parsePolicy(snapshot.data ?? '');
            final title = blocks.whereType<PolicyTitle>().firstOrNull?.text;
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
                  child: TopBarTitle(label: title ?? ''),
                ),
              ),
              body: SingleChildScrollView(
                key: const ValueKey('policy-body'),
                padding: EdgeInsets.fromLTRB(
                  spacing.md,
                  spacing.sm,
                  spacing.lg,
                  spacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final block in blocks)
                      if (block is! PolicyTitle) _block(theme, block),
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

  // [text] in [style], its Markdown drawn and its links touchable.
  Widget _words(String text, TextStyle style, SmThemeData theme) {
    final colors = theme.colors;
    final link = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    final spans = <InlineSpan>[];
    var at = 0;
    for (final match in link.allMatches(text)) {
      if (match.start > at) {
        spans.add(
          Markdown.span(
            text.substring(at, match.start),
            style,
            colors: colors,
            showMarks: false,
          ),
        );
      }
      final url = match[2]!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: url.startsWith('http') ? () => AppInfo.open(url) : null,
            child: Text(
              match[1]!,
              style: style.copyWith(
                color: colors.accent,
                decoration: TextDecoration.underline,
                decorationColor: colors.accent,
              ),
            ),
          ),
        ),
      );
      at = match.end;
    }
    if (at < text.length) {
      spans.add(
        Markdown.span(
          text.substring(at),
          style,
          colors: colors,
          showMarks: false,
        ),
      );
    }
    return Text.rich(TextSpan(children: spans));
  }

  Widget _block(SmThemeData theme, PolicyBlock block) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    final prose = theme.type.body.copyWith(
      color: colors.textPrimary,
      height: 1.6,
    );
    final small = theme.type.label.copyWith(
      color: colors.textSecondary,
      height: 1.5,
    );

    return switch (block) {
      PolicyTitle() => const SizedBox.shrink(),
      PolicyHeading(:final text) => Padding(
        padding: EdgeInsets.only(top: spacing.md, bottom: spacing.sm),
        child: Text(
          text.toUpperCase(),
          style: theme.type.caption.copyWith(
            color: colors.accent,
            letterSpacing: 1.2,
          ),
        ),
      ),
      PolicyParagraph(:final text) => Padding(
        padding: EdgeInsets.only(bottom: spacing.md),
        child: _words(text, prose, theme),
      ),
      PolicyItem(:final text, :final number) => Padding(
        padding: EdgeInsets.only(bottom: spacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Text(
                number == null ? '–' : '$number.',
                style: small.copyWith(color: colors.accent),
              ),
            ),
            Expanded(child: _words(text, small, theme)),
          ],
        ),
      ),
      PolicyTable(:final rows) => Padding(
        padding: EdgeInsets.only(bottom: spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final row in rows)
              Container(
                padding: EdgeInsets.symmetric(vertical: spacing.sm),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: colors.outline)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _words(
                      row.first,
                      prose.copyWith(fontWeight: FontWeight.w500, height: 1.4),
                      theme,
                    ),
                    for (final cell in row.skip(1)) _words(cell, small, theme),
                  ],
                ),
              ),
          ],
        ),
      ),
    };
  }
}
