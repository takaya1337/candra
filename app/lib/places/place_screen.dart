import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import '../glyph_button.dart';
import '../house.dart';
import '../parts.dart';
import '../routes.dart';
import '../sky_place.dart';
import '../strings.dart';
import 'kecamatan_outlines.dart';
import 'place_catalog.dart';
import 'world_map.dart';

/// Opens the place picker.
Future<void> pushPlace(BuildContext context) =>
    Navigator.of(context)
        .push(fadeRoute<void>(context, (context) => const PlaceScreen()));

/// Where the sky, the prayer times and the rest are worked out for,
/// picked by name or on the map, offline.
///
///  * Top bar: the name, and the place chosen with the named place
///    nearest it.
///  * Main body: the world map, the place chosen as a pin and the places
///    found as dots; near enough, Indonesia's kecamatan, the one the
///    place is in lit. A touch in Indonesia picks the kecamatan it falls
///    in, the place going to the point inside it the catalogue gives;
///    elsewhere it puts the place where it fell. Two fingers move and
///    zoom it.
///  * Lower panel: the places found by the words in the bar, or, with
///    none, the named places nearest the pin. A touch picks one.
///  * Bottom bar: back, and the words to find a place by.
///
/// The place is rounded to 0.1°, as wherever it is set.
class PlaceScreen extends StatefulWidget {
  const PlaceScreen({super.key});

  @override
  State<PlaceScreen> createState() => _PlaceScreenState();
}

class _PlaceScreenState extends State<PlaceScreen> {
  PlaceCatalog? _catalog;
  KecamatanOutlines? _kecamatan;
  Path? _outline;
  final _query = TextEditingController();
  final _queryFocus = FocusNode();
  ValueNotifier<MapView>? _view;

  @override
  void initState() {
    super.initState();
    PlaceCatalog.load().then((c) {
      if (mounted) setState(() => _catalog = c);
    });
    KecamatanOutlines.load().then((k) {
      if (mounted) setState(() => _kecamatan = k);
    });
    WorldOutline.load().then((o) {
      if (mounted) setState(() => _outline = o);
    });
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    _queryFocus.dispose();
    _view?.dispose();
    super.dispose();
  }

  void _set(double latitude, double longitude, {bool centre = false}) {
    final place = SkyPlace.rounded(latitude, longitude);
    SkyPlace.current.value = place;
    final view = _view;
    if (centre && view != null) {
      final v = view.value;
      view.value = (
        longitude: place.longitude,
        latitude: place.latitude,
        scale: v.scale < 20 ? 20 : v.scale,
      );
    }
  }

  void _pick(int i, {bool centre = true}) {
    final catalog = _catalog!;
    HapticFeedback.selectionClick();
    _queryFocus.unfocus();
    _set(catalog.latitude[i], catalog.longitude[i], centre: centre);
    PlaceCatalog.picked = (index: i, at: SkyPlace.current.value!);
  }

  // A touch on the map: in Indonesia, the kecamatan it falls in (its
  // named point, so coarse by design); elsewhere, or off every outline,
  // the point itself.
  void _touch(double latitude, double longitude) {
    _queryFocus.unfocus();
    final region = _catalog == null || !Indonesia.has(latitude, longitude)
        ? null
        : _kecamatan?.at(latitude, longitude);
    if (region != null) {
      _pick(region.row, centre: false);
    } else {
      _set(latitude, longitude);
    }
  }

  // The kecamatan the place is in: the one picked there, else the one
  // that holds it.
  KecamatanOutline? _chosen(({double latitude, double longitude})? place) {
    final regions = _kecamatan;
    if (regions == null || place == null) return null;
    final picked = PlaceCatalog.picked;
    if (picked != null && picked.at == place) {
      final own = regions.ofRow(picked.index);
      if (own != null) return own;
    }
    if (!Indonesia.has(place.latitude, place.longitude)) return null;
    return regions.at(place.latitude, place.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final strings = Strings.of(context);

    return ValueListenableBuilder(
      valueListenable: SkyPlace.current,
      builder: (context, place, _) {
        final catalog = _catalog;
        final words = _query.text.trim();
        final abroad =
            place != null && !Indonesia.has(place.latitude, place.longitude);
        final found = catalog == null
            ? const <int>[]
            : words.isNotEmpty
            ? catalog.find(words, indonesiaFirst: !abroad)
            : place == null
            ? const <int>[]
            : catalog.nearest(place.latitude, place.longitude);
        final nearest = catalog == null || place == null
            ? null
            : catalog.nameFor(place);

        return ColoredBox(
          color: colors.background,
          child: SafeArea(
            child: FourParts(
              top: TopBar(
                key: const ValueKey('place-top-bar'),
                leading: TopBarTitle(label: strings.skyPlaceTab),
                subtitle: place == null
                    ? strings.skyNoPlace
                    : nearest == null
                    ? SkyPlace.label(place)
                    : '${SkyPlace.label(place)} · '
                          '${strings.placeNear(catalog!.name[nearest])}',
              ),
              body: LayoutBuilder(
                builder: (context, constraints) {
                  _view ??= ValueNotifier(
                    viewOf(
                      place ?? (latitude: -2.5, longitude: 118.0),
                      constraints.maxWidth,
                      degrees: place == null ? 50 : 12,
                    ),
                  );
                  return WorldMap(
                    key: const ValueKey('place-map'),
                    outline: _outline,
                    view: _view!,
                    pin: place,
                    dots: [
                      if (catalog != null && words.isNotEmpty)
                        for (final i in found)
                          (
                            latitude: catalog.latitude[i].toDouble(),
                            longitude: catalog.longitude[i].toDouble(),
                          ),
                    ],
                    kecamatan: _kecamatan,
                    chosen: _chosen(place),
                    onPick: _touch,
                  );
                },
              ),
              // The search at the panel's top, over what it finds; the
              // keyboard lifts the panel with it.
              panel: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      spacing.md,
                      spacing.md,
                      spacing.md,
                      0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: spacing.md,
                              vertical: spacing.sm + 1,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: colors.outline),
                              borderRadius: BorderRadius.circular(
                                theme.radii.md,
                              ),
                            ),
                            child: SmTextField(
                              key: const ValueKey('place-query'),
                              controller: _query,
                              focusNode: _queryFocus,
                              labels: strings.textToolbar,
                              placeholder: strings.placeSearchPlaceholder,
                              plain: true,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _queryFocus.unfocus(),
                              style: theme.type.body.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        if (words.isNotEmpty) ...[
                          SizedBox(width: spacing.sm),
                          GlyphButton(
                            key: const ValueKey('place-query-clear'),
                            glyph: Glyph.close,
                            square: true,
                            onTap: () => _query.clear(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(child: _list(theme, strings, catalog, found, words)),
                ],
              ),
              bar: const RoomBar(),
            ),
          ),
        );
      },
    );
  }

  // The places found, or near the pin: each its name, what it is in, and
  // where. A touch picks it.
  Widget _list(
    SmThemeData theme,
    Strings strings,
    PlaceCatalog? catalog,
    List<int> found,
    String words,
  ) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    if (catalog == null) return const SizedBox.expand();
    if (found.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Text(
            words.isEmpty ? strings.placeMapHint : strings.placeNoneFound,
            key: const ValueKey('place-empty'),
            textAlign: TextAlign.center,
            style: theme.type.label.copyWith(color: colors.textFaint),
          ),
        ),
      );
    }
    return ListView(
      key: const ValueKey('place-list'),
      padding: EdgeInsets.symmetric(vertical: spacing.xs),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.md,
            spacing.xs,
            spacing.md,
            spacing.xs,
          ),
          child: Text(
            (words.isEmpty ? strings.placeNearPin : strings.placeFound)
                .toUpperCase(),
            style: theme.type.caption.copyWith(
              color: colors.textFaint,
              letterSpacing: 1.2,
            ),
          ),
        ),
        for (final i in found)
          GestureDetector(
            key: ValueKey('place-row-$i'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _pick(i),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.md,
                vertical: spacing.xs + 2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          catalog.name[i],
                          style: theme.type.body.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          catalog.area[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.type.caption.copyWith(
                            color: colors.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: spacing.sm),
                  Text(
                    SkyPlace.label(
                      SkyPlace.rounded(
                        catalog.latitude[i].toDouble(),
                        catalog.longitude[i].toDouble(),
                      ),
                    ),
                    style: theme.type.caption.copyWith(
                      color: colors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
