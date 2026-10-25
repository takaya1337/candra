import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import '../strings.dart';
import 'iching_art.dart';
import 'iching_pack.dart';
import 'iching_record.dart';

/// A journal entry's cast of the Yijing, drawn from its lines
/// (`Entry.iching`) and never from text: how and when it was cast, the
/// hexagram with its changing lines marked, and the one it becomes.
/// Touching it opens the cast in the casting page, standing whole
/// ([onOpen]).
class IchingCard extends StatefulWidget {
  final String value;
  final Color hue;
  final VoidCallback? onOpen;

  const IchingCard({
    super.key,
    required this.value,
    required this.hue,
    this.onOpen,
  });

  @override
  State<IchingCard> createState() => _IchingCardState();
}

class _IchingCardState extends State<IchingCard> {
  IchingPack? _pack = IchingPack.ready;

  @override
  void initState() {
    super.initState();
    if (_pack == null) {
      IchingPack.load().then((pack) {
        if (mounted) setState(() => _pack = pack);
      });
    }
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final strings = Strings.of(context);
    final record = IchingRecord.parse(widget.value);
    final pack = _pack;

    Widget body;
    if (record == null) {
      body = Text(
        strings.ichingCardIncomplete,
        style: theme.type.label.copyWith(color: colors.textFaint),
      );
    } else {
      final cast = record.cast;
      Widget named(Hexagram? hexagram) => hexagram == null
          ? const SizedBox(height: 40)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${hexagram.number} ${hexagram.name}',
                  style: theme.type.title.copyWith(color: colors.textPrimary),
                ),
                Text(
                  hexagram.readIn(strings.language)?.reading.name ??
                      hexagram.spoken,
                  style: theme.type.label.copyWith(color: colors.accent),
                ),
              ],
            );
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${strings.ichingMethod(record.method)} · '
            '${strings.gregorian(record.date)} · '
            '${_two(record.minute ~/ 60)}:${_two(record.minute % 60)}',
            key: const ValueKey('iching-card-from'),
            style: theme.type.label.copyWith(color: colors.textSecondary),
          ),
          SizedBox(height: spacing.sm),
          Row(
            children: [
              HexagramFigure(
                lines: cast.lines,
                width: 44,
                color: colors.textPrimary,
                faint: colors.outline,
                mark: colors.accent,
              ),
              SizedBox(width: spacing.md),
              Expanded(child: named(pack?.of(cast.primary))),
              if (cast.changing.isNotEmpty) ...[
                Text(
                  '→',
                  style: theme.type.title.copyWith(color: colors.textFaint),
                ),
                SizedBox(width: spacing.md),
                Expanded(child: named(pack?.of(cast.relating))),
              ],
            ],
          ),
        ],
      );
    }

    return GestureDetector(
      key: const ValueKey('entry-iching-card'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onOpen == null || record == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onOpen!();
            },
      child: Container(
        padding: EdgeInsets.all(spacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: widget.hue.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(theme.radii.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.ichingTitle.toUpperCase(),
                    style: theme.type.caption.copyWith(
                      color: colors.textFaint,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Text(
                  record != null && widget.onOpen != null
                      ? strings.ichingCardOpen
                      : '',
                  style: theme.type.caption.copyWith(color: colors.accent),
                ),
              ],
            ),
            SizedBox(height: spacing.sm),
            body,
          ],
        ),
      ),
    );
  }
}
