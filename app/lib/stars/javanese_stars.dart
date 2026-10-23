/// The stars of Javanese reckoning: the figures pranata mangsa refers
/// to, as the sources name them, each tied to the stars of the catalogue
/// it is made of (by Hipparcos number) or to a constellation's figure.
///
/// Each says how firm its ground is. Every identification here is from a
/// scholarly source: Daldjoeni and Hidayat (1987), Maass (1924, with the
/// Javanese informants it quotes), Gericke and Roorda's dictionary
/// (1901), Handayani and others (2023). Sources, and where they disagree,
/// in `docs/provenance/javanese-stars/notes.md`.
library;

/// How firm a figure's identification is.
enum Ground {
  /// In a scholarly source.
  scholarly,

  /// In popular writing only.
  popular,
}

class JavaneseFigure {
  final String id;

  /// Its name, and its other names, each other name as firm as
  /// [aliasGround].
  final String name;
  final List<String> aliases;
  final Ground aliasGround;

  /// What the name means, where that is clear; empty where it is not.
  final String meaningEn;
  final String meaningId;

  /// The Western figure it is.
  final String western;

  /// Its stars, by Hipparcos number, and the lines drawn between them.
  final List<int> stars;
  final List<(int, int)> lines;

  /// Or a whole Western figure's lines (three letters), where the
  /// sources name the constellation, not its stars.
  final String? figure;

  /// Or a patch of sky with no stars to it (the Coalsack): its centre,
  /// J2000, and its radius, in degrees.
  final ({double rightAscension, double declination, double radius})? patch;

  final Ground ground;

  /// What the sources say it marks, in each language; empty where they
  /// tie it to nothing.
  final String marksEn;
  final String marksId;

  const JavaneseFigure({
    required this.id,
    required this.name,
    this.aliases = const [],
    this.aliasGround = Ground.scholarly,
    this.meaningEn = '',
    this.meaningId = '',
    required this.western,
    this.stars = const [],
    this.lines = const [],
    this.figure,
    this.patch,
    required this.ground,
    this.marksEn = '',
    this.marksId = '',
  });
}

/// Orion's middle Belt star (Alnilam), by which Waluku's rising and
/// setting at dawn are reckoned.
const walukuMark = (rightAscension: 84.05338, declination: -1.20192);

const javaneseFigures = [
  JavaneseFigure(
    id: 'waluku',
    name: 'Waluku',
    aliases: ['Luku', 'Weluku', 'Kidang', 'Guru Desa'],
    meaningEn: 'the plough',
    meaningId: 'bajak sawah (luku)',
    western: 'Orion: the Belt and the sword',
    // The plough: the Belt (Mintaka, Alnilam, Alnitak) and the sword
    // hanging from it as its beam (42, θ¹ and ι Orionis); its two beasts
    // Rigel (the buffalo) and Saiph (the ox). Betelgeuse is not of it
    // (Maass 1924, after the Regent of Kudus; Handayani 2023).
    stars: [25930, 26311, 26727, 26237, 26220, 26241, 24436, 27366],
    lines: [
      (25930, 26311),
      (26311, 26727),
      (26311, 26237),
      (26237, 26220),
      (26220, 26241),
    ],
    ground: Ground.scholarly,
    marksEn:
        'Rising in the east before dawn, it opens Kasa, the first '
        'mangsa: time to plough. Setting in the west at dawn, it marks '
        'Kapitu, the seventh. Farmers judged the mangsa by how high it '
        'and Wuluh stood at nightfall or before dawn.',
    marksId:
        'Terbit di timur sebelum fajar, ia membuka Kasa, mangsa pertama: '
        'saatnya membajak. Terbenam di barat saat subuh, ia menandai '
        'Kapitu, mangsa ketujuh. Petani menimbang mangsa dari tingginya, '
        'dan tinggi Wuluh, saat senja atau sebelum fajar.',
  ),
  JavaneseFigure(
    id: 'wuluh',
    name: 'Wuluh',
    aliases: ['Kartika'],
    meaningEn: 'the bamboo',
    meaningId: 'bambu',
    western: 'the Pleiades',
    // Alcyone, Atlas, Electra, Maia, Merope, Taygeta, Pleione, Celaeno,
    // Asterope.
    stars: [17702, 17847, 17499, 17573, 17608, 17531, 17851, 17489, 17579],
    ground: Ground.scholarly,
    marksEn:
        'On Java\'s north coast, when it stands at nightfall as high as '
        'the sun when the buffalo are unyoked (about 50°), it is the '
        'seventh mangsa: time to transplant.',
    marksId:
        'Di pesisir utara Jawa, bila saat senja ia setinggi matahari ketika '
        'kerbau dilepas dari bajak (sekitar 50°), itulah mangsa ketujuh: '
        'saatnya tandur.',
  ),
  JavaneseFigure(
    id: 'lumbung',
    name: 'Lumbung',
    aliases: ['Gubuk Penceng'],
    meaningEn: 'the rice barn; the leaning hut',
    meaningId: 'lumbung padi; gubuk yang miring',
    western: 'Crux',
    // Gacrux, Mimosa, Acrux, Imai: the kite.
    stars: [61084, 62434, 60718, 59747],
    lines: [(61084, 62434), (62434, 60718), (60718, 59747), (59747, 61084)],
    ground: Ground.scholarly,
    marksEn: 'The south is found by it.',
    marksId: 'Arah selatan dicari dengannya.',
  ),
  JavaneseFigure(
    id: 'banyakangrem',
    name: 'Banyakangrem',
    meaningEn: 'the brooding goose',
    meaningId: 'angsa yang mengeram',
    western: 'the Coalsack, the dark cloud beside Crux',
    patch: (rightAscension: 192.5, declination: -62.5, radius: 3),
    ground: Ground.scholarly,
  ),
  JavaneseFigure(
    id: 'klapadoyong',
    name: 'Klapa Doyong',
    meaningEn: 'the leaning coconut palm',
    meaningId: 'pohon kelapa yang condong',
    western: 'Scorpius',
    // The fronds β¹, δ and π; the trunk down through σ, Antares, τ and
    // ε Scorpii.
    stars: [78820, 78401, 78265, 80112, 80763, 81266, 82396],
    lines: [
      (78820, 78401),
      (78401, 78265),
      (78401, 80112),
      (80112, 80763),
      (80763, 81266),
      (81266, 82396),
    ],
    ground: Ground.scholarly,
  ),
  JavaneseFigure(
    id: 'puyuhatarung',
    name: 'Puyuh Atarung',
    meaningEn: 'the fighting quails',
    meaningId: 'burung puyuh yang beradu',
    western: 'μ and ζ Scorpii',
    // The two pairs, a quail each.
    stars: [82514, 82545, 82729, 82671],
    lines: [(82514, 82545), (82729, 82671)],
    ground: Ground.scholarly,
  ),
  JavaneseFigure(
    id: 'wulanjarngirim',
    name: 'Wulanjarngirim',
    meaningEn: 'the widow bringing food',
    meaningId: 'janda yang mengirim makanan',
    western: 'α and β Centauri',
    // Rigil Kentaurus, Hadar.
    stars: [71683, 68702],
    lines: [(71683, 68702)],
    ground: Ground.scholarly,
    marksEn:
        'Seen in the southeast on evenings in April and May, beside '
        'Lumbung.',
    marksId:
        'Tampak di tenggara pada petang April dan Mei, di samping '
        'Lumbung.',
  ),
  JavaneseFigure(
    id: 'badaknyempal',
    name: 'Badak Nyempal',
    meaningEn: 'the grazing rhinoceros',
    meaningId: 'badak yang merumput',
    western: 'Sirius',
    stars: [32349],
    ground: Ground.scholarly,
  ),
  JavaneseFigure(
    id: 'hasta',
    name: 'Hasta',
    meaningEn: 'the hand, a lunar mansion of the old texts',
    meaningId: 'tangan, salah satu rumah bulan dalam naskah lama',
    western: 'α and β Corvi',
    // Alchiba, Kraz.
    stars: [59199, 61359],
    lines: [(59199, 61359)],
    ground: Ground.scholarly,
  ),
  JavaneseFigure(
    id: 'pedatisuwung',
    name: 'Pedati Suwung',
    aliases: ['Lintang Jong'],
    meaningEn: 'the empty cart',
    meaningId: 'pedati kosong',
    western: 'the Big Dipper',
    // Dubhe, Merak, Phecda, Megrez, Alioth, Mizar, Alkaid: low in the
    // north from Java.
    stars: [54061, 53910, 58001, 59774, 62956, 65378, 67301],
    lines: [
      (54061, 53910),
      (53910, 58001),
      (58001, 59774),
      (59774, 54061),
      (59774, 62956),
      (62956, 65378),
      (65378, 67301),
    ],
    ground: Ground.scholarly,
  ),
  JavaneseFigure(
    id: 'bimasakti',
    name: 'Bimasakti',
    meaningEn: 'the Milky Way',
    meaningId: 'galaksi kita, sabuk cahaya di langit',
    western: 'the Milky Way, its bright southern reach',
    ground: Ground.scholarly,
  ),
];
