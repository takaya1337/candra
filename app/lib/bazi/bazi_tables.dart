import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sacred_time/sacred_time.dart';

/// The tables of bazi that schools differ on, read from data files: which
/// stems each branch hides, and which branches punish and harm each
/// other. Each file names the lineage it speaks for and says whether it
/// has been checked against that lineage's texts.
class BaziTables {
  /// The stems hidden in each branch, principal first.
  final Map<Branch, List<Stem>> hiddenStems;

  /// For a table that says so: the stems that command a month in turn
  /// from the node term that opens it, each with its days. Null for a
  /// table that only lists the stems.
  final Map<Branch, List<(Stem, int)>>? command;
  final List<
    ({List<Branch> branches, String name, String english, String indonesian})
  >
  punishments;
  final Set<Branch> selfPunishing;
  final List<(Branch, Branch)> harms;

  /// What the hidden-stem table says of itself.
  final TableSource hidden;

  /// What the table of punishments and harms says of itself.
  final TableSource relations;

  const BaziTables({
    required this.hiddenStems,
    required this.command,
    required this.punishments,
    required this.selfPunishing,
    required this.harms,
    required this.hidden,
    required this.relations,
  });

  /// The tables of the default lineage, read once.
  static Future<BaziTables> load([AssetBundle? bundle]) async =>
      (await BaziLibrary.load(bundle)).tables(0, 0);

  static BaziTables parse(String hiddenStems, String relations) {
    final hidden = jsonDecode(hiddenStems) as Map<String, dynamic>;
    final related = jsonDecode(relations) as Map<String, dynamic>;
    Branch branch(Object? hanzi) =>
        Branch.values.firstWhere((b) => b.hanzi == hanzi);
    Stem stem(Object? hanzi) => Stem.values.firstWhere((s) => s.hanzi == hanzi);
    final command = hidden['command'] as Map<String, dynamic>?;

    return BaziTables(
      hiddenStems: {
        for (final entry
            in (hidden['branches'] as Map<String, dynamic>).entries)
          branch(entry.key): [for (final s in entry.value as List) stem(s)],
      },
      command: command == null
          ? null
          : {
              for (final entry in command.entries)
                branch(entry.key): [
                  for (final turn
                      in (entry.value as List).cast<List<dynamic>>())
                    (stem(turn[0]), turn[1] as int),
                ],
            },
      punishments: [
        for (final item
            in (related['punishments'] as List).cast<Map<String, dynamic>>())
          (
            branches: [for (final b in item['branches'] as List) branch(b)],
            name: item['name'] as String,
            english: item['english'] as String,
            indonesian: item['indonesian'] as String,
          ),
      ],
      selfPunishing: {
        for (final b in related['selfPunishing'] as List) branch(b),
      },
      harms: [
        for (final pair in (related['harms'] as List).cast<List<dynamic>>())
          (branch(pair[0]), branch(pair[1])),
      ],
      hidden: TableSource._of(hidden),
      relations: TableSource._of(related),
    );
  }

  /// The element a branch is counted as: that of its principal stem.
  Unsur elementOf(Branch branch) => hiddenStems[branch]!.first.unsur;

  /// The stem in command of the month of [branch], [elapsed] after the
  /// node term that opened it, by a table that divides the month; null
  /// by one that does not. The last in turn keeps whatever of the month
  /// is left.
  Stem? commanding(Branch branch, Duration elapsed) {
    final turns = command?[branch];
    if (turns == null) return null;
    var days = elapsed.inSeconds / Duration.secondsPerDay;
    for (final (stem, length) in turns) {
      if (days < length) return stem;
      days -= length;
    }
    return turns.last.$1;
  }
}

/// What a table says of itself: its name, whose it is, where it was read
/// and whether it has been checked.
class TableSource {
  final String id;
  final String english;
  final String indonesian;
  final String lineage;
  final String source;
  final bool verified;
  final String notes;

  const TableSource({
    required this.id,
    required this.english,
    required this.indonesian,
    required this.lineage,
    required this.source,
    required this.verified,
    required this.notes,
  });

  TableSource._of(Map<String, dynamic> file)
    : id = file['id'] as String,
      english = file['english'] as String,
      indonesian = file['indonesian'] as String,
      lineage = file['lineage'] as String,
      source = file['source'] as String,
      verified = file['verified'] == true,
      notes = file['notes'] as String;
}

/// Every table the app ships, to choose among. No one of them is the
/// right one: the first of each kind is only where a chart starts.
class BaziLibrary {
  static const hiddenStemFiles = ['ziping.v1', 'siling.v1'];
  static const relationFiles = ['ziping.v1', 'yuanhai.v1', 'renshi.v1'];

  final List<String> _hidden;
  final List<String> _relations;
  final _made = <(int, int), BaziTables>{};

  /// From the text of each file, in the order they are offered.
  BaziLibrary(this._hidden, this._relations);

  static BaziLibrary? _loaded;

  static Future<BaziLibrary> load([AssetBundle? bundle]) async {
    final from = bundle ?? rootBundle;
    return _loaded ??= BaziLibrary(
      [
        for (final id in hiddenStemFiles)
          await from.loadString('assets/bazi/hidden_stems.$id.json'),
      ],
      [
        for (final id in relationFiles)
          await from.loadString('assets/bazi/relations.$id.json'),
      ],
    );
  }

  /// The tables with the hidden stems of one file and the punishments
  /// and harms of another.
  BaziTables tables(int hidden, int relations) => _made[(hidden, relations)] ??=
      BaziTables.parse(_hidden[hidden], _relations[relations]);

  /// What each hidden-stem table says of itself.
  late final hiddenStems = [
    for (var i = 0; i < _hidden.length; i++) tables(i, 0).hidden,
  ];

  /// What each table of punishments and harms says of itself.
  late final relations = [
    for (var i = 0; i < _relations.length; i++) tables(0, i).relations,
  ];
}

/// One relation found between the branches of a chart.
typedef BranchRelation = ({
  BaziTerm kind,
  List<Branch> branches,
  String? detail,
});

/// Every relation among [branches], the four of a chart in their order:
/// the three every school agrees on, worked out; then the punishments
/// and harms of [tables].
List<BranchRelation> relationsAmong(List<Branch> branches, BaziTables tables) {
  final found = <BranchRelation>[];
  final distinct = branches.toSet();
  for (var i = 0; i < branches.length; i++) {
    for (var j = i + 1; j < branches.length; j++) {
      final a = branches[i];
      final b = branches[j];
      if (a.clash == b) {
        found.add((kind: BaziTerms.clash, branches: [a, b], detail: null));
      }
      if (a.harmony == b) {
        found.add((kind: BaziTerms.harmony, branches: [a, b], detail: null));
      }
      if (tables.harms.any(
        (h) => (h.$1 == a && h.$2 == b) || (h.$1 == b && h.$2 == a),
      )) {
        found.add((kind: BaziTerms.harm, branches: [a, b], detail: null));
      }
      if (a == b && tables.selfPunishing.contains(a)) {
        found.add((kind: BaziTerms.punishment, branches: [a, b], detail: null));
      }
    }
  }
  // A trine is whole only with all three of its branches.
  for (final element in Unsur.values) {
    final members = [
      for (final branch in Branch.values)
        if (branch.trine == element && distinct.contains(branch)) branch,
    ];
    if (members.length == 3) {
      found.add((kind: BaziTerms.trine, branches: members, detail: null));
    }
  }
  for (final punishment in tables.punishments) {
    final members = [
      for (final branch in punishment.branches)
        if (distinct.contains(branch)) branch,
    ];
    // Two of a three, or the pair, is enough to note.
    if (members.length >= 2) {
      found.add((
        kind: BaziTerms.punishment,
        branches: members,
        detail: punishment.name,
      ));
    }
  }
  return found;
}
