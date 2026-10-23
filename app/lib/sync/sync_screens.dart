import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import '../parts.dart';

import '../bar_button.dart';
import '../house.dart';
import '../journal/entry_file.dart';
import '../journal/markdown.dart';
import '../strings.dart';
import '../toast.dart';
import 'sync_controller.dart';
import 'sync_engine.dart';

Route<T> _fade<T>(BuildContext context, Widget screen) {
  final motion = SmTheme.of(context).motion;
  return PageRouteBuilder<T>(
    transitionDuration: motion.medium,
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, _, _) => screen,
    transitionsBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      child: child,
    ),
  );
}

/// Opens the screen where sync is set up.
Future<void> pushSyncSetup(BuildContext context) =>
    Navigator.of(context).push(_fade<void>(context, const SyncSetupScreen()));

/// Opens the screen where conflicts are settled.
Future<void> pushConflicts(BuildContext context) =>
    Navigator.of(context).push(_fade<void>(context, const ConflictsScreen()));

/// What sync has to say for itself, in a line.
String syncStatus(Strings strings, SyncController sync) {
  switch (sync.phase) {
    case SyncPhase.off:
      return '';
    case SyncPhase.syncing:
      return strings.syncing;
    case SyncPhase.conflicts:
      return strings.syncResolveHint;
    case SyncPhase.failed:
      return switch (sync.problem) {
        SyncProblem.offline => strings.syncOffline,
        SyncProblem.denied => strings.syncDenied,
        SyncProblem.notFound => strings.syncNotFound,
        SyncProblem.rateLimited => strings.syncRateLimited(
          sync.retryAfter == null ? null : _clock(sync.retryAfter!),
        ),
        SyncProblem.damaged => strings.syncDamaged,
        _ => strings.syncFailed(sync.detail),
      };
    case SyncPhase.idle:
      final at = sync.lastSynced;
      if (at == null) return strings.syncNever;
      return strings.syncedAt(_clock(at));
  }
}

String _clock(DateTime at) {
  String two(int value) => value.toString().padLeft(2, '0');
  final local = at.toLocal();
  return '${two(local.hour)}:${two(local.minute)}';
}

/// Where a repository and a token are put in to start syncing.
class SyncSetupScreen extends StatefulWidget {
  const SyncSetupScreen({super.key});

  @override
  State<SyncSetupScreen> createState() => _SyncSetupScreenState();
}

class _SyncSetupScreenState extends State<SyncSetupScreen> {
  final _repository = TextEditingController();
  final _token = TextEditingController();
  final _tokenFocus = FocusNode();

  bool _connecting = false;
  String? _toast;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _repository.dispose();
    _token.dispose();
    _tokenFocus.dispose();
    super.dispose();
  }

  void _say(String message) {
    if (!mounted) return;
    _toastTimer?.cancel();
    _toastTimer = Timer(
      const Duration(seconds: 6),
      () => setState(() => _toast = null),
    );
    setState(() => _toast = message);
  }

  Future<void> _connect() async {
    final strings = Strings.of(context);
    final sync = SyncScope.maybeOf(context)!;
    final navigator = Navigator.of(context);
    if (_repository.text.trim().isEmpty || _token.text.trim().isEmpty) {
      _say(strings.syncNeedsBoth);
      return;
    }
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _connecting = true;
      _toast = null;
    });
    final problem = await sync.connect(_repository.text, _token.text);
    if (!mounted) return;
    setState(() => _connecting = false);
    if (problem == null) {
      navigator.pop();
      return;
    }
    _say(switch (problem) {
      SyncProblem.offline => strings.syncOffline,
      SyncProblem.denied => strings.syncDenied,
      SyncProblem.notFound => strings.syncNotFound,
      SyncProblem.rateLimited => strings.syncRateLimited(null),
      SyncProblem.damaged => strings.syncDamaged,
      SyncProblem.other => strings.syncFailed(null),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final strings = Strings.of(context);
    final labels = SmTextToolbarLabels(
      cut: strings.cut,
      copy: strings.copy,
      paste: strings.paste,
      selectAll: strings.selectAll,
    );

    Widget field(
      String name,
      TextEditingController controller,
      String placeholder, {
      FocusNode? focusNode,
      TextInputAction action = TextInputAction.done,
      ValueChanged<String>? onSubmitted,
    }) => Container(
      margin: EdgeInsets.only(bottom: spacing.sm),
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(theme.radii.md),
      ),
      child: SmTextField(
        key: ValueKey(name),
        controller: controller,
        focusNode: focusNode,
        placeholder: placeholder,
        plain: true,
        textInputAction: action,
        onSubmitted: onSubmitted,
        labels: labels,
        style: theme.type.body.copyWith(color: colors.textPrimary),
      ),
    );

    return PopScope(
      canPop: !_connecting,
      child: ColoredBox(
        color: colors.background,
        child: SafeArea(
          child: FourParts.fitted(
            top: Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.lg,
                spacing.lg,
                spacing.lg,
                spacing.md,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  strings.syncSetupTitle,
                  style: theme.type.title.copyWith(color: colors.textPrimary),
                ),
              ),
            ),
            body: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: _connecting ? 0.35 : 1,
                    duration: theme.motion.medium,
                    child: IgnorePointer(
                      ignoring: _connecting,
                      child: ListView(
                        padding: EdgeInsets.symmetric(horizontal: spacing.lg),
                        children: [
                          field(
                            'sync-repository',
                            _repository,
                            strings.syncRepository,
                            action: TextInputAction.next,
                            onSubmitted: (_) => _tokenFocus.requestFocus(),
                          ),
                          field(
                            'sync-token',
                            _token,
                            strings.syncToken,
                            focusNode: _tokenFocus,
                            onSubmitted: (_) => _connect(),
                          ),
                          Padding(
                            padding: EdgeInsets.all(spacing.sm),
                            // What GitHub's own pages call
                            // things stands out from the rest.
                            child: Text.rich(
                              key: const ValueKey('sync-how-to'),
                              TextSpan(
                                children: [
                                  for (final (i, part)
                                      in strings.syncHowTo.split('`').indexed)
                                    TextSpan(
                                      text: part,
                                      style: i.isOdd
                                          ? TextStyle(
                                              color: colors.textPrimary,
                                              fontWeight: FontWeight.w500,
                                            )
                                          : null,
                                    ),
                                ],
                              ),
                              style: theme.type.label.copyWith(
                                color: colors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                          // Connecting, under what it needs: the bar is
                          // the house's.
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: spacing.md),
                            child: Center(
                              child: BarButton(
                                key: const ValueKey('sync-connect'),
                                label: strings.syncConnect,
                                onTap: _connect,
                                primary: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Toast(
                    message: _connecting ? strings.syncing : _toast,
                    hurried: _connecting,
                  ),
                ),
              ],
            ),
            bar: const RoomBar(),
          ),
        ),
      ),
    );
  }
}

/// Where entries changed on two devices are settled, one at a time: this
/// device's version, GitHub's, and a choice of which to keep, or both.
/// Nothing is done until every one has been chosen for.
class ConflictsScreen extends StatefulWidget {
  const ConflictsScreen({super.key});

  @override
  State<ConflictsScreen> createState() => _ConflictsScreenState();
}

class _ConflictsScreenState extends State<ConflictsScreen> {
  // The conflicts as they were when the screen opened.
  late final List<Conflict> _conflicts = SyncScope.maybeOf(context)!.conflicts;
  final _choices = <String, Keep>{};
  var _at = 0;

  void _choose(Keep keep) {
    HapticFeedback.selectionClick();
    _choices[_conflicts[_at].path] = keep;
    if (_at < _conflicts.length - 1) {
      setState(() => _at++);
      return;
    }
    // The last one: carry them all out.
    final sync = SyncScope.maybeOf(context)!;
    Navigator.of(context).pop();
    unawaited(sync.resolve(_choices));
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final strings = Strings.of(context);
    if (_conflicts.isEmpty) return ColoredBox(color: colors.background);
    final conflict = _conflicts[_at];

    Widget version(String name, String heading, List<int>? bytes) {
      String? text;
      if (bytes != null) {
        try {
          text = utf8.decode(bytes);
        } on FormatException {
          text = '';
        }
      }
      final entry = text == null ? null : EntryFile.decode(text);
      return Expanded(
        child: Container(
          key: ValueKey(name),
          width: double.infinity,
          margin: EdgeInsets.only(bottom: spacing.sm),
          padding: EdgeInsets.all(spacing.md),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.outline),
            borderRadius: BorderRadius.circular(theme.radii.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading.toUpperCase(),
                style: theme.type.caption.copyWith(
                  color: colors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: spacing.sm),
              if (text == null)
                Text(
                  strings.conflictDeleted,
                  style: theme.type.body.copyWith(color: colors.textFaint),
                )
              else if (entry == null)
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      text,
                      style: theme.type.label.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                )
              else ...[
                if (entry.title.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing.xs),
                    child: Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.type.body.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text.rich(
                      Markdown.span(
                        entry.content,
                        theme.type.label.copyWith(
                          color: colors.textPrimary.withValues(alpha: 0.85),
                          height: 1.45,
                        ),
                        colors: colors,
                        showMarks: false,
                        flat: true,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // "11 October 2026 · 10:00" out of the entry's place in the journal.
    final where = RegExp(
      r'entries/(\d{4})/(\d{2})/(\d{2})/[^/]+/(\d{2})(\d{2})',
    ).firstMatch(conflict.path);
    final when = where == null
        ? conflict.path
        : '${int.parse(where[3]!)} '
              '${strings.monthNames[int.parse(where[2]!) - 1]} ${where[1]} · '
              '${where[4]}:${where[5]}';

    return PopScope(
      child: ColoredBox(
        color: colors.background,
        child: SafeArea(
          child: FourParts.fitted(
            top: Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.lg,
                spacing.lg,
                spacing.lg,
                spacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    strings.conflictTitle(_at + 1, _conflicts.length),
                    style: theme.type.title.copyWith(color: colors.textPrimary),
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    when,
                    style: theme.type.label.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    strings.conflictIntro,
                    style: theme.type.label.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            body: Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.lg),
              child: Column(
                children: [
                  version('conflict-mine', strings.conflictMine, conflict.mine),
                  version(
                    'conflict-theirs',
                    strings.conflictTheirs,
                    conflict.theirs,
                  ),
                ],
              ),
            ),
            panel: Padding(
              padding: EdgeInsets.all(spacing.md),
              // Which to keep, answered in the panel: the bar is the
              // house's. The two short ones take what they need; the long
              // one has the rest, and gives way only if that is not
              // enough.
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: BarButton(
                      key: const ValueKey('keep-mine'),
                      label: strings.keepMine,
                      onTap: () => _choose(Keep.mine),
                    ),
                  ),
                  if (conflict.canKeepBoth) ...[
                    SizedBox(width: spacing.sm),
                    BarButton(
                      key: const ValueKey('keep-both'),
                      label: strings.keepBoth,
                      onTap: () => _choose(Keep.both),
                      filled: true,
                    ),
                  ],
                  SizedBox(width: spacing.sm),
                  BarButton(
                    key: const ValueKey('keep-theirs'),
                    label: strings.keepTheirs,
                    onTap: () => _choose(Keep.theirs),
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
}
