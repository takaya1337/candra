import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'pressable.dart';
import 'theme.dart';

/// The words on the selection toolbar, supplied by the app so the design
/// system carries no language of its own.
class SmTextToolbarLabels {
  final String cut;
  final String copy;
  final String paste;
  final String selectAll;

  const SmTextToolbarLabels({
    required this.cut,
    required this.copy,
    required this.paste,
    required this.selectAll,
  });

  String? of(ContextMenuButtonType type) => switch (type) {
    ContextMenuButtonType.cut => cut,
    ContextMenuButtonType.copy => copy,
    ContextMenuButtonType.paste => paste,
    ContextMenuButtonType.selectAll => selectAll,
    _ => null,
  };
}

/// A text field drawn entirely by the design system: caret, selection,
/// drag handles and the cut / copy / paste toolbar. Built on Flutter's
/// bare editing primitive, with nothing from Material.
///
/// The platform still does what it should: the system keyboard, tap to
/// place the caret, double tap for a word, long press to select, and
/// handles to stretch a selection.
class SmTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final TextStyle style;

  /// Shown, faintly, while the field is empty.
  final String? placeholder;

  /// Grows downward with its text and takes line breaks. A single-line
  /// field scrolls sideways and submits on the keyboard's action key.
  final bool multiline;

  final bool autofocus;

  /// Shows the text for reading: it can be selected and copied, but not
  /// changed, and the keyboard stays away.
  final bool readOnly;

  final SmTextToolbarLabels labels;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// Whether a selection brings up the floating toolbar. Off where the
  /// screen offers what to do with a selection some other way.
  final bool toolbar;

  /// The colour of the caret, the selection and its handles, in place of
  /// the accent; and how strongly the selection is washed with it.
  final Color? highlight;
  final double selectionStrength;

  /// For things that are not prose, a token or an address: no capital
  /// letters put in, nothing corrected or suggested, nothing learnt by the
  /// keyboard.
  final bool plain;

  /// Applied, in order, to everything typed.
  final List<TextInputFormatter>? inputFormatters;

  const SmTextField({
    super.key,
    required this.controller,
    required this.style,
    required this.labels,
    this.focusNode,
    this.placeholder,
    this.multiline = false,
    this.autofocus = false,
    this.readOnly = false,
    this.textInputAction,
    this.onSubmitted,
    this.inputFormatters,
    this.plain = false,
    this.toolbar = true,
    this.highlight,
    this.selectionStrength = 0.32,
  });

  @override
  State<SmTextField> createState() => _SmTextFieldState();
}

class _SmTextFieldState extends State<SmTextField>
    implements TextSelectionGestureDetectorBuilderDelegate {
  @override
  final GlobalKey<EditableTextState> editableTextKey =
      GlobalKey<EditableTextState>();

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => true;

  late final _gestures = TextSelectionGestureDetectorBuilder(delegate: this);

  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  // Handles show after a touch places or stretches the selection, and step
  // aside again once typing resumes.
  bool _showHandles = false;

  // Kept between builds: handing the editor a new controls object makes it
  // throw away its selection overlay, handles and all.
  _SmSelectionControls? _controls;

  _SmSelectionControls _controlsIn(Color color) => _controls?.color == color
      ? _controls!
      : _controls = _SmSelectionControls(color);

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _onSelectionChanged(
    TextSelection selection,
    SelectionChangedCause? cause,
  ) {
    final byTouch =
        cause == SelectionChangedCause.tap ||
        cause == SelectionChangedCause.doubleTap ||
        cause == SelectionChangedCause.longPress ||
        cause == SelectionChangedCause.drag ||
        cause == SelectionChangedCause.toolbar;
    // Text that is only read has no caret to put a handle on: handles are
    // for a stretch of it selected.
    final show = byTouch && !(widget.readOnly && selection.isCollapsed);
    if (show != _showHandles) setState(() => _showHandles = show);
  }

  // A selection taken away from outside (a tap on the page around the
  // text) takes its handles with it.
  void _onControllerChanged() {
    if (widget.readOnly &&
        _showHandles &&
        widget.controller.selection.isCollapsed) {
      setState(() => _showHandles = false);
      editableTextKey.currentState?.hideToolbar();
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(SmTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = SmTheme.of(context).colors;
    final highlight = widget.highlight ?? colors.accent;

    return _gestures.buildGestureDetector(
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          if (widget.placeholder != null && !widget.readOnly)
            ValueListenableBuilder(
              valueListenable: widget.controller,
              builder: (context, value, _) => value.text.isEmpty
                  ? Text(
                      widget.placeholder!,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: widget.style.copyWith(color: colors.textFaint),
                    )
                  : const SizedBox.shrink(),
            ),
          RepaintBoundary(
            child: EditableText(
              // The phone's keyboard in the phone's own light or dark,
              // whatever the app's colours are.
              keyboardAppearance: MediaQuery.platformBrightnessOf(context),
              key: editableTextKey,
              controller: widget.controller,
              focusNode: _focus,
              style: widget.style,
              cursorColor: highlight,
              backgroundCursorColor: colors.textFaint,
              selectionColor: highlight.withValues(
                alpha: widget.selectionStrength,
              ),
              cursorWidth: 2,
              cursorRadius: const Radius.circular(1),
              maxLines: widget.multiline ? null : 1,
              keyboardType: widget.multiline
                  ? TextInputType.multiline
                  : widget.plain
                  ? TextInputType.visiblePassword
                  : TextInputType.text,
              textInputAction: widget.textInputAction,
              textCapitalization: widget.plain
                  ? TextCapitalization.none
                  : TextCapitalization.sentences,
              autocorrect: !widget.plain,
              enableSuggestions: !widget.plain,
              enableIMEPersonalizedLearning: !widget.plain,
              autofocus: widget.autofocus,
              readOnly: widget.readOnly,
              rendererIgnoresPointer: true,
              showSelectionHandles: _showHandles,
              selectionControls: _controlsIn(highlight),
              onSelectionChanged: _onSelectionChanged,
              onSubmitted: widget.onSubmitted,
              inputFormatters: widget.inputFormatters,
              contextMenuBuilder: (context, editable) => !widget.toolbar
                  ? const SizedBox.shrink()
                  : SmTextToolbar(
                      anchors: editable.contextMenuAnchors,
                      items: editable.contextMenuButtonItems,
                      labels: widget.labels,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The drag handles: a small disc hanging from the end of the selection.
// The mixin tells Flutter these controls draw handles only, so the toolbar
// comes from the field's own context menu builder.
class _SmSelectionControls extends EmptyTextSelectionControls
    with TextSelectionHandleControls {
  final Color color;

  _SmSelectionControls(this.color);

  static const _diameter = 18.0;
  // Room around the disc that catches the finger too: a handle is easy to
  // miss, and a miss lands on the text and throws the selection away. To
  // the sides and below only: reaching up, it would lie over the line just
  // touched, and the second touch of a double tap would take the handle
  // instead of selecting the word.
  static const _reach = 22.0;
  static const _below = 16.0;

  // The disc hangs this far under the line.
  static const _drop = 2.0;

  @override
  Size getHandleSize(double textLineHeight) =>
      const Size(_diameter + 2 * _reach, _drop + _diameter + _below);

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) =>
      const Offset(_diameter / 2 + _reach, 0);

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) => GestureDetector(
    // Solid all the way out to its edge: nothing meant for the handle
    // falls through to the text, or to a page that would scroll instead.
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(_reach, _drop, _reach, _below),
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: const SizedBox.square(dimension: _diameter),
      ),
    ),
  );
}

/// The floating row of actions for a selection: cut, copy, paste, select
/// all. Sits above the selection, or below it when there is no room above.
class SmTextToolbar extends StatelessWidget {
  final TextSelectionToolbarAnchors anchors;
  final List<ContextMenuButtonItem> items;
  final SmTextToolbarLabels labels;

  const SmTextToolbar({
    super.key,
    required this.anchors,
    required this.items,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final actions = [
      for (final item in items)
        if (labels.of(item.type) != null && item.onPressed != null)
          (labels.of(item.type)!, item.onPressed!),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();

    final inset = MediaQuery.paddingOf(context).top + spacing.sm;
    return Padding(
      padding: EdgeInsets.fromLTRB(spacing.sm, inset, spacing.sm, spacing.sm),
      child: CustomSingleChildLayout(
        delegate: TextSelectionToolbarLayoutDelegate(
          anchorAbove:
              anchors.primaryAnchor - Offset(spacing.sm, inset + spacing.sm),
          anchorBelow:
              (anchors.secondaryAnchor ?? anchors.primaryAnchor) -
              Offset(spacing.sm, inset - spacing.lg),
        ),
        // Taps on the toolbar are part of editing, not taps outside it.
        child: TextFieldTapRegion(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colors.surfaceRaised,
              border: Border.all(color: theme.colors.outline),
              borderRadius: BorderRadius.circular(theme.radii.md),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (label, onPressed) in actions)
                  SmPressable(
                    onTap: onPressed,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: spacing.md - 2,
                        vertical: spacing.sm + 2,
                      ),
                      child: Text(
                        label,
                        style: theme.type.label.copyWith(
                          color: theme.colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
