import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import '../glyph_button.dart';
import '../house.dart';
import '../inertial_snap.dart';
import '../parts.dart';
import '../strings.dart';
import '../toast.dart';
import 'journal_files.dart';
import '../reminders/reminder_store.dart';
import '../sync/sync_controller.dart';
import '../sync/sync_screens.dart';
import 'journal_store.dart';
import '../routes.dart';

/// Opens the export and import screen.
Future<void> pushJournalFile(BuildContext context) {
  return Navigator.of(context)
      .push(fadeRoute<void>(context, (context) => const JournalFileScreen()));
}

/// What can be done on the export and import screen. Each is a chip on
/// the action strip.
enum FileAction { share, save, import, connect, resolve, sync, turnOff }

/// Getting the whole journal out as one file, a file back in, and keeping
/// it in step with a repository.
///
///  * Top bar: the name of the screen, and the journal in a line.
///  * Main body: what is in the journal, category by category. It holds
///    still: nothing in it changes with what is chosen below.
///  * Lower panel: the action strip, for reading and sliding: a card for
///    each action, saying what it does; the one at the centre is chosen.
///  * Bottom bar: for doing it: the chosen action's glyph at the centre,
///    and the calendar on the right, which leaves.
///
/// Importing only ever adds.
class JournalFileScreen extends StatefulWidget {
  /// Does the work with files; replaced in tests.
  final JournalFiles files;

  const JournalFileScreen({super.key, this.files = const JournalFiles()});

  @override
  State<JournalFileScreen> createState() => _JournalFileScreenState();
}

class _JournalFileScreenState extends State<JournalFileScreen> {
  // What is being done, said where a toast would be; null when idle.
  String? _busy;

  // The action at the centre of the strip; null until first built.
  FileAction? _chosen;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_chosen != null) return;
    // Where sync wants a look, the screen opens on what it wants.
    final sync = SyncScope.maybeOf(context);
    _chosen = sync == null
        ? FileAction.share
        : sync.conflicts.isNotEmpty
        ? FileAction.resolve
        : sync.phase == SyncPhase.failed
        ? FileAction.sync
        : FileAction.share;
  }

  String? _toast;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _say(String message) {
    if (!mounted) return;
    _toastTimer?.cancel();
    _toastTimer = Timer(
      const Duration(seconds: 5),
      () => setState(() => _toast = null),
    );
    setState(() {
      _busy = null;
      _toast = message;
    });
  }

  void _work(String message) {
    _toastTimer?.cancel();
    setState(() {
      _toast = null;
      _busy = message;
    });
  }

  Future<void> _export({required bool share}) async {
    final strings = Strings.of(context);
    final store = JournalScope.of(context);
    HapticFeedback.selectionClick();
    _work(strings.packing);
    try {
      final file = await widget.files.pack(store);
      if (share) {
        await widget.files.share(file);
        if (mounted) setState(() => _busy = null);
      } else if (await widget.files.saveAs(file)) {
        _say(strings.copySaved);
      } else if (mounted) {
        setState(() => _busy = null);
      }
    } catch (_) {
      _say(strings.exportFailed);
    }
  }

  Future<void> _import() async {
    final strings = Strings.of(context);
    final store = JournalScope.of(context);
    final reminders = ReminderScope.of(context);
    HapticFeedback.selectionClick();
    _work(strings.reading);
    try {
      final contents = await widget.files.pick();
      if (contents == null) {
        if (mounted) setState(() => _busy = null);
        return;
      }
      final result = await store.merge(
        contents.categories,
        contents.entries,
        tags: contents.tags,
        onProgress: (done, total) {
          if (mounted) setState(() => _busy = strings.importing(done, total));
        },
      );
      // Reminders come along: those not here already are added.
      reminders.merge(contents.reminders, tagIds: result.tagIds);
      HapticFeedback.mediumImpact();
      _say(
        strings.importDone(
          entries: result.entries,
          categories: result.categories,
          alreadyHere: result.alreadyHere,
          unreadable: contents.unreadable,
        ),
      );
    } on FormatException {
      _say(strings.notJournalFile);
    } on TooManyCategories catch (error) {
      _say(strings.tooManyCategories(error.count));
    } catch (_) {
      _say(strings.importFailed);
    }
  }

  void _run(FileAction action) {
    final sync = SyncScope.maybeOf(context);
    switch (action) {
      case FileAction.share:
        _export(share: true);
      case FileAction.save:
        _export(share: false);
      case FileAction.import:
        _import();
      case FileAction.connect:
        HapticFeedback.selectionClick();
        pushSyncSetup(context);
      case FileAction.resolve:
        HapticFeedback.selectionClick();
        pushConflicts(context);
      case FileAction.sync:
        HapticFeedback.selectionClick();
        sync?.syncNow();
      case FileAction.turnOff:
        HapticFeedback.selectionClick();
        sync?.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final strings = Strings.of(context);
    final store = JournalScope.of(context);
    final reminders = ReminderScope.of(context);
    final sync = SyncScope.maybeOf(context);
    final busy = _busy != null;

    final actions = [
      FileAction.share,
      FileAction.save,
      FileAction.import,
      if (sync != null && sync.phase == SyncPhase.off) FileAction.connect,
      if (sync != null && sync.phase != SyncPhase.off) ...[
        if (sync.conflicts.isNotEmpty) FileAction.resolve,
        FileAction.sync,
        FileAction.turnOff,
      ],
    ];
    // Sync being set up or turned off changes what there is to choose
    // from; whichever of its actions is left takes the place.
    if (!actions.contains(_chosen)) {
      _chosen = actions.contains(FileAction.sync)
          ? FileAction.sync
          : actions.last;
    }
    final action = _chosen!;

    // The glyph that stands for an action: on its card, and in the bar
    // where it is what is pressed to do it.
    Glyph glyph(FileAction action) => switch (action) {
      FileAction.share => Glyph.share,
      FileAction.save => Glyph.saveImage,
      FileAction.import => Glyph.import,
      FileAction.connect || FileAction.sync => Glyph.sync,
      FileAction.resolve => Glyph.edit,
      FileAction.turnOff => Glyph.close,
    };

    // Dimmed and out of reach while something is being done.
    Widget waits(Widget child) => AnimatedOpacity(
      opacity: busy ? 0.35 : 1,
      duration: theme.motion.medium,
      child: IgnorePointer(ignoring: busy, child: child),
    );

    return PopScope(
      // Not in the middle of an import.
      canPop: !busy,
      child: ColoredBox(
        color: colors.background,
        child: SafeArea(
          child: FourParts(
            top: TopBar(
              leading: TopBarTitle(label: strings.journalFileTitle),
              subtitle: strings.journalSummary(
                store.entryTotal,
                store.categories.length,
              ),
            ),
            body: waits(
              Padding(
                padding: EdgeInsets.fromLTRB(
                  spacing.sm,
                  0,
                  spacing.sm,
                  spacing.md,
                ),
                child: _manifest(
                  theme,
                  strings,
                  store,
                  reminders.reminders.length,
                ),
              ),
            ),
            panel: Stack(
              children: [
                Positioned.fill(
                  child: waits(
                    _ActionStrip(
                      // A new strip when what it offers changes.
                      key: ValueKey(actions.map((a) => a.name).join(' ')),
                      actions: actions,
                      chosen: action,
                      glyph: glyph,
                      words: (action) => _words(strings, sync, action),
                      onChosen: (action) => setState(() => _chosen = action),
                      onRun: _run,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Toast(message: _busy ?? _toast, hurried: busy),
                ),
              ],
            ),
            bar: const RoomBar(),
          ),
        ),
      ),
    );
  }

  /// What is in the journal: every category with how many entries it has,
  /// then the reminders.
  Widget _manifest(
    SmThemeData theme,
    Strings strings,
    JournalStore store,
    int reminders,
  ) {
    final spacing = theme.spacing;
    final colors = theme.colors;

    Widget row(Widget mark, String name, int count) => Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.sm),
      child: Row(
        children: [
          SizedBox(width: 8, height: 8, child: mark),
          SizedBox(width: spacing.md),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.type.body.copyWith(color: colors.textPrimary),
            ),
          ),
          Text(
            '$count',
            style: theme.type.body.copyWith(
              color: count == 0 ? colors.textFaint : colors.textSecondary,
            ),
          ),
        ],
      ),
    );

    return Container(
      key: const ValueKey('journal-manifest'),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(theme.radii.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.lg,
          vertical: spacing.md,
        ),
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: spacing.sm),
            child: Text(
              strings.inJournal.toUpperCase(),
              style: theme.type.caption.copyWith(
                color: colors.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          for (final category in store.categories)
            row(
              DecoratedBox(
                decoration: BoxDecoration(
                  color: category.color,
                  shape: BoxShape.circle,
                ),
              ),
              category.name,
              _countIn(store, category.id),
            ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.sm),
            child: Container(height: 1, color: colors.outline),
          ),
          // A ring, as reminders have on the calendar.
          row(
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.textSecondary),
              ),
            ),
            strings.remindersTitle,
            reminders,
          ),
        ],
      ),
    );
  }

  // How many entries each category has, counted once per change to the
  // journal and not once per frame.
  final _counts = <String, int>{};
  int? _countedAt;

  int _countIn(JournalStore store, String id) {
    if (_countedAt != store.revision) {
      _counts.clear();
      _countedAt = store.revision;
    }
    return _counts.putIfAbsent(id, () => store.entryCount(id));
  }

  /// What an action's card says: its name, what it does, and a fainter
  /// line under that.
  ({String title, String hint, String note}) _words(
    Strings strings,
    SyncController? sync,
    FileAction action,
  ) => switch (action) {
    FileAction.share => (
      title: strings.shareCopy,
      hint: strings.shareCopyHint,
      note: strings.exportNote,
    ),
    FileAction.save => (
      title: strings.saveCopy,
      hint: strings.saveCopyHint,
      note: strings.exportNote,
    ),
    FileAction.import => (
      title: strings.importFile,
      hint: strings.importFileHint,
      note: '',
    ),
    FileAction.connect => (
      title: strings.syncSetUp,
      hint: strings.syncSetUpHint,
      note: '',
    ),
    FileAction.resolve => (
      title: strings.syncResolve(sync!.conflicts.length),
      hint: strings.syncResolveHint,
      note: sync.repository ?? '',
    ),
    FileAction.sync => (
      title: strings.syncNow,
      hint: syncStatus(strings, sync!),
      note: sync.repository ?? '',
    ),
    FileAction.turnOff => (
      title: strings.syncOff,
      hint: strings.syncOffHint,
      note: sync!.repository ?? '',
    ),
  };
}

/// The action strip: the actions as cards in a row, each a long rectangle
/// with its name and what it does, in words only, swiped sideways. The card
/// at the centre is the chosen one.
///
/// Tapping the chosen card does its action. Tapping another only brings
/// it to the centre: it is not done until it is tapped again there.
///
/// Where the lower panel is tall (a tablet on its side) the cards run down
/// it instead, as wide as the column and a third of its height, so that
/// the one at the middle is the chosen one with one either side of it.
class _ActionStrip extends StatefulWidget {
  final List<FileAction> actions;
  final FileAction chosen;
  final Glyph Function(FileAction action) glyph;
  final ({String title, String hint, String note}) Function(FileAction action)
  words;
  final ValueChanged<FileAction> onChosen;
  final ValueChanged<FileAction> onRun;

  const _ActionStrip({
    super.key,
    required this.actions,
    required this.chosen,
    required this.glyph,
    required this.words,
    required this.onChosen,
    required this.onRun,
  });

  @override
  State<_ActionStrip> createState() => _ActionStripState();
}

class _ActionStripState extends State<_ActionStrip> {
  // Made for the way the strip runs, and made again, on the same card, if
  // a tablet is turned and the strip changes direction.
  PageController? _controller;
  bool? _tall;

  PageController get _pages => _controller!;

  PageController _pagesFor(bool tall) {
    if (tall == _tall) return _pages;
    final old = _controller;
    _tall = tall;
    _controller = PageController(
      viewportFraction: tall ? 1 / 3 : 0.84,
      initialPage: old != null && old.hasClients
          ? old.page!.round()
          : widget.actions.indexOf(widget.chosen),
    );
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    return _pages;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _tap(int index) {
    final page = _pages.page ?? _pages.initialPage.toDouble();
    // At the centre and at rest there: do it. Anywhere else: come here.
    if ((page - index).abs() < 0.05) {
      widget.onRun(widget.actions[index]);
      return;
    }
    final motion = SmTheme.of(context).motion;
    _pages.animateToPage(
      index,
      duration: motion.transition,
      curve: motion.transitionCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final tall = FourParts.tallPanel(context);
    final pages = _pagesFor(tall);

    return Padding(
      // The lower panel is the size it is on every screen; the cards are
      // made to fit it.
      padding: tall
          ? EdgeInsets.symmetric(horizontal: spacing.md)
          : EdgeInsets.symmetric(vertical: spacing.sm),
      child: PageView.builder(
        key: const ValueKey('action-strip'),
        controller: pages,
        scrollDirection: tall ? Axis.vertical : Axis.horizontal,
        // A flick carries it on over several cards, to rest on one.
        pageSnapping: false,
        physics: InertialSnapPhysics.pages(tall ? 1 / 3 : 0.84),
        itemCount: widget.actions.length,
        onPageChanged: (index) {
          HapticFeedback.selectionClick();
          widget.onChosen(widget.actions[index]);
        },
        itemBuilder: (context, index) {
          final action = widget.actions[index];
          final words = widget.words(action);
          return GestureDetector(
            key: ValueKey('action-${action.name}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _tap(index),
            child: AnimatedBuilder(
              animation: _pages,
              builder: (context, child) {
                final page = _pages.hasClients && _pages.position.haveDimensions
                    ? _pages.page!
                    : _pages.initialPage.toDouble();
                final away = math.min(1.0, (page - index).abs());
                return Opacity(
                  opacity: 1 - 0.5 * away,
                  child: Container(
                    margin: tall
                        ? EdgeInsets.symmetric(vertical: spacing.xs)
                        : EdgeInsets.symmetric(horizontal: spacing.xs),
                    padding: EdgeInsets.all(spacing.md),
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        colors.surfaceRaised,
                        colors.surface,
                        away,
                      ),
                      border: Border.all(
                        color: Color.lerp(colors.accent, colors.outline, away)!,
                      ),
                      borderRadius: BorderRadius.circular(theme.radii.md),
                    ),
                    child: child,
                  ),
                );
              },
              // Words only: the glyph lives in the bottom bar.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    words.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.type.body.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    words.hint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.type.label.copyWith(
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  if (words.note.isNotEmpty) ...[
                    SizedBox(height: spacing.sm),
                    Flexible(
                      child: Text(
                        words.note,
                        key: ValueKey('note-${action.name}'),
                        overflow: TextOverflow.fade,
                        style: theme.type.caption.copyWith(
                          color: colors.textFaint,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
