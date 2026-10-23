import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import 'native_bar.dart';

/// The top bar every screen shares, so that moving from one to another the
/// top of the screen holds still: a row as tall as the month button, then
/// a line of smaller text.
///
/// The top bar is for where you are and for things rarely touched. What
/// it shows changes from screen to screen; its size does not.
class TopBar extends StatelessWidget {
  /// The left of the row: a [TopBarButton], or a [TopBarTitle] where
  /// there is nothing to press.
  final Widget leading;

  /// The right of the row, if anything.
  final Widget? trailing;

  /// The line under the row. Empty keeps its place.
  final String subtitle;

  /// More on the same line, after [subtitle], in what room is left. It
  /// must be able to give way: the subtitle is never cut for it.
  final Widget? detail;

  /// A touch on the subtitle, where it can be touched; and its key.
  final VoidCallback? onSubtitleTap;
  final Key? subtitleKey;

  const TopBar({
    super.key,
    required this.leading,
    this.trailing,
    this.subtitle = '',
    this.detail,
    this.onSubtitleTap,
    this.subtitleKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);

    final shown = AnimatedSwitcher(
      duration: theme.motion.medium,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      child: Text(
        subtitle,
        key: ValueKey(subtitle),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
        style: theme.type.label.copyWith(color: theme.colors.textSecondary),
      ),
    );
    final line = onSubtitleTap == null
        ? shown
        : GestureDetector(
            key: subtitleKey,
            behavior: HitTestBehavior.opaque,
            onTap: onSubtitleTap,
            child: shown,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: leading),
            ),
            if (trailing != null) ...[
              SizedBox(width: theme.spacing.md),
              trailing!,
            ],
          ],
        ),
        SizedBox(height: theme.spacing.md),
        // With a detail, the subtitle takes what it needs and the detail
        // has the rest; alone, it has the whole line and fades at the end.
        if (detail == null)
          line
        else
          Row(
            children: [
              line,
              Expanded(child: detail!),
            ],
          ),
      ],
    );
  }
}

/// A title in the top bar that opens something when tapped: framed, with a
/// chevron that turns over while what it opened is open.
class TopBarButton extends StatelessWidget {
  final String label;
  final bool open;
  final VoidCallback onTap;

  const TopBarButton({
    super.key,
    required this.label,
    required this.open,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);

    return SmPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: theme.motion.transition,
        curve: theme.motion.transitionCurve,
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.sm,
        ),
        decoration: BoxDecoration(
          color: open
              ? theme.colors.surfaceRaised
              : theme.colors.surfaceRaised.withValues(alpha: 0),
          border: Border.all(color: theme.colors.outline),
          borderRadius: BorderRadius.circular(theme.radii.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: AnimatedSize(
                duration: theme.motion.medium,
                curve: theme.motion.curve,
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: theme.motion.medium,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    clipBehavior: Clip.none,
                    children: [
                      for (final child in previous)
                        Positioned.fill(
                          child: OverflowBox(
                            alignment: Alignment.centerLeft,
                            maxWidth: double.infinity,
                            child: child,
                          ),
                        ),
                      ?current,
                    ],
                  ),
                  child: Text(
                    label,
                    key: ValueKey(label),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: theme.type.title.copyWith(
                      color: theme.colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: theme.spacing.sm),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: theme.motion.transition,
              curve: theme.motion.transitionCurve,
              child: CustomPaint(
                size: const Size(10, 6),
                painter: _ChevronPainter(theme.colors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A title in the top bar that is only a title. It stands exactly where a
/// [TopBarButton]'s words would, frame and all, so the two can replace
/// each other without anything moving.
class TopBarTitle extends StatelessWidget {
  final String label;

  const TopBarTitle({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);

    return Padding(
      // The button's padding, plus the width of its border.
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm + 1),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
        style: theme.type.title.copyWith(color: theme.colors.textPrimary),
      ),
    );
  }
}

/// The four parts of a screen, arranged for the way the phone is held.
///
/// **Upright:** stacked, as the design has it: the top bar, then the main
/// body, a line, the lower panel, and the bottom bar at the foot.
///
/// **On its side:** height is what is scarce, so the main body takes the
/// left at full height, and the other three stand in a column on the
/// right in their usual order, top bar over lower panel over bottom bar.
/// The column is as wide as an upright phone, so the three are laid out
/// exactly as they are upright; the line between body and panel stands
/// upright between the two sides.
///
/// Turning the phone moves the four parts; it does not make them again.
/// Each keeps its state, where it had scrolled to and all.
class FourParts extends StatefulWidget {
  final Widget top;
  final Widget body;
  final Widget panel;
  final Widget bar;

  /// Whether the parts are taken as they come: each with its own
  /// padding, and the panel as tall as it makes itself. For the screens
  /// where something is edited, whose panels come and go with what is
  /// being done.
  final bool fitted;

  /// Where the panel is tall ([tallPanel]), whether a fitted panel
  /// stands at the top of the column's middle, under the top bar, rather
  /// than at its foot over the bar: for an instrument that wants the
  /// whole of the room it is given (the wheels and their tabs with the
  /// keyboard up, a colour grid, the tags kept in sight). It moves there
  /// eased. Elsewhere it changes nothing.
  final bool panelAtTop;

  /// Upright, the share of the height the lower panel has, against
  /// [bodyFlex] for the top bar and the body: 4 against 13 on most
  /// screens, more where the panel is where the work is done (the
  /// search).
  final int panelFlex;
  final int bodyFlex;

  /// Upright, the height the panel takes, given the height its share
  /// would give it and the keyboard's height: for a panel that gives way
  /// to the keyboard (the search, while its words are typed). Only this
  /// part of the screen hears the keyboard move, so the rest is not
  /// built again on every frame of it. None takes the share.
  final double Function(double share, double keyboard)? panelSize;

  const FourParts({
    super.key,
    required this.top,
    required this.body,
    required this.panel,
    required this.bar,
    this.panelFlex = 4,
    this.bodyFlex = 13,
    this.panelSize,
  }) : fitted = false,
       panelAtTop = false;

  /// The same arrangement for parts that size and pad themselves.
  /// Upright they are simply stacked, the body taking what is left; on
  /// its side the panel has the column's middle, and scrolls there if it
  /// is ever taller than the room.
  const FourParts.fitted({
    super.key,
    required this.top,
    required this.body,
    this.panel = const SizedBox.shrink(),
    required this.bar,
    this.panelAtTop = false,
  }) : fitted = true,
       panelFlex = 4,
       bodyFlex = 13,
       panelSize = null;

  /// How wide the column is when the phone is on its side: an upright
  /// phone's width.
  static const columnWidth = 400.0;

  /// Whether the screen is wider than it is tall, and wide enough for a
  /// body beside the column.
  static bool sideways(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width > size.height && size.width >= columnWidth + 280;
  }

  /// How tall a screen on its side must be for its lower panel to count
  /// as tall. A phone on its side is at most about 440 points tall; the
  /// smallest tablets are 600 on their short side (a seven-inch Android
  /// tablet) and the iPad mini 744. The line falls in the gap, so no
  /// phone ever crosses it.
  static const tallHeight = 600.0;

  /// Whether the screen is on its side and tall enough that the column's
  /// lower panel is several hundred points tall: a tablet, not a phone.
  /// A row of cards laid across such a panel would stretch each card to
  /// its whole height, so there the rows of cards run down the column
  /// instead, the cards as wide as it and short.
  static bool tallPanel(BuildContext context) =>
      sideways(context) && MediaQuery.sizeOf(context).height >= tallHeight;

  /// The phone the layout is measured on, held upright: the Pixel 4 XL,
  /// 412 x 869 points. On a tablet upright the lower panel is this
  /// phone's, scaled ([phoneScale]).
  static const phone = Size(412, 869);

  /// Whether the screen is a tablet held upright: not on its side, and at
  /// least [tallHeight] wide, which no phone is (the widest are about 440
  /// points). An iPad in split screen narrower than that is a phone here.
  static bool tabletUpright(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return !sideways(context) && size.width >= tallHeight;
  }

  /// On a tablet upright, how much larger than on [phone] the lower panel
  /// and everything in it are: the smaller of the two ratios, widths and
  /// heights, so that the phone's layout keeps its proportion to the whole
  /// screen, as the tablet on its side does by its height (owner,
  /// 19 October 2026: "far too small" at 1, then on 20 October "made for
  /// grandpas" at the widths' 1.81, the panel over half the screen). On the
  /// iPad mini the heights decide: 1133 / 869 = 1.30, and the panel keeps
  /// the phone's share of the height. 1 everywhere else.
  static double phoneScale(BuildContext context) {
    if (!tabletUpright(context)) return 1;
    final size = MediaQuery.sizeOf(context);
    return math.min(size.width / phone.width, size.height / phone.height);
  }

  /// Whether a panel that comes and goes with what is being done should
  /// go while the keyboard is up, so that what is being written has the
  /// room. Upright, and on a phone on its side, it should: there is no
  /// room for both. Where the panel is tall there is: with a keyboard of
  /// half the height or more, the column still has some 270 points over
  /// the bar once its top bar has folded away, so the panel stays, to
  /// be used while typing.
  static bool panelGivesWay(BuildContext context) =>
      MediaQuery.viewInsetsOf(context).bottom > 0 && !tallPanel(context);

  /// Where the panel is tall, how high the column's middle is: the room a
  /// fitted panel has between the top bar (or the top, the bar folded
  /// away) and the bottom bar, so that an instrument can take all of it
  /// (the wheels, more of their rows in sight). It follows the keyboard.
  /// Null elsewhere, where a panel keeps its own height.
  static double? roomOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PanelRoom>()?.height;

  /// On a tablet upright, inside a fitted panel (an editor's), the height
  /// of the screen's standard lower panel with the line over it, in the
  /// panel's own measure, the phone's: what [FourParts] gives the main
  /// pages, so that an instrument there (the reminder's wheels and lists,
  /// the entry's tags and its date and time) stands exactly as tall, its
  /// top line where theirs is, and uses the room. On the Pixel's measure
  /// about 188 points against the reminder's own 181 and the entry's 190
  /// (owner, 20 October 2026: the reminder's panel was smaller than the
  /// others'). Null elsewhere, where a panel keeps its own height.
  static double? standardOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PanelStandard>()?.height;

  // The phone's bar, in the phone's points, as last laid out upright on a
  // tablet without the keyboard: the main pages' and the editors' bars
  // are the same, so an editor knows the standard panel from its first
  // frame. Until one is laid out, the bar as the app makes it, a button
  // 40 high with 16 above and below it, and on Android the line over it.
  static double? _phoneBar;
  static double get _phoneBarNow => _phoneBar ?? 72 + (BottomBar.glass ? 0 : 1);

  // The phone's panel, in the phone's points, beside a bar [phoneBar]
  // high: its share of what the bar and the line leave.
  static double _phoneShare(double phoneBar, int panelFlex, int bodyFlex) =>
      math.max(0.0, phone.height - phoneBar - 1) *
      panelFlex /
      (bodyFlex + panelFlex);

  @override
  State<FourParts> createState() => _FourPartsState();
}

class _FourPartsState extends State<FourParts> {
  // One key a part, so that a part moved to another place in the tree is
  // the same part there.
  final _top = GlobalKey();
  final _body = GlobalKey();
  final _panel = GlobalKey();
  final _bar = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final line = theme.colors.outline;
    // Each part also under a name, so a test can find where it stands.
    Widget part(GlobalKey key, String name, Widget child) => KeyedSubtree(
      key: key,
      child: KeyedSubtree(key: ValueKey('part-$name'), child: child),
    );
    final top = part(_top, 'top', widget.top);
    final body = part(_body, 'body', widget.body);
    final panel = part(_panel, 'panel', widget.panel);
    final bar = part(_bar, 'bar', widget.bar);

    if (widget.fitted) {
      if (!FourParts.sideways(context)) {
        // On a tablet upright the panel is the phone's, scaled to the
        // width, whatever height it gives itself.
        final scale = FourParts.phoneScale(context);
        if (scale == 1) {
          return Column(
            children: [
              top,
              Expanded(child: body),
              panel,
              bar,
            ],
          );
        }
        // And it is told the standard panel's height, the main pages'
        // share with its line, from the phone's bar; the bar is measured
        // as it is laid out, and should it differ from the one the share
        // was worked out from, the share is worked out again.
        final keyboard = MediaQuery.viewInsetsOf(context).bottom;
        final standard =
            FourParts._phoneShare(
              FourParts._phoneBarNow,
              widget.panelFlex,
              widget.bodyFlex,
            ) +
            1 / scale;
        return Column(
          children: [
            top,
            Expanded(child: body),
            PhoneScale(
              scale: scale,
              child: _PanelStandard(height: standard, child: panel),
            ),
            _Measured(
              onHeight: (height) {
                if (keyboard > 0) return;
                final phoneBar = height / scale;
                if ((phoneBar - FourParts._phoneBarNow).abs() < 0.01) return;
                FourParts._phoneBar = phoneBar;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() {});
                });
              },
              child: bar,
            ),
          ],
        );
      }
      // On its side the keyboard takes more than half the height. What
      // is being written must stay above it, so the body ends where the
      // keyboard begins; and the column gives up its top bar while the
      // keyboard is up, so that the panel still has room over the bar.
      final keyboard = MediaQuery.viewInsetsOf(context).bottom;
      return Row(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: keyboard),
              child: body,
            ),
          ),
          Container(width: 1, color: line),
          SizedBox(
            width: FourParts.columnWidth,
            child: Column(
              children: [
                _folding(top, keyboard),
                Expanded(
                  child: !FourParts.tallPanel(context)
                      ? SingleChildScrollView(
                          // What is nearest the bar stays in sight.
                          reverse: true,
                          child: panel,
                        )
                      // Where the panel is tall, the same, or the panel
                      // at the top and what is nearest the top in sight;
                      // as wide as the column either way.
                      : LayoutBuilder(
                          builder: (context, room) => SingleChildScrollView(
                            reverse: !widget.panelAtTop,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: room.maxHeight,
                              ),
                              child: AnimatedAlign(
                                duration: theme.motion.medium,
                                curve: theme.motion.curve,
                                alignment: widget.panelAtTop
                                    ? Alignment.topCenter
                                    : Alignment.bottomCenter,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: _PanelRoom(
                                    height: room.maxHeight,
                                    child: panel,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                bar,
              ],
            ),
          ),
        ],
      );
    }
    if (!FourParts.sideways(context)) {
      final upper = Padding(
        padding: EdgeInsets.fromLTRB(spacing.md, spacing.md, spacing.md, 0),
        child: Column(
          children: [
            top,
            SizedBox(height: spacing.md),
            Expanded(child: body),
          ],
        ),
      );
      // A line between the body and what is read from it.
      final separator = Container(
        key: const ValueKey('panel-separator'),
        height: 1,
        color: line,
      );
      final scale = FourParts.phoneScale(context);
      final keyboard = MediaQuery.viewInsetsOf(context).bottom;
      return _Upright(
        bodyFlex: widget.bodyFlex,
        panelFlex: widget.panelFlex,
        panelSize: widget.panelSize,
        keyboard: keyboard,
        // What the safe area gave back at the foot as the keyboard rose.
        released: math.min(keyboard, MediaQuery.viewPaddingOf(context).bottom),
        scale: scale,
        children: [
          upper,
          separator,
          if (scale == 1) panel else PhoneScale(scale: scale, child: panel),
          bar,
        ],
      );
    }
    // On its side the keyboard takes half the height or more, over both
    // sides. As on the screens where something is edited, the body ends
    // where the keyboard begins, so that the whole of it stays in sight,
    // and the column gives up its top bar, so that the panel keeps room
    // over the bar the keyboard lifts: on a tablet, and since 22 October
    // 2026 on a phone too, where the top bar alone is taller than what the
    // keyboard leaves.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(spacing.md)
                .copyWith(bottom: spacing.md + keyboard),
            child: body,
          ),
        ),
        Container(
          key: const ValueKey('panel-separator'),
          width: 1,
          color: line,
        ),
        SizedBox(
          width: FourParts.columnWidth,
          child: Column(
            children: [
              _folding(
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.md,
                    spacing.md,
                    spacing.md,
                    spacing.sm,
                  ),
                  child: top,
                ),
                keyboard,
              ),
              Expanded(child: panel),
              bar,
            ],
          ),
        ),
      ],
    );
  }
}

/// The four parts upright, as fixed segments: the top bar and the body
/// over the line, the lower panel, and the bar at the foot.
///
/// Without the keyboard the body and the panel share what the bar leaves,
/// [bodyFlex] to [panelFlex]; on a tablet upright the panel is instead the
/// phone's, scaled ([FourParts.phoneScale]).
///
/// The keyboard moves things; it never resizes them. The bar rises on it
/// (its own padding takes the keyboard's height), the panel rides on the
/// bar at the height it had, and the top bar and the body keep the size
/// they were laid out at, the panel covering the foot of the body as it
/// comes up. Only a panel that gives way ([FourParts.panelSize], the
/// search) changes height, and then the body holds still above it. So no
/// part is laid out again on a frame of the keyboard, and nothing in the
/// body (a dome, a map, a grid fitted to its room) shrinks under it. A tab
/// changed in the panel touches none of the other parts.
class _Upright extends MultiChildRenderObjectWidget {
  final int bodyFlex;
  final int panelFlex;
  final double Function(double share, double keyboard)? panelSize;
  final double keyboard;
  final double released;
  final double scale;

  const _Upright({
    required this.bodyFlex,
    required this.panelFlex,
    required this.panelSize,
    required this.keyboard,
    required this.released,
    required this.scale,
    required super.children,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderUpright()
    ..bodyFlex = bodyFlex
    ..panelFlex = panelFlex
    ..panelSize = panelSize
    ..keyboard = keyboard
    ..released = released
    ..scale = scale;

  @override
  void updateRenderObject(BuildContext context, _RenderUpright renderObject) {
    renderObject
      ..bodyFlex = bodyFlex
      ..panelFlex = panelFlex
      ..panelSize = panelSize
      ..keyboard = keyboard
      ..released = released
      ..scale = scale;
  }
}

class _UprightData extends ContainerBoxParentData<RenderBox> {}

class _RenderUpright extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _UprightData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _UprightData> {
  int _bodyFlex = 13;
  set bodyFlex(int value) {
    if (value == _bodyFlex) return;
    _bodyFlex = value;
    _steady = null;
    markNeedsLayout();
  }

  int _panelFlex = 4;
  set panelFlex(int value) {
    if (value == _panelFlex) return;
    _panelFlex = value;
    _steady = null;
    markNeedsLayout();
  }

  // A function made anew on every build of the screen: it is called on
  // every layout, so a new one needs no layout of its own.
  double Function(double share, double keyboard)? panelSize;

  double _keyboard = 0;
  set keyboard(double value) {
    if (value == _keyboard) return;
    _keyboard = value;
    markNeedsLayout();
  }

  double released = 0;

  double _scale = 1;
  set scale(double value) {
    if (value == _scale) return;
    _scale = value;
    _steady = null;
    markNeedsLayout();
  }

  // The body's height and the panel's, as laid out with the keyboard
  // down, and the width and height they were laid out for.
  ({double width, double height, double upper, double panel})? _steady;

  // How much of the upper part is in sight over the panel.
  double _shown = 0;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _UprightData) child.parentData = _UprightData();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    final upper = firstChild!;
    final line = childAfter(upper)!;
    final panel = childAfter(line)!;
    final bar = childAfter(panel)!;
    final width = size.width;
    final height = size.height;
    final keyboard = _keyboard;

    bar.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
    final barHeight = bar.size.height;
    line.layout(BoxConstraints.tightFor(width: width, height: 1));

    var steady = _steady;
    if (keyboard == 0 ||
        steady == null ||
        steady.width != width ||
        // Turned or resized with the keyboard up: worked out afresh.
        (steady.height - height).abs() > keyboard + 1) {
      // Without the keyboard; or, should the screen open with it up, as
      // it would be without: the bar less the keyboard it stands on, the
      // height less what the safe area gave back.
      final rest = math.max(
        0.0,
        height - released - math.max(0.0, barHeight - keyboard) - 1,
      );
      var share = rest * _panelFlex / (_bodyFlex + _panelFlex);
      if (_scale != 1) {
        // The phone's panel, from the phone's own height less the same
        // bar (the bar is the phone's scaled, less what the keyboard
        // lifts it by), scaled; never more than three fifths of the room.
        final phoneBar = math.max(0.0, barHeight - keyboard) / _scale;
        if (keyboard == 0) FourParts._phoneBar = phoneBar;
        share = math.min(
          FourParts._phoneShare(phoneBar, _panelFlex, _bodyFlex) * _scale,
          rest * 0.6,
        );
      }
      steady = (
        width: width,
        height: keyboard == 0 ? height : height - released,
        upper: rest - share,
        panel: share,
      );
      _steady = steady;
    }

    var panelHeight = steady.panel;
    final giving = panelSize;
    if (giving != null) {
      // The panel's own rule, in the phone's measure where it is scaled.
      panelHeight = giving(steady.panel / _scale, keyboard / _scale) * _scale;
    }
    // Whatever the safe area gives back over a panel that has given way
    // goes to the panel, so that the body holds still.
    panelHeight = math.max(panelHeight, height - barHeight - 1 - steady.upper);
    panelHeight = math.max(0.0, math.min(panelHeight, height - barHeight - 1));

    upper.layout(BoxConstraints.tightFor(width: width, height: steady.upper));
    panel.layout(BoxConstraints.tightFor(width: width, height: panelHeight));

    final panelTop = height - barHeight - panelHeight;
    _shown = math.max(0.0, math.min(steady.upper, panelTop - 1));
    (upper.parentData! as _UprightData).offset = Offset.zero;
    (line.parentData! as _UprightData).offset = Offset(0, panelTop - 1);
    (panel.parentData! as _UprightData).offset = Offset(0, panelTop);
    (bar.parentData! as _UprightData).offset = Offset(0, height - barHeight);
  }

  final _clip = LayerHandle<ClipRectLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    final upper = firstChild!;
    if (_shown < upper.size.height) {
      _clip.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & Size(size.width, _shown),
        (context, offset) => context.paintChild(upper, offset),
        oldLayer: _clip.layer,
      );
    } else {
      _clip.layer = null;
      context.paintChild(upper, offset);
    }
    var child = childAfter(upper);
    while (child != null) {
      final data = child.parentData! as _UprightData;
      context.paintChild(child, offset + data.offset);
      child = data.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // The upper part only where it is in sight.
    var child = lastChild;
    while (child != null) {
      final data = child.parentData! as _UprightData;
      if (child != firstChild || position.dy < _shown) {
        final hit = result.addWithPaintOffset(
          offset: data.offset,
          position: position,
          hitTest: (result, transformed) =>
              child!.hitTest(result, position: transformed),
        );
        if (hit) return true;
      }
      child = data.previousSibling;
    }
    return false;
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }
}

/// Lays [child] out as on a phone [scale] times smaller and shows it
/// [scale] times larger: on a tablet upright, the lower panel as the
/// phone has it, in the phone's proportions to the width
/// ([FourParts.phoneScale]). Inside, the screen is told it is that phone
/// (its size, the keyboard, the safe area, all divided by [scale], and
/// that many more pixels to a point), so whatever is in the panel lays
/// itself out, picks its form and draws its pictures as on the phone.
class PhoneScale extends StatelessWidget {
  final double scale;
  final Widget child;

  const PhoneScale({super.key, required this.scale, required this.child});

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    EdgeInsets less(EdgeInsets edges) => edges / scale;
    return _PhoneScaled(
      scale: scale,
      child: MediaQuery(
        data: data.copyWith(
          size: data.size / scale,
          devicePixelRatio: data.devicePixelRatio * scale,
          padding: less(data.padding),
          viewPadding: less(data.viewPadding),
          viewInsets: less(data.viewInsets),
          systemGestureInsets: less(data.systemGestureInsets),
        ),
        child: child,
      ),
    );
  }
}

class _PhoneScaled extends SingleChildRenderObjectWidget {
  final double scale;

  const _PhoneScaled({required this.scale, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPhoneScaled(scale);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPhoneScaled renderObject,
  ) => renderObject.scale = scale;
}

class _RenderPhoneScaled extends RenderProxyBox {
  _RenderPhoneScaled(this._scale);

  double _scale;
  set scale(double value) {
    if (value == _scale) return;
    _scale = value;
    markNeedsLayout();
  }

  BoxConstraints _inner(BoxConstraints c) => BoxConstraints(
    minWidth: c.minWidth / _scale,
    maxWidth: c.maxWidth / _scale,
    minHeight: c.minHeight / _scale,
    maxHeight: c.maxHeight / _scale,
  );

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final inner = child?.getDryLayout(_inner(constraints)) ?? Size.zero;
    return constraints.constrain(inner * _scale);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_inner(constraints), parentUsesSize: true);
    size = constraints.constrain(child.size * _scale);
  }

  Matrix4 get _transform => Matrix4.diagonal3Values(_scale, _scale, 1);

  final _layer = LayerHandle<TransformLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    _layer.layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      (context, offset) => context.paintChild(child, offset),
      oldLayer: _layer.layer,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform);
  }

  @override
  void dispose() {
    _layer.layer = null;
    super.dispose();
  }
}

/// The height of the column's middle, handed down to a fitted panel
/// where the panel is tall ([FourParts.roomOf]).
class _PanelRoom extends InheritedWidget {
  final double height;

  const _PanelRoom({required this.height, required super.child});

  @override
  bool updateShouldNotify(_PanelRoom old) => old.height != height;
}

/// The standard panel's height, handed down to a fitted panel on a tablet
/// upright ([FourParts.standardOf]).
class _PanelStandard extends InheritedWidget {
  final double height;

  const _PanelStandard({required this.height, required super.child});

  @override
  bool updateShouldNotify(_PanelStandard old) => old.height != height;
}

/// Tells [onHeight] how tall its child is laid out, each time it is.
class _Measured extends SingleChildRenderObjectWidget {
  final ValueChanged<double> onHeight;

  const _Measured({required this.onHeight, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasured(onHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasured renderObject) =>
      renderObject.onHeight = onHeight;
}

class _RenderMeasured extends RenderProxyBox {
  _RenderMeasured(this.onHeight);

  ValueChanged<double> onHeight;

  @override
  void performLayout() {
    super.performLayout();
    onHeight(size.height);
  }
}

/// The column's top bar, folded away while the keyboard is up. At once,
/// not eased: the keyboard is already taking the room as it rises, and
/// the two together would not fit.
Widget _folding(Widget top, double keyboard) => ClipRect(
  child: Align(
    alignment: Alignment.topCenter,
    heightFactor: keyboard > 0 ? 0 : 1,
    child: top,
  ),
);

/// The bottom bar of a screen: where it is confirmed, left or acted on.
///
/// On Android it is a band of the surface colour across the foot of the
/// screen, with a line above it. On an iPhone it is the phone's own bar:
/// real buttons in the system's glass (see [NativeBar]), not a likeness
/// of them.
///
/// Takes what a [Container] takes, so a screen says the same thing for
/// both. A [padding] deeper at the bottom than at the top is a bar being
/// lifted by the keyboard: the band reaches down behind the keyboard, the
/// capsule rides on top of it.
class BottomBar extends StatelessWidget {
  final EdgeInsets padding;
  final AlignmentGeometry? alignment;
  final Decoration decoration;
  final Widget child;

  const BottomBar({
    super.key,
    required this.padding,
    this.alignment,
    required this.decoration,
    required this.child,
  });

  /// Whether bars are drawn as glass here.
  static bool get glass => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final scale = FourParts.phoneScale(context);
    if (scale != 1) return _scaled(scale);
    if (!glass) {
      return Container(
        // Across the whole foot of the screen, whatever is in it.
        width: double.infinity,
        padding: padding,
        alignment: alignment,
        decoration: decoration,
        child: child,
      );
    }
    return NativeBar(padding: padding, alignment: alignment, child: child);
  }

  /// On a tablet upright, the phone's bar scaled, as the lower panel is
  /// ([FourParts.phoneScale]): laid out as wide as [FourParts.phone], its
  /// buttons, glyphs, gaps and centre pill where the phone has them, and
  /// drawn that many times larger at the middle of the foot. Before, the
  /// row was laid out across the tablet's whole width at the phone's
  /// size, so the glyphs were small beside the panel and the buttons
  /// stood far out to the sides (owner, 20 October 2026).
  ///
  /// What the keyboard lifts it by is in the screen's own points and is
  /// not scaled. On Android the band and its line still run across the
  /// whole foot of the screen, as the panel does over it; on the iPad the
  /// glass is the phone's capsule scaled, which belongs to its buttons.
  Widget _scaled(double scale) {
    final lift = math.max(0.0, padding.bottom - padding.top);
    final own = padding.copyWith(bottom: padding.bottom - lift);
    Widget phone(Widget bar) => Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: SizedBox(
        width: FourParts.phone.width * scale,
        child: PhoneScale(scale: scale, child: bar),
      ),
    );
    if (!glass) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.only(bottom: lift),
        decoration: decoration,
        child: phone(
          Container(
            width: double.infinity,
            padding: own,
            alignment: alignment,
            child: child,
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: lift),
      child: phone(
        NativeBar(
          padding: own,
          alignment: alignment,
          scale: scale,
          child: child,
        ),
      ),
    );
  }
}

/// The line between the main body and the lower panel.
class PanelSeparator extends StatelessWidget {
  const PanelSeparator({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: SmTheme.of(context).colors.outline);
}

class _ChevronPainter extends CustomPainter {
  final Color color;

  const _ChevronPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.color != color;
}
