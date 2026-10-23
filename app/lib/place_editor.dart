import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import 'glyph_button.dart';
import 'journal/geo.dart';
import 'places/place_catalog.dart';
import 'places/place_screen.dart';
import 'sky_place.dart';
import 'step_field.dart';
import 'strings.dart';

/// The place the sky is worked out for, as a lower panel: the latitude
/// and the longitude, each stepped a tenth of a degree at a time (held,
/// faster), and the pin, which takes both from the phone. It sets
/// [SkyPlace.current], which the calendar's sky shares.
class PlaceEditor extends StatefulWidget {
  final Strings strings;

  const PlaceEditor({super.key, required this.strings});

  @override
  State<PlaceEditor> createState() => _PlaceEditorState();
}

class _PlaceEditorState extends State<PlaceEditor> {
  bool _finding = false;
  String? _problem;

  Future<void> _useHere() async {
    final strings = widget.strings;
    if (_finding) {
      Locator.current.cancel();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _finding = true;
      _problem = null;
    });
    try {
      final fix = await Locator.current.find();
      SkyPlace.current.value = SkyPlace.rounded(fix.latitude, fix.longitude);
      if (mounted) setState(() => _finding = false);
    } on LocateFailed catch (failed) {
      if (!mounted) return;
      setState(() {
        _finding = false;
        _problem = switch (failed.problem) {
          LocateProblem.denied => strings.placeDenied,
          LocateProblem.off => strings.placeOff,
          LocateProblem.timeout => strings.placeTimeout,
          LocateProblem.sky => strings.placeNeedsSky,
          LocateProblem.unavailable => strings.placeUnavailable,
          LocateProblem.cancelled => null,
        };
      });
    }
  }

  @override
  void dispose() {
    if (_finding) Locator.current.cancel();
    super.dispose();
  }

  // Steps are tenths of a degree. Latitude stops at the poles; longitude
  // goes round.
  void _step({int latitude = 0, int longitude = 0}) {
    final place = SkyPlace.current.value ?? (latitude: 0.0, longitude: 0.0);
    var tenthsEast = (place.longitude * 10).round() + longitude;
    tenthsEast = (tenthsEast + 1800) % 3600 - 1800;
    final tenthsNorth = ((place.latitude * 10).round() + latitude).clamp(
      -900,
      900,
    );
    SkyPlace.current.value = SkyPlace.rounded(
      tenthsNorth / 10,
      tenthsEast / 10,
    );
  }

  static String _degrees(double value, String positive, String negative) =>
      '${value.abs().toStringAsFixed(1)}° ${value < 0 ? negative : positive}';

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final strings = widget.strings;
    final points = strings.compassFour;

    return ValueListenableBuilder(
      valueListenable: SkyPlace.current,
      builder: (context, place, _) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          spacing.md,
          spacing.sm,
          spacing.md,
          spacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: StepField(
                    name: 'place-latitude',
                    label: strings.skyLatitude,
                    hold: true,
                    value: place == null
                        ? '—'
                        : _degrees(place.latitude, points[0], points[2]),
                    onStep: (by) => _step(latitude: by),
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: StepField(
                    name: 'place-longitude',
                    label: strings.skyLongitude,
                    hold: true,
                    value: place == null
                        ? '—'
                        : _degrees(place.longitude, points[1], points[3]),
                    onStep: (by) => _step(longitude: by),
                  ),
                ),
                SizedBox(width: spacing.sm),
                GlyphButton(
                  key: const ValueKey('place-here'),
                  glyph: Glyph.place,
                  square: true,
                  marked: _finding,
                  onTap: _useHere,
                ),
              ],
            ),
            SizedBox(height: spacing.sm),
            // The named place nearest, and the way to find one by name or
            // on the map.
            GestureDetector(
              key: const ValueKey('place-find'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                pushPlace(context);
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.md,
                  vertical: spacing.sm,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.outline),
                  borderRadius: BorderRadius.circular(theme.radii.md),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FutureBuilder(
                        future: PlaceCatalog.load(),
                        builder: (context, snapshot) {
                          final catalog = snapshot.data;
                          final near = catalog == null || place == null
                              ? null
                              : catalog.nameFor(place);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                near == null
                                    ? strings.placeFind
                                    : strings.placeNear(catalog!.name[near]),
                                key: const ValueKey('place-near'),
                                style: theme.type.body.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              if (near != null)
                                Text(
                                  catalog!.area[near],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.type.caption.copyWith(
                                    color: colors.textFaint,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    SizedBox(width: spacing.sm),
                    GlyphMark(
                      glyph: Glyph.search,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing.sm),
            Text(
              _finding
                  ? strings.skyFinding
                  : _problem ??
                        (place == null
                            ? '${strings.skyNoPlace}. ${strings.skyPlaceNote}'
                            : strings.skyPlaceNote),
              key: const ValueKey('place-note'),
              style: theme.type.caption.copyWith(
                color: colors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
