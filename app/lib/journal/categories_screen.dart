import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import '../confirm_bar.dart';
import '../glyph_button.dart';
import '../house.dart';
import '../parts.dart';
import '../reminders/reminder_store.dart';
import '../strings.dart';
import '../swipe_to_delete.dart';
import '../toast.dart';
import 'card_stack.dart';
import 'entry.dart';
import 'journal_store.dart';
import '../routes.dart';

/// Opens the categories screen.
Future<void> pushCategories(BuildContext context) {
  return Navigator.of(context)
      .push(fadeRoute<void>(context, (context) => const CategoriesScreen()));
}

/// Every category there is, up to twenty-four.
///
/// This screen is for managing categories and nothing else: tapping a
/// category opens it for changes, a new name or another colour. Each colour belongs
/// to one category only, so saving with a colour another category has asks
/// first, and has that category's new colour chosen: the colour trade.
///
/// Nothing is deleted by a hold. The bin asks, where a toast would be, and
/// asks a second time when the category still has entries.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  // Stands for the row of a category that has not been saved yet.
  static const _newRow = 'new';

  final _name = TextEditingController();
  final _nameFocus = FocusNode();

  final _scroll = ScrollController();

  // The single row of colours shown while the keyboard is up.
  final _swatchScroll = ScrollController();
  bool _wasCompact = false;
  final _editorKey = GlobalKey();

  // The row open for changes, and the colour chosen for it so far.
  String? _editing;
  int _color = 0;

  // What the category open for changes holds, entries and reminders,
  // counted once when it is opened for the preview.
  ({int entries, int reminders})? _holds;

  // During a colour trade: the colour the category that had [_color] is
  // to get. Null when no trade is being asked about.
  int? _trade;

  // The delete question: 0 not asked, 1 asked, 2 asked again because the
  // category has entries.
  int _deleting = 0;

  String? _toast;
  Timer? _toastTimer;

  // Whether whatever is in the toast's place leaves at the quick pace.
  bool _hurried = false;

  // The keyboard's height when the editor was last brought into view, and
  // whether it is being glided there.
  double _inset = 0;
  bool _gliding = false;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _scroll.dispose();
    _swatchScroll.dispose();
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _say(String message) {
    _toastTimer?.cancel();
    _toastTimer = Timer(
      const Duration(seconds: 3),
      () => setState(() => _toast = null),
    );
    setState(() {
      _toast = message;
      _hurried = false;
    });
  }

  // Scrolls the list just far enough that the whole editor shows, once
  // this frame is laid out. [follow] is for keeping up with something
  // already moving, the keyboard or the editor growing: no glide.
  void _reveal({bool follow = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _editorKey.currentContext?.findRenderObject();
      if (box == null || !_scroll.hasClients) return;
      final viewport = RenderAbstractViewport.of(box);
      final position = _scroll.position;
      var target = position.pixels;
      final bottom = viewport.getOffsetToReveal(box, 1).offset;
      final top = viewport.getOffsetToReveal(box, 0).offset;
      if (target < bottom) target = bottom;
      if (target > top) target = top;
      target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
      if ((target - position.pixels).abs() < 0.5) return;
      if (follow && !_gliding) {
        _scroll.jumpTo(target);
        return;
      }
      final motion = SmTheme.of(context).motion;
      _gliding = true;
      _scroll
          .animateTo(
            target,
            duration: follow ? motion.fast : motion.medium,
            curve: follow ? Curves.easeOut : motion.curve,
          )
          .whenComplete(() => _gliding = false);
    });
  }

  // The keyboard is about to take [rise] more of the list's height: moves
  // the list by as much as keeps the editor clear of it, before this frame
  // is laid out, so the two move as one.
  void _keepUp(double rise) {
    final box = _editorKey.currentContext?.findRenderObject();
    if (rise <= 0 || box == null || !_scroll.hasClients) return;
    final position = _scroll.position;
    final target =
        RenderAbstractViewport.of(box).getOffsetToReveal(box, 1).offset + rise;
    if (position.pixels >= target) return;
    position.correctPixels(
      target.clamp(position.minScrollExtent, position.maxScrollExtent + rise),
    );
  }

  void _startNew() {
    final store = JournalScope.of(context);
    if (!store.canAddCategory) {
      _say(Strings.of(context).categoryLimit);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _editing = _newRow;
      _color = store.freeColor;
      _name.clear();
    });
    _nameFocus.requestFocus();
    _reveal();
  }

  void _startEditing(JournalCategory category) {
    HapticFeedback.selectionClick();
    _fromSwipe = false;
    setState(() {
      _holds = null;
      _editing = category.id;
      _color = category.colorIndex;
      _name.text = category.name;
    });
    _reveal();
  }

  void _stopEditing() {
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _editing = null;
      _trade = null;
      _deleting = 0;
    });
  }

  // The category, other than the one being edited, that has [_color].
  JournalCategory? get _rival {
    final owner = JournalScope.of(context).ownerOf(_color);
    return owner == null || owner.id == _editing ? null : owner;
  }

  // Whether the category giving up its colour may take palette colour [i]:
  // only one nobody has, or the one the edited category is leaving.
  bool _tradable(int i) {
    final owner = JournalScope.of(context).ownerOf(i);
    return i != _color && (owner == null || owner.id == _editing);
  }

  void _save() {
    final store = JournalScope.of(context);
    if (_name.text.trim().isEmpty) {
      _say(Strings.of(context).categoryNeedsName);
      return;
    }
    if (_rival == null || _trade != null) {
      _commit();
      return;
    }
    // The colour is somebody's: ask before taking it. A plain swap is
    // offered first.
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    _toastTimer?.cancel();
    setState(() {
      _toast = null;
      _hurried = true;
      _trade = store.category(_editing)?.colorIndex ?? store.freeColor;
    });
  }

  void _commit() {
    final store = JournalScope.of(context);
    final name = _name.text.trim();
    HapticFeedback.selectionClick();
    if (_editing == _newRow) {
      store.addCategory(name, colorIndex: _color, ownerTo: _trade);
    } else {
      store
        ..renameCategory(_editing!, name)
        ..recolorCategory(_editing!, _color, ownerTo: _trade);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _editing = null;
      _trade = null;
    });
  }

  // Whether the delete being asked about was begun by drawing a row
  // aside, not from the row's editor.
  bool _fromSwipe = false;

  void _askDelete() {
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    _toastTimer?.cancel();
    setState(() {
      _toast = null;
      _hurried = true;
      _deleting = 1;
    });
  }

  void _confirmDelete() {
    final store = JournalScope.of(context);
    final reminders = ReminderScope.of(context);
    if (_deleting == 1 &&
        store.entryCount(_editing!) + reminders.countIn(_editing!) > 0) {
      HapticFeedback.selectionClick();
      setState(() => _deleting = 2);
      return;
    }
    HapticFeedback.mediumImpact();
    // Its reminders go with it, as its entries do.
    reminders.deleteIn(_editing!);
    store.deleteCategory(_editing!);
    _fromSwipe = false;
    setState(() {
      _editing = null;
      _deleting = 0;
    });
  }

  // Back, or the cross: takes back a question first, then the editor.
  void _stepBack() {
    if (_deleting == 0 && _trade == null) {
      _stopEditing();
      return;
    }
    // A delete begun by drawing a row aside, taken back: back to the
    // list, not into the row's editor (owner, 21 October 2026).
    if (_deleting > 0 && _fromSwipe) {
      _fromSwipe = false;
      _stopEditing();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _deleting = 0;
      _trade = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final strings = Strings.of(context);
    final store = JournalScope.of(context);
    final editing = _editing != null;
    final edited = store.category(_editing);
    final deleting = _deleting > 0 && edited != null;
    final trading = _trade != null && _rival != null;

    // When the colours fold into one row, bring the chosen one into it.
    // They fold for the keyboard on a phone, except in a tall panel,
    // which has room for the grid over the bar the keyboard lifts; and on
    // a tablet upright, whose keyboard leaves room for both: there the
    // grid is the one form, keyboard or not, so nothing changes as it
    // rises (owner, 19 October 2026).
    final compact =
        FourParts.panelGivesWay(context) && !FourParts.tabletUpright(context);
    if (compact && !_wasCompact) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_swatchScroll.hasClients) return;
        final position = _swatchScroll.position;
        final cell = (position.viewportDimension - 2 * theme.spacing.md) / 8;
        _swatchScroll.jumpTo(
          ((_trade ?? _color) * cell - position.viewportDimension / 2 + cell)
              .clamp(position.minScrollExtent, position.maxScrollExtent),
        );
      });
    }
    _wasCompact = compact;

    // Keep the editor above the keyboard as it rises.
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset != _inset) {
      if (editing) {
        _keepUp(inset - _inset);
        _reveal(follow: true);
      }
      _inset = inset;
    }

    return PopScope(
      // Back leaves the row being changed before it leaves the screen.
      canPop: !editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stepBack();
      },
      child: ColoredBox(
        color: colors.background,
        child: SafeArea(
          child: FourParts.fitted(
            // Where the panel is tall, the colours stand at the top of
            // the column always, keyboard up or down, with the category
            // as it will look under them.
            panelAtTop: true,
            top: Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.md,
                spacing.md,
                spacing.md,
                spacing.md,
              ),
              child: TopBar(
                leading: TopBarTitle(label: strings.categoriesTitle),
                trailing: Text(
                  strings.categoryCount(
                    store.categories.length,
                    JournalStore.maxCategories,
                  ),
                  style: theme.type.label.copyWith(color: colors.textSecondary),
                ),
              ),
            ),
            body: Stack(
              children: [
                Positioned.fill(
                  // The list ends over the add button, a little clear of
                  // it: no row ever passes under it, so a row's own
                  // delete, drawn out at its right, is never covered by it
                  // (owner, 21 October 2026). While a row is edited the
                  // button is gone, and the list reaches the foot, so the
                  // editor is never cut short over the keyboard on a
                  // phone on its side (owner, 22 October 2026).
                  bottom: editing ? 0 : spacing.md + 40 + spacing.sm,
                  // The list steps back while a delete question is
                  // up, as the lower panel does for a toast.
                  child: AnimatedOpacity(
                    opacity: deleting ? 0.04 : 1,
                    duration: deleting ? theme.motion.medium : Toast.makeWay,
                    child: IgnorePointer(
                      ignoring: deleting,
                      // The editor growing pushes the list along.
                      child: NotificationListener<SizeChangedLayoutNotification>(
                        onNotification: (_) {
                          _reveal(follow: true);
                          return true;
                        },
                        // The list itself changing size, as the colours rise
                        // under it, does the same.
                        child: SizeChangedLayoutNotifier(
                          child: SingleChildScrollView(
                            key: const ValueKey('category-list'),
                            controller: _scroll,
                            // On its side nothing stands over the list, so
                            // it keeps a margin of its own at the top.
                            padding: EdgeInsets.fromLTRB(
                              spacing.md,
                              FourParts.sideways(context) ? spacing.md : 0,
                              spacing.md,
                              spacing.sm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final category in store.categories)
                                  _editing == category.id
                                      ? _editor(theme, strings, store)
                                      : _row(theme, category, dimmed: editing),
                                if (_editing == _newRow)
                                  _editor(theme, strings, store),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // A new category: at the bottom right, over the rows,
                // where the journal's and the reminders' add buttons are.
                Positioned(
                  right: spacing.md,
                  bottom: spacing.md,
                  child: AnimatedOpacity(
                    opacity: editing ? 0 : 1,
                    duration: theme.motion.shift,
                    child: IgnorePointer(
                      ignoring: editing,
                      child: GlyphButton(
                        key: const ValueKey('category-add'),
                        glyph: Glyph.add,
                        square: true,
                        lit: true,
                        here: true,
                        onTap: _startNew,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: PanelFoot(
                    toast: Toast(
                      hurried: _hurried,
                      message: !deleting
                          ? _toast
                          : _deleting == 1
                          ? strings.deleteCategoryQuestion(edited.name)
                          : strings.deleteCategoryEntriesQuestion(
                              edited.name,
                              store.entryCount(edited.id),
                              reminders: ReminderScope.of(context)
                                  .countIn(edited.id),
                            ),
                    ),
                    // The questions are answered where they are asked.
                    answer: deleting
                        ? ConfirmBar(
                            label: strings.delete,
                            onConfirm: _confirmDelete,
                            onCancel: _stepBack,
                          )
                        : trading
                        ? ConfirmBar(
                            label: strings.swap,
                            tint: null,
                            confirmKey: const ValueKey('confirm-swap'),
                            onConfirm: _commit,
                            onCancel: _stepBack,
                          )
                        : null,
                  ),
                ),
              ],
            ),
            panel: AnimatedSize(
              duration: theme.motion.medium,
              curve: theme.motion.curve,
              alignment: Alignment.bottomCenter,
              child: !editing || deleting
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      key: const ValueKey('swatch-panel'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PanelSeparator(),
                        _swatches(theme, store, compact: compact),
                        // Where the panel is tall, the room under the
                        // colours shows the category being made.
                        Builder(
                          builder: (context) =>
                              FourParts.roomOf(context) == null
                              ? const SizedBox(width: double.infinity)
                              : _preview(theme, strings, store),
                        ),
                      ],
                    ),
            ),
            bar: const RoomBar(),
          ),
        ),
      ),
    );
  }

  /// A category at rest: tap it anywhere to change it.
  Widget _row(
    SmThemeData theme,
    JournalCategory category, {
    required bool dimmed,
  }) {
    final spacing = theme.spacing;
    final hue = category.color;

    return AnimatedOpacity(
      duration: theme.motion.medium,
      opacity: dimmed ? 0.35 : 1,
      child: IgnorePointer(
        ignoring: dimmed,
        child: Padding(
          padding: EdgeInsets.only(bottom: spacing.sm),
          // Drawn to the left, a category shows its delete button. It
          // asks first, as deleting from the editor does: a category
          // takes its entries and reminders with it.
          child: SwipeToDelete(
            name: category.id,
            onDelete: () {
              _startEditing(category);
              _fromSwipe = true;
              _askDelete();
            },
            child: SmPressable(
              key: ValueKey('category-${category.id}'),
              onTap: () => _startEditing(category),
              child: Container(
                height: 46,
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.lg + spacing.xs,
                ),
                // Lit a little from within, and glowing at its edge, so
                // it reads as something to touch: the whole row opens it
                // (owner, 20 October 2026).
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    hue.withValues(alpha: 0.2),
                    theme.colors.surface,
                  ),
                  border: Border.all(color: hue),
                  borderRadius: BorderRadius.circular(theme.radii.md),
                  boxShadow: [
                    BoxShadow(
                      color: hue.withValues(alpha: 0.28),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: hue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: spacing.md),
                    Expanded(
                      child: Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.type.body.copyWith(
                          color: theme.colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The row open for changes: its name, tinted in the colour chosen for
  /// it so far. The colours themselves are in the lower panel.
  Widget _editor(SmThemeData theme, Strings strings, JournalStore store) {
    final spacing = theme.spacing;
    final hue = categoryPalette[_color];
    final rival = _trade == null ? null : _rival;

    return Padding(
      key: _editorKey,
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: _ShownWhole(
        child: SizeChangedLayoutNotifier(
          child: AnimatedContainer(
            key: const ValueKey('category-editor'),
            duration: theme.motion.medium,
            padding: EdgeInsets.all(spacing.lg),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                hue.withValues(alpha: 0.13),
                theme.colors.surface,
              ),
              border: Border.all(color: hue.withValues(alpha: 0.9), width: 1.2),
              borderRadius: BorderRadius.circular(theme.radii.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SmTextField(
                  key: const ValueKey('category-name'),
                  controller: _name,
                  focusNode: _nameFocus,
                  readOnly: rival != null,
                  placeholder: strings.categoryNamePlaceholder,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  labels: SmTextToolbarLabels(
                    cut: strings.cut,
                    copy: strings.copy,
                    paste: strings.paste,
                    selectAll: strings.selectAll,
                  ),
                  style: theme.type.body.copyWith(
                    color: theme.colors.textPrimary,
                  ),
                ),
                // The colour trade: why, and whose colour is being chosen now,
                // written in that colour.
                AnimatedSize(
                  duration: theme.motion.medium,
                  curve: theme.motion.curve,
                  alignment: Alignment.topCenter,
                  child: rival == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: EdgeInsets.only(top: spacing.md),
                          child: Text(
                            strings.colorTaken(rival.name),
                            key: const ValueKey('trade-question'),
                            style: theme.type.label.copyWith(
                              color: categoryPalette[_trade!],
                              height: 1.5,
                            ),
                          ),
                        ),
                ),
                // Its own way out: deleting it at the left (a category
                // not saved yet has nothing to delete), and at the right
                // leaving it as it was, or saving it. The bar is the
                // house's, so the editor carries these itself.
                // Away while a question is up: it is answered under the list.
                if (rival == null && _deleting == 0) ...[
                  SizedBox(height: spacing.md),
                  Row(
                    children: [
                      if (_editing != _newRow)
                        GlyphButton(
                          key: const ValueKey('category-delete'),
                          glyph: Glyph.delete,
                          square: true,
                          tint: DeleteCardButton.red,
                          onTap: _askDelete,
                        ),
                      const Spacer(),
                      GlyphButton(
                        key: const ValueKey('category-cancel'),
                        glyph: Glyph.close,
                        square: true,
                        onTap: _stopEditing,
                      ),
                      SizedBox(width: spacing.sm),
                      GlyphButton(
                        key: const ValueKey('categories-done'),
                        glyph: Glyph.save,
                        square: true,
                        lit: true,
                        onTap: _save,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The category being made or changed, as the journal will show it: its
  /// folder in the colour chosen, with the name as typed; and for one that
  /// is kept already, what it holds.
  Widget _preview(SmThemeData theme, Strings strings, JournalStore store) {
    final spacing = theme.spacing;
    final kept = _editing != _newRow ? _editing : null;
    // Both are cheap: a count in the journal's index and a pass over the
    // reminders in memory. Taken once for the category opened.
    final holds = kept == null
        ? null
        : _holds ??= (
            entries: store.entryCount(kept),
            reminders: ReminderScope.of(context).countIn(kept),
          );
    return ColoredBox(
      key: const ValueKey('category-preview'),
      color: theme.colors.background,
      child: Padding(
        padding: EdgeInsets.fromLTRB(spacing.md, spacing.sm, spacing.md, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The name as it is typed.
            ListenableBuilder(
              listenable: _name,
              builder: (context, _) => FolderPreview(
                name: _name.text.trim(),
                hue: categoryPalette[_color],
              ),
            ),
            if (holds != null)
              Padding(
                padding: EdgeInsets.only(top: spacing.md),
                child: Text(
                  strings.categoryHolds(holds.entries, holds.reminders),
                  key: const ValueKey('category-holds'),
                  textAlign: TextAlign.center,
                  style: theme.type.label.copyWith(
                    color: theme.colors.textSecondary,
                  ),
                ),
              ),
            SizedBox(height: spacing.md),
          ],
        ),
      ),
    );
  }

  /// The twenty-four colours: three rows of eight, or [compact], one row
  /// that scrolls sideways and keeps the chosen colour in view.
  Widget _swatches(
    SmThemeData theme,
    JournalStore store, {
    required bool compact,
  }) {
    final spacing = theme.spacing;
    final rival = _trade == null ? null : _rival;

    Widget swatch(int i, double cell) => GestureDetector(
      key: ValueKey('swatch-$i'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (rival != null && !_tradable(i)) return;
        HapticFeedback.selectionClick();
        setState(() => rival == null ? _color = i : _trade = i);
      },
      child: SizedBox(
        width: cell,
        height: cell,
        child: Center(
          child: rival == null
              ? _Swatch(
                  color: categoryPalette[i],
                  chosen: i == _color,
                  // Another category has this colour.
                  taken:
                      i != _color &&
                      store.ownerOf(i) != null &&
                      store.ownerOf(i)!.id != _editing,
                )
              // During a trade only the colours the other category may
              // take stand out.
              : _Swatch(
                  color: categoryPalette[i],
                  chosen: i == _trade,
                  taken: i != _color && !_tradable(i),
                  faded: i != _color && !_tradable(i),
                ),
        ),
      ),
    );

    return ColoredBox(
      color: theme.colors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cell = (constraints.maxWidth - 2 * spacing.md) / 8;
          return AnimatedSwitcher(
            duration: theme.motion.shift,
            // The panel takes the new form's height at once, eased by the
            // AnimatedSize round it, while the old form fades out under
            // it, held to the foot: one continuous change, where the old
            // form's height held for the fade and then let go at once.
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.bottomCenter,
              // The old form stands up out of it, inside the AnimatedSize's
              // own clip.
              clipBehavior: Clip.none,
              children: [
                for (final child in previous)
                  Positioned(left: 0, right: 0, bottom: 0, child: child),
                ?current,
              ],
            ),
            child: compact
                ? SizedBox(
                    key: const ValueKey('swatch-row'),
                    height: cell + spacing.sm,
                    child: ListView(
                      controller: _swatchScroll,
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: spacing.md),
                      children: [
                        for (var i = 0; i < categoryPalette.length; i++)
                          Center(child: swatch(i, cell)),
                      ],
                    ),
                  )
                : Padding(
                    key: const ValueKey('swatch-grid'),
                    padding: EdgeInsets.all(spacing.md),
                    child: Wrap(
                      children: [
                        for (var i = 0; i < categoryPalette.length; i++)
                          swatch(i, cell),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
}

/// Whatever inside it asks to be scrolled into view, the whole of it is.
///
/// A text field asks only for its caret, which would leave the swatch grid
/// under the keyboard.
class _ShownWhole extends SingleChildRenderObjectWidget {
  const _ShownWhole({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderShownWhole();
}

class _RenderShownWhole extends RenderProxyBox {
  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) => super.showOnScreen(duration: duration, curve: curve);
}

/// One palette colour. The chosen one is ringed; one that belongs to
/// another category is hollow; one that cannot be chosen is faint.
class _Swatch extends StatelessWidget {
  final Color color;
  final bool chosen;
  final bool taken;
  final bool faded;

  const _Swatch({
    required this.color,
    required this.chosen,
    required this.taken,
    this.faded = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);

    return AnimatedOpacity(
      duration: theme.motion.medium,
      opacity: faded ? 0.25 : 1,
      child: AnimatedContainer(
        duration: theme.motion.medium,
        curve: theme.motion.curve,
        width: chosen ? 26 : 18,
        height: chosen ? 26 : 18,
        padding: EdgeInsets.all(chosen ? 4 : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: chosen ? Border.all(color: color, width: 1.4) : null,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: taken ? color.withValues(alpha: 0) : color,
            border: taken ? Border.all(color: color, width: 1.6) : null,
          ),
        ),
      ),
    );
  }
}
