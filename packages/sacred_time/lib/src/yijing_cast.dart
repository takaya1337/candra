import 'dart:math';

/// What a cast gives for one line of a hexagram: one of the four numbers
/// of the Yijing. Seven and eight are lines at rest; nine and six are
/// lines about to turn into their opposite.
enum LineValue {
  /// Six, old yin: a broken line that changes to a whole one.
  oldYin(6),

  /// Seven, young yang: a whole line that stays.
  youngYang(7),

  /// Eight, young yin: a broken line that stays.
  youngYin(8),

  /// Nine, old yang: a whole line that changes to a broken one.
  oldYang(9);

  final int number;

  const LineValue(this.number);

  bool get isYang => number.isOdd;
  bool get changes => number == 6 || number == 9;

  static LineValue of(int number) =>
      values.firstWhere((value) => value.number == number);
}

/// One throw of three coins: a line.
///
/// A coin has a face with writing on it and a blank back. The back
/// counts three and the face two, so three backs make nine and three
/// faces six: 顧炎武, 日知錄 15, of the practice of his day, "以三漫為重
/// 爻為陽，三字為交爻為陰". The method is first described by 賈公彥 in
/// the Tang: "今則用錢，以三少為重錢，重錢則九也；三多為交錢，交錢則六
/// 也；兩多一少為單錢，單錢則七也；兩少一多為拆錢，拆錢則八也".
///
/// Each coin falls either way as often as the other, so six and nine
/// each come once in eight throws, seven and eight three times.
class CoinThrow {
  /// Whether each coin fell with its blank back up.
  final List<bool> backs;

  const CoinThrow(this.backs);

  LineValue get value =>
      LineValue.of(backs.fold(0, (sum, back) => sum + (back ? 3 : 2)));
}

/// One of the three countings of the stalks that make a line.
class StalkChange {
  /// The stalks in hand when the change began.
  final int before;

  /// The two heaps the stalks were parted into.
  final int left;
  final int right;

  /// What was left of each heap after counting it off by fours: one to
  /// four. The right heap had one stalk taken from it first.
  final int leftRemainder;
  final int rightRemainder;

  const StalkChange({
    required this.before,
    required this.left,
    required this.right,
    required this.leftRemainder,
    required this.rightRemainder,
  });

  /// The stalks laid aside: the one hung between the fingers and the two
  /// remainders. Five or nine in the first change, four or eight after.
  int get removed => 1 + leftRemainder + rightRemainder;

  /// The stalks carried into the next change.
  int get after => before - removed;
}

/// A line cast with the yarrow stalks: three changes.
///
/// The method of the Great Treatise ("大衍之數五十，其用四十有九。分而為
/// 二以象兩，掛一以象三，揲之以四以象四時，歸奇於扐以象閏"), as 朱熹's
/// 筮儀 sets it out step by step. Of fifty stalks one is put back and
/// forty-nine are used. They are parted in two at random; one is taken
/// from the right heap; each heap is counted off by fours and what is
/// left over, one to four, is laid aside with the one. That is a change.
/// It is done three times, with the stalks that remain, and what remains
/// at the end is thirty-six, thirty-two, twenty-eight or twenty-four:
/// nine, eight, seven or six fours.
///
/// The first change lays aside five three times in four and nine once;
/// the second and third, four or eight equally. So nine comes three
/// times in sixteen, six once, seven five times and eight seven: not the
/// odds of the coins.
class StalkLine {
  final List<StalkChange> changes;

  const StalkLine(this.changes);

  LineValue get value => LineValue.of(changes.last.after ~/ 4);
}

/// A hexagram as cast: six lines from the bottom up.
class YijingCast {
  final List<LineValue> lines;

  const YijingCast(this.lines);

  /// The hexagram cast: each line whole (true) or broken, bottom up.
  List<bool> get primary => [for (final line in lines) line.isYang];

  /// The places of the lines that change, from 0 at the bottom.
  List<int> get changing => [
    for (final (i, line) in lines.indexed)
      if (line.changes) i,
  ];

  /// The hexagram it turns into once the changing lines have changed;
  /// the same as [primary] when none do.
  List<bool> get relating => [
    for (final line in lines) line.changes ? !line.isYang : line.isYang,
  ];
}

/// The two ways of casting a line.
abstract final class Yijing {
  /// The stalks used: fifty less the one put back.
  static const stalks = 49;

  static CoinThrow throwCoins(Random random) =>
      CoinThrow([for (var i = 0; i < 3; i++) random.nextBool()]);

  static StalkLine countStalks(Random random) {
    final changes = <StalkChange>[];
    var inHand = stalks;
    for (var i = 0; i < 3; i++) {
      // Parted by hand: somewhere about the middle, over a stretch of
      // stalks that is a whole number of fours, so that the left heap
      // is as likely to leave one over as two, three or four. That is
      // how 朱熹 reckons the odds ("奇者三而偶者一").
      final span = 4 * (inHand ~/ 8);
      final left = (inHand - span) ~/ 2 + random.nextInt(span);
      final right = inHand - left;
      int remainder(int heap) => heap % 4 == 0 ? 4 : heap % 4;
      final change = StalkChange(
        before: inHand,
        left: left,
        right: right,
        leftRemainder: remainder(left),
        rightRemainder: remainder(right - 1),
      );
      changes.add(change);
      inHand = change.after;
    }
    return StalkLine(changes);
  }
}
