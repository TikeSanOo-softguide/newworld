import '../../core/network/api_client.dart';
import '../../core/network/app_endpoints.dart';
import '../lobby/realtime/lobby_socket_service.dart';
import 'baccarat_detail_models.dart';
import 'repeat_bet.dart';

class BaccaratDetailRepository {
  BaccaratDetailRepository(this._api);

  final ApiClient _api;

  Future<BaccaratDeskDetail> getDesk(int deskId, String token) async {
    final response = await _api.getJson(
      AppEndpoints.desks,
      query: AppEndpoints.siteNameUserQuery,
      token: token,
    );
    final data = response['data'];
    final desks = data is Map ? data['desks'] : null;
    if (desks is! List) {
      throw const FormatException('桌台列表响应缺少 desks');
    }
    for (final item in desks) {
      if (item is! Map) continue;
      final id = _asInt(item['id']);
      if (id == deskId) {
        return BaccaratDeskDetail.fromJson(Map<String, dynamic>.from(item));
      }
    }
    throw const FormatException('找不到所选桌台');
  }

  Future<List<BaccaratResultOption>> getResultOptions(
    int deskId,
    String token,
  ) async {
    final response = await _api.getJson(
      AppEndpoints.resultsByDesk(deskId),
      token: token,
    );
    final data = response['data'];
    final options = data is Map ? data['results'] : null;
    if (options is! List) {
      throw const FormatException('投注选项响应缺少 results');
    }
    final parsed =
        options.map(BaccaratResultOption.fromJson).toList(growable: true)
          ..sort((a, b) => a.position.compareTo(b.position));
    return List.unmodifiable(parsed);
  }

  Future<BaccaratRoundStatus> getRoundStatus(int deskId, String token) async {
    final response = await _api.getJson(
      AppEndpoints.lastRoundStatusFor(deskId),
      token: token,
    );
    return BaccaratRoundStatus.fromApi(response);
  }

  Future<BaccaratConfirmedBets> getConfirmedBets(
    int? lastRoundId,
    String token,
  ) async {
    if (lastRoundId == null) return _emptyConfirmedBets;
    final response = await _api.getJson(
      AppEndpoints.confirmBets(lastRoundId),
      token: token,
    );
    return BaccaratConfirmedBets.fromApi(response);
  }

  Future<BaccaratPoolTotals> getPoolTotals(int? roundId, String token) async {
    if (roundId == null) return BaccaratPoolTotals.empty;
    final response = await _api.getJson(
      AppEndpoints.roundPoolTotals(roundId),
      token: token,
    );
    return BaccaratPoolTotals.fromApi(response);
  }

  Future<BaccaratMemberProfile> getProfile(String token) async {
    final response = await _api.getJson(AppEndpoints.profile, token: token);
    return BaccaratMemberProfile.fromApi(response);
  }

  Future<BaccaratBetSubmission> submitBets({
    required int lastRoundId,
    required List<BaccaratBetSubmissionItem> bets,
    required String token,
    required String csrfToken,
  }) async {
    final response = await _api.postJson(
      AppEndpoints.betResults,
      token: token,
      csrfToken: csrfToken,
      body: {
        'last_round': lastRoundId,
        'bets': bets.map((bet) => bet.toJson()).toList(growable: false),
      },
    );
    _requireSuccess(response);
    final data = response['data'];
    if (data is! Map) {
      throw const FormatException('投注成功响应缺少 data');
    }
    return BaccaratBetSubmission.fromJson(data);
  }

  Future<void> cancelBets({
    required int lastRoundId,
    required String token,
    required String csrfToken,
  }) async {
    final response = await _api.postJson(
      AppEndpoints.cancelBetResults,
      token: token,
      csrfToken: csrfToken,
      body: {'last_round': lastRoundId},
    );
    _requireSuccess(response);
  }

  Future<List<BaccaratLedgerEntry>> getLedger({
    required String token,
    required DateTime date,
  }) async {
    final day = _dateString(date);
    final response = await _api.getJson(
      AppEndpoints.memberLedger,
      query: {'startDate': day, 'endDate': day, 'page': '1', 'limit': '20'},
      token: token,
    );
    final data = response['data'];
    final reports = data is Map ? data['memberReports'] : null;
    if (reports is! List) {
      throw const FormatException('投注记录响应缺少 memberReports');
    }
    return List.unmodifiable(reports.map(BaccaratLedgerEntry.fromJson));
  }

  /// Newest stake rows for one desk. `tableNo` is the desk id on this route.
  Future<List<DeskStakeRow>> recentDeskStakes({
    required String token,
    required int deskId,
  }) async {
    final response = await _api.getJson(
      AppEndpoints.memberLedger,
      query: {'tableNo': '$deskId', 'page': '1', 'limit': '20'},
      token: token,
    );
    final data = response['data'];
    final reports = data is Map ? data['memberReports'] : null;
    if (reports is! List) {
      throw const FormatException('投注记录响应缺少 memberReports');
    }
    final rows = <DeskStakeRow>[];
    for (final item in reports) {
      if (item is! Map) continue;
      if (item['row_kind']?.toString() == 'wallet') continue;
      if (item['cancel_flg'] == true) continue;
      final betName = item['bet_name']?.toString() ?? '';
      if (betName.trim().isEmpty) continue;
      rows.add(
        DeskStakeRow(
          deskName: item['desk_name']?.toString() ?? '',
          betName: betName,
        ),
      );
    }
    return List.unmodifiable(rows);
  }
}

class BaccaratPoolTotals {
  const BaccaratPoolTotals({
    required this.roundId,
    required this.poolType,
    required this.totals,
    required this.displayTotals,
  });

  static const empty = BaccaratPoolTotals(
    roundId: 0,
    poolType: '',
    totals: {},
    displayTotals: {},
  );

  final int roundId;
  final String poolType;
  final Map<String, num> totals;
  final Map<String, num> displayTotals;

  factory BaccaratPoolTotals.fromApi(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map) {
      throw const FormatException('台面投注汇总响应缺少 data');
    }
    final roundId = _asInt(data['round_id']);
    final poolType = data['pool_type']?.toString();
    final totals = _numericMap(data['totals']);
    final displayTotals = _numericMap(data['display_totals']);
    if (roundId == null ||
        poolType == null ||
        totals == null ||
        displayTotals == null) {
      throw const FormatException('台面投注汇总响应格式无效');
    }
    return BaccaratPoolTotals(
      roundId: roundId,
      poolType: poolType,
      totals: Map.unmodifiable(totals),
      displayTotals: Map.unmodifiable(displayTotals),
    );
  }

  factory BaccaratPoolTotals.fromSocket(LobbyDeskPoolTotalsUpdate update) =>
      BaccaratPoolTotals(
        roundId: update.roundId,
        poolType: update.poolType,
        totals: update.totals,
        displayTotals: update.displayTotals,
      );
}

class BaccaratBetSubmissionItem {
  const BaccaratBetSubmissionItem({
    required this.resultId,
    required this.amount,
    required this.image,
  });

  final int resultId;
  final num amount;
  final String image;

  Map<String, Object> toJson() => {
    'result_id': resultId,
    'amount': amount,
    'image': image,
  };
}

class BaccaratBetSubmission {
  const BaccaratBetSubmission({
    required this.totalBetAmount,
    required this.remainingBalance,
    required this.confirmedBets,
  });

  final num totalBetAmount;
  final num remainingBalance;
  final BaccaratConfirmedBets confirmedBets;

  factory BaccaratBetSubmission.fromJson(Map data) {
    final totalAmount = _asNum(data['totalBetAmount']);
    final balance = _asNum(data['remainingBalance']);
    if (totalAmount == null || balance == null) {
      throw const FormatException('投注响应缺少 totalBetAmount 或 remainingBalance');
    }
    return BaccaratBetSubmission(
      totalBetAmount: totalAmount,
      remainingBalance: balance,
      confirmedBets: BaccaratConfirmedBets.fromApi({'data': data}),
    );
  }
}

const _emptyConfirmedBets = BaccaratConfirmedBets(
  byResultKey: {},
  totalAmount: 0,
);

void _requireSuccess(Map<String, dynamic> response) {
  if (response['success'] == true) return;
  throw BaccaratActionException(
    response['message']?.toString().trim().isNotEmpty == true
        ? response['message'].toString()
        : '服务器未确认投注操作',
  );
}

class BaccaratActionException implements Exception {
  const BaccaratActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _dateString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

num? _asNum(Object? value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '');
}

Map<String, num>? _numericMap(Object? value) {
  if (value is! Map) return null;
  final parsed = <String, num>{};
  for (final entry in value.entries) {
    final amount = _asNum(entry.value);
    if (amount == null) return null;
    parsed[entry.key.toString()] = amount;
  }
  return parsed;
}
