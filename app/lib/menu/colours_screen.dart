import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import '../app_shell.dart';
import '../appearance.dart';
import '../bazi/two_wheels.dart';
import '../bar_button.dart';
import '../calendar_system.dart';
import '../colour_schemes.dart';
import '../confirm_bar.dart';
import '../day_page.dart';
import '../house.dart';
import '../parts.dart';
import '../routes.dart';
import '../strings.dart';

/// Opens the colours of the calendar systems.
Future<void> pushColours(BuildContext context) =>
    Navigator.of(context)
        .push(fadeRoute<void>(context, (context) => const ColoursScreen()));

/// Which colour scheme each calendar system is shown in.
///
///  * Top bar: the name, and the system and its scheme.
///  * Main body: today's day view in that system, as a sample.
///  * Lower panel: two wheels (owner, 25 October 2026, after a row of
///    pills): at the left the calendar being coloured, at the right the
///    schemes, standing at its own; the scheme turned to is its colours
///    at once (two systems may share one). The whole screen, bars and
///    all, is in the scheme of the system shown, to see it as it would
///    be.
///  * Bottom bar: back; at the right, every system back to its own
///    colours, once asked.
class ColoursScreen extends StatefulWidget {
  const ColoursScreen({super.key});

  @override
  State<ColoursScreen> createState() => _ColoursScreenState();
}

class _ColoursScreenState extends State<ColoursScreen> {
  CalendarSystem? _system;

  // The bar asking whether to put every system back to its own colours.
  bool _confirming = false;

  // Counts the restores, so the wheels stand afresh where the defaults
  // put them.
  int _restored = 0;

  void _setConfirming(bool confirming) {
    HapticFeedback.selectionClick();
    setState(() => _confirming = confirming);
  }

  void _restore() {
    HapticFeedback.mediumImpact();
    ColourChoice.restore();
    setState(() {
      _confirming = false;
      _restored++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final system = _system ??= SystemScope.of(context).value;
    final base = SmTheme.of(context);
    final side = Legible.light ? Brightness.light : Brightness.dark;
    return PopScope(
      // Back, while asking, is no.
      canPop: !_confirming,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setConfirming(false);
      },
      child: ValueListenableBuilder(
        valueListenable: ColourChoice.chosen,
        builder: (context, _, _) {
          final scheme = ColourChoice.of(system);
          return SmTheme(
            data: base.withColors(scheme.on(side)),
            child: Builder(
              builder: (context) => _screen(context, system, scheme, side),
            ),
          );
        },
      ),
    );
  }

  Widget _screen(
    BuildContext context,
    CalendarSystem system,
    ColourScheme scheme,
    Brightness side,
  ) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final strings = Strings.of(context);
    final now = DateTime.now();
    final today = CivilDate(now.year, now.month, now.day);

    Widget heading(String text) => Padding(
      padding: EdgeInsets.fromLTRB(spacing.md, spacing.sm, spacing.md, 0),
      child: Text(
        text.toUpperCase(),
        style: theme.type.caption.copyWith(
          color: colors.textFaint,
          letterSpacing: 1.2,
        ),
      ),
    );

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: FourParts(
          top: TopBar(
            key: const ValueKey('colours-top-bar'),
            leading: TopBarTitle(label: strings.coloursTitle),
            subtitle:
                '${strings.systemLabel(system)} · '
                '${strings.colourSchemeName(scheme)}',
            // Every system back to its first colours: at the top right,
            // where the pages keep what undoes everything. It asks first.
            trailing: BarButton(
              key: const ValueKey('colours-restore'),
              label: strings.coloursRestore,
              compact: true,
              onTap: () => _setConfirming(!_confirming),
            ),
          ),
          // As wide as the calendar's own day view.
          body: Padding(
            padding: EdgeInsets.only(bottom: spacing.md),
            child: IgnorePointer(
              child: DayPage(
                key: const ValueKey('colours-sample'),
                date: today,
                today: today,
                system: system,
                utcOffset: now.timeZoneOffset,
                strings: strings,
              ),
            ),
          ),
          panel: _confirming
              ? Padding(
                  key: const ValueKey('colours-restore-ask'),
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        strings.coloursRestoreAsk,
                        style: theme.type.label.copyWith(
                          color: colors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: spacing.md),
                      // Answered where it is asked.
                      ConfirmBar(
                        label: strings.coloursRestore,
                        onConfirm: _restore,
                        onCancel: () => _setConfirming(false),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.md,
                    0,
                    spacing.md,
                    spacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: heading(strings.coloursCalendar),
                          ),
                          Expanded(
                            flex: 5,
                            child: heading(strings.coloursScheme),
                          ),
                        ],
                      ),
                      SizedBox(height: spacing.xs),
                      Expanded(
                        child: TwoWheels(
                          key: ValueKey('colours-wheels-$_restored'),
                          name: 'colours',
                          headings: [
                            for (final each in CalendarSystem.values)
                              strings.systemLabel(each),
                          ],
                          under: (_) => [
                            for (final each in ColourScheme.values)
                              strings.colourSchemeName(each),
                          ],
                          heading: CalendarSystem.values.indexOf(system),
                          chosen: (each) =>
                              ColourChoice.of(CalendarSystem.values[each])
                                  .index,
                          onChanged: (each, choice) {
                            final calendar = CalendarSystem.values[each];
                            final chosen = ColourScheme.values[choice];
                            if (calendar != _system) {
                              setState(() => _system = calendar);
                            }
                            if (ColourChoice.of(calendar) != chosen) {
                              ColourChoice.choose(calendar, chosen);
                            }
                          },
                          secondLead: (_, choice) => _Swatch(
                            scheme: ColourScheme.values[choice],
                            side: side,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          bar: const RoomBar(),
        ),
      ),
    );
  }
}

/// A scheme's colours, small: its accent on its own ground.
class _Swatch extends StatelessWidget {
  final ColourScheme scheme;
  final Brightness side;

  const _Swatch({required this.scheme, required this.side});

  @override
  Widget build(BuildContext context) {
    final own = scheme.on(side);
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: own.accent,
        border: Border.all(color: own.background, width: 3),
      ),
    );
  }
}
