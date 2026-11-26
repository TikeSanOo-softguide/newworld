import 'baccarat_detail_models.dart';

/// One settled stake row from `GET /user/member_ledger`.
class DeskStakeRow {
  const DeskStakeRow({required this.deskName, required this.betName});

  /// `desk/session/round`, as stored by the ledger.
  final String deskName;

  /// `闲: 50, 庄对: 100`. This is the stake list, not the round outcome.
  final String betName;
}

/// `闲: 50, 庄对: 100` becomes `{闲: 50, 庄对: 100}`.
Map<String, num> parseRepeatStakeText(String betName) {
  final amounts = <String, num>{};
  final pattern = RegExp(r'([^,:]+):\s*([0-9]+(?:\.[0-9]+)?)');
  for (final match in pattern.allMatches(betName)) {
    final name = match.group(1)!.trim();
    final amount = num.tryParse(match.group(2)!);
    if (name.isEmpty || amount == null || amount <= 0) continue;
    amounts.update(name, (value) => value + amount, ifAbsent: () => amount);
  }
  return amounts;
}

bool stakeRowMatchesDesk(String deskName, String desk) {
  final head = deskName.split('/').first.trim();
  return head.isNotEmpty && head == desk.trim();
}

bool stakeRowIsCurrentRound({
  required String deskName,
  required int? sessionNo,
  required int? roundNo,
}) {
  final parts = deskName.split('/');
  if (parts.length < 3 || sessionNo == null || roundNo == null) return false;
  return parts[parts.length - 2] == '$sessionNo' && parts.last == '$roundNo';
}

/// The newest ledger stake for [deskName] that is not the open round.
/// Positions are matched by the result name on this desk.
Map<int, num>? repeatAmountsForDesk({
  required List<DeskStakeRow> rows,
  required String deskName,
  required int? sessionNo,
  required int? roundNo,
  required List<BaccaratResultOption> options,
}) {
  final optionsByName = {for (final option in options) option.name: option};
  for (final row in rows) {
    if (!stakeRowMatchesDesk(row.deskName, deskName)) continue;
    if (stakeRowIsCurrentRound(
      deskName: row.deskName,
      sessionNo: sessionNo,
      roundNo: roundNo,
    )) {
      continue;
    }
    final amounts = <int, num>{};
    for (final entry in parseRepeatStakeText(row.betName).entries) {
      final option = optionsByName[entry.key];
      if (option == null) continue;
      amounts.update(
        option.id,
        (value) => value + entry.value,
        ifAbsent: () => entry.value,
      );
    }
    if (amounts.isNotEmpty) return amounts;
  }
  return null;
}
