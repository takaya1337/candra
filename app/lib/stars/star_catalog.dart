import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// The naked-eye stars and the constellation figures, read once from the
/// app's own files (`assets/stars/`, sources in
/// `docs/provenance/stars/notes.md`) and kept for as long as the app
/// runs.
///
/// The stars are held brightest first, in plain number arrays, so the
/// whole sky can be placed many times a second.
class StarCatalog {
  /// J2000 right ascension and declination, degrees.
  final Float64List rightAscension;
  final Float64List declination;

  /// Visual magnitude: the smaller, the brighter.
  final Float32List magnitude;

  /// Colour index B−V, or NaN where the catalogue has none.
  final Float32List colour;

  /// Constellation (three letters), Bayer and Flamsteed designations,
  /// proper name; empty where there is none.
  final List<String> constellation;
  final List<String> bayer;
  final List<String> flamsteed;
  final List<String> name;

  /// Hipparcos and Bright Star numbers; 0 where there is none.
  final Int32List hip;
  final Int32List hr;

  final List<Constellation> figures;

  StarCatalog._({
    required this.rightAscension,
    required this.declination,
    required this.magnitude,
    required this.colour,
    required this.constellation,
    required this.bayer,
    required this.flamsteed,
    required this.name,
    required this.hip,
    required this.hr,
    required this.figures,
  });

  int get length => magnitude.length;

  /// Which star, by place in the table, has Hipparcos number [number].
  int? byHip(int number) => (_byHip ??= {
    for (var i = 0; i < length; i++)
      if (hip[i] != 0) hip[i]: i,
  })[number];
  Map<int, int>? _byHip;

  static Future<StarCatalog>? _loading;

  /// The catalogue, read the first time it is asked for.
  static Future<StarCatalog> load() => _loading ??= _read();

  /// For tests: forget what was read.
  static void reset() => _loading = null;

  static Future<StarCatalog> _read() async {
    final stars = await rootBundle.loadString(
      'assets/stars/hyg_v44_naked_eye.csv',
    );
    final lines = await rootBundle.loadString(
      'assets/stars/constellations.json',
    );
    return Isolate.run(() => parse(stars, lines));
  }

  /// The catalogue from the text of its two files.
  static StarCatalog parse(String starsCsv, String figuresJson) {
    final rows = const LineSplitter().convert(starsCsv).skip(1).toList();
    final n = rows.length;
    final ra = Float64List(n);
    final dec = Float64List(n);
    final mag = Float32List(n);
    final ci = Float32List(n);
    final con = List.filled(n, '');
    final bayer = List.filled(n, '');
    final flam = List.filled(n, '');
    final proper = List.filled(n, '');
    final hip = Int32List(n);
    final hr = Int32List(n);
    for (var i = 0; i < n; i++) {
      final f = rows[i].split(',');
      ra[i] = double.parse(f[0]);
      dec[i] = double.parse(f[1]);
      mag[i] = double.parse(f[2]);
      ci[i] = f[3].isEmpty ? double.nan : double.parse(f[3]);
      con[i] = f[4];
      bayer[i] = f[5];
      flam[i] = f[6];
      hip[i] = int.tryParse(f[7]) ?? 0;
      hr[i] = int.tryParse(f[8]) ?? 0;
      // A name with a comma in it comes quoted.
      proper[i] = f.length > 9
          ? f.sublist(9).join(',').replaceAll('"', '')
          : '';
    }
    final figures = [
      for (final item in jsonDecode(figuresJson) as List)
        Constellation.fromJson(item as Map<String, dynamic>),
    ];
    return StarCatalog._(
      rightAscension: ra,
      declination: dec,
      magnitude: mag,
      colour: ci,
      constellation: con,
      bayer: bayer,
      flamsteed: flam,
      name: proper,
      hip: hip,
      hr: hr,
      figures: figures,
    );
  }

  /// What a star is called: its proper name, else its Bayer or Flamsteed
  /// designation with its constellation, else its Bright Star number.
  String labelOf(int i) {
    if (name[i].isNotEmpty) return name[i];
    final c = constellation[i];
    if (bayer[i].isNotEmpty) return '${_greek(bayer[i])} $c';
    if (flamsteed[i].isNotEmpty) return '${flamsteed[i]} $c';
    if (hr[i] != 0) return 'HR ${hr[i]}';
    return 'HIP ${hip[i]}';
  }

  /// The stars that answer [query], at most [limit], best first: those
  /// whose name or designation begins with it, then those that hold it
  /// anywhere (the constellation's Latin name too), each group brightest
  /// first. A number finds the star of that Bright Star or Hipparcos
  /// number.
  List<int> find(String query, {int limit = 40}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final number = int.tryParse(q.replaceAll(RegExp(r'^(hr|hip)\s*'), ''));
    final names = {
      for (final f in figures) f.id.toLowerCase(): f.name.toLowerCase(),
    };
    final starting = <int>[];
    final holding = <int>[];
    for (var i = 0; i < length; i++) {
      if (number != null && (hr[i] == number || hip[i] == number)) {
        starting.add(i);
        continue;
      }
      final label = labelOf(i).toLowerCase();
      final proper = name[i].toLowerCase();
      if (proper.startsWith(q) || label.startsWith(q)) {
        starting.add(i);
      } else if (proper.contains(q) ||
          label.contains(q) ||
          (names[constellation[i].toLowerCase()] ?? '').contains(q)) {
        holding.add(i);
      }
    }
    // The table is brightest first already: each group keeps that order.
    return [...starting, ...holding].take(limit).toList();
  }

  /// The named stars brighter than [magnitude], brightest first: the ones
  /// people know.
  List<int> brightNamed({double magnitude = 2.0}) => [
    for (var i = 0; i < length && this.magnitude[i] <= magnitude; i++)
      if (name[i].isNotEmpty) i,
  ];

  static const _letters = {
    'Alp': 'α', 'Bet': 'β', 'Gam': 'γ', 'Del': 'δ', 'Eps': 'ε', 'Zet': 'ζ', //
    'Eta': 'η', 'The': 'θ', 'Iot': 'ι', 'Kap': 'κ', 'Lam': 'λ', 'Mu': 'μ',
    'Nu': 'ν', 'Xi': 'ξ', 'Omi': 'ο', 'Pi': 'π', 'Rho': 'ρ', 'Sig': 'σ',
    'Tau': 'τ', 'Ups': 'υ', 'Phi': 'φ', 'Chi': 'χ', 'Psi': 'ψ', 'Ome': 'ω',
  };

  // "Alp-1" to "α¹".
  static String _greek(String bayer) {
    final [letter, ...rest] = bayer.split('-');
    final greek = _letters[letter] ?? letter;
    if (rest.isEmpty) return greek;
    const superscripts = ['⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹'];
    return greek +
        rest.first.split('').map((d) => superscripts[int.parse(d)]).join();
  }
}

/// One of the 88 constellations (Serpens in two): its Latin name, how
/// prominent its label is (1 the most), where its label stands, and its
/// stick figure as strokes of J2000 points.
class Constellation {
  final String id;
  final String name;
  final int rank;
  final double labelRightAscension;
  final double labelDeclination;

  /// Each stroke a run of points, right ascension then declination,
  /// degrees, J2000.
  final List<Float64List> strokes;

  const Constellation({
    required this.id,
    required this.name,
    required this.rank,
    required this.labelRightAscension,
    required this.labelDeclination,
    required this.strokes,
  });

  factory Constellation.fromJson(Map<String, dynamic> json) {
    final label = (json['label'] as List).cast<num>();
    return Constellation(
      id: json['id'] as String,
      name: json['name'] as String,
      rank: json['rank'] as int,
      labelRightAscension: label[0].toDouble(),
      labelDeclination: label[1].toDouble(),
      strokes: [
        for (final stroke in json['lines'] as List)
          Float64List.fromList([
            for (final point in stroke as List)
              for (final v in (point as List).cast<num>()) v.toDouble(),
          ]),
      ],
    );
  }
}

/// One of the brighter galaxies (OpenNGC, CC BY-SA 4.0; sources in
/// `docs/provenance/stars/notes.md`): its name, its designations, J2000
/// place, visual magnitude, size in arc minutes, constellation.
class Galaxy {
  final String name;
  final String designations;
  final double rightAscension;
  final double declination;
  final double magnitude;
  final double? major;
  final double? minor;
  final String constellation;

  const Galaxy({
    required this.name,
    required this.designations,
    required this.rightAscension,
    required this.declination,
    required this.magnitude,
    required this.major,
    required this.minor,
    required this.constellation,
  });

  static Future<List<Galaxy>>? _loading;

  /// The galaxies, brightest first, read the first time they are asked
  /// for.
  /// For tests: forget what was read.
  static void reset() => _loading = null;

  static Future<List<Galaxy>> load() => _loading ??= rootBundle
      .loadString('assets/stars/galaxies.tsv', cache: false)
      .then(parse);

  static List<Galaxy> parse(String tsv) => [
    for (final row in const LineSplitter().convert(tsv).skip(1))
      if (row.split('\t') case [
        final name,
        final ids,
        final ra,
        final dec,
        final mag,
        final major,
        final minor,
        _,
        final con,
      ])
        Galaxy(
          name: name,
          designations: ids,
          rightAscension: double.parse(ra),
          declination: double.parse(dec),
          magnitude: double.parse(mag),
          major: double.tryParse(major),
          minor: double.tryParse(minor),
          constellation: con,
        ),
  ];
}
