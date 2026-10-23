import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import '../strings.dart';
import 'bazi_places.dart';
import 'bazi_record.dart';
import 'bazi_screen.dart';
import 'bazi_tables.dart';

/// A journal entry's bazi chart, drawn from what it was written from
/// (`Entry.bazi`) and never from text: what it was read from, the four
/// pillars, and the tables it follows. Touching it opens the chart in the
/// bazi page, to look at or correct ([onOpen]).
class BaziCard extends StatefulWidget {
  final String value;
  final Color hue;
  final VoidCallback? onOpen;

  /// For tests: the tables, and no loading.
  final BaziLibrary? library;

  const BaziCard({
    super.key,
    required this.value,
    required this.hue,
    this.onOpen,
    this.library,
  });

  @override
  State<BaziCard> createState() => _BaziCardState();
}

class _BaziCardState extends State<BaziCard> {
  late BaziLibrary? _library = widget.library;

  @override
  void initState() {
    super.initState();
    if (_library == null) {
      BaziLibrary.load().then((library) {
        if (mounted) setState(() => _library = library);
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
    final record = BaziRecord.parse(widget.value);
    final library = _library;

    final hidden = record == null
        ? -1
        : BaziLibrary.hiddenStemFiles.indexOf(record.hidden);
    final relations = record == null
        ? -1
        : BaziLibrary.relationFiles.indexOf(record.relations);
    final whole = record != null && hidden >= 0 && relations >= 0;

    Widget body;
    if (!whole) {
      body = Text(
        strings.baziCardIncomplete,
        style: theme.type.label.copyWith(color: colors.textFaint),
      );
    } else if (library == null) {
      body = const SizedBox(height: 120);
    } else {
      final tables = library.tables(hidden, relations);
      final chart = BaziChart.at(
        DateTime.utc(
          record.date.year,
          record.date.month,
          record.date.day,
          record.minute ~/ 60,
          record.minute % 60,
        ).subtract(record.offset),
        utcOffset: record.offset,
        longitude: record.longitude,
        config: record.config,
      );
      final commanding = tables.commanding(
        chart.month.branch,
        chart.instant.difference(chart.termBefore),
      );
      final from = [
        '${strings.gregorian(record.date)} · '
            '${_two(record.minute ~/ 60)}:${_two(record.minute % 60)}',
        'UTC${BaziPlaces.label(record.offset)}',
        if (record.zone case final zone?) BaziPlaces.cityOf(zone),
        record.male == null
            ? strings.baziNoSex
            : record.male!
            ? strings.baziMale
            : strings.baziFemale,
      ].join(' · ');
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            from,
            key: const ValueKey('bazi-card-from'),
            style: theme.type.label.copyWith(color: colors.textSecondary),
          ),
          SizedBox(height: spacing.sm),
          BaziPillars(
            chart: chart,
            tables: tables,
            strings: strings,
            commanding: commanding,
          ),
          SizedBox(height: spacing.sm),
          Text(
            strings.baziCardTables(tables.hidden, tables.relations),
            style: theme.type.caption.copyWith(
              color: colors.textFaint,
              height: 1.4,
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      key: const ValueKey('entry-bazi-card'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onOpen == null || !whole
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
                    strings.baziTitle.toUpperCase(),
                    style: theme.type.caption.copyWith(
                      color: colors.textFaint,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Text(
                  whole && widget.onOpen != null ? strings.baziCardOpen : '',
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
