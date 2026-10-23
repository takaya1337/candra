import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import '../house.dart';
import '../parts.dart';
import '../routes.dart';
import '../strings.dart';
import '../appearance.dart';

/// Opens the pranata mangsa on [date].
Future<void> pushMangsa(BuildContext context, {required CivilDate date}) =>
    Navigator.of(context)
        .push(fadeRoute<void>(context, (context) => MangsaScreen(date: date)));

/// The colours of the four seasons on the wheel: dry ochre, the green of
/// the first growth, the blue of the rains, and the pale of the harvest.
Map<MangsaSeason, Color> get seasonColors => Legible.map(_seasonColors);

const _seasonColors = <MangsaSeason, Color>{
  MangsaSeason.katiga: Color(0xFFCFA64E),
  MangsaSeason.labuh: Color(0xFF7DB870),
  MangsaSeason.rendheng: Color(0xFF5FA3DC),
  MangsaSeason.mareng: Color(0xFFD9D9D2),
};

/// The pranata mangsa: the Javanese year of the seasons, and where a day
/// stands in it.
///
///  * Top bar: the name of the screen, the year, and the day being read.
///  * Main body: the year as a wheel of its twelve unequal mangsa, the
///    day marked on it; and under it the candra of the mangsa chosen, in
///    Javanese and in words.
///  * Lower panel: what the mangsa chosen is: its dates, its season, what
///    its candra stands for, its signs, the work of the field, and the
///    shadow it opens at.
///  * Bottom bar: back.
class MangsaScreen extends StatefulWidget {
  final CivilDate date;

  const MangsaScreen({super.key, required this.date});

  @override
  State<MangsaScreen> createState() => _MangsaScreenState();
}

class _MangsaScreenState extends State<MangsaScreen> {
  late final PranataMangsa? _day = PranataMangsa.supports(widget.date)
      ? PranataMangsa.of(widget.date)
      : null;

  late Mangsa _chosen = _day?.mangsa ?? Mangsa.kasa;

  void _choose(Mangsa mangsa) {
    if (mangsa == _chosen) return;
    HapticFeedback.selectionClick();
    setState(() => _chosen = mangsa);
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final strings = Strings.of(context);
    final day = _day;

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: FourParts(
          top: TopBar(
            key: const ValueKey('mangsa-top-bar'),
            leading: TopBarTitle(label: strings.mangsaTitle),
            trailing: day == null
                ? null
                : Text(
                    strings.mangsaYear(day.year),
                    style: theme.type.title.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
            subtitle: day == null
                ? strings.gregorian(widget.date)
                : '${day.day} ${day.mangsa.label} · '
                      '${strings.gregorian(widget.date)}',
          ),
          body: day == null
              ? const SizedBox.expand()
              : _body(theme, strings, day),
          panel: day == null
              ? const SizedBox.expand()
              : _panel(theme, strings, day),
          bar: const RoomBar(),
        ),
      ),
    );
  }

  Widget _body(SmThemeData theme, Strings strings, PranataMangsa day) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    final chosen = _chosen;
    final isNow = chosen == day.mangsa;
    final from = PranataMangsa.startOf(day.year, chosen);
    final length = PranataMangsa.lengthOf(day.year, chosen);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: MangsaWheel(
                  key: const ValueKey('mangsa-wheel'),
                  day: day,
                  chosen: chosen,
                  onChoose: _choose,
                ),
              ),
              // The hub of the wheel: the mangsa chosen.
              IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${chosen.number}',
                      style: theme.type.caption.copyWith(
                        color: seasonColors[chosen.season],
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      chosen.label.toUpperCase(),
                      key: const ValueKey('mangsa-name'),
                      style: theme.type.title.copyWith(
                        color: colors.textPrimary,
                        letterSpacing: 3,
                      ),
                    ),
                    Text(
                      chosen.alias,
                      style: theme.type.label.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    SizedBox(height: spacing.sm),
                    Text(
                      isNow
                          ? strings.mangsaDay(day)
                          : strings.mangsaDays(length),
                      key: const ValueKey('mangsa-count'),
                      style: theme.type.label.copyWith(
                        color: isNow ? colors.accent : colors.textFaint,
                      ),
                    ),
                    Text(
                      strings.mangsaRange(from, from.addDays(length - 1)),
                      style: theme.type.caption.copyWith(
                        color: colors.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.sm),
        // The image the mangsa is known by. Two lines are kept for each
        // half, so the wheel above never moves.
        SizedBox(
          height: 76,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                chosen.candra,
                key: const ValueKey('mangsa-candra'),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: theme.type.body.copyWith(
                  color: colors.accent,
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(height: spacing.xs),
              Text(
                strings.candra(chosen),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: theme.type.label.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _panel(SmThemeData theme, Strings strings, PranataMangsa day) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    final chosen = _chosen;
    final caption = theme.type.caption.copyWith(
      color: colors.textFaint,
      letterSpacing: 1.2,
    );
    final value = theme.type.label.copyWith(
      color: colors.textPrimary,
      height: 1.4,
    );

    Widget row(String label, String text) => Padding(
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: caption),
          Text(text, style: value),
        ],
      ),
    );

    return SingleChildScrollView(
      // A new mangsa is read from its top.
      key: ValueKey('mangsa-panel-${chosen.name}'),
      padding: EdgeInsets.fromLTRB(
        spacing.md,
        spacing.sm,
        spacing.md,
        spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(strings.mangsaMeans, strings.candraMeans(chosen)),
          row(
            strings.mangsaSeasonLabel,
            '${chosen.season.label} (${strings.mangsaSeason(chosen.season)}) · '
            '${chosen.phase.label} (${strings.mangsaPhase(chosen.phase)})',
          ),
          row(strings.mangsaSigns, strings.mangsaSignsOf(chosen)),
          row(strings.mangsaWork, strings.mangsaWorkOf(chosen)),
          row(strings.mangsaShadow, strings.mangsaPecak(chosen)),
          // The same shadow by the sun itself, on the day being read.
          if (chosen == day.mangsa)
            row(
              strings.mangsaShadowNow,
              strings.mangsaMeasured(PranataMangsa.noonShadow(widget.date)),
            ),
        ],
      ),
    );
  }
}

/// The year as a wheel: twelve arcs as long as their mangsa, Kasa
/// opening at the top and the year turning clockwise, each in the colour
/// of its season. The day is a dot on the rim; the mangsa chosen is lit.
/// Touching an arc chooses it.
class MangsaWheel extends StatelessWidget {
  final PranataMangsa day;
  final Mangsa chosen;
  final ValueChanged<Mangsa> onChoose;

  const MangsaWheel({
    super.key,
    required this.day,
    required this.chosen,
    required this.onChoose,
  });

  /// The mangsa under a touch at [position] in a wheel of [size], or
  /// null when the touch is in the hub or outside the wheel.
  Mangsa? at(Offset position, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final offset = position - centre;
    final distance = offset.distance;
    if (distance < radius * 0.58 || distance > radius * 1.04) return null;
    var turn = (math.atan2(offset.dy, offset.dx) + math.pi / 2) / (2 * math.pi);
    turn -= turn.floorToDouble();
    final total = _total(day.year);
    var left = turn * total;
    for (final mangsa in Mangsa.values) {
      final length = PranataMangsa.lengthOf(day.year, mangsa);
      if (left < length) return mangsa;
      left -= length;
    }
    return Mangsa.sada;
  }

  static int _total(int year) => Mangsa.values.fold(
    0,
    (sum, mangsa) => sum + PranataMangsa.lengthOf(year, mangsa),
  );

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final mangsa = at(details.localPosition, constraints.biggest);
          if (mangsa != null) onChoose(mangsa);
        },
        child: CustomPaint(
          painter: _WheelPainter(
            day: day,
            chosen: chosen,
            ink: theme.colors.textPrimary,
            faint: theme.colors.textFaint,
            numeral: theme.type.caption,
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final PranataMangsa day;
  final Mangsa chosen;
  final Color ink;
  final Color faint;
  final TextStyle numeral;

  const _WheelPainter({
    required this.day,
    required this.chosen,
    required this.ink,
    required this.faint,
    required this.numeral,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final total = MangsaWheel._total(day.year);
    final perDay = 2 * math.pi / total;
    final rim = radius * 0.86;
    // A hair of room between one mangsa and the next.
    final gap = 3 / rim;

    var start = -math.pi / 2;
    var dayAngle = start;
    for (final mangsa in Mangsa.values) {
      final length = PranataMangsa.lengthOf(day.year, mangsa);
      final sweep = length * perDay;
      final lit = mangsa == chosen;
      final color = seasonColors[mangsa.season]!;
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: rim),
        start + gap / 2,
        sweep - gap,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt
          ..strokeWidth = radius * (lit ? 0.16 : 0.09)
          ..color = color.withValues(alpha: lit ? 1 : 0.42),
      );

      // Its number, inside the rim at the middle of its arc.
      final middle = start + sweep / 2;
      final text = TextPainter(
        text: TextSpan(
          text: '${mangsa.number}',
          style: numeral.copyWith(color: lit ? ink : faint),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final at =
          centre +
          Offset(math.cos(middle), math.sin(middle)) * (radius * 0.68) -
          Offset(text.width / 2, text.height / 2);
      text.paint(canvas, at);

      if (mangsa == day.mangsa) {
        dayAngle = start + (day.day - 0.5) * perDay;
      }
      start += sweep;
    }

    // The day itself, on the outside of the rim.
    canvas.drawCircle(
      centre + Offset(math.cos(dayAngle), math.sin(dayAngle)) * (radius * 0.98),
      radius * 0.022,
      Paint()..color = ink,
    );
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.day != day ||
      old.chosen != chosen ||
      old.ink != ink ||
      old.faint != faint ||
      old.numeral != numeral;
}
