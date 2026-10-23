import 'package:flutter/widgets.dart';

import 'bazi_places.dart';
import 'two_wheels.dart';

/// Two wheels: the region, and the city whose clock the chart is read
/// by. The first region is not a place at all but a plain offset from
/// Greenwich, for a birth record kept by some other convention than the
/// database knows.
class PlacePicker extends StatefulWidget {
  final BaziPlaces places;

  /// The zone chosen, or null when a plain offset is.
  final String? zone;

  /// The plain offset; the one shown when [zone] is null.
  final Duration offset;
  final ValueChanged<String> onZone;
  final ValueChanged<Duration> onOffset;

  const PlacePicker({
    super.key,
    required this.places,
    required this.zone,
    required this.offset,
    required this.onZone,
    required this.onOffset,
  });

  @override
  State<PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<PlacePicker> {
  late final _regions = [BaziPlaces.manual, ...widget.places.regions];

  // Where each region's wheel was left, so coming back to it finds the
  // same city.
  late final _left = <int, int>{
    if (widget.zone != null)
      _regionOf(widget.zone!): _zones(_regionOf(widget.zone!))
          .indexOf(widget.zone!),
  };

  int _regionOf(String zone) => _regions.indexOf(BaziPlaces.regionOf(zone));

  List<String> _zones(int region) => widget.places.zonesIn(_regions[region]);

  int _nearestOffset() {
    var nearest = 0;
    for (var i = 0; i < BaziPlaces.offsets.length; i++) {
      if ((BaziPlaces.offsets[i] - widget.offset).abs() <
          (BaziPlaces.offsets[nearest] - widget.offset).abs()) {
        nearest = i;
      }
    }
    return nearest;
  }

  @override
  Widget build(BuildContext context) => TwoWheels(
    name: 'picker-place',
    headings: _regions,
    under: (region) => region == 0
        ? [for (final offset in BaziPlaces.offsets) BaziPlaces.label(offset)]
        : [for (final zone in _zones(region)) BaziPlaces.cityOf(zone)],
    heading: widget.zone == null ? 0 : _regionOf(widget.zone!),
    // A plain offset starts from what the clock there already stood at.
    chosen: (region) => region == 0 ? _nearestOffset() : _left[region] ?? 0,
    onChanged: (region, index) {
      _left[region] = index;
      if (region == 0) {
        widget.onOffset(BaziPlaces.offsets[index]);
      } else {
        widget.onZone(_zones(region)[index]);
      }
    },
  );
}
