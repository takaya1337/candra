import 'bazi.dart';
import 'bazi_chart.dart';
import 'chinese_date.dart';

/// One term of the art in every tongue the app speaks it in.
///
/// [hanzi] is the term itself, in traditional characters. [pinyin] is
/// its Mandarin reading. [hokkien] is its Hokkien reading, the tongue
/// most Chinese Indonesians have these words from, in the plain alphabet
/// as Indonesians write it: the sourced Pe̍h-ōe-jī with its tone marks
/// and special letters taken off (piáⁿ is pian, bō͘ is bo). It is empty
/// where no attested reading was found, never guessed. [english] and
/// [indonesian] say what it means; where a tongue has no settled word for
/// it they are a plain translation of the sense, made for this app, and
/// [coined] says so.
class BaziTerm {
  final String hanzi;
  final String pinyin;
  final String hokkien;
  final String english;
  final String indonesian;

  /// Whether the English and Indonesian are this app's own renderings and
  /// not established terms.
  final bool coined;

  const BaziTerm(
    this.hanzi,
    this.pinyin,
    this.hokkien,
    this.english,
    this.indonesian, {
    this.coined = false,
  });
}

/// The words of bazi in Chinese, English, Indonesian and Hokkien.
///
/// Sources. Characters and pinyin: the Chinese Wikipedia articles 天干,
/// 地支 and 節氣. Hokkien readings of the stems, the branches and the
/// twenty-four solar terms: the Bân-lâm-gí (Min Nan) Wikipedia articles
/// Thian-kan, Tē-chi and Jī-cha̍p-sì chiat-khì, read on 12 October 2026.
/// Hokkien readings of the five elements: the literary readings in the
/// Ministry of Education's Taiwanese dictionary (sutian.moe.edu.tw), read
/// on 13 October 2026, respelt from its Tâi-lô into Pe̍h-ōe-jī. That
/// dictionary has no entry for any of the ten gods, so those stay empty.
/// English names of the ten gods and the solar terms follow common usage
/// in English-language writing on the subject. Indonesian has no settled
/// vocabulary for the ten gods or the solar terms: those are translated
/// here from the sense, and marked [BaziTerm.coined].
abstract final class BaziTerms {
  /// The ten heavenly stems, in the order of [Stem].
  static const stems = [
    BaziTerm('甲', 'jiǎ', 'kah', 'Yang Wood', 'Kayu Yang'),
    BaziTerm('乙', 'yǐ', 'it', 'Yin Wood', 'Kayu Yin'),
    BaziTerm('丙', 'bǐng', 'pian', 'Yang Fire', 'Api Yang'),
    BaziTerm('丁', 'dīng', 'teng', 'Yin Fire', 'Api Yin'),
    BaziTerm('戊', 'wù', 'bo', 'Yang Earth', 'Tanah Yang'),
    BaziTerm('己', 'jǐ', 'ki', 'Yin Earth', 'Tanah Yin'),
    BaziTerm('庚', 'gēng', 'kin', 'Yang Metal', 'Logam Yang'),
    BaziTerm('辛', 'xīn', 'sin', 'Yin Metal', 'Logam Yin'),
    BaziTerm('壬', 'rén', 'jim', 'Yang Water', 'Air Yang'),
    BaziTerm('癸', 'guǐ', 'kui', 'Yin Water', 'Air Yin'),
  ];

  /// The twelve earthly branches, in the order of [Branch], each by its
  /// animal.
  static const branches = [
    BaziTerm('子', 'zǐ', 'chu', 'Rat', 'Tikus'),
    BaziTerm('丑', 'chǒu', 'thiu', 'Ox', 'Kerbau'),
    BaziTerm('寅', 'yín', 'in', 'Tiger', 'Macan'),
    BaziTerm('卯', 'mǎo', 'bau', 'Rabbit', 'Kelinci'),
    BaziTerm('辰', 'chén', 'sin', 'Dragon', 'Naga'),
    BaziTerm('巳', 'sì', 'su', 'Snake', 'Ular'),
    BaziTerm('午', 'wǔ', 'ngo', 'Horse', 'Kuda'),
    BaziTerm('未', 'wèi', 'bi', 'Goat', 'Kambing'),
    BaziTerm('申', 'shēn', 'sin', 'Monkey', 'Monyet'),
    BaziTerm('酉', 'yǒu', 'iu', 'Rooster', 'Ayam'),
    BaziTerm('戌', 'xū', 'sut', 'Dog', 'Anjing'),
    BaziTerm('亥', 'hài', 'hai', 'Pig', 'Babi'),
  ];

  /// The five elements, in the order of [Unsur].
  static const elements = [
    BaziTerm('木', 'mù', 'bok', 'Wood', 'Kayu'),
    BaziTerm('火', 'huǒ', 'hon', 'Fire', 'Api'),
    BaziTerm('土', 'tǔ', 'tho', 'Earth', 'Tanah'),
    BaziTerm('金', 'jīn', 'kim', 'Metal', 'Logam'),
    BaziTerm('水', 'shuǐ', 'sui', 'Water', 'Air'),
  ];

  /// The ten gods, in the order of [TenGod].
  static const tenGods = [
    BaziTerm('比肩', 'bǐjiān', '', 'Peer', 'Sejawat', coined: true),
    BaziTerm('劫財', 'jiécái', '', 'Rival', 'Perebut Harta', coined: true),
    BaziTerm('食神', 'shíshén', '', 'Eating God', 'Dewa Makan', coined: true),
    BaziTerm(
      '傷官',
      'shāngguān',
      '',
      'Hurting Officer',
      'Pelawan Pejabat',
      coined: true,
    ),
    BaziTerm(
      '偏財',
      'piāncái',
      '',
      'Indirect Wealth',
      'Harta Tak Langsung',
      coined: true,
    ),
    BaziTerm(
      '正財',
      'zhèngcái',
      '',
      'Direct Wealth',
      'Harta Langsung',
      coined: true,
    ),
    BaziTerm(
      '七殺',
      'qīshā',
      '',
      'Seven Killings',
      'Tujuh Pembunuh',
      coined: true,
    ),
    BaziTerm(
      '正官',
      'zhèngguān',
      '',
      'Direct Officer',
      'Pejabat Langsung',
      coined: true,
    ),
    BaziTerm(
      '偏印',
      'piānyìn',
      '',
      'Indirect Seal',
      'Cap Tak Langsung',
      coined: true,
    ),
    BaziTerm('正印', 'zhèngyìn', '', 'Direct Seal', 'Cap Langsung', coined: true),
  ];

  /// The twenty-four solar terms, from Lichun, each fifteen degrees of
  /// the sun's path after the last. The even places are the twelve nodes
  /// (節) that turn the month pillar; the odd are the breaths (氣), which
  /// turn nothing.
  static const solarTerms = [
    BaziTerm(
      '立春',
      'lìchūn',
      'lip-chhun',
      'Start of Spring',
      'Awal Musim Semi',
      coined: true,
    ),
    BaziTerm('雨水', 'yǔshuǐ', 'u-sui', 'Rain Water', 'Air Hujan', coined: true),
    BaziTerm(
      '驚蟄',
      'jīngzhé',
      'ken-tit',
      'Awakening of Insects',
      'Serangga Terbangun',
      coined: true,
    ),
    BaziTerm(
      '春分',
      'chūnfēn',
      'chhun-hun',
      'Spring Equinox',
      'Ekuinoks Musim Semi',
    ),
    BaziTerm(
      '清明',
      'qīngmíng',
      'chheng-beng',
      'Pure Brightness',
      'Terang Jernih',
      coined: true,
    ),
    BaziTerm(
      '穀雨',
      'gǔyǔ',
      'kok-u',
      'Grain Rain',
      'Hujan Biji-bijian',
      coined: true,
    ),
    BaziTerm(
      '立夏',
      'lìxià',
      'lip-ha',
      'Start of Summer',
      'Awal Musim Panas',
      coined: true,
    ),
    BaziTerm(
      '小滿',
      'xiǎomǎn',
      'siau-boan',
      'Grain Buds',
      'Bulir Mulai Berisi',
      coined: true,
    ),
    BaziTerm(
      '芒種',
      'mángzhòng',
      'bong-cheng',
      'Grain in Ear',
      'Bulir Berjanggut',
      coined: true,
    ),
    BaziTerm(
      '夏至',
      'xiàzhì',
      'ha-chi',
      'Summer Solstice',
      'Titik Balik Musim Panas',
    ),
    BaziTerm(
      '小暑',
      'xiǎoshǔ',
      'siau-su',
      'Minor Heat',
      'Panas Kecil',
      coined: true,
    ),
    BaziTerm(
      '大暑',
      'dàshǔ',
      'tai-su',
      'Major Heat',
      'Panas Besar',
      coined: true,
    ),
    BaziTerm(
      '立秋',
      'lìqiū',
      'lip-chhiu',
      'Start of Autumn',
      'Awal Musim Gugur',
      coined: true,
    ),
    BaziTerm(
      '處暑',
      'chǔshǔ',
      'chhu-su',
      'End of Heat',
      'Akhir Panas',
      coined: true,
    ),
    BaziTerm('白露', 'báilù', 'peh-lo', 'White Dew', 'Embun Putih', coined: true),
    BaziTerm(
      '秋分',
      'qiūfēn',
      'chhiu-hun',
      'Autumn Equinox',
      'Ekuinoks Musim Gugur',
    ),
    BaziTerm('寒露', 'hánlù', 'han-lo', 'Cold Dew', 'Embun Dingin', coined: true),
    BaziTerm(
      '霜降',
      'shuāngjiàng',
      'sng-kang',
      'Frost Descent',
      'Turunnya Embun Beku',
      coined: true,
    ),
    BaziTerm(
      '立冬',
      'lìdōng',
      'lip-tang',
      'Start of Winter',
      'Awal Musim Dingin',
      coined: true,
    ),
    BaziTerm(
      '小雪',
      'xiǎoxuě',
      'siau-soat',
      'Minor Snow',
      'Salju Kecil',
      coined: true,
    ),
    BaziTerm(
      '大雪',
      'dàxuě',
      'tai-soat',
      'Major Snow',
      'Salju Besar',
      coined: true,
    ),
    BaziTerm(
      '冬至',
      'dōngzhì',
      'tang-chi',
      'Winter Solstice',
      'Titik Balik Musim Dingin',
    ),
    BaziTerm(
      '小寒',
      'xiǎohán',
      'siau-han',
      'Minor Cold',
      'Dingin Kecil',
      coined: true,
    ),
    BaziTerm(
      '大寒',
      'dàhán',
      'tai-han',
      'Major Cold',
      'Dingin Besar',
      coined: true,
    ),
  ];

  /// The four pillars: year, month, day, hour.
  static const pillars = [
    BaziTerm('年柱', 'niánzhù', '', 'Year', 'Tahun'),
    BaziTerm('月柱', 'yuèzhù', '', 'Month', 'Bulan'),
    BaziTerm('日柱', 'rìzhù', '', 'Day', 'Hari'),
    BaziTerm('時柱', 'shízhù', '', 'Hour', 'Jam'),
  ];

  /// The relations between branches.
  static const clash = BaziTerm('冲', 'chōng', '', 'Clash', 'Bentrok');
  static const harmony = BaziTerm('六合', 'liùhé', '', 'Harmony', 'Selaras');
  static const trine = BaziTerm(
    '三合',
    'sānhé',
    '',
    'Trine',
    'Tiga Selaras',
    coined: true,
  );
  static const punishment = BaziTerm('刑', 'xíng', '', 'Punishment', 'Hukuman');
  static const harm = BaziTerm('害', 'hài', '', 'Harm', 'Celaka');

  /// The stem that has the month in hand on a given day of it.
  static const command = BaziTerm(
    '司令',
    'sīlìng',
    '',
    'In Command',
    'Berkuasa',
    coined: true,
  );

  /// The combining of two stems five apart.
  static const stemCombination = BaziTerm(
    '五合',
    'wǔhé',
    '',
    'Stem Combination',
    'Gabungan Batang',
    coined: true,
  );

  /// The two branches a pillar's ten-day week does not reach.
  static const voidBranches = BaziTerm(
    '空亡',
    'kōngwáng',
    '',
    'Void',
    'Kosong',
    coined: true,
  );

  /// The element a pillar's pair is said to sound. No tongue but Chinese
  /// has a word for it.
  static const nayin = BaziTerm('納音', 'nàyīn', '', 'Nayin', 'Nayin');

  /// Other words of the chart.
  static const dayMaster = BaziTerm(
    '日主',
    'rìzhǔ',
    '',
    'Day Master',
    'Tuan Hari',
    coined: true,
  );
  static const hiddenStems = BaziTerm(
    '藏干',
    'cánggān',
    '',
    'Hidden Stems',
    'Batang Tersembunyi',
    coined: true,
  );
  static const luckPillars = BaziTerm(
    '大運',
    'dàyùn',
    '',
    'Luck Pillars',
    'Pilar Keberuntungan',
    coined: true,
  );
  static const trueSolarTime = BaziTerm(
    '真太陽時',
    'zhēn tàiyáng shí',
    '',
    'True Solar Time',
    'Waktu Matahari Sejati',
  );
  static const lateZi = BaziTerm(
    '晚子時',
    'wǎn zǐshí',
    '',
    'Late Zi Hour',
    'Jam Zi Akhir',
    coined: true,
  );

  static BaziTerm stem(Stem stem) => stems[stem.index];
  static BaziTerm branch(Branch branch) => branches[branch.index];
  static BaziTerm element(Unsur element) => elements[element.index];
  static BaziTerm tenGod(TenGod god) => tenGods[god.index];

  /// The solar term at [longitude] degrees of the sun, a multiple of 15.
  static BaziTerm solarTerm(double longitude) =>
      solarTerms[(((longitude - 315) % 360) / 15).round() % 24];
}
