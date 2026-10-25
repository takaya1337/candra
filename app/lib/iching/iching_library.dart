import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import '../bar_button.dart';
import '../house.dart';
import '../panel_tabs.dart';
import '../parts.dart';
import '../strings.dart';
import '../wheel_row.dart';
import 'iching_art.dart';
import 'iching_pack.dart';
import 'iching_reading_screen.dart';

/// How a hexagram is chosen in the library.
enum LibraryTab { number, trigrams }

/// The book: the sixty-four, to read without casting.
///
///  * Top bar: its name, and the hexagram chosen.
///  * Main body: all sixty-four, a row each (figure, number, name, its
///    sound, our name), the one chosen lit. A touch on a row opens it.
///  * Lower panel: two ways of choosing, as tabs: by number, on one wheel,
///    or by the two trigrams it is made of, on two. Turning either brings
///    the chosen row into sight; the button beside opens it.
///  * Bottom bar: the house's. Back is the swipe.
///
/// A hexagram opened is read on its own card; coming back, it is the one
/// chosen.
class IchingLibrary extends StatefulWidget {
  /// The text pack; loaded from the app's assets when not given.
  final IchingPack? pack;

  const IchingLibrary({super.key, this.pack});

  @override
  State<IchingLibrary> createState() => _IchingLibraryState();
}

class _IchingLibraryState extends State<IchingLibrary> {
  static const _rowHeight = 56.0;

  late IchingPack? _pack = widget.pack ?? IchingPack.ready;
  final _rows = ScrollController();

  // The hexagram chosen, by its number.
  int _chosen = 1;
  LibraryTab _tab = LibraryTab.number;

  // Counts the times the choice was made from outside the wheels (a row
  // touched), so they are made again where it now is.
  int _placed = 0;

  @override
  void initState() {
    super.initState();
    if (_pack == null) {
      IchingPack.load().then((pack) {
        if (mounted) setState(() => _pack = pack);
      });
    }
  }

  @override
  void dispose() {
    _rows.dispose();
    super.dispose();
  }

  // Chooses [number] from the wheels: the row lit and brought to the
  // middle of the body.
  void _choose(int number) {
    if (number == _chosen) return;
    HapticFeedback.selectionClick();
    setState(() => _chosen = number);
    if (!_rows.hasClients) return;
    final position = _rows.position;
    final target =
        ((number - 1) * _rowHeight -
                (position.viewportDimension - _rowHeight) / 2)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
    final motion = SmTheme.of(context).motion;
    _rows.animateTo(target, duration: motion.medium, curve: motion.curve);
  }

  void _open(int number) {
    HapticFeedback.selectionClick();
    setState(() {
      if (number != _chosen) _placed++;
      _chosen = number;
    });
    pushIchingReading(context, number: number, pack: _pack);
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final strings = Strings.of(context);
    final pack = _pack;
    final chosen = pack?.hexagrams[_chosen - 1];
    final english = chosen?.readIn(strings.language)?.reading.name;

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: FourParts(
          top: TopBar(
            key: const ValueKey('iching-library-top-bar'),
            leading: TopBarTitle(label: strings.ichingLibrary),
            subtitle: chosen == null
                ? ''
                : '${chosen.number} · ${chosen.name} ${chosen.spoken}'
                      '${english == null ? '' : ' · $english'}',
          ),
          body: pack == null
              ? const SizedBox.expand()
              : ListView.builder(
                  key: const ValueKey('iching-library-rows'),
                  controller: _rows,
                  itemExtent: _rowHeight,
                  itemCount: pack.hexagrams.length,
                  itemBuilder: (context, i) =>
                      _row(theme, strings, pack.hexagrams[i]),
                ),
          panel: pack == null || chosen == null
              ? const SizedBox.expand()
              : _panel(theme, strings, pack, chosen),
          bar: const RoomBar(),
        ),
      ),
    );
  }

  Widget _row(SmThemeData theme, Strings strings, Hexagram hexagram) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    final lit = hexagram.number == _chosen;
    final english = hexagram.readIn(strings.language)?.reading.name;
    return GestureDetector(
      key: ValueKey('iching-row-${hexagram.number}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(hexagram.number),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.xs / 2),
        child: AnimatedContainer(
          duration: theme.motion.medium,
          curve: theme.motion.curve,
          padding: EdgeInsets.symmetric(horizontal: spacing.sm),
          decoration: BoxDecoration(
            color: lit
                ? colors.surfaceRaised
                : colors.surfaceRaised.withValues(alpha: 0),
            border: Border.all(
              color: lit ? colors.accent : colors.outline.withValues(alpha: 0),
            ),
            borderRadius: BorderRadius.circular(theme.radii.md),
          ),
          child: Row(
            children: [
              HexagramFigure.still(
                figure: hexagram.figure,
                width: 30,
                color: lit ? colors.accent : colors.textSecondary,
              ),
              SizedBox(width: spacing.md),
              SizedBox(
                width: 26,
                child: Text(
                  '${hexagram.number}',
                  textAlign: TextAlign.end,
                  style: theme.type.label.copyWith(color: colors.textFaint),
                ),
              ),
              SizedBox(width: spacing.sm),
              SizedBox(
                width: 52,
                child: Text(
                  hexagram.name,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: theme.type.title.copyWith(
                    color: lit ? colors.accent : colors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hexagram.spoken,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: theme.type.label.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      english ?? '',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
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
      ),
    );
  }

  Widget _panel(
    SmThemeData theme,
    Strings strings,
    IchingPack pack,
    Hexagram chosen,
  ) {
    final spacing = theme.spacing;
    final labels = {
      LibraryTab.number: strings.ichingByNumber,
      LibraryTab.trigrams: strings.ichingByTrigrams,
    };
    final Widget wheels = switch (_tab) {
      LibraryTab.number => _Wheel(
        key: ValueKey('iching-wheel-number-$_placed'),
        name: 'iching-wheel-number',
        count: 64,
        initial: _chosen - 1,
        row: (i) => _label(theme, '${i + 1} · ${pack.hexagrams[i].name}'),
        onChanged: (i) => _choose(i + 1),
      ),
      LibraryTab.trigrams => Row(
        key: ValueKey('iching-wheels-trigrams-$_placed'),
        children: [
          for (final (name, trigram) in [
            ('iching-wheel-upper', chosen.upperTrigram),
            ('iching-wheel-lower', chosen.lowerTrigram),
          ])
            Expanded(
              child: Column(
                children: [
                  Text(
                    (name.endsWith('upper')
                            ? strings.ichingUpper
                            : strings.ichingLower)
                        .toUpperCase(),
                    style: theme.type.caption.copyWith(
                      color: theme.colors.textFaint,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Expanded(
                    child: _Wheel(
                      name: name,
                      count: Trigram.values.length,
                      initial: trigram.index,
                      row: (i) => _trigram(theme, strings, Trigram.values[i]),
                      onChanged: (i) {
                        // The other trigram as it now stands.
                        final now = pack.hexagrams[_chosen - 1];
                        final picked = Trigram.values[i];
                        final made = name.endsWith('upper')
                            ? pack.made(now.lowerTrigram, picked)
                            : pack.made(picked, now.upperTrigram);
                        _choose(made.number);
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    };

    return Column(
      children: [
        SizedBox(height: spacing.sm),
        Row(
          children: [
            Expanded(
              child: PanelTabs(
                listKey: const ValueKey('iching-library-tabs'),
                tabs: LibraryTab.values,
                shown: _tab,
                label: (tab) => labels[tab]!,
                keyOf: (tab) => 'iching-library-tab-${tab.name}',
                onChoose: (tab) {
                  HapticFeedback.selectionClick();
                  setState(() => _tab = tab);
                },
              ),
            ),
            // The hexagram chosen, opened.
            Padding(
              padding: EdgeInsets.only(right: spacing.md, bottom: 12),
              child: SizedBox(
                height: PillRow.pill,
                child: BarButton(
                  key: const ValueKey('iching-library-open'),
                  label: strings.ichingOpen,
                  compact: true,
                  small: true,
                  primary: true,
                  onTap: () => _open(_chosen),
                ),
              ),
            ),
          ],
        ),
        Expanded(
          // Clipped, so a wheel does not run up under the tabs.
          child: ClipRect(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.lg,
                0,
                spacing.lg,
                spacing.sm,
              ),
              child: AnimatedSwitcher(
                duration: theme.motion.medium,
                child: KeyedSubtree(key: ValueKey(_tab), child: wheels),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(SmThemeData theme, String text) => Text(
    text,
    maxLines: 1,
    softWrap: false,
    overflow: TextOverflow.fade,
    style: theme.type.body.copyWith(color: theme.colors.textPrimary),
  );

  // A trigram on its wheel: its figure, its name and ours.
  Widget _trigram(SmThemeData theme, Strings strings, Trigram trigram) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      HexagramFigure.still(
        figure: trigram.lines,
        width: 18,
        color: theme.colors.textPrimary,
      ),
      SizedBox(width: theme.spacing.sm),
      Flexible(
        child: _label(
          theme,
          '${trigram.name} ${strings.ichingTrigram(trigram)}',
        ),
      ),
    ],
  );
}

/// One wheel of the library's, in the manner of the date picker's: every
/// notch reported as it passes, and every row can be touched to.
class _Wheel extends StatefulWidget {
  final String name;
  final int count;
  final int initial;
  final Widget Function(int index) row;
  final ValueChanged<int> onChanged;

  const _Wheel({
    super.key,
    required this.name,
    required this.count,
    required this.initial,
    required this.row,
    required this.onChanged,
  });

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  static const _itemExtent = 36.0;

  late final _controller = FixedExtentScrollController(
    initialItem: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: _itemExtent,
          decoration: BoxDecoration(
            color: theme.colors.surfaceRaised,
            borderRadius: BorderRadius.circular(theme.radii.md),
          ),
        ),
        ListWheelScrollView.useDelegate(
          key: ValueKey(widget.name),
          controller: _controller,
          itemExtent: _itemExtent,
          diameterRatio: 1.4,
          overAndUnderCenterOpacity: 0.35,
          physics: const FixedExtentScrollPhysics(),
          // Counted from where the finger went down, so the rows that can
          // be touched (WheelRow) take nothing from the turn.
          dragStartBehavior: DragStartBehavior.down,
          onSelectedItemChanged: widget.onChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: widget.count,
            builder: (context, index) => WheelRow(
              controller: _controller,
              index: index,
              child: Center(child: widget.row(index)),
            ),
          ),
        ),
      ],
    );
  }
}
