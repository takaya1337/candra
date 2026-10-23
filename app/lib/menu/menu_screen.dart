import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import '../bar_button.dart';
import '../house.dart';
import '../journal/journal_file_screen.dart';
import '../parts.dart';
import '../routes.dart';
import '../sigil.dart';
import '../strings.dart';
import '../sync/sync_controller.dart';
import 'notes_text.dart';
import '../appearance_toggle.dart';
import 'colours_screen.dart';
import 'manual_screen.dart';
import 'policy_screen.dart';
import 'essay_screen.dart';

/// The app's dealings with the phone outside itself: its own version,
/// and handing a link or an address to whatever opens it.
abstract final class AppInfo {
  static const _channel = MethodChannel('candra/app');

  static const feedbackAddress = 'takaya@suryamajapahit.com';

  /// The version as the phone has it, "1.0.0+3"; null where it cannot be
  /// asked.
  static Future<String?> version() async {
    try {
      return await _channel.invokeMethod<String>('version');
    } on Exception {
      return null;
    }
  }

  static Future<bool> open(String url) async {
    try {
      return await _channel.invokeMethod<bool>('open', {'url': url}) ?? false;
    } on Exception {
      return false;
    }
  }

  static bool _registered = false;

  /// Adds the licences of the typefaces and the star data to those of the
  /// packages, which
  /// register themselves.
  static void registerLicences() {
    if (_registered) return;
    _registered = true;
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        'IBM Plex Mono',
      ], await rootBundle.loadString('assets/licences/IBMPlexMono-OFL.txt'));
      yield LicenseEntryWithLineBreaks([
        'JetBrains Mono',
      ], await rootBundle.loadString('assets/licences/JetBrainsMono-OFL.txt'));
      yield LicenseEntryWithLineBreaks(
        ['Noto Sans Symbols'],
        await rootBundle.loadString('assets/licences/NotoSansSymbols-OFL.txt'),
      );
      yield LicenseEntryWithLineBreaks([
        'HYG star database',
      ], await rootBundle.loadString('assets/licences/HYG-star-database.txt'));
      yield LicenseEntryWithLineBreaks([
        'd3-celestial',
      ], await rootBundle.loadString('assets/licences/d3-celestial.txt'));
      yield LicenseEntryWithLineBreaks([
        'OpenNGC',
      ], await rootBundle.loadString('assets/licences/OpenNGC.txt'));
      yield LicenseEntryWithLineBreaks([
        'Adhan',
      ], await rootBundle.loadString('assets/licences/adhan.txt'));
      yield LicenseEntryWithLineBreaks([
        'GeoNames',
      ], await rootBundle.loadString('assets/licences/GeoNames.txt'));
      yield LicenseEntryWithLineBreaks([
        'Wilayah Indonesia',
      ], await rootBundle.loadString('assets/licences/wilayah.txt'));
      yield LicenseEntryWithLineBreaks([
        'VSOP87',
      ], await rootBundle.loadString('assets/licences/VSOP87.txt'));
      yield LicenseEntryWithLineBreaks([
        'World Magnetic Model',
      ], await rootBundle.loadString('assets/licences/WMM2025.txt'));
      yield LicenseEntryWithLineBreaks([
        'IMO Meteor Shower Calendar',
      ], await rootBundle.loadString('assets/licences/IMO-meteor-showers.txt'));
    });
  }
}

/// The menu: everything that has no button of its own.
///
///  * Top bar: the name of the screen.
///  * Main body: the rows, each with a line on what it is.
///  * Lower panel: the app's name, its version and where to write.
///  * Bottom bar: the house's. The menu is a room of the house (`House`),
///    the first on the left; what it opens stays in it, and goes back
///    to it.
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String? _version;

  // The essay's own title, read from it, in the language it is read in.
  String? _stance;
  AppLanguage? _stanceLanguage;
  final _scroll = ScrollController();

  // Whether the sigil is tracing itself in place of the top bar and the
  // rows, from a touch on the app's name in the panel.
  bool _sigil = false;

  // While it does, a layer over the whole screen, the house's bar too,
  // that any touch anywhere, a tap or the start of a gesture, ends it
  // with, and does nothing else.
  OverlayEntry? _leave;

  void _showSigil() {
    setState(() => _sigil = true);
    _leave = OverlayEntry(
      builder: (context) => Listener(
        key: const ValueKey('menu-sigil-leave'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _hideSigil(),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_leave!);
  }

  void _hideSigil() {
    _leave?.remove();
    _leave = null;
    if (mounted) setState(() => _sigil = false);
  }

  @override
  void dispose() {
    _leave?.remove();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    AppInfo.version().then((version) {
      if (mounted) setState(() => _version = version);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Strings.of(context).language;
    if (language == _stanceLanguage) return;
    _stanceLanguage = language;
    Stance.load(language).then((text) {
      if (mounted) setState(() => _stance = Stance.titleOf(text));
    });
  }

  void _tap(VoidCallback action) {
    HapticFeedback.selectionClick();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final strings = Strings.of(context);

    Widget row(
      String name,
      String title,
      String summary,
      VoidCallback onTap, {
      bool marked = false,
    }) => Padding(
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: GestureDetector(
        key: ValueKey('menu-$name'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _tap(onTap),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.outline),
            borderRadius: BorderRadius.circular(theme.radii.md),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: theme.type.body.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: theme.type.label.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (marked)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    Widget heading(String text) => Padding(
      padding: EdgeInsets.only(top: spacing.sm, bottom: spacing.xs + 2),
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
          top: _sigil
              ? const SizedBox.shrink()
              : TopBar(
                  key: const ValueKey('menu-top-bar'),
                  leading: TopBarTitle(label: strings.menuTitle),
                ),
          // The sigil traces itself, and its crescent then goes round the
          // month for as long as it is looked at.
          body: _sigil
              ? SigilTracing(
                  key: const ValueKey('menu-sigil'),
                  ink: colors.textPrimary,
                  // A month in twenty seconds.
                  lunation: 20,
                )
              // The app's bar at the right edge says there is more below.
              : SingleChildScrollView(
                  key: const ValueKey('menu-body'),
                  controller: _scroll,
                  padding: EdgeInsets.only(right: spacing.sm + 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heading(strings.menuLook),
                      row(
                        'colours',
                        strings.menuColours,
                        strings.menuColoursSummary,
                        () => pushColours(context),
                      ),
                      heading(strings.menuYourData),
                      row(
                        'data',
                        strings.menuData,
                        strings.menuDataSummary,
                        () => pushJournalFile(context),
                        marked:
                            SyncScope.maybeOf(context)?.needsAttention ?? false,
                      ),
                      heading(strings.menuHelp),
                      row(
                        'manual',
                        strings.menuManual,
                        strings.menuManualSummary,
                        () => pushManual(context),
                      ),
                      row(
                        'feedback',
                        strings.menuFeedback,
                        AppInfo.feedbackAddress,
                        () => AppInfo.open(
                          'mailto:${AppInfo.feedbackAddress}'
                          '?subject=${Uri.encodeComponent('Candra ${_version ?? ''}'.trim())}',
                        ),
                      ),
                      heading(strings.menuAbout),
                      row(
                        'reckoning',
                        strings.menuReckoning,
                        strings.menuReckoningSummary,
                        () => pushReckoning(context),
                      ),
                      if (_stance != null && _stance!.isNotEmpty)
                        row(
                          'stance',
                          _stance!,
                          strings.menuStanceSummary,
                          () => pushEssay(context),
                        ),
                      row(
                        'privacy',
                        strings.menuPrivacy,
                        strings.menuPrivacySummary,
                        () => pushPolicy(context),
                      ),
                      row(
                        'licences',
                        strings.menuLicences,
                        strings.menuLicencesSummary,
                        () => pushLicences(context),
                      ),
                    ],
                  ),
                ),
          // Dark or light at the top left; the app's name in the middle,
          // which shows the sigil.
          panel: Stack(
            children: [
              GestureDetector(
                key: const ValueKey('menu-about'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _tap(_showSigil),
                child: Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.all(spacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Candra',
                        style: theme.type.title.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: spacing.xs),
                      Text(
                        _version == null ? '' : strings.menuVersion(_version!),
                        key: const ValueKey('menu-version'),
                        style: theme.type.label.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        AppInfo.feedbackAddress,
                        style: theme.type.label.copyWith(
                          color: colors.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: spacing.md,
                top: spacing.md,
                child: const AppearanceToggle(),
              ),
            ],
          ),
          bar: const RoomBar(),
        ),
      ),
    );
  }
}

/// Opens a page of notes.
Future<void> pushNotes(
  BuildContext context, {
  required String title,
  required List<NoteSection> sections,
}) => Navigator.of(context).push(
  fadeRoute<void>(
    context,
    (context) => NotesScreen(title: title, sections: sections),
  ),
);

/// A page to be read: headed stretches of plain text, and the way back.
class NotesScreen extends StatelessWidget {
  final String title;
  final List<NoteSection> sections;

  const NotesScreen({super.key, required this.title, required this.sections});

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: FourParts.fitted(
          top: Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.md,
              spacing.md,
              spacing.md,
              spacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TopBarTitle(label: title),
            ),
          ),
          body: SingleChildScrollView(
            key: const ValueKey('notes-body'),
            padding: EdgeInsets.fromLTRB(spacing.md, 0, spacing.md, spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final section in sections) ...[
                  Padding(
                    padding: EdgeInsets.only(
                      top: spacing.md,
                      bottom: spacing.xs,
                    ),
                    child: Text(
                      section.heading.toUpperCase(),
                      style: theme.type.caption.copyWith(
                        color: colors.accent,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  for (final paragraph in section.paragraphs)
                    Padding(
                      padding: EdgeInsets.only(bottom: spacing.sm),
                      child: Text(
                        paragraph,
                        style: theme.type.label.copyWith(
                          color: colors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          bar: const RoomBar(),
        ),
      ),
    );
  }
}

/// Opens the licences of the software inside the app.
Future<void> pushLicences(BuildContext context) =>
    Navigator.of(context)
        .push(fadeRoute<void>(context, (context) => const LicencesScreen()));

/// The licences of the open-source software and the typeface the app is
/// built with, by package. Touching one opens its text.
class LicencesScreen extends StatefulWidget {
  const LicencesScreen({super.key});

  @override
  State<LicencesScreen> createState() => _LicencesScreenState();
}

class _LicencesScreenState extends State<LicencesScreen> {
  // Each package's licence texts, the packages in order of name.
  Map<String, List<String>>? _licences;

  @override
  void initState() {
    super.initState();
    AppInfo.registerLicences();
    _load();
  }

  Future<void> _load() async {
    final found = <String, List<String>>{};
    await for (final entry in LicenseRegistry.licenses) {
      final text = entry.paragraphs.map((p) => p.text).join('\n\n');
      for (final package in entry.packages) {
        found.putIfAbsent(package, () => []).add(text);
      }
    }
    final names = found.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (!mounted) return;
    setState(() => _licences = {for (final name in names) name: found[name]!});
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final strings = Strings.of(context);
    final licences = _licences;

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: FourParts.fitted(
          top: Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.md,
              spacing.md,
              spacing.md,
              spacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TopBarTitle(label: strings.menuLicences),
            ),
          ),
          body: licences == null
              ? const SizedBox.expand()
              : ListView(
                  key: const ValueKey('licences-body'),
                  padding: EdgeInsets.fromLTRB(
                    spacing.md,
                    spacing.sm,
                    spacing.md,
                    spacing.lg,
                  ),
                  children: [
                    for (final MapEntry(key: name, value: texts)
                        in licences.entries)
                      GestureDetector(
                        key: ValueKey('licence-$name'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => pushNotes(
                          context,
                          title: name,
                          sections: [
                            for (final text in texts)
                              (heading: name, paragraphs: text.split('\n\n')),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: spacing.sm),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                  style: theme.type.body.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                '${texts.length}',
                                style: theme.type.label.copyWith(
                                  color: colors.textFaint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
          bar: const RoomBar(),
        ),
      ),
    );
  }
}

/// Opens how the dates are reckoned.
Future<void> pushReckoning(BuildContext context) =>
    Navigator.of(context)
        .push(fadeRoute<void>(context, (context) => const ReckoningScreen()));

/// How the dates are reckoned: a chapter for each reckoning.
///
///  * Top bar: the name of the screen, and of the chapter open.
///  * Main body: the chapter: what the rule is, where it differs from
///    others, and under that the works it rests on, each marked with how
///    far we stand behind it.
///  * Lower panel: the chapters, to choose among.
///  * Bottom bar: back to the menu.
class ReckoningScreen extends StatefulWidget {
  const ReckoningScreen({super.key});

  @override
  State<ReckoningScreen> createState() => _ReckoningScreenState();
}

class _ReckoningScreenState extends State<ReckoningScreen> {
  String _open = 'rule';

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final colors = theme.colors;
    final strings = Strings.of(context);
    final chapters = reckoningChapters(strings.language);
    final chapter = chapters.firstWhere((c) => c.id == _open);
    final text = theme.type.label.copyWith(
      color: colors.textPrimary,
      height: 1.5,
    );

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: FourParts(
          top: TopBar(
            key: const ValueKey('reckoning-top-bar'),
            leading: TopBarTitle(label: strings.menuReckoning),
            subtitle: chapter.name,
          ),
          body: SingleChildScrollView(
            // A chapter is read from its head.
            key: ValueKey('reckoning-body-${chapter.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final paragraph in chapter.paragraphs)
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing.sm),
                    child: Text(paragraph, style: text),
                  ),
                Padding(
                  padding: EdgeInsets.only(top: spacing.md, bottom: spacing.xs),
                  child: Text(
                    strings.reckoningSources.toUpperCase(),
                    style: theme.type.caption.copyWith(
                      color: colors.accent,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                if (chapter.sources.isEmpty)
                  Text(
                    strings.reckoningNoSources,
                    style: text.copyWith(color: colors.textSecondary),
                  ),
                for (final source in chapter.sources)
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(source.cite, style: text),
                        Text(
                          strings.sourceStanding(source),
                          style: theme.type.caption.copyWith(
                            // A source known only second-hand, or used as
                            // a control, is marked out from a primary one.
                            color: source.standing == SourceStanding.read
                                ? colors.textFaint
                                : colors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: spacing.md),
              ],
            ),
          ),
          panel: SingleChildScrollView(
            key: const ValueKey('reckoning-chapters'),
            padding: EdgeInsets.all(spacing.md),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: spacing.sm,
              runSpacing: spacing.sm,
              children: [
                for (final each in chapters)
                  BarButton(
                    key: ValueKey('reckoning-chapter-${each.id}'),
                    label: each.name,
                    compact: true,
                    // Fourteen chapters: the small size keeps them in
                    // view together.
                    small: true,
                    filled: each.id == _open,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _open = each.id);
                    },
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
