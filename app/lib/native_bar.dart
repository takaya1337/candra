import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import 'bar_button.dart';
import 'calendar_system.dart';
import 'glyph_button.dart';
import 'system_button.dart';
import 'system_glyph.dart';
import 'edge_swipe_back.dart';
import 'sigil.dart';

/// A screen's bottom bar drawn by the iPhone itself: real buttons in one
/// capsule of the system's glass, which bends what is behind it and
/// answers the finger as that system's own bars do.
///
/// A screen goes on describing its bar as it always has, with glyph
/// buttons and bar buttons laid out in a row. Here that row is laid out
/// but never drawn: after every frame it is read (which buttons, where,
/// in what state) and the reading is handed to the phone, which draws a
/// button of its own in each one's place and reports the taps and holds
/// back. So nothing about a screen changes, and Android never sees any of
/// this.
///
/// **There is one bar for the whole app.** It stands over the app, not
/// in it, and is never made again: going from one screen to another only
/// changes which buttons it holds, each new one fading in where an old
/// one fades out, as a tab bar's would. The screen in front is the one
/// that says what it holds.
///
/// A bar that scrolls sideways, as the format bar does, cannot be given
/// over this way: it is drawn by the app as before, over a plain capsule
/// of glass, and the phone's bar stands down while it is up.
class NativeBar extends StatefulWidget {
  final EdgeInsets padding;
  final AlignmentGeometry? alignment;
  final Widget child;

  /// How many times larger than it is laid out the bar is drawn: on a
  /// tablet upright, the phone's bar scaled ([FourParts.phoneScale]), so
  /// the phone is told every place and size that many times larger, and
  /// draws its glyphs, words, glass and lens to match. 1 elsewhere.
  final double scale;

  const NativeBar({
    super.key,
    required this.padding,
    this.alignment,
    this.scale = 1,
    required this.child,
  });

  /// Whether the bar laid out at [context] belongs to the page in front,
  /// set by the house (`House`): a page's bar for typing in a room the
  /// house is not in is never the one shown, though its page is the top
  /// of that room's own way down. The house's own bar stands outside the
  /// rooms and is always in front.
  static bool Function(BuildContext context, ModalRoute<Object?>? route)?
  inFront;

  @override
  State<NativeBar> createState() => _NativeBarState();
}

class _NativeBarState extends State<NativeBar> {
  static const _phone = MethodChannel('candra/bar');
  static Future<void>? _sentImages;

  // Every bar there is, one a screen; the one whose screen is in front
  // is read after each frame that is drawn.
  static final _live = <_NativeBarState>[];
  static bool _watching = false;
  static String _sent = '';
  static var _actions = <String, (VoidCallback?, VoidCallback?)>{};

  final _laid = GlobalKey();
  // What the screen put in the bar, kept as it is when the bar goes from
  // being the phone's to being drawn by the app and back. The two lay
  // the row out in different boxes, and without this everything in it
  // was made anew: a field that had just been given the keyboard was
  // thrown away, which put the keyboard away with it, and the one made
  // in its place kept the focus and so never asked for the keyboard
  // again (the search's words and the star map's search, on the iPad,
  // 19 October 2026).
  final _kept = GlobalKey();
  ModalRoute<Object?>? _route;

  // Whether this bar is one that has to be drawn the old way.
  bool _drawn = false;

  @override
  void initState() {
    super.initState();
    _live.add(this);
    if (!_watching) {
      _watching = true;
      _phone.setMethodCallHandler((call) async {
        final action = _actions[call.arguments as String?];
        if (call.method == 'tap') action?.$1?.call();
        if (call.method == 'hold') action?.$2?.call();
      });
      // Called on frames that happen anyway; it asks for none itself.
      SchedulerBinding.instance.addPersistentFrameCallback((_) {
        SchedulerBinding.instance.addPostFrameCallback((_) => _tell());
      });
    }
    _sentImages ??= _sendImages().then((_) {
      _sent = '';
      _tell();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    _live.remove(this);
    super.dispose();
  }

  // Every glyph the app has, once, for the phone to draw with.
  static Future<void> _sendImages() async {
    final images = <String, Uint8List>{
      for (final glyph in Glyph.values)
        'glyph-${glyph.name}': await glyphPng(glyph),
      for (final system in CalendarSystem.values)
        'system-${system.name}': await systemGlyphPng(system),
      // Filled and glowing, for the room the house is in.
      for (final glyph in Glyph.solids)
        'glyph-${glyph.name}-solid': await glyphPng(glyph, solid: true),
    };
    try {
      await _phone.invokeMethod<void>('images', images);
    } on MissingPluginException {
      // Not an iPhone.
    }
  }

  // Tells the phone what its bar holds now: what the screen in front
  // has laid out, or nothing.
  static void _tell() {
    _NativeBarState? front;
    // The last made of those in front: a page's bar for typing, made
    // after the house's, stands in for it while it is up.
    for (final bar in _live) {
      if (bar.mounted &&
          (bar._route?.isCurrent ?? true) &&
          (NativeBar.inFront?.call(bar.context, bar._route) ?? true)) {
        front = bar;
      }
    }
    // The opening sigil covers the whole screen, and the phone draws its
    // bar over the app: none while it is up.
    final reading = SigilOpening.showing.value ? null : front?._read();
    if (reading == null) {
      if (_sent != 'none') {
        _sent = 'none';
        _phone.invokeMethod<void>('hide').catchError((Object _) {});
      }
      return;
    }
    if (reading == _sent) return;
    _sent = reading;
    _phone.invokeMethod<void>('show', reading).catchError((Object _) {});
  }

  // Reads the row as it is laid out, and tells the phone if it has
  // changed.
  String? _read() {
    final root = _laid.currentContext;
    final box = root?.findRenderObject();
    if (root == null || box is! RenderBox || !box.attached) return null;
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    // The row is laid out at the phone's size and drawn scaled: every
    // place and size in it is sent as drawn.
    final scale = widget.scale;

    final items = <Map<String, Object?>>[];
    final actions = <String, (VoidCallback?, VoidCallback?)>{};
    var scrolls = false;
    // The top of the highest button as the row lays it out, which is
    // where the glass stands.
    double? top;

    void add(
      Element element,
      double alpha,
      bool enabled, {
      String? image,
      String? title,
      required Color tint,
      bool prominent = false,
      bool marked = false,
      bool selected = false,
      VoidCallback? onTap,
      VoidCallback? onHold,
    }) {
      final render = element.renderObject;
      if (render is! RenderBox || !render.hasSize || alpha < 0.02) return;
      final at = render.localToGlobal(Offset.zero, ancestor: box);
      final laid = _laidAt(render, box).dy;
      if (top == null || laid < top!) top = laid;
      final key = element.widget.key;
      final id = key is ValueKey ? '${key.value}' : 'item-${items.length}';
      actions[id] = (onTap, onHold);
      items.add({
        'id': id,
        'x': at.dx,
        'y': at.dy,
        'w': render.size.width,
        'h': render.size.height,
        'image': image,
        'title': title,
        'tint': tint.toARGB32(),
        'ink': colors.background.toARGB32(),
        'dot': colors.accent.toARGB32(),
        'prominent': prominent,
        'alpha': alpha,
        'enabled': enabled,
        'marked': marked,
        'selected': selected,
        'hold': onHold != null,
      });
    }

    void visit(Element element, double alpha, bool enabled) {
      final widget = element.widget;
      if (widget is Scrollable) {
        scrolls = true;
        return;
      }
      if (widget is GlyphButton) {
        add(
          element,
          alpha,
          enabled,
          image: widget.here && Glyph.solids.contains(widget.glyph)
              ? 'glyph-${widget.glyph.name}-solid'
              : 'glyph-${widget.glyph.name}',
          tint:
              widget.tint ??
              (widget.filled || widget.lit || widget.here
                  ? colors.accent
                  : colors.textPrimary),
          prominent: widget.filled,
          marked: widget.marked,
          selected: widget.here,
          onTap: widget.onTap,
          onHold: widget.onHold,
        );
        return;
      }
      if (widget is SystemButton) {
        add(
          element,
          alpha,
          enabled,
          image: 'system-${widget.system.name}',
          tint: colors.accent,
          // At home, its inverse: the glyph on a solid accent pill.
          prominent: widget.here,
          marked: widget.marked,
          selected: widget.here,
          onTap: widget.onTap,
          onHold: widget.onHold,
        );
        return;
      }
      if (widget is BarButton) {
        add(
          element,
          alpha,
          enabled,
          title: widget.label,
          tint:
              widget.tint ??
              (widget.primary ? colors.accent : colors.textPrimary),
          prominent: widget.primary,
          marked: widget.marked,
          onTap: widget.onTap,
          onHold: widget.onHold,
        );
        return;
      }
      // What is faded, hidden or deaf above a button is so for the
      // button the phone draws too.
      if (widget is Opacity) alpha *= widget.opacity;
      if (widget is FadeTransition) alpha *= widget.opacity.value;
      if (widget is AnimatedOpacity) {
        final render = element.renderObject;
        if (render is RenderAnimatedOpacity) alpha *= render.opacity.value;
      }
      if (widget is Visibility && !widget.visible) alpha = 0;
      if (widget is Offstage && widget.offstage) alpha = 0;
      if (widget is IgnorePointer && widget.ignoring) enabled = false;
      element.visitChildren((child) => visit(child, alpha, enabled));
    }

    (root as Element).visitChildren((child) => visit(child, 1, true));

    if (scrolls != _drawn) {
      setState(() => _drawn = scrolls);
      return null;
    }
    if (scrolls) return null;
    // Nothing to show (the house's bar faded for the keyboard): no glass.
    if (items.isEmpty) return null;
    _actions = actions;
    // No button is filled for being at the centre any more: the bar is
    // the house's, the same everywhere, and the room it is in is the
    // one lit from behind ('selected'; owner, 20 October 2026).
    for (final item in items) {
      if (scale != 1) {
        for (final name in const ['x', 'y', 'w', 'h']) {
          item[name] = (item[name]! as double) * scale;
        }
      }
    }
    // Where the bar stands on the screen, and what is in it: where it
    // stands with its screen in place, so that a screen drawn aside from
    // an edge does not drag the phone's bar along a frame behind.
    final at =
        box.localToGlobal(Offset.zero) -
        Offset(EdgeSwipeBack.shiftOf(context), 0);
    final laidTop = top;
    return jsonEncode({
      'x': at.dx,
      'y': at.dy,
      'w': box.size.width * scale,
      'h': box.size.height * scale,
      if (laidTop != null) 'top': laidTop * scale,
      'scale': scale,
      'items': items,
    });
  }

  // Where [render] stands in [row] as the row lays it out: its place
  // before anything painted over it moves it. Each button is told where
  // it is drawn (a button rising into the bar is drawn lower until it
  // has risen), but the glass is placed by this, so that it stands
  // still while buttons come and go in it: the pickers' tick and the
  // utilities' way back rise from 14 points below as everything else
  // fades, and the glass, placed at the highest button drawn, went down
  // with them by up to 5.6 points and glided back (read from the bar's
  // own readings on the iPad, 20 October 2026).
  static Offset _laidAt(RenderBox render, RenderBox row) {
    var at = Offset.zero;
    RenderObject? node = render;
    while (node != null && node != row) {
      final data = node.parentData;
      if (data is BoxParentData) at += data.offset;
      node = node.parent;
    }
    return at;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = SmTheme.of(context).spacing;
    final child = KeyedSubtree(key: _kept, child: widget.child);
    final row = Container(
      key: _laid,
      width: double.infinity,
      padding: widget.padding,
      alignment: widget.alignment,
      child: child,
    );

    if (_drawn) {
      // Drawn by the app, over one capsule of the system's glass: as tall
      // in all as the phone's own bar would be, so that the panel and the
      // body over it do not move when a bar with a field in it comes and
      // goes (the search's words, the star map's search).
      final lift = widget.padding.bottom - widget.padding.top;
      final inner = spacing.sm + 2;
      final outer = math.max(0.0, widget.padding.top - inner);
      return Padding(
        padding: EdgeInsets.fromLTRB(
          spacing.md,
          outer,
          spacing.md,
          outer + (lift > 0 ? lift : 0),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(child: UiKitView(viewType: 'candra/glass')),
            ),
            Container(
              key: _laid,
              padding: EdgeInsets.symmetric(
                horizontal: spacing.md,
                vertical: inner,
              ),
              alignment: widget.alignment,
              child: child,
            ),
          ],
        ),
      );
    }

    // Laid out, so that every button has its place, and never drawn or
    // touched: the phone's bar stands over it.
    return IgnorePointer(child: Opacity(opacity: 0, child: row));
  }
}
