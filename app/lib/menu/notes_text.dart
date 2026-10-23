import '../strings.dart';

/// A headed stretch of a page of notes.
typedef NoteSection = ({String heading, List<String> paragraphs});

/// What a source is to a reckoning.
enum SourceStanding {
  /// A primary source: consulted itself, at the place given.
  read,

  /// A secondary source: known only as another work quotes or cites it
  /// (that work, where known, in [Source.via]).
  cited,

  /// A control: software or published figures the results were checked
  /// against.
  compared,
}

/// A work a reckoning rests on, what it is to it, and, for a secondary
/// source, the work it is known through.
typedef Source = ({String cite, SourceStanding standing, String? via});

/// One reckoning: what the rule is, where it differs from others, and
/// what it rests on.
typedef Chapter = ({
  String id,
  String name,
  List<String> paragraphs,
  List<Source> sources,
});

/// How each calendar in the app is worked out, what it was checked
/// against, and where it will differ from other calendars: a chapter
/// for each, with its own sources. The working in full is kept with the
/// app's source.
List<Chapter> reckoningChapters(AppLanguage language) {
  // The Indonesian is put aside for now (owner, 23 October 2026): both
  // languages read the English until it is written again.
  final texts = _reckoningEn;
  return [
    for (final (i, id) in _chapterIds.indexed)
      (
        id: id,
        name: texts[i].heading,
        paragraphs: texts[i].paragraphs,
        sources: _sources[id]!,
      ),
  ];
}

const _chapterIds = [
  'rule',
  'weton',
  'javanese',
  'hijri',
  'chinese',
  'bazi',
  'mangsa',
  'lintang',
  'moon',
  'stars',
  'planets',
  'light',
  'salat',
  'hilal',
  'places',
];

const _read = SourceStanding.read;
const _cited = SourceStanding.cited;
const _compared = SourceStanding.compared;

// The works are named as they are published, in whatever language that
// is, so one list serves both languages.
const _sources = <String, List<Source>>{
  'rule': [],
  'weton': [
    (
      cite:
          'Kraton Jogja, "Kalender Jawa Sultan Agungan". '
          'kratonjogja.id/ragam/21-kalender-jawa-sultan-agungan',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'A. L. Maulidiyah, "Petungan Weton dalam Kitab Primbon Betaljemur '
          'Adammakna Perspektif Tradisi Jawa", skripsi, UIN Sunan Kalijaga '
          'Yogyakarta, 2024, p. 5. digilib.uin-suka.ac.id/id/eprint/67607',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'K. P. H. Tjakraningrat, Kitab Primbon Betaljemur Adammakna, '
          'Yogyakarta: Soemodidjojo Maha-Dewa, 1994.',
      standing: _cited,
      via: 'A. L. Maulidiyah, "Petungan Weton dalam Kitab Primbon Betaljemur Adammakna Perspektif Tradisi Jawa", skripsi, UIN Sunan Kalijaga Yogyakarta, 2024, p. 5',
    ),
    (
      cite: 'F. Beauducel, weton. github.com/beaudu/weton',
      standing: _compared,
      via: null,
    ),
  ],
  'javanese': [
    (
      cite:
          'Kraton Jogja, "Kalender Jawa Sultan Agungan". '
          'kratonjogja.id/ragam/21-kalender-jawa-sultan-agungan',
      standing: _read,
      via: null,
    ),
    (
      cite: 'Wikipedia bahasa Indonesia, "Kalender Jawa".',
      standing: _read,
      via: null,
    ),
    (
      cite: 'Almanak van Nederlandsch-Indië, 1837.',
      standing: _cited,
      via: 'the Kraton Yogyakarta\'s page and Wikipedia bahasa Indonesia',
    ),
    (
      cite: 'English Wikipedia, "Javanese calendar".',
      standing: _read,
      via: null,
    ),
    (
      cite: 'F. Beauducel, weton. github.com/beaudu/weton',
      standing: _compared,
      via: null,
    ),
    (
      cite:
          '"Keraton Yogyakarta gelar Mubeng Beteng 1 Suro, malam Jumat 26 '
          'Juni 2025", bacajogja.id, 22 June 2025.',
      standing: _read,
      via: null,
    ),
  ],
  'hijri': [
    (
      cite: 'English Wikipedia, "Tabular Islamic calendar".',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'N. Dershowitz and E. M. Reingold, Calendrical Calculations, 3rd '
          'ed., Cambridge University Press, 2008, ch. 6, pp. 82-87.',
      standing: _cited,
      via: 'Wikipedia, "Tabular Islamic calendar"',
    ),
    (
      cite:
          'R. H. van Gent, "Online Calendar Converters Based on the Tabular '
          'Islamic Calendar", Mathematical Institute, Utrecht University, '
          '2019.',
      standing: _cited,
      via: 'Wikipedia, "Tabular Islamic calendar"',
    ),
    (
      cite:
          'Kementerian Agama RI, hasil sidang isbat 1 Ramadan, 1 Syawal '
          'dan 10 Zulhijah 1444-1447 H, and the joint ministerial decrees '
          '(SKB 3 Menteri) on national holidays 2023-2026, as reported at '
          'the time by setkab.go.id, antaranews.com, detik.com, '
          'kontan.co.id, metrotvnews.com and nu.or.id.',
      standing: _compared,
      via: null,
    ),
  ],
  'chinese': [
    (
      cite:
          'Hong Kong Observatory, Gregorian-Lunar Calendar Conversion '
          'Tables, 1901-2100, one file a year. '
          'hko.gov.hk/en/gts/time/calendar/text/files/T2026e.txt',
      standing: _read,
      via: null,
    ),
    (
      cite: '"Pengertian Kongzili", detik.com (Jogja, Budaya).',
      standing: _read,
      via: null,
    ),
    (
      cite:
          '"Besok 17 Februari 2026 Libur Apa? Simak Ketentuan Pemerintah", '
          'kompas.tv, on Tahun Baru Imlek 2577 Kongzili.',
      standing: _read,
      via: null,
    ),
  ],
  'bazi': [
    (
      cite: 'J. Meeus, Astronomical Algorithms, 2nd ed. (1998).',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'P. Bretagnon and G. Francou, "Planetary theories in rectangular '
          'and spherical variables: VSOP87 solutions", Astronomy and '
          'Astrophysics 202 (1988), 309-315.',
      standing: _cited,
      via:
          'J. Meeus, Astronomical Algorithms, 2nd ed., ch. 25 and appendix III',
    ),
    (cite: 'lunar_python (6tail).', standing: _compared, via: null),
    (cite: 'sxtwl (元谷), after 许剑伟\'s 寿星天文历.', standing: _compared, via: null),
    (cite: 'IANA Time Zone Database, 2026c.', standing: _read, via: null),
    (
      cite:
          '《淵海子平》卷一「又地支藏遁歌」「又論節氣歌」, transcription at '
          'donglishuzhai.net and zh.wikisource.org.',
      standing: _read,
      via: null,
    ),
    (
      cite: '《三命通會》卷二「論三刑」「論六害」, 四庫全書本, zh.wikisource.org.',
      standing: _read,
      via: null,
    ),
    (cite: '任鐵樵《滴天髓闡微》, zh.wikisource.org.', standing: _read, via: null),
    (
      cite: '徐樂吾《子平真詮評註》「十二月令人元司令分野表」.',
      standing: _cited,
      via: 'a repost at blog.sina.com.cn',
    ),
    (cite: '袁樹珊 and 韋千里, on the hour of the rat.', standing: _cited, via: null),
  ],
  'mangsa': [
    (
      cite:
          'Karaton Surakarta, "Pranoto Mongso (aturan waktu musim)", '
          'karatonsurakarta.com, archived 27 August 2011 at web.archive.org.',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'Skripsi 102111099, UIN Walisongo Semarang (2014), bab 3. '
          'eprints.walisongo.ac.id/id/eprint/2758',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'H. Tjakraningrat, Kitab Primbon Qamarulsyamsi Adammakna, '
          'Yogyakarta: Soemodidjojo Mahadewa, 1990, pp. 16-19.',
      standing: _cited,
      via: 'thesis 102111099, UIN Walisongo Semarang, 2014, chapter 3',
    ),
    (
      cite:
          'N. Daldjoeni, "Pranatamangsa, the Javanese agricultural '
          'calendar", The Environmentalist 4 (1984), 15-18.',
      standing: _cited,
      via: 'Wikipedia bahasa Indonesia and bahasa Jawa, "Pranata mangsa"',
    ),
    (
      cite:
          'Wikipedia bahasa Indonesia and Wikipedia basa Jawa, '
          '"Pranata mangsa".',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'L. Gislén and J. C. Eade, "The calendars of Southeast Asia. 4: '
          'Malaysia and Indonesia", Journal of Astronomical History and '
          'Heritage 22(3) (2019), 447-457.',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'Museum Sonobudoyo, "Reading the Sky, Working the Fields". '
          'sonobudoyo.jogjaprov.go.id',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'KITLV, "The case of Javanese cropping calendars" (A. Perkasa, '
          'from 2024). kitlv.nl',
      standing: _read,
      via: null,
    ),
  ],
  'moon': [
    (
      cite:
          'J. Meeus, Astronomical Algorithms, 2nd ed. (1998), chapters 12, '
          '13, 16, 22, 25, 40, 47 and 48, and appendix III.',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'US Naval Observatory, phases of the moon for 1950, 2000, '
          '2025-2027 and 2050.',
      standing: _compared,
      via: null,
    ),
    (
      cite:
          'JPL Horizons (DE441), apparent places of the sun and the moon '
          'from Jakarta and from the centre of the Earth, 2020-2029. '
          'ssd.jpl.nasa.gov/horizons',
      standing: _compared,
      via: null,
    ),
    (
      cite:
          'US Naval Observatory, rise, transit, set and twilight for '
          'Jakarta and Helsinki, 2026-2027. aa.usno.navy.mil/data/RS_OneDay',
      standing: _compared,
      via: null,
    ),
  ],
  'lintang': [
    (
      cite:
          'N. Daldjoeni and B. Hidayat, "Astronomical aspects of '
          '\'Pranotomongso\' of the 19th century Central Java", IAU '
          'Colloquium 91, History of Oriental Astronomy, Cambridge, 1987, '
          'pp. 249-252.',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'A. Maass, "Sternkunde und Sterndeuterei im malaiischen '
          'Archipel", Tijdschrift voor Indische Taal-, Land- en '
          'Volkenkunde 64 (1924), pp. 6-7, 111-123, 142-150, 163-164, '
          '429-430, 444 and its comparative table.',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'The Regent of Kudus, R. M. A. A. Tjondro Negoro, letter of 1880, '
          'in J. A. C. Oudemans, Verslagen en Mededeelingen KNAW (1881), '
          'pp. 177-193.',
      standing: _cited,
      via: 'A. Maass, "Sternkunde und Sterndeuterei im malaiischen Archipel", 1924',
    ),
    (
      cite:
          'J. F. C. Gericke and T. Roorda, Javaansch-Nederlandsch '
          'Handwoordenboek, 1901, the entries for the stars named, in the '
          'transcription at sastra.org.',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'R. D. Handayani, Z. K. Prasetyo and I. Wilujeng, Pranata Mangsa '
          'dalam Tinjauan Sains, revised ed., Penerbit BRIN, 2023, pp. '
          '10-21.',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'G. Ammarell, "Sky Calendars of the Indo-Malay Archipelago", '
          'Indonesia 45 (1988), pp. 85-104.',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'N. Daldjoeni, "Pranatamangsa, the Javanese agricultural '
          'calendar", The Environmentalist 4 (1984), pp. 15-18.',
      standing: _cited,
      via: 'Wikipedia bahasa Indonesia, "Pranata mangsa"',
    ),
  ],
  'stars': [
    (
      cite:
          'D. Nash, the HYG star database, version 4.4 (CC BY-SA 4.0). '
          'codeberg.org/astronexus/hyg',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'O. Frohn, d3-celestial, the constellation figures (BSD). '
          'github.com/ofrohn/d3-celestial',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'M. Verga, OpenNGC, the galaxies (CC BY-SA 4.0). '
          'github.com/mattiaverga/OpenNGC',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'J. Meeus, Astronomical Algorithms, 2nd ed. (1998), chapter 21 '
          'and example 21.b.',
      standing: _compared,
      via: null,
    ),
  ],
  'planets': [
    (
      cite:
          'P. Bretagnon and G. Francou, "Planetary theories in rectangular '
          'and spherical variables: VSOP87 solutions", Astronomy and '
          'Astrophysics 202 (1988), pp. 309-315; the VSOP87D files from '
          'IMCCE, Observatoire de Paris. ftp.imcce.fr/pub/ephem/planets/vsop87',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'A. Mallama and J. L. Hilton, "Computing apparent planetary '
          'magnitudes for The Astronomical Almanac", Astronomy and Computing '
          '25 (2018), pp. 10-24.',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'JPL Horizons, the seven planets on 15 June 1990, 16 October 2026 '
          'and 1 January 2030; IMCCE\'s check values of the full VSOP87D. '
          'ssd.jpl.nasa.gov/horizons',
      standing: _compared,
      via: null,
    ),
    (
      cite:
          'Cassius Dio, Roman History 37.18-19, tr. E. Cary (Loeb, 1914), '
          'on LacusCurtius.',
      standing: _read,
      via: null,
    ),
    (
      cite: 'Vettius Valens, Anthologies I.10, tr. M. Riley.',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'H. C. Agrippa, Three Books of Occult Philosophy (English, 1651), '
          'I.23-29, II.22 and II.34, on esotericarchives.com.',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'G. Chaucer, A Treatise on the Astrolabe (1391), II.10-12, ed. W. W. '
          'Skeat.',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'The Key of Solomon I.2, ed. S. L. MacGregor Mathers (1889), rev. '
          'J. H. Peterson.',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'Ptolemy, Tetrabiblos I.7 and I.17, tr. F. E. Robbins (Loeb, 1940), '
          'on LacusCurtius.',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'M. Berthelot, Les origines de l\'alchimie (1885), pp. 48-50; '
          'Olympiodorus and Proclus as he quotes them.',
      standing: _read,
      via: null,
    ),
    (
      cite: 'W. W. Skeat, Malay Magic (1900), on the ketika tujuh.',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'Trigangga and others, Prasasti dan Raja-Raja Nusantara, Museum '
          'Nasional, 2015, p. 21; the inscriptions of Wukiran (863) and '
          'Wayuku (854) at dharmalekha.info.',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'Wardani, "Astrologi dan Pengobatan Melayu: Telaah atas Kitab Tāj '
          'al-Mulk", Al-Banjari 9/1 (2010), pp. 89-120.',
      standing: _read,
      via: null,
    ),
  ],
  'light': [
    (
      cite:
          'NASA, Lunar Photography Guide, on the Looney 11 rule. '
          'science.nasa.gov/moon/photography-guide',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'International Meteor Organization, Meteor Shower Calendar 2027, '
          'table 5. imo.net',
      standing: _read,
      via: null,
    ),
    (
      cite: 'F. Michaud, the NPF rule, Société Astronomique du Havre.',
      standing: _cited,
      via: null,
    ),
    (
      cite:
          'NOAA NCEI and the British Geological Survey, the World Magnetic '
          'Model 2025, its coefficients and its 100 test values. '
          'ncei.noaa.gov/products/world-magnetic-model',
      standing: _compared,
      via: null,
    ),
    (
      cite:
          'F. Espenak and J. Meeus, NASA\'s Five Millennium Canon of solar '
          'and lunar eclipses, 2021-2030.',
      standing: _compared,
      via: null,
    ),
  ],
  'salat': [
    (
      cite:
          'Kementerian Agama RI, kriteria jadwal shalat, as given at '
          'rukyatulhilal.org/imsakiyah/kriteria.html.',
      standing: _read,
      via: null,
    ),
    (
      cite:
          '"Kemenag: Kriteria Waktu Subuh -20 Derajat Benar secara Fiqih '
          'dan Sains", NU Online, 21 December 2020. nu.or.id',
      standing: _read,
      via: null,
    ),
    (
      cite:
          '"Catat! Muhammadiyah Tambah Awal Waktu Subuh 8 Menit, Ini '
          'Alasannya", Kompas TV, 14 March 2021: the Majelis Tarjih\'s '
          '-18°. kompas.tv',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'Kementerian Agama RI (Bimas Islam), jadwal shalat for Kota '
          'Jakarta, Kota Yogyakarta, Kota Banda Aceh and Kota Jayapura, '
          'June, October and December 2026, as republished at '
          'api.myquran.com.',
      standing: _compared,
      via: null,
    ),
    (
      cite:
          'Batoul Apps, the adhan library: the conventions and their '
          'parameters (MIT). github.com/batoulapps/adhan-js',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'The timetables of Diyanet (Ankara), Qatar, the Dubai Awqaf, '
          'Kuwait, the Moonsighting Committee (London), Umm al-Qura '
          '(Makkah) and MUIS (Singapore), as adhan\'s test files carry '
          'them.',
      standing: _compared,
      via: null,
    ),
  ],
  'hilal': [
    (
      cite:
          'T. Djamaluddin, "Bismillah, Indonesia Menerapkan Kriteria Baru '
          'MABIMS", 23 February 2022, and "Alhamdulillah, Sepakat demi '
          'Titik Temu", 16 March 2023. tdjamaluddin.wordpress.com',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'Majelis Tarjih dan Tajdid PP Muhammadiyah, Pedoman Hisab '
          'Muhammadiyah, 2nd printing, 2009, pp. 82-94.',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'PP Muhammadiyah, Maklumat 2/MLM/I.0/E/2025 on Ramadan, Syawal '
          'and Zulhijah 1447 H. muhammadiyah.or.id',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'M. Sh. Odeh, "New criterion for lunar crescent visibility", '
          'Experimental Astronomy 18 (2004), pp. 39-64.',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'B. D. Yallop, A Method for Predicting the First Sighting of the '
          'New Crescent Moon, NAO Technical Note 69, 1997.',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'Observatorium Bosscha ITB, press releases on the hilal of '
          'Ramadan and Syawal 1446 and 1447 H. bosscha.itb.ac.id',
      standing: _compared,
      via: null,
    ),
  ],
  'places': [
    (
      cite:
          'Cahya DSN, Wilayah Indonesia and Wilayah Boundaries, after '
          'Kepmendagri No 300.2.2-2138 and 300.2.2-2430 Tahun 2025 (MIT). '
          'github.com/cahyadsn',
      standing: _read,
      via: null,
    ),
    (
      cite:
          'GeoNames, towns of 15,000 people or more (CC BY 4.0). geonames.org',
      standing: _read,
      via: null,
    ),
    (
      cite: 'Natural Earth, 1:50m countries (public domain). naturalearthdata.com',
      standing: _read,
      via: null,
    ),
  ],
};

const _reckoningEn = <NoteSection>[
  (
    heading: 'The rule',
    paragraphs: [
      'Every date is worked out on the phone from a stated rule. Nothing is '
          'looked up online, and nothing is adjusted by hand to agree with '
          'another calendar.',
      'Where a tradition has more than one rule in print, the app follows '
          'one, says which, and says where the others differ. Where a rule '
          'does not reach, the app shows nothing instead of a guess.',
      'The day changes at midnight by the phone\'s clock in every system. '
          'By tradition the Hijri and Javanese day begins at sunset; that is '
          'not yet followed.',
    ],
  ),
  (
    heading: 'Weton',
    paragraphs: [
      'The seven-day week against the five-day pasaran, a cycle of 35 '
          'days. It runs unbroken and no source disputes it.',
      'The neptu is the sum of the value of the day and the value of '
          'the pasaran: Minggu 5, Senin 4, Selasa 3, Rabu 7, Kamis 8, '
          'Jumat 6, Sabtu 9; Legi 5, Pahing 9, Pon 7, Wage 4, Kliwon 8. '
          'These are the values of the Primbon Betaljemur Adammakna as a '
          '2024 thesis on that primbon tabulates them; the primbon itself '
          'has not been consulted.',
    ],
  ),
  (
    heading: 'Javanese',
    paragraphs: [
      'Sultan Agung\'s calendar by the arithmetic of the courts, in the '
          'current kurup, Asapon: from 1 Sura 1867 (24 March 1936) to 29 '
          'Besar 1986 (25 August 2052). Dates outside it are not shown: '
          'earlier kurup differ between Surakarta and Yogyakarta, and the '
          'next has not been defined by the courts.',
      'Long years are Ehe, Dal and Jimakir, as the Yogyakarta palace '
          'states. Two other lists are in print; under them dates in a Dal '
          'or a Jimawal year fall a day away from the app\'s.',
      'This is court arithmetic, not the sighting of the moon. Many '
          'calendars and news sites print the government\'s Hijri date '
          'under Javanese month names, so they are often a day from the '
          'court\'s. 1 Sura 1960 is Wednesday 17 June 2026 here; it was '
          'widely reported as 16 June.',
    ],
  ),
  (
    heading: 'Hijri',
    paragraphs: [
      'The tabular Islamic calendar: months of 30 and 29 days in '
          'turn, eleven leap years in every thirty (the 2nd, 5th, 7th, '
          '10th, 13th, 16th, 18th, 21st, 24th, 26th and 29th), counted '
          'from Friday 16 July 622. This is the commonest of the tabular '
          'schemes, the one of al-Khwarizmi, al-Battani and the Toledan '
          'and Alfonsine tables. It never changes and needs no '
          'observation.',
      'Indonesia\'s official dates come from the Ministry of Religious '
          'Affairs, by criteria of the moon\'s visibility and, for '
          'Ramadan, Syawal and Zulhijah, an actual sighting. No fixed '
          'rule can reproduce that.',
      'The tabular calendar was held against the 24 dates the '
          'government set from 2023 to 2026 for 27 Rajab, 1 Ramadan, 1 '
          'Syawal, 10 Zulhijah, 1 Muharam and 12 Rabiulawal. It agrees on '
          '15 and is one day away on 9, never more. The nine: 28 '
          'September 2023, 8 February 2024, 12 March 2024, 7 July 2024, 6 '
          'June 2025, 19 February 2026, 21 March 2026, 16 June 2026 and '
          '25 August 2026. The comparison is repeated every time the app '
          'is built.',
      'For fasting and the feasts, follow the announcement, not this '
          'app.',
    ],
  ),
  (
    heading: 'Chinese',
    paragraphs: [
      'The standard Chinese calendar; Indonesia\'s is the same in every '
          'date. New moons and leap months are taken from the Hong Kong '
          'Observatory\'s tables for 1901 to 2100, not computed. What is '
          'Indonesian is the naming: the Kongzili year (the year of Imlek '
          'plus 551), the Hokkien month names, and the shio.',
      'The element shown for a day is that of the day\'s heavenly stem, '
          'yin or yang.',
    ],
  ),
  (
    heading: 'Bazi',
    paragraphs: [
      'The pillars turn on the solar terms, which are computed from the '
          'sun\'s position (VSOP87, after Meeus) to the minute. The engine '
          'was compared with two independent libraries over 7,000 charts '
          'and 2,412 solar terms.',
      'A birth time is read in the time zone that was in force at that '
          'place on that day, from the IANA time zone history. Where the '
          'schools differ (the hidden stems, the relations, the hour of '
          'the rat, the rounding of the luck pillars) the screen offers '
          'each school\'s rule by name and does not choose for you.',
      'What is entered for a chart is never stored.',
    ],
  ),
  (
    heading: 'Pranata mangsa',
    paragraphs: [
      'The form fixed by the court of Surakarta in 1855: the year '
          'opens with Kasa on 22 June, and the twelve mangsa have 41, 23, '
          '24, 25, 27, 43, 43, 26, 25, 24, 23 and 41 days, Kawolu taking '
          'a 27th in a leap year. Year 1 opened on 22 June 1855. The '
          'primbon, the court\'s own page and Gislén and Eade (2019) agree '
          'on all of this. The app claims nothing about how old the '
          'reckoning is before 1855.',
      'Some tables in print, and English Wikipedia\'s, open the year '
          'on 23 June and run a day later throughout. Wikipedia lists '
          'Gislén and Eade among its references, but their paper says 22 '
          'June. '
          'The court\'s own page lists a few mangsa a day late against the '
          'lengths it prints beside them, which looks like where the '
          'later dates began.',
      'The mangsa are cut by the noon shadow of an upright stick near '
          'Surakarta, at about 7.5 degrees south: the stretch between the '
          'longest shadow to the south and the longest to the north is '
          'divided into six equal parts, and the sun\'s passage over each '
          'is a mangsa. Gislén and Eade give this construction; the '
          'primbon tradition counts the same parts as feet of a person\'s '
          'own shadow. The shadow was computed from the sun\'s position for '
          'every opening day, and it falls on its division each time.',
      'The candra are given in Javanese as printed. The translations '
          'are the app\'s own; what each stands for is the court\'s own '
          'gloss.',
    ],
  ),
  (
    heading: 'Lintang Jawa',
    paragraphs: [
      'The figures and the stars they are made of follow the older '
          'scholarly literature: Daldjoeni and Hidayat (1987), Maass (1924) '
          'with the Javanese informants he quotes, Gericke and Roorda\'s '
          'dictionary (1901) and Handayani and others (2023). Where they '
          'name a constellation and not its stars, the figure is drawn as '
          'they describe it, and nothing is added.',
      'Waluku, the plough, is Orion\'s Belt with the sword hanging from '
          'it as its beam, and Rigel and Saiph as the beasts that pull it. '
          'Betelgeuse is not part of it: in Maass\'s table it is a wound on '
          'the ploughman\'s foot. Banyakangrem, '
          'the brooding goose, is the Coalsack, the dark cloud beside the '
          'Southern Cross, and is drawn as a ring with no stars. Scorpius '
          'is Klapa Doyong, the leaning coconut palm.',
      'A first version followed Wikipedia, which gives Banyakangrem as '
          'Scorpius and cites Daldjoeni\'s paper of 1984. Daldjoeni\'s own '
          'later paper says the Coalsack, and so do Maass and the '
          'dictionary; the app follows them.',
      'Only what the sources say a figure marks is shown. Waluku rising '
          'before dawn opens Kasa, and setting at dawn marks Kapitu; '
          'farmers read the mangsa by how high Waluku and Wuluh stood at '
          'nightfall or before dawn. The dates the app gives for Waluku '
          'are its own working (Alnilam 5° up with the sun 12° down), '
          'not the sources\'.',
    ],
  ),
  (
    heading: 'Sun, moon and sky',
    paragraphs: [
      'The moon\'s phase and light are computed, and were compared with '
          'the phase times published by the US Naval Observatory. Rising '
          'and setting times are for the place you set, and are not stored '
          'anywhere but on the phone.',
      'The sky utility works the sun from the VSOP87 theory and the moon '
          'from the full sixty-term series Meeus gives, then carries both '
          'to your place: nutation, aberration, the apparent sidereal '
          'time, the moon\'s parallax (up to a degree) and the bending of '
          'the air near the horizon. Against the JPL Horizons ephemeris '
          'the sun came within three seconds of arc and the moon within '
          'ten; rise, culmination, set and twilight came within a minute '
          'of the US Naval Observatory\'s, in Jakarta and in Helsinki.',
      'The sky is drawn as seen from above, north at the top and east to '
          'the right, as on a map.',
    ],
  ),
  (
    heading: 'Star map',
    paragraphs: [
      'The 8,920 stars the eye can see, magnitude 6.5 and brighter, from '
          'the HYG database (version 4.4), with the constellation figures '
          'of d3-celestial and the brightest galaxies of OpenNGC. Their '
          'catalogue places are for the year 2000; the app moves them to '
          'the night shown by Meeus\'s rigorous precession, checked against '
          'his worked example to a hundred-thousandth of a degree.',
      'The stars\' own small motions, nutation and aberration are left '
          'out, each under twenty seconds of arc. The constellations keep '
          'their Latin names, as Indonesian astronomy uses them.',
    ],
  ),
  (
    heading: 'Planets',
    paragraphs: [
      'The planets are worked out from VSOP87, the planetary theory of '
          'Bretagnon and Francou (Paris, 1988), cut to its largest terms, '
          'and carried to your place as the sun and the moon are. Against '
          'JPL\'s ephemeris, the seven planets on three dates from 1990 to '
          '2030 came within two seconds of arc; their brightness, by Mallama '
          'and Hilton\'s formulas, within two hundredths of a magnitude (Mars '
          'within five, its surface markings left out).',
      'The planetary hours are the old astrologers\': sunrise to sunset cut '
          'into twelve, sunset to the next sunrise into twelve, each hour to '
          'a planet in the Chaldean order, the day\'s first hour to the '
          'planet it is named for. Cassius Dio, Vettius Valens, Chaucer, '
          'Agrippa and the Key of Solomon agree on the rule. Sunrise is the '
          'sun\'s centre on the horizon, as Chaucer takes it, and the night '
          'belongs to the day before it. Agrippa also gives hours by the '
          'rising of the zodiac; those are not used.',
      'The lore is each planet\'s usual metal, its weekday in Latin and in '
          'Old Javanese, its Arabic name from the Malay manuals, Ptolemy\'s '
          'houses and whether it is of the day or the night. The metals were '
          'not always these: the oldest Greek lists gave Jupiter electrum and '
          'Mercury tin.',
      'The Malay ketika tujuh, which Skeat recorded in 1900, divides each '
          'day into seven parts starting with the day\'s own planet in the '
          'same order: read here as the first seven planetary hours. The '
          'Javanese primbon consulted has no planetary hours.',
    ],
  ),
  (
    heading: 'Light',
    paragraphs: [
      'The golden hour is the sun between 6° up and 4° down, the blue '
          'hour between 4° and 6° down. These bands are a photographers\' '
          'convention, not a measure: the light on the day is the '
          'weather\'s, which the app does not know.',
      'Eclipses are worked out from the sun and the moon themselves and '
          'were checked against NASA\'s canon: every lunar eclipse of '
          '2021 to 2030 but one too faint to see, and the total eclipse of '
          '2024 at Dallas to thirty seconds. Meteor showers are the '
          'International Meteor Organization\'s list, each peak found for '
          'the year from the sun\'s longitude.',
      'The compass is turned from magnetic to true north by the World '
          'Magnetic Model 2025, which the app matches on all 100 of '
          'NOAA\'s published test values. Exposure limits use the NPF rule '
          'and the older 500 rule; the moon\'s exposure starts from Looney '
          '11, as NASA\'s guide gives it.',
    ],
  ),
  (
    heading: 'Prayer times',
    paragraphs: [
      'Reckoned as the Ministry of Religious Affairs reckons its '
          'schedules: Subuh with the sun 20° below the horizon, Isya 18° '
          'below, Asar when a shadow is its own length beyond its noon '
          'shadow, Duha with the sun 4.5° up, Imsak ten minutes before '
          'Subuh, and two minutes of margin on each (three on Zuhur, and '
          'two taken off Terbit). The ministry does not say at what height '
          'it puts the sun at sunrise and sunset; fitted to its schedules '
          'it is 1° below the horizon, and that is used.',
      'Held against the ministry\'s own schedules for Jakarta, '
          'Yogyakarta, Banda Aceh and Jayapura over three months, every '
          'one of the 2,944 times came within a minute, and more than nine '
          'in ten to the minute. The minute left over is the place: the '
          'ministry does not say which point of a city it reckons from.',
      'The times are for the place you set, at sea level. A mosque\'s '
          'schedule, or another body\'s (Muhammadiyah reckons Subuh at '
          '18°), may differ.',
      'Outside Indonesia the times follow the convention you choose: the '
          'Muslim World League, the Moonsighting Committee, ISNA, Egypt, '
          'Karachi, Umm al-Qura, Dubai, Kuwait, Qatar, Singapore and '
          'Malaysia, Turkey\'s Diyanet or Tehran, with the parameters of '
          'the adhan library. Against the timetables those bodies publish '
          'they came within two minutes, most to the minute. Inside '
          'Indonesia the ministry\'s reckoning is always used.',
    ],
  ),
  (
    heading: 'Hilal',
    paragraphs: [
      'Astronomy only. The app shows where the young crescent stands after '
          'the new moon and what each published criterion makes of it; it '
          'never says a month has begun. That is for those who rule on it, '
          'by their own criterion and, for many, by sight.',
      'Sunset is the sun\'s upper edge on the horizon, the air lifting it '
          '34′. The moon\'s height is its centre from your place with no '
          'air, as Bosscha Observatory gives it; the elongation is from '
          'the Earth\'s centre, as the ministry agreed in 2023. On four '
          'evenings of 2025 and 2026 the app matched Bosscha\'s published '
          'figures to within seconds of time and of arc.',
      'MABIMS asks for the moon 3° high and 6.4° from the sun, and the '
          'ministry holds it for all Indonesia if it is met anywhere in it; '
          'the app sweeps every whole degree of the country. Wujudul hilal '
          'was Muhammadiyah\'s rule until 1446 H, as its Pedoman Hisab sets '
          'it out. Its global calendar since then is reckoned for the whole '
          'world and is not worked out here.',
      'Odeh (2004) and Yallop (1997) are forecasts of whether the crescent '
          'can be seen at all, built from records of sightings. The app '
          'gives the same numbers as their own published tables.',
    ],
  ),
  (
    heading: 'Places',
    paragraphs: [
      'Indonesia\'s provinces, kabupaten, kota and 7,285 kecamatan carry '
          'their official names and outlines, after the Home Ministry\'s '
          'decrees of 2025; the rest of the world, its towns of 15,000 '
          'people or more from GeoNames; the map, Natural Earth\'s '
          'countries. Everything is in the app, and nothing is looked up '
          'over the network.',
      'A place is kept only on the phone, rounded to a tenth of a degree, '
          'about 11 km. A touch on the map in Indonesia picks the kecamatan '
          'it falls in and puts the place at a point inside it, so the map '
          'never knows the exact spot touched.',
    ],
  ),
];
