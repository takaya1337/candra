import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// The named places a place can be picked by, read once from the app's
/// own file (`assets/places/places.tsv`, sources in
/// `docs/provenance/places/notes.md`) and kept while the app runs:
/// Indonesia to the kecamatan, and the world's towns of 15,000 people or
/// more. Nothing is looked up anywhere else.
class PlaceCatalog {
  final List<String> name;

  /// What it is in: "Kecamatan · Kota Bandung, Jawa Barat", "Bavaria,
  /// Germany".
  final List<String> area;

  /// ISO 3166 code of its country.
  final List<String> country;
  final Float32List latitude;
  final Float32List longitude;

  // The name and area folded for matching: lower case, no accents.
  final List<String> _folded;

  PlaceCatalog._({
    required this.name,
    required this.area,
    required this.country,
    required this.latitude,
    required this.longitude,
  }) : _folded = [for (var i = 0; i < name.length; i++) fold(name[i])];

  int get length => name.length;

  static Future<PlaceCatalog>? _loading;

  /// The catalogue, read the first time it is asked for.
  static Future<PlaceCatalog> load() => _loading ??= _read();

  /// For tests: forget what was read.
  static void reset() => _loading = null;

  static Future<PlaceCatalog> _read() async {
    final text = await rootBundle.loadString('assets/places/places.tsv');
    return Isolate.run(() => parse(text));
  }

  /// The catalogue from the text of its file.
  static PlaceCatalog parse(String tsv) {
    final rows = const LineSplitter().convert(tsv).skip(1).toList();
    final n = rows.length;
    final name = List.filled(n, '');
    final area = List.filled(n, '');
    final country = List.filled(n, '');
    final lat = Float32List(n);
    final lon = Float32List(n);
    for (var i = 0; i < n; i++) {
      final f = rows[i].split('\t');
      name[i] = f[0];
      area[i] = f[1];
      country[i] = f[2];
      lat[i] = double.parse(f[3]);
      lon[i] = double.parse(f[4]);
    }
    return PlaceCatalog._(
      name: name,
      area: area,
      country: country,
      latitude: lat,
      longitude: lon,
    );
  }

  /// Lower case, and the accented Latin letters plain, so "sao paulo"
  /// finds São Paulo.
  static String fold(String text) {
    const from = 'àáâãäåāăąçćčďèéêëēėęěìíîïīįłñńňòóôõöøōőŕřśšşţťùúûüūůűųýÿźżžß';
    const to = 'aaaaaaaaacccdeeeeeeeeiiiiiilnnnoooooooorrsssttuuuuuuuuyyzzzs';
    final lower = text.toLowerCase();
    final out = StringBuffer();
    for (final rune in lower.runes) {
      final c = String.fromCharCode(rune);
      final k = from.indexOf(c);
      out.write(k < 0 ? c : to[k]);
    }
    return out.toString();
  }

  /// The places that answer [query], at most [limit], best first: a name
  /// that is the words, then one that begins with them, then one with a
  /// word that does. Within each, Indonesia's first where
  /// [indonesiaFirst], else the world's towns (largest first) before
  /// Indonesia's kecamatan.
  List<int> find(String query, {int limit = 40, bool indonesiaFirst = true}) {
    final q = fold(query.trim());
    if (q.isEmpty) return const [];
    final exact = <int>[], starting = <int>[], worded = <int>[];
    for (var i = 0; i < length; i++) {
      final n = _folded[i];
      if (n == q) {
        exact.add(i);
      } else if (n.startsWith(q)) {
        starting.add(i);
      } else if (n.contains(' $q') || n.contains('-$q')) {
        worded.add(i);
      }
    }
    // The file is Indonesia first, then the world by size.
    List<int> order(List<int> group) => indonesiaFirst
        ? group
        : [
            ...group.where((i) => country[i] != 'ID'),
            ...group.where((i) => country[i] == 'ID'),
          ];
    return [
      ...order(exact),
      ...order(starting),
      ...order(worded),
    ].take(limit).toList();
  }

  /// The place last picked by name, and where it put the place: its name
  /// is shown for as long as the place stays there.
  static ({int index, ({double latitude, double longitude}) at})? picked;

  /// What to call [place]: the place picked there by name, else the named
  /// place nearest it (within 0.3°), else null.
  int? nameFor(({double latitude, double longitude}) place) {
    final p = picked;
    if (p != null && p.at == place) return p.index;
    return nearest(
      place.latitude,
      place.longitude,
      limit: 1,
      within: 0.3,
    ).firstOrNull;
  }

  /// The places nearest [lat], [lon], nearest first, at most [limit] and
  /// no farther than [within] degrees.
  List<int> nearest(
    double lat,
    double lon, {
    int limit = 12,
    double within = 1.0,
  }) {
    final found = <(double, int)>[];
    final reach = within * within;
    for (var i = 0; i < length; i++) {
      final dy = latitude[i] - lat;
      if (dy.abs() > within) continue;
      var dx = (longitude[i] - lon).abs();
      if (dx > 180) dx = 360 - dx;
      if (dx > within) continue;
      final d = dx * dx + dy * dy;
      if (d <= reach) found.add((d, i));
    }
    found.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final (_, i) in found.take(limit)) i];
  }
}
