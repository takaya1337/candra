import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import '../app_shell.dart';
import '../appearance.dart';
import '../bar_button.dart';
import '../glyph_button.dart';
import '../house.dart';
import '../inertial_snap.dart';
import '../journal/categories_screen.dart';
import '../journal/markdown.dart';
import '../journal/journal_file_screen.dart';
import '../journal/showcase_text.dart';
import '../parts.dart';
import '../routes.dart';
import '../strings.dart';
import '../system_glyph.dart';
import '../utilities.dart';
import 'colours_screen.dart';

/// Opens the manual.
Future<void> pushManual(BuildContext context) =>
    Navigator.of(context)
        .push(fadeRoute<void>(context, (context) => const ManualScreen()));

/// The manual's words, read once from the file the owner writes them in
/// (`manual.*` in [ShowcaseText.asset]), in either language.
abstract final class Manual {
  static Future<String>? _source;

  /// Whether the first-run note on where the manual is still stands. Off
  /// unless the app's start-up says otherwise, so nothing shows in tests.
  static final offered = ValueNotifier(false);

  /// Gives the manual its words without reading the asset: for tests,
  /// whose clock never lets the asset's read finish.
  static void preload(String source) => _preloaded = source;
  static String? _preloaded;

  /// Where each part the manual names stands on its exhibit, for each
  /// version: `en-dark` -> feature -> part -> [x, y], shares of the
  /// picture's width and height (`assets/manual/marks.json`, made with
  /// the pictures by `tool/manual_pictures.sh`).
  static Future<Map<String, dynamic>> marks() async =>
      _marksPreloaded ??
      (jsonDecode(await (_marks ??= rootBundle.loadString(marksAsset)))
          as Map<String, dynamic>);
  static Future<String>? _marks;
  static Map<String, dynamic>? _marksPreloaded;
  static const marksAsset = 'assets/manual/marks.json';

  /// The marks, given without reading the asset: for tests.
  static void preloadMarks(String source) =>
      _marksPreloaded = jsonDecode(source) as Map<String, dynamic>;

  /// The exhibit of [feature]: its screen as the app draws it, in
  /// [language] and on [side].
  static String picture(
    ManualFeature feature,
    AppLanguage language,
    Brightness side,
  ) => 'assets/manual/${language.name}-${side.name}/${feature.name}.webp';

  static Future<ShowcaseText> text(AppLanguage language) async =>
      ShowcaseText.parse(
        _preloaded ??
            await (_source ??= rootBundle.loadString(ShowcaseText.asset)),
        language,
      );
}

/// A feature of the app, as the manual tells of it: in the bar's order,
/// left to right, each with what belongs under it.
enum ManualFeature {
  menu(Glyph.menu),
  colours(Glyph.dayView),
  journalFile(Glyph.archive),
  today(Glyph.today),
  utilities(Glyph.utilities),
  bazi(Glyph.bazi, Utility.bazi),
  iching(Glyph.iching, Utility.iching),
  mangsa(Glyph.mangsa, Utility.mangsa),
  lintang(Glyph.lintang, Utility.lintang),
  salat(Glyph.salat, Utility.salat),
  hilal(Glyph.hilal, Utility.hilal),
  ephemeris(Glyph.sky, Utility.sky),
  planets(Glyph.planets, Utility.planets),
  stars(Glyph.stars, Utility.stars),
  light(Glyph.light, Utility.light),
  place(Glyph.place),
  calendar(Glyph.monthView),
  systems(null),
  reading(Glyph.expand),
  practice(Glyph.practice),
  reminders(Glyph.reminder),
  journal(Glyph.journal),
  entry(Glyph.edit),
  categories(Glyph.categories),
  search(Glyph.search);

  /// Its glyph on its card; none for the systems, which show the
  /// calendar the app is in.
  final Glyph? glyph;

  /// The utility it is, if it is one.
  final Utility? utility;

  const ManualFeature(this.glyph, [this.utility]);

  String get _key => 'manual.$name';
}

/// One page of a feature's large card.
///
/// Each is the exhibit and its placard: [marks], where given, are the
/// numbered markers on the picture, by part, each with its number.
typedef _Page = ({
  String title,
  Widget Function(BuildContext) body,
  Map<int, Rect> marks,
});

/// A wing of the manual: the features under one of the bar's rooms.
enum ManualGroup {
  menu(Glyph.menu, [
    ManualFeature.menu,
    ManualFeature.colours,
    ManualFeature.journalFile,
  ]),
  calendar(Glyph.monthView, [
    ManualFeature.calendar,
    ManualFeature.systems,
    ManualFeature.today,
    ManualFeature.reading,
  ]),
  utilities(Glyph.utilities, [
    ManualFeature.utilities,
    ManualFeature.bazi,
    ManualFeature.iching,
    ManualFeature.mangsa,
    ManualFeature.lintang,
    ManualFeature.salat,
    ManualFeature.hilal,
    ManualFeature.ephemeris,
    ManualFeature.planets,
    ManualFeature.stars,
    ManualFeature.light,
    ManualFeature.place,
  ]),
  practice(Glyph.practice, [ManualFeature.practice]),
  reminders(Glyph.reminder, [ManualFeature.reminders]),
  journal(Glyph.journal, [
    ManualFeature.journal,
    ManualFeature.entry,
    ManualFeature.categories,
    ManualFeature.search,
  ]);

  final Glyph glyph;
  final List<ManualFeature> features;

  const ManualGroup(this.glyph, this.features);

  String get _key => 'manual.group.$name';
}

/// The manual (owner, 22 October 2026): in place of a tutorial, every
/// feature, what it is, its buttons and what people use it for, as a
/// museum is walked.
///
///  * Lower panel: the wings, as cards, one per room of the bar; the one
///    at the centre is chosen.
///  * Main body: the chosen wing's exhibits, a thin row each, scrolled up
///    and down. A row touched opens its exhibit over the whole page
///    ([ManualTourScreen]).
class ManualScreen extends StatefulWidget {
  const ManualScreen({super.key});

  @override
  State<ManualScreen> createState() => _ManualScreenState();
}

class _ManualScreenState extends State<ManualScreen> {
  ManualGroup _group = ManualGroup.values.first;
  ShowcaseText? _text;
  AppLanguage? _language;
  Map<String, dynamic>? _marks;

  @override
  void initState() {
    super.initState();
    Manual.marks().then((marks) {
      if (mounted) setState(() => _marks = marks);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Strings.of(context).language;
    if (language != _language) {
      _language = language;
      Manual.text(language).then((text) {
        if (mounted && _language == language) setState(() => _text = text);
      });
    }
  }

  void _open(ManualFeature feature) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      fadeRoute<void>(
        context,
        (context) => ManualTourScreen(
          feature: feature,
          group: _group,
          text: _text!,
          marks: _marks ?? const {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final text = _text;
    final system = SystemScope.of(context).value;

    Widget glyphOf(ManualFeature feature, double size) => feature.glyph == null
        ? SystemGlyph(system: system, size: size, color: colors.textPrimary)
        : GlyphMark(
            glyph: feature.glyph!,
            size: size,
            color: colors.textPrimary,
          );

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: FourParts(
          top: TopBar(
            key: const ValueKey('manual-top-bar'),
            leading: TopBarTitle(
              label: text == null ? '' : text('manual.title'),
            ),
            subtitle: text == null ? '' : text('${_group._key}.name'),
          ),
          // The wing's exhibits, a thin row each.
          body: text == null
              ? const SizedBox.shrink()
              : ListView(
                  key: ValueKey('manual-rows-${_group.name}'),
                  padding: EdgeInsets.only(
                    bottom: spacing.md,
                    right: spacing.sm + 2,
                  ),
                  children: [
                    for (final (i, feature) in _group.features.indexed) ...[
                      if (i > 0) SizedBox(height: spacing.sm),
                      SmPressable(
                        key: ValueKey('manual-row-${feature.name}'),
                        onTap: () => _open(feature),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: spacing.md,
                            vertical: spacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            border: Border.all(color: colors.outline),
                            borderRadius: BorderRadius.circular(theme.radii.md),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                child: Center(child: glyphOf(feature, 20)),
                              ),
                              SizedBox(width: spacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      text('${feature._key}.name'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.type.body.copyWith(
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      text('${feature._key}.line'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.type.label.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
          panel: text == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: EdgeInsets.only(bottom: spacing.xs),
                  child: _GroupStrip(
                    chosen: _group,
                    name: (group) => text('${group._key}.name'),
                    line: (group) => text('${group._key}.line'),
                    onChosen: (group) => setState(() => _group = group),
                  ),
                ),
          bar: const RoomBar(),
        ),
      ),
    );
  }
}

/// One exhibit of the manual over the whole page, the panel's room
/// included: its pages swiped left and right (what it is, its buttons,
/// its uses, and for some what is good to know), each the screen's
/// picture and its placard; where the page is at the bottom left, and the
/// offer to go there at the bottom right. Back returns to the wing.
class ManualTourScreen extends StatefulWidget {
  final ManualFeature feature;
  final ManualGroup group;
  final ShowcaseText text;
  final Map<String, dynamic> marks;

  const ManualTourScreen({
    super.key,
    required this.feature,
    required this.group,
    required this.text,
    required this.marks,
  });

  @override
  State<ManualTourScreen> createState() => _ManualTourScreenState();
}

class _ManualTourScreenState extends State<ManualTourScreen> {
  PageController _pager = PageController();
  int _page = 0;
  bool? _sideways;

  // Turning the phone lays the pages out anew; they start again on the
  // page that was showing.
  PageController _pagerFor(bool sideways) {
    if (_sideways != null && _sideways != sideways) {
      final old = _pager;
      _pager = PageController(initialPage: _page);
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    _sideways = sideways;
    return _pager;
  }

  ManualFeature get feature => widget.feature;
  ShowcaseText get text => widget.text;
  Map<String, dynamic> get marks => widget.marks;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  // The keys under [prefix], in the file's order.
  List<String> _under(String prefix) => [
    for (final key in text.keys)
      if (key.startsWith(prefix)) key,
  ];

  List<_Page> _pages(String version) {
    final key = feature._key;
    final buttons = _under('$key.button.');
    final uses = _under('$key.use.');
    final tip = _under('$key.tip');
    // Where the parts stand on this version's picture; the buttons the
    // picture shows are numbered in the order the placard names them.
    final where =
        ((marks[version] as Map<String, dynamic>?)?[feature.name]
            as Map<String, dynamic>?) ??
        const {};
    final numbers = <String, int>{};
    for (final button in buttons) {
      final name = button.split('.').last;
      if (where.containsKey(name)) numbers[name] = numbers.length + 1;
    }
    const none = <int, Rect>{};
    return [
      (
        title: text('manual.pageWhat'),
        body: (context) => _Words(text('$key.what')),
        marks: none,
      ),
      if (buttons.isNotEmpty)
        (
          title: text('manual.pageButtons'),
          body: (context) => _Buttons([
            for (final button in buttons)
              (
                name: button.split('.').last,
                words: text(button),
                number: numbers[button.split('.').last],
              ),
          ]),
          marks: {
            for (final MapEntry(key: name, value: number) in numbers.entries)
              number: _shareRect(where[name] as List),
          },
        ),
      if (uses.isNotEmpty)
        (
          title: text('manual.pageUses'),
          body: (context) => _Uses([for (final use in uses) text(use)]),
          marks: none,
        ),
      if (tip.isNotEmpty)
        (
          title: text('manual.pageTip'),
          body: (context) => _Words(text(tip.single)),
          marks: none,
        ),
    ];
  }

  // A part's place on its picture: its centre and size as shares of the
  // picture's (or, from an older marks file, its centre alone).
  static Rect _shareRect(List at) => Rect.fromCenter(
    center: Offset((at[0] as num).toDouble(), (at[1] as num).toDouble()),
    width: at.length > 2 ? (at[2] as num).toDouble() : 0,
    height: at.length > 3 ? (at[3] as num).toDouble() : 0,
  );

  /// Takes the user to [feature]: an offer, made by the card's button.
  void _takeThere(BuildContext context) {
    final house = House.maybeOf(context);
    if (house == null) return;
    final system = SystemScope.of(context);
    HapticFeedback.selectionClick();
    switch (feature) {
      case ManualFeature.menu:
        house.toRoomItself(Room.menu);
      case ManualFeature.colours:
        Navigator.of(context).pushReplacement(
          fadeRoute<void>(context, (context) => const ColoursScreen()),
        );
      case ManualFeature.journalFile:
        Navigator.of(context).pushReplacement(
          fadeRoute<void>(context, (context) => const JournalFileScreen()),
        );
      case ManualFeature.today ||
          ManualFeature.calendar ||
          ManualFeature.reading:
        house.homeWith(LivingCards.none);
      case ManualFeature.systems:
        house.homeWith(LivingCards.systems);
      case ManualFeature.utilities || ManualFeature.place:
        house.homeWith(LivingCards.utilities);
      case ManualFeature.practice:
        house.go(Room.practice);
      case ManualFeature.reminders:
        house.go(Room.reminders);
      case ManualFeature.journal || ManualFeature.entry || ManualFeature.search:
        house.go(Room.journal);
      case ManualFeature.categories:
        house.openIn(
          Room.journal,
          fadeRoute<void>(context, (context) => const CategoriesScreen()),
        );
      default:
        // A utility: under its own calendar, with the cards up.
        system.value = feature.utility!.system;
        house.homeWith(LivingCards.utilities);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final language = Strings.of(context).language;
    final side = AppearanceScope.of(context)
        .of(MediaQuery.platformBrightnessOf(context));
    final pages = _pages('${language.name}-${side.name}');
    final name = text('${feature._key}.name');
    final sideways = FourParts.sideways(context);

    final card = Padding(
      padding: EdgeInsets.all(spacing.md),
      child: _FeatureCard(
        key: ValueKey('manual-card-${feature.name}'),
        name: name,
        pages: pages,
        picture: Manual.picture(feature, language, side),
        takeThere: text('manual.takeMeThere'),
        onTakeThere: () => _takeThere(context),
        pager: _pagerFor(sideways),
        page: _page,
        onPage: (page) => setState(() => _page = page),
        withPlacard: !sideways,
      ),
    );

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: sideways
            // On its side: the picture, the dots and the offer on the
            // left; every word in the column on the right, over the bar
            // (owner, 22 October 2026). The page turns on the picture,
            // and the words follow it.
            ? Row(
                children: [
                  Expanded(child: card),
                  Container(width: 1, color: colors.outline),
                  SizedBox(
                    width: FourParts.columnWidth,
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: spacing.md),
                            child: AnimatedSwitcher(
                              duration: theme.motion.fast,
                              child: _Placard(
                                key: ValueKey(_page),
                                name: name,
                                page: pages[_page.clamp(0, pages.length - 1)],
                              ),
                            ),
                          ),
                        ),
                        const RoomBar(),
                      ],
                    ),
                  ),
                ],
              )
            // Upright, no top bar: the exhibit takes the page, the panel's
            // room included.
            : FourParts.fitted(
                top: const SizedBox.shrink(),
                body: card,
                bar: const RoomBar(),
              ),
      ),
    );
  }
}

/// A feature's exhibit card: its pages swiped left and right, each the
/// screen's picture, with where the page is at the bottom left and the
/// offer to go there at the bottom right. Upright the page's placard (its
/// name, then its words) is under the picture, in the card; on its side
/// the placard stands in the column on the right instead
/// ([ManualTourScreen]), and the card holds the picture alone.
class _FeatureCard extends StatelessWidget {
  final String name;
  final List<_Page> pages;
  final String picture;
  final String takeThere;
  final VoidCallback onTakeThere;
  final PageController pager;
  final int page;
  final ValueChanged<int> onPage;
  final bool withPlacard;

  const _FeatureCard({
    super.key,
    required this.name,
    required this.pages,
    required this.picture,
    required this.takeThere,
    required this.onTakeThere,
    required this.pager,
    required this.page,
    required this.onPage,
    required this.withPlacard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;

    return Container(
      key: const ValueKey('manual-card'),
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
              key: const ValueKey('manual-pages'),
              controller: pager,
              itemCount: pages.length,
              onPageChanged: (page) {
                HapticFeedback.selectionClick();
                onPage(page);
              },
              itemBuilder: (context, index) {
                final picture = Padding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.md,
                    spacing.md,
                    spacing.md,
                    spacing.sm,
                  ),
                  child: _Picture(
                    picture: this.picture,
                    marks: pages[index].marks,
                  ),
                );
                if (!withPlacard) return picture;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 7, child: picture),
                    Expanded(
                      flex: 3,
                      child: _Placard(name: name, page: pages[index]),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.md, spacing.md),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  // Where the page is among the feature's pages.
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: theme.motion.fast,
                      width: i == page ? 16 : 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: i == page ? colors.accent : colors.outline,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  const Spacer(),
                  BarButton(
                    key: const ValueKey('manual-take-there'),
                    label: takeThere,
                    compact: true,
                    onTap: onTakeThere,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A page's placard: its name in the accent, and its words under it,
/// scrolled when they are longer than the room; the scroll's bar kept
/// well clear of them.
class _Placard extends StatelessWidget {
  final String name;
  final _Page page;

  const _Placard({super.key, required this.name, required this.page});

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    return Padding(
      padding: EdgeInsets.fromLTRB(spacing.lg, spacing.sm, spacing.sm, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$name · ${page.title}'.toUpperCase(),
            key: const ValueKey('manual-placard-title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.type.caption.copyWith(
              color: theme.colors.accent,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: spacing.sm),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(right: spacing.lg, bottom: spacing.md),
              child: page.body(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// A feature's screen as the app draws it, and on it, for the buttons
/// page, each part the placard names: outlined where it stands, and its
/// number set clear of it with a line between, as the guide once joined
/// its names to their buttons, so the part itself is never covered.
class _Picture extends StatelessWidget {
  final String picture;
  final Map<int, Rect> marks;

  /// The pictures' shape: an iPhone upright (440 x 956 points).
  static const aspect = 440 / 956;

  const _Picture({required this.picture, required this.marks});

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    return Center(
      child: AspectRatio(
        aspectRatio: aspect,
        child: Container(
          key: const ValueKey('manual-exhibit'),
          decoration: BoxDecoration(
            border: Border.all(color: colors.outline),
            borderRadius: BorderRadius.circular(theme.radii.md),
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, room) {
              final size = Size(room.maxWidth, room.maxHeight);
              final placed = _Marks.place(marks, size);
              final marker = _Marks.markerOf(size.width);
              return Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      picture,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stack) =>
                          ColoredBox(color: colors.surfaceRaised),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MarksPainter(placed, colors.accent),
                    ),
                  ),
                  for (final mark in placed)
                    Positioned(
                      left: mark.label.dx - marker / 2,
                      top: mark.label.dy - marker / 2,
                      child: _Marker(
                        mark.number,
                        key: ValueKey('manual-marker-${mark.number}'),
                        size: marker,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Where a marked part's outline, line and number stand on a picture.
typedef _Placed = ({int number, Rect frame, Offset from, Offset label});

abstract final class _Marks {
  /// A number's size on a picture [width] wide.
  static double markerOf(double width) => (width * 0.055).clamp(14.0, 22.0);

  /// Puts each part's number clear of every part, on the side of it away
  /// from the picture's nearer edge (above what is low, under what is
  /// high, beside what is in the middle), further out when it would touch
  /// another number, and never off the picture.
  static List<_Placed> place(Map<int, Rect> marks, Size size) {
    final m = markerOf(size.width);
    final frames = {
      for (final MapEntry(key: number, value: share) in marks.entries)
        number: Rect.fromLTRB(
          share.left * size.width,
          share.top * size.height,
          share.right * size.width,
          share.bottom * size.height,
        ).inflate(2),
    };
    final placed = <_Placed>[];
    for (final number in frames.keys.toList()..sort()) {
      final frame = frames[number]!;
      final c = frame.center;
      final (dir, from) = c.dy > size.height * 0.6
          ? (const Offset(0, -1), Offset(c.dx, frame.top))
          : c.dy < size.height * 0.4
          ? (const Offset(0, 1), Offset(c.dx, frame.bottom))
          : c.dx > size.width / 2
          ? (const Offset(-1, 0), Offset(frame.left, c.dy))
          : (const Offset(1, 0), Offset(frame.right, c.dy));
      var label = from;
      for (var step = 0; step < 10; step++) {
        final out = from + dir * (m * 1.4 + m / 2 + step * m * 1.15);
        label = Offset(
          out.dx.clamp(m / 2 + 1, size.width - m / 2 - 1),
          out.dy.clamp(m / 2 + 1, size.height - m / 2 - 1),
        );
        final disc = Rect.fromCircle(center: label, radius: m / 2 + 2);
        final clear =
            placed.every((p) => (p.label - label).distance > m * 1.15) &&
            frames.values.every((f) => !f.overlaps(disc));
        if (clear) break;
      }
      placed.add((number: number, frame: frame, from: from, label: label));
    }
    return placed;
  }
}

class _MarksPainter extends CustomPainter {
  final List<_Placed> placed;
  final Color color;

  _MarksPainter(this.placed, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final line = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    for (final mark in placed) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(mark.frame, const Radius.circular(6)),
        outline,
      );
      canvas.drawLine(mark.from, mark.label, line);
    }
  }

  @override
  bool shouldRepaint(_MarksPainter old) =>
      old.color != color || old.placed != placed;
}

/// A numbered marker, as on a museum's plan: on the picture, clear of the
/// part it names, and beside that part's line in the placard.
class _Marker extends StatelessWidget {
  final int number;
  final double size;

  const _Marker(this.number, {super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: colors.background, width: size / 12),
      ),
      child: Text(
        '$number',
        style: theme.type.caption.copyWith(
          color: colors.background,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.5,
          height: 1,
        ),
      ),
    );
  }
}

/// A page of plain words, Markdown and all.
class _Words extends StatelessWidget {
  final String text;

  const _Words(this.text);

  /// A placard narrower than this, a phone's beside its picture, is set
  /// smaller, so its lines are not a word or two long.
  static const narrow = 280.0;

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    return LayoutBuilder(
      builder: (context, room) => Text.rich(
        Markdown.span(
          text,
          (room.maxWidth < narrow ? theme.type.label : theme.type.body)
              .copyWith(color: theme.colors.textPrimary, height: 1.5),
          colors: theme.colors,
          showMarks: false,
        ),
      ),
    );
  }
}

/// A feature's uses, one after another, a little apart.
class _Uses extends StatelessWidget {
  final List<String> uses;

  const _Uses(this.uses);

  @override
  Widget build(BuildContext context) {
    final spacing = SmTheme.of(context).spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, use) in uses.indexed) ...[
          if (i > 0) SizedBox(height: spacing.lg),
          _Words(use),
        ],
      ],
    );
  }
}

/// A feature's buttons: each drawn as it stands in the app, with a line
/// on what it does.
class _Buttons extends StatelessWidget {
  final List<({String name, String words, int? number})> buttons;

  const _Buttons(this.buttons);

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final system = SystemScope.of(context).value;

    Widget picture(String name) {
      final glyph = Glyph.values.where((g) => g.name == name).firstOrNull;
      if (glyph != null) {
        return GlyphMark(glyph: glyph, size: 18, color: colors.textPrimary);
      }
      return switch (name) {
        // The bar's centre: the calendar the app is in.
        'system' => SystemGlyph(
          system: system,
          size: 20,
          color: colors.textPrimary,
        ),
        // The month button: its chevron.
        _ => Text(
          '▾',
          style: theme.type.body.copyWith(color: colors.textPrimary),
        ),
      };
    }

    // Where the placard is narrow, each button's number and glyph stand
    // over its words, which then have the whole width.
    // As a button of the bar: framed, the glyph in the middle.
    Widget frame(String name) => Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(theme.radii.md),
      ),
      child: picture(name),
    );

    return LayoutBuilder(
      builder: (context, room) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, button) in buttons.indexed) ...[
            if (i > 0) SizedBox(height: spacing.md),
            if (room.maxWidth < _Words.narrow) ...[
              Row(
                children: [
                  if (button.number != null) ...[
                    _Marker(button.number!),
                    SizedBox(width: spacing.sm),
                  ],
                  frame(button.name),
                ],
              ),
              SizedBox(height: spacing.xs),
              _Words(button.words),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Its number on the picture, where the picture shows it.
                  SizedBox(
                    width: 24,
                    child: button.number == null
                        ? null
                        : _Marker(button.number!),
                  ),
                  SizedBox(width: spacing.sm),
                  frame(button.name),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: _Words(button.words),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

/// The manual's wings as cards in a row, the chosen one at the centre. Where the lower panel is tall (a
/// tablet on its side) they run down it instead.
class _GroupStrip extends StatefulWidget {
  final ManualGroup chosen;
  final String Function(ManualGroup group) name;
  final String Function(ManualGroup group) line;
  final ValueChanged<ManualGroup> onChosen;

  const _GroupStrip({
    required this.chosen,
    required this.name,
    required this.line,
    required this.onChosen,
  });

  @override
  State<_GroupStrip> createState() => _GroupStripState();
}

class _GroupStripState extends State<_GroupStrip> {
  PageController? _controller;
  bool? _tall;

  PageController get _pages => _controller!;

  // Made for the way the strip runs, and made again, on the same card, if
  // a tablet is turned and the strip changes direction.
  PageController _pagesFor(bool tall) {
    if (tall == _tall) return _pages;
    final old = _controller;
    _tall = tall;
    _controller = PageController(
      viewportFraction: tall ? 1 / 4 : 0.46,
      initialPage: old != null && old.hasClients
          ? old.page!.round()
          : ManualGroup.values.indexOf(widget.chosen),
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
      padding: tall
          ? EdgeInsets.symmetric(horizontal: spacing.md)
          : EdgeInsets.symmetric(vertical: spacing.sm),
      child: PageView.builder(
        key: const ValueKey('manual-strip'),
        controller: pages,
        scrollDirection: tall ? Axis.vertical : Axis.horizontal,
        // A flick carries it on over several wings, to rest on one.
        pageSnapping: false,
        physics: InertialSnapPhysics.pages(tall ? 1 / 4 : 0.46),
        itemCount: ManualGroup.values.length,
        onPageChanged: (index) {
          HapticFeedback.selectionClick();
          widget.onChosen(ManualGroup.values[index]);
        },
        itemBuilder: (context, index) {
          final group = ManualGroup.values[index];
          return GestureDetector(
            key: ValueKey('manual-group-${group.name}'),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlyphMark(
                    glyph: group.glyph,
                    size: 22,
                    color: colors.textPrimary,
                  ),
                  const Spacer(),
                  Text(
                    widget.name(group),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.type.body.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    widget.line(group),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.type.label.copyWith(
                      color: colors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The note shown once, the first time the app opens, over the lower
/// panel: where the manual is, and nothing more (owner, 22 October 2026:
/// show where it is, then leave people to explore).
class ManualOffer extends StatelessWidget {
  const ManualOffer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final strings = Strings.of(context);

    return ColoredBox(
      key: const ValueKey('manual-offer'),
      color: colors.background,
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: FutureBuilder(
          future: Manual.text(strings.language),
          builder: (context, text) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                text.data?.call('manual.offer') ?? '',
                textAlign: TextAlign.center,
                style: theme.type.body.copyWith(color: colors.textPrimary),
              ),
              SizedBox(height: spacing.md),
              Center(
                child: BarButton(
                  key: const ValueKey('manual-offer-ok'),
                  label: strings.manualGotIt,
                  compact: true,
                  primary: true,
                  onTap: () => Manual.offered.value = false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
