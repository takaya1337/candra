import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import '../bar_button.dart';
import '../glyph_button.dart';
import '../house.dart';
import '../parts.dart';
import '../routes.dart';
import '../strings.dart';
import '../toast.dart';
import 'iching_art.dart';
import 'iching_markdown.dart';
import 'iching_pack.dart';

/// Opens the book at hexagram [number].
Future<void> pushIchingReading(
  BuildContext context, {
  required int number,
  IchingPack? pack,
}) => Navigator.of(context).push(
  fadeRoute<void>(
    context,
    (context) => IchingReadingScreen(number: number, pack: pack),
  ),
);

/// Opens the reading of a [cast]: the hexagram cast, and where lines
/// change, a button to the one it becomes and back.
Future<void> pushIchingCastReading(
  BuildContext context, {
  required YijingCast cast,
  IchingPack? pack,
}) => Navigator.of(context).push(
  fadeRoute<void>(
    context,
    (context) => IchingReadingScreen.cast(cast: cast, pack: pack),
  ),
);

/// The pages of the card, in the order they are swiped to.
enum ReadingPage { main, wilhelm, legge, notes, readings, credit }

/// Our notes on the book (Notes, Readings, and what Main unfolds under
/// the judgment, the Image and each line) are drafts the owner has not
/// read yet, and are kept from the public until they have (owner, 25
/// October 2026). Off, the card has neither page and Main unfolds nothing.
/// The same version of the app has them for everyone; only the hold below
/// shows them.
abstract final class IchingDrafts {
  static final shown = ValueNotifier(false);

  /// Where the choice is kept (`main.dart`), so it outlasts a restart.
  static const shownKey = 'iching_drafts';

  /// How long the faint 易 on the I Ching page is held to turn them on or
  /// off: the owner's own way in (owner, 25 October 2026: hidden from view
  /// in the app "unless you do something secret").
  static const hold = Duration(seconds: 5);

  /// Turns them on or off, and says which by touch alone: one firm knock
  /// for on, two light ones for off.
  static Future<void> toggle() async {
    shown.value = !shown.value;
    if (shown.value) {
      await HapticFeedback.heavyImpact();
    } else {
      await HapticFeedback.lightImpact();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await HapticFeedback.lightImpact();
    }
  }

  /// The pages the card has, in their order.
  static List<ReadingPage> get pages => [
    for (final page in ReadingPage.values)
      if (shown.value ||
          (page != ReadingPage.notes && page != ReadingPage.readings))
        page,
  ];
}

/// One hexagram read, on a large card that fills the page, as the
/// manual's exhibits are: its six pages swiped sideways, where the page
/// is shown under them as the manual shows it (owner, 25 October 2026).
///
///  * No top bar and no lower panel: the card takes the page over the
///    house's bar. Back is the swipe.
///  * Main: the figure, and beside it the name with its sound under it;
///    under them our name, large. Then the judgment and the Image as
///    cards of their own, and the lines (from a cast only the ones that
///    change). A card shows the Chinese, its sound and our English; a
///    touch unfolds what is said of it, another folds it again.
///  * Wilhelm and Legge: each translator's text on a page of its own
///    (owner, 25 October 2026), his name for the hexagram, his judgment,
///    his Image and his lines, read as Main reads them, whole, and where
///    it is taken from. Where his text is not in yet the page says so.
///  * Notes: what the name means, the trigrams, the essays, and why a
///    character is read as it is.
///  * Readings: the readings that are disputed.
///  * Credit: whose text it is, and on what terms.
///
/// From a cast whose lines change, a button at the foot of the card, at
/// its centre, turns the card to the hexagram the cast becomes, and back.
/// Beside the page's name at the foot, a copy button puts the page shown
/// on the clipboard as markdown, that page alone (owner, 25 October 2026).
/// The library's card holds the one hexagram chosen, and no button.
///
/// Where the Indonesian is not done the English is read, and says so.
class IchingReadingScreen extends StatefulWidget {
  /// The hexagram read, from the library.
  final int number;

  /// The text pack; loaded from the app's assets when not given.
  final IchingPack? pack;

  /// The cast read, or null for the library.
  final YijingCast? reading;

  const IchingReadingScreen({super.key, required this.number, this.pack})
    : reading = null;

  const IchingReadingScreen.cast({
    super.key,
    required YijingCast cast,
    this.pack,
  }) : reading = cast,
       number = 0;

  @override
  State<IchingReadingScreen> createState() => _IchingReadingScreenState();
}

class _IchingReadingScreenState extends State<IchingReadingScreen> {
  late IchingPack? _pack = widget.pack ?? IchingPack.ready;
  final _pager = PageController();
  ReadingPage _page = ReadingPage.main;

  // From a cast, whether the card shows the hexagram it becomes.
  bool _becomes = false;

  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    IchingDrafts.shown.addListener(_drafts);
    if (_pack == null) {
      IchingPack.load().then((pack) {
        if (mounted) setState(() => _pack = pack);
      });
    }
  }

  @override
  void dispose() {
    IchingDrafts.shown.removeListener(_drafts);
    _toastTimer?.cancel();
    _pager.dispose();
    super.dispose();
  }

  // The drafts shown or hidden: the card begins again at Main.
  void _drafts() {
    if (!mounted) return;
    if (_pager.hasClients) _pager.jumpToPage(0);
    setState(() => _page = ReadingPage.main);
  }

  // The page shown, as markdown, on the clipboard.
  Future<void> _copy(Hexagram hexagram, IchingPack pack) async {
    HapticFeedback.selectionClick();
    final strings = Strings.of(context);
    await Clipboard.setData(
      ClipboardData(
        text: ichingPageMarkdown(
          page: _page,
          hexagram: hexagram,
          pack: pack,
          strings: strings,
          cast: widget.reading,
          becomes:
              widget.reading != null &&
              widget.reading!.changing.isNotEmpty &&
              _becomes,
        ),
      ),
    );
    if (!mounted) return;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
    setState(() => _toast = strings.copied);
  }

  void _turn() {
    HapticFeedback.selectionClick();
    setState(() => _becomes = !_becomes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final strings = Strings.of(context);
    final pack = _pack;
    final cast = widget.reading;
    final changes = cast != null && cast.changing.isNotEmpty;
    final becomes = changes && _becomes;
    final pages = IchingDrafts.pages;

    Widget card(IchingPack pack) {
      final hexagram = cast == null
          ? pack.hexagrams[(widget.number - 1).clamp(0, 63)]
          : pack.of(becomes ? cast.relating : cast.primary);
      final other = changes
          ? pack.of(becomes ? cast.primary : cast.relating)
          : null;
      return Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Container(
          key: const ValueKey('iching-reading-card'),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.outline),
            borderRadius: BorderRadius.circular(theme.radii.lg),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: PageView.builder(
                  key: const ValueKey('iching-reading-pages'),
                  controller: _pager,
                  itemCount: pages.length,
                  onPageChanged: (page) {
                    HapticFeedback.selectionClick();
                    setState(() => _page = pages[page]);
                  },
                  // Turned to the other hexagram, each page fades to its
                  // own, begun again at the top.
                  itemBuilder: (context, index) => AnimatedSwitcher(
                    duration: theme.motion.medium,
                    child: _HexagramPage(
                      key: ValueKey('iching-page-${hexagram.number}-$index'),
                      page: pages[index],
                      hexagram: hexagram,
                      pack: pack,
                      cast: cast,
                      becomes: becomes,
                    ),
                  ),
                ),
              ),
              _Where(
                pages: pages,
                page: _page,
                label: strings.ichingPage(_page).toUpperCase(),
                onCopy: () => _copy(hexagram, pack),
                turn: other == null
                    ? null
                    : BarButton(
                        key: const ValueKey('iching-switch'),
                        label: becomes
                            ? strings.ichingBackTo(other.number, other.name)
                            : strings.ichingBecomesTo(other.number, other.name),
                        compact: true,
                        small: true,
                        primary: !becomes,
                        onTap: _turn,
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: FourParts.fitted(
          top: const SizedBox.shrink(),
          body: pack == null
              ? const SizedBox.expand()
              : Stack(
                  children: [
                    Positioned.fill(child: card(pack)),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 44 + 3 * spacing.md),
                        child: Toast(message: _toast),
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

/// Where the page is, as the manual's card shows it: a dot for each of
/// the pages, the one showing long and in the accent, and at the
/// right its name, and after it the button that copies the page. From a
/// cast whose lines change, the button to the other hexagram stands at
/// the centre.
class _Where extends StatelessWidget {
  final List<ReadingPage> pages;
  final ReadingPage page;
  final String label;
  final VoidCallback onCopy;
  final Widget? turn;

  const _Where({
    required this.pages,
    required this.page,
    required this.label,
    required this.onCopy,
    required this.turn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    return Padding(
      padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.lg, spacing.md),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              key: const ValueKey('iching-reading-dots'),
              children: [
                for (final each in pages)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: AnimatedContainer(
                      key: ValueKey('iching-dot-${each.index}'),
                      duration: theme.motion.fast,
                      width: each == page ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: each == page ? colors.accent : colors.outline,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  label,
                  key: const ValueKey('iching-page-name'),
                  style: theme.type.caption.copyWith(
                    color: colors.textFaint,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(width: spacing.sm),
                GlyphButton(
                  key: const ValueKey('iching-copy'),
                  glyph: Glyph.copy,
                  compact: true,
                  onTap: onCopy,
                ),
              ],
            ),
            ?turn,
          ],
        ),
      ),
    );
  }
}

/// One of the card's pages for one hexagram, scrolled down, its bar kept
/// as far from the words as the manual's placard keeps its own.
class _HexagramPage extends StatefulWidget {
  final ReadingPage page;
  final Hexagram hexagram;
  final IchingPack pack;

  /// The cast read, or null in the library; [becomes] where this is the
  /// hexagram it turns into.
  final YijingCast? cast;
  final bool becomes;

  const _HexagramPage({
    super.key,
    required this.page,
    required this.hexagram,
    required this.pack,
    required this.cast,
    required this.becomes,
  });

  @override
  State<_HexagramPage> createState() => _HexagramPageState();
}

class _HexagramPageState extends State<_HexagramPage> {
  // The cards unfolded, by name.
  final _open = <String>{};

  void _toggle(String name) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_open.remove(name)) _open.add(name);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    final content = switch (widget.page) {
      ReadingPage.main => _main(theme),
      ReadingPage.wilhelm => _translator(theme, widget.hexagram.wilhelm),
      ReadingPage.legge => _translator(theme, widget.hexagram.legge),
      ReadingPage.notes => _notes(theme),
      ReadingPage.readings => _readings(theme),
      ReadingPage.credit => _credit(theme),
    };

    // As the manual's placard: the bar a little in from the card's edge,
    // and the words well clear of it.
    return Padding(
      padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.sm, 0),
      child: SingleChildScrollView(
        key: ValueKey('iching-scroll-${widget.page.name}'),
        padding: EdgeInsets.fromLTRB(0, spacing.lg, spacing.lg, spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: content,
        ),
      ),
    );
  }

  // The words of the pages after the first, and their headings.
  TextStyle _note(SmThemeData theme) =>
      theme.type.label.copyWith(color: theme.colors.textSecondary, height: 1.5);
  TextStyle _caption(SmThemeData theme) => theme.type.caption.copyWith(
    color: theme.colors.textFaint,
    letterSpacing: 1.2,
  );
  TextStyle _quiet(SmThemeData theme) =>
      theme.type.label.copyWith(color: theme.colors.textFaint, height: 1.4);

  Widget _heading(SmThemeData theme, String text) => Padding(
    padding: EdgeInsets.only(top: theme.spacing.sm, bottom: theme.spacing.xs),
    child: Text(text.toUpperCase(), style: _caption(theme)),
  );

  Widget _gap(SmThemeData theme) => SizedBox(height: theme.spacing.xs + 2);

  // At the head of a page after the first: whose page it is, in the
  // accent, as the manual's placard names its own.
  // A translator's page has the year of his book after his name.
  Widget _title(SmThemeData theme, Strings strings, [String? year]) => Padding(
    padding: EdgeInsets.only(bottom: theme.spacing.sm),
    child: Text(
      '${widget.hexagram.number} ${widget.hexagram.name} · '
              '${strings.ichingPage(widget.page)}'
              '${year == null ? '' : ' ($year)'}'
          .toUpperCase(),
      key: ValueKey('iching-title-${widget.page.name}'),
      style: _caption(theme).copyWith(color: theme.colors.accent),
    ),
  );

  List<Widget> _main(SmThemeData theme) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    final strings = Strings.of(context);
    final hexagram = widget.hexagram;
    final sound = hexagram.sound;
    final read = hexagram.readIn(strings.language);
    final reading = read?.reading;
    final cast = widget.cast;
    // The cast's own changing lines, read in the hexagram cast.
    final changing = cast == null || widget.becomes
        ? const <int>[]
        : cast.changing;
    final allChange = changing.length == 6;

    final chinese = theme.type.title.copyWith(
      color: colors.textPrimary,
      height: 1.5,
    );
    final spoken = theme.type.label.copyWith(
      color: colors.textSecondary,
      height: 1.4,
    );
    final ours = theme.type.body.copyWith(color: colors.accent, height: 1.4);
    final note = _note(theme);
    final caption = _caption(theme);
    final quiet = _quiet(theme);

    Widget gap() => _gap(theme);
    Widget heading(String text) => _heading(theme, text);
    Widget separator() => Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.md),
      child: Container(height: 1, color: colors.outline),
    );

    // One of the hexagram's texts: the Chinese, its sound, our English.
    List<Widget> told(String text, String? said, String? english) => [
      Text(text, style: chinese),
      if (said != null) Text(said, style: spoken),
      if (english != null) ...[gap(), Text(english, style: ours)],
    ];

    final lines = ichingLinesRead(
      widget.hexagram,
      widget.cast,
      becomes: widget.becomes,
    );
    // What each card unfolds is ours, and a draft: only where the drafts
    // are shown.
    final unfolds = reading != null && IchingDrafts.shown.value;

    // The figure, and beside it the name over its sound, the two as tall
    // as the figure.
    const figureWidth = 88.0;
    const figureHeight = figureWidth * 0.86;
    final figure = HexagramFigure(
      key: const ValueKey('iching-figure'),
      lines: cast != null && !widget.becomes
          ? cast.lines
          : [
              for (final whole in hexagram.figure)
                whole ? LineValue.youngYang : LineValue.youngYin,
            ],
      width: figureWidth,
      color: colors.textPrimary,
      faint: colors.outline,
      mark: colors.accent,
    );

    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          figure,
          SizedBox(width: spacing.md + spacing.xs),
          SizedBox(
            height: figureHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  hexagram.name,
                  key: const ValueKey('iching-name'),
                  maxLines: 1,
                  softWrap: false,
                  style: theme.type.display.copyWith(
                    fontSize: figureHeight * 0.62,
                    height: 1,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  hexagram.spoken,
                  key: const ValueKey('iching-name-sound'),
                  maxLines: 1,
                  softWrap: false,
                  style: theme.type.title.copyWith(
                    fontSize: figureHeight * 0.26,
                    height: 1,
                    color: colors.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      if (reading != null)
        Padding(
          padding: EdgeInsets.only(top: spacing.md),
          child: Text(
            reading.name,
            key: const ValueKey('iching-name-ours'),
            textAlign: TextAlign.center,
            style: theme.type.display.copyWith(color: colors.textPrimary),
          ),
        ),
      // Read in Indonesian where the Indonesian is not done: the English,
      // and a small word that it is so.
      if (read != null && read.borrowed && strings.language != AppLanguage.en)
        Padding(
          padding: EdgeInsets.only(top: spacing.xs),
          child: Text(
            const Strings(AppLanguage.id).ichingNoIndonesian,
            key: const ValueKey('iching-no-indonesian'),
            textAlign: TextAlign.center,
            style: theme.type.caption.copyWith(color: colors.textFaint),
          ),
        ),
      if (reading == null)
        Padding(
          padding: EdgeInsets.only(top: spacing.sm),
          child: Text(
            strings.ichingNotYet,
            key: const ValueKey('iching-not-yet'),
            textAlign: TextAlign.center,
            style: quiet,
          ),
        ),
      separator(),
      _Fold(
        key: const ValueKey('iching-judgment'),
        heading: strings.ichingJudgment,
        open: _open.contains('judgment'),
        onTap: unfolds ? () => _toggle('judgment') : null,
        shown: told(hexagram.judgment, sound?.judgment, reading?.judgment),
        more: [
          if (reading != null) ...[
            gap(),
            Text(
              reading.judgmentNote,
              key: const ValueKey('iching-judgment-note'),
              style: note,
            ),
            heading(strings.ichingAsRead(reading.traditionBy)),
            Text(reading.tradition, style: note),
          ],
        ],
      ),
      SizedBox(height: spacing.sm),
      _Fold(
        key: const ValueKey('iching-image'),
        heading: strings.ichingImage,
        open: _open.contains('image'),
        onTap: unfolds ? () => _toggle('image') : null,
        shown: told(hexagram.image, sound?.image, reading?.image),
        more: [
          if (reading != null) ...[
            heading(strings.ichingLater),
            Text(
              reading.imageNote,
              key: const ValueKey('iching-image-note'),
              style: note,
            ),
          ],
        ],
      ),
      separator(),
      heading(strings.ichingLines),
      if (widget.becomes)
        Text(
          strings.ichingBecomesLines,
          key: const ValueKey('iching-becomes-lines'),
          style: quiet,
        )
      else if (lines.isEmpty)
        Text(
          strings.ichingNoLineChanges,
          key: const ValueKey('iching-no-change'),
          style: quiet,
        ),
      for (final i in lines)
        Padding(
          padding: EdgeInsets.only(top: spacing.sm),
          child: _Fold(
            key: ValueKey('iching-line-$i'),
            heading: hexagram.lines[i].label,
            small: true,
            marked: cast != null,
            badge: cast != null && i < 6 ? strings.ichingChanges : null,
            badgeKey: 'iching-line-changes-$i',
            open: _open.contains('line-$i'),
            onTap: unfolds ? () => _toggle('line-$i') : null,
            shown: [
              if (i == 6 && allChange)
                Text(
                  strings.ichingAllChange,
                  style: caption.copyWith(color: colors.accent),
                ),
              ...told(
                hexagram.lines[i].text,
                sound?.line(i),
                reading?.lines[i].text,
              ),
            ],
            more: [
              if (reading != null) ...[
                gap(),
                Text(
                  reading.lines[i].note,
                  key: ValueKey('iching-line-note-$i'),
                  style: note,
                ),
              ],
            ],
          ),
        ),
    ];
  }

  // A translator's page: his name for the hexagram, then his judgment,
  // his Image and his lines as cards, whole, in the words he wrote and
  // under the headings he gave them; his source small at the foot. No
  // pinyin here: the sound of the Chinese is Main's.
  List<Widget> _translator(SmThemeData theme, TranslatorText? text) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    final strings = Strings.of(context);
    final page = widget.page;
    final hexagram = widget.hexagram;
    final cast = widget.cast;
    final german = page == ReadingPage.wilhelm;
    final title = _title(theme, strings, strings.ichingTranslatorYear(page));
    if (text == null) {
      return [
        title,
        Text(
          strings.ichingTranslatorNotYet(page),
          key: ValueKey('iching-${page.name}-not-yet'),
          style: _quiet(theme),
        ),
      ];
    }
    final words = theme.type.body.copyWith(
      color: colors.textPrimary,
      height: 1.4,
    );
    final lines = ichingLinesRead(
      widget.hexagram,
      widget.cast,
      becomes: widget.becomes,
    );
    final allChange = cast != null && cast.changing.length == 6;
    // His headings, as he gives them: Wilhelm's "Das Urteil" and "Das
    // Bild"; Legge's "The Text", and his Image, which is in his second
    // appendix.
    Widget part(String id, String heading, String said) => _Fold(
      key: ValueKey('iching-${page.name}-$id'),
      heading: heading,
      open: false,
      onTap: null,
      shown: [Text(said, style: words)],
      more: const [],
    );
    return [
      title,
      Padding(
        padding: EdgeInsets.only(top: spacing.xs, bottom: spacing.md),
        child: Text(
          text.name,
          key: ValueKey('iching-${page.name}-name'),
          textAlign: TextAlign.center,
          style: theme.type.display.copyWith(color: colors.textPrimary),
        ),
      ),
      part('judgment', german ? 'Das Urteil' : 'The Text', text.judgment),
      SizedBox(height: spacing.sm),
      // Legge gives the Image no heading of its own: he sets it apart, in
      // his Appendix II, "Treatise on the Symbolism of the Hexagrams".
      part('image', german ? 'Das Bild' : 'The Symbolism', text.image),
      SizedBox(height: spacing.md),
      _heading(theme, strings.ichingLines),
      if (widget.becomes)
        Text(strings.ichingBecomesLines, style: _quiet(theme))
      else if (lines.isEmpty)
        Text(strings.ichingNoLineChanges, style: _quiet(theme)),
      for (final i in lines)
        Padding(
          padding: EdgeInsets.only(top: spacing.sm),
          child: _Fold(
            key: ValueKey('iching-${page.name}-line-$i'),
            heading: hexagram.lines[i].label,
            small: true,
            marked: cast != null,
            badge: cast != null && i < 6 ? strings.ichingChanges : null,
            open: false,
            onTap: null,
            shown: [
              if (i == 6 && allChange)
                Text(
                  strings.ichingAllChange,
                  style: _caption(theme).copyWith(color: colors.accent),
                ),
              Text(text.lines[i], style: words),
            ],
            more: const [],
          ),
        ),
      Padding(
        padding: EdgeInsets.only(top: spacing.lg),
        child: Text(
          text.source,
          key: ValueKey('iching-${page.name}-source'),
          style: theme.type.caption.copyWith(color: colors.textFaint),
        ),
      ),
    ];
  }

  List<Widget> _notes(SmThemeData theme) {
    final strings = Strings.of(context);
    final hexagram = widget.hexagram;
    final reading = hexagram.readIn(strings.language)?.reading;
    final note = _note(theme);
    return [
      _title(theme, strings),
      Text(
        strings.ichingBelowAbove(hexagram.lowerTrigram, hexagram.upperTrigram),
        key: const ValueKey('iching-trigrams'),
        style: note,
      ),
      if (reading != null) ...[
        _heading(theme, '${hexagram.name} · ${reading.name}'),
        Text(
          reading.nameNote,
          key: const ValueKey('iching-name-note'),
          style: note,
        ),
        for (final essay in reading.essays) ...[
          _heading(theme, essay.title),
          Text(essay.text, style: note),
        ],
      ],
      if (hexagram.soundNotes.isNotEmpty) ...[
        _heading(theme, strings.ichingPinyin),
        for (final each in hexagram.soundNotes) ...[
          Text(each, style: note),
          _gap(theme),
        ],
      ],
    ];
  }

  List<Widget> _readings(SmThemeData theme) {
    final strings = Strings.of(context);
    final reading = widget.hexagram.readIn(strings.language)?.reading;
    final readings = reading?.readings ?? const [];
    return [
      _title(theme, strings),
      if (readings.isEmpty)
        Text(
          strings.ichingNoReadings,
          key: const ValueKey('iching-no-readings'),
          style: _quiet(theme),
        ),
      for (final each in readings) ...[
        _heading(theme, each.title),
        Text(each.text, style: _note(theme)),
      ],
    ];
  }

  List<Widget> _credit(SmThemeData theme) {
    final strings = Strings.of(context);
    final pack = widget.pack;
    final note = _note(theme);
    return [
      _title(theme, strings),
      Text(pack.licence, key: const ValueKey('iching-licence'), style: note),
      _gap(theme),
      Text(pack.licenceUrl, style: note),
      for (final line in pack.credit) ...[_gap(theme), Text(line, style: note)],
    ];
  }
}

/// A card in the page: its heading, what is always shown, and what a
/// touch unfolds under it, eased; another touch folds it again. With
/// nothing to unfold ([onTap] null) it only shows.
class _Fold extends StatelessWidget {
  final String heading;
  final List<Widget> shown;
  final List<Widget> more;
  final bool open;
  final VoidCallback? onTap;

  /// A line's card: smaller, and [marked] in the accent where it is a
  /// line that changes, with a [badge] saying so.
  final bool small;
  final bool marked;
  final String? badge;
  final String? badgeKey;

  const _Fold({
    super.key,
    required this.heading,
    required this.shown,
    required this.more,
    required this.open,
    required this.onTap,
    this.small = false,
    this.marked = false,
    this.badge,
    this.badgeKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final caption = theme.type.caption.copyWith(
      color: marked ? colors.accent : colors.textFaint,
      letterSpacing: 1.2,
    );
    final folds = onTap != null && more.isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: folds ? onTap : null,
      child: Container(
        padding: EdgeInsets.all(small ? spacing.sm + 2 : spacing.md),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          border: Border.all(color: marked ? colors.accent : colors.outline),
          borderRadius: BorderRadius.circular(theme.radii.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    small ? heading : heading.toUpperCase(),
                    style: caption,
                  ),
                ),
                if (badge != null)
                  Text(
                    badge!.toUpperCase(),
                    key: badgeKey == null ? null : ValueKey(badgeKey!),
                    style: caption.copyWith(color: colors.accent),
                  ),
                if (folds) ...[
                  SizedBox(width: spacing.sm),
                  Text(
                    open ? '−' : '+',
                    style: caption.copyWith(color: colors.textFaint),
                  ),
                ],
              ],
            ),
            SizedBox(height: spacing.xs),
            ...shown,
            AnimatedSize(
              duration: theme.motion.medium,
              curve: theme.motion.curve,
              alignment: Alignment.topCenter,
              child: open && more.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: more,
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
