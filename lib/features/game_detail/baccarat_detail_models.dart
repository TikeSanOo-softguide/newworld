import '../lobby/models/lobby_round_result.dart';

class BaccaratDeskDetail {
  const BaccaratDeskDetail({
    required this.id,
    required this.gameId,
    required this.name,
    required this.gameName,
    required this.minBet,
    required this.maxBet,
    required this.sessionId,
    required this.lastRoundId,
    required this.lastRoundNo,
    required this.singleCamera,
    required this.rateLimitEnabled,
    required this.deskResultRateLimits,
    required this.results,
  });

  final int id;
  final int gameId;
  final String name;
  final String gameName;
  final int minBet;
  final int maxBet;
  final int? sessionId;
  final int? lastRoundId;
  final int? lastRoundNo;
  final bool singleCamera;
  final bool rateLimitEnabled;
  final Map<int, BaccaratBetLimit> deskResultRateLimits;
  final List<LobbyRoundResult> results;

  factory BaccaratDeskDetail.fromJson(Map<String, dynamic> json) {
    final id = _asInt(json['id']);
    final gameId = _asInt(json['game_id']);
    if (id == null || gameId == null) {
      throw const FormatException('桌台缺少有效的 ID');
    }

    final game = json['game'] is Map
        ? Map<String, dynamic>.from(json['game'] as Map)
        : const <String, dynamic>{};
    final type = game['type']?.toString() ?? '';
    if (type.toUpperCase() != 'BACCARAT') {
      throw const FormatException('所选桌台不是百家乐桌台');
    }

    final rawResults = json['results'];
    final results = <LobbyRoundResult>[];
    if (rawResults is List) {
      for (final result in rawResults) {
        results.add(LobbyRoundResult.fromApi(id, result));
      }
    }
    final session = json['session'] is Map
        ? Map<String, dynamic>.from(json['session'] as Map)
        : const <String, dynamic>{};
    final lastRound = json['last_round'] is Map
        ? Map<String, dynamic>.from(json['last_round'] as Map)
        : const <String, dynamic>{};
    final deskResultRateLimits = <int, BaccaratBetLimit>{};
    final rawDeskResultRateLimits = json['deskResultRateLimits'];
    if (rawDeskResultRateLimits is List) {
      for (final item in rawDeskResultRateLimits) {
        if (item is! Map ||
            item['status']?.toString() != 'online_betting_limit') {
          continue;
        }
        final resultId = _asInt(item['result_id']);
        final minBet = _asNum(item['min_bet']);
        final maxBet = _asNum(item['max_bet']);
        if (resultId == null || minBet == null || maxBet == null) continue;
        deskResultRateLimits[resultId] = BaccaratBetLimit(
          minBet: minBet,
          maxBet: maxBet,
        );
      }
    }

    return BaccaratDeskDetail(
      id: id,
      gameId: gameId,
      name: json['name']?.toString() ?? '台桌',
      gameName: game['name']?.toString() ?? '百家乐',
      minBet: _asInt(json['min_bet']) ?? 0,
      maxBet: _asInt(json['max_bet']) ?? 0,
      sessionId: _asInt(session['id']),
      lastRoundId: _asInt(lastRound['id']),
      lastRoundNo: _asInt(lastRound['round_no']),
      singleCamera: _asBool(json['single_camera_flg']),
      rateLimitEnabled: _asBool(json['rate_limit_flg']),
      deskResultRateLimits: Map.unmodifiable(deskResultRateLimits),
      results: List.unmodifiable(results),
    );
  }
}

class BaccaratBetLimit {
  const BaccaratBetLimit({required this.minBet, required this.maxBet});

  final num minBet;
  final num maxBet;
}

class BaccaratMemberProfile {
  const BaccaratMemberProfile({
    required this.balance,
    required this.resultRateLimits,
  });

  final num balance;
  final Map<int, BaccaratBetLimit> resultRateLimits;

  factory BaccaratMemberProfile.fromApi(Map<String, dynamic> response) {
    final data = response['data'];
    final user = data is Map ? data['user'] : null;
    if (user is! Map) {
      throw const FormatException('会员资料响应缺少 user');
    }
    final balance = _asNum(user['balance']);
    if (balance == null) {
      throw const FormatException('会员资料响应缺少 balance');
    }

    final limits = <int, BaccaratBetLimit>{};
    final rawUserLimits = user['userRateLimits'];
    if (rawUserLimits is List) {
      for (final userLimit in rawUserLimits) {
        if (userLimit is! Map) continue;
        final resultLimit = userLimit['resultRateLimit'];
        if (resultLimit is! Map) continue;
        final resultId = _asInt(resultLimit['result_id']);
        final minBet = _asNum(resultLimit['min_bet']);
        final maxBet = _asNum(resultLimit['max_bet']);
        if (resultId == null || minBet == null || maxBet == null) continue;
        limits[resultId] = BaccaratBetLimit(minBet: minBet, maxBet: maxBet);
      }
    }
    return BaccaratMemberProfile(
      balance: balance,
      resultRateLimits: Map.unmodifiable(limits),
    );
  }
}

class BaccaratResultOption {
  const BaccaratResultOption({
    required this.id,
    required this.key,
    required this.name,
    required this.ratio,
    required this.position,
  });

  final int id;
  final String key;
  final String name;
  final num ratio;
  final int position;

  factory BaccaratResultOption.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('投注选项必须是对象');
    }
    final id = _asInt(value['id']);
    final key = value['key']?.toString() ?? '';
    final ratio = _asNum(value['ratio']);
    if (id == null || key.isEmpty || ratio == null) {
      throw const FormatException('投注选项缺少 ID、key 或赔率');
    }
    return BaccaratResultOption(
      id: id,
      key: key,
      name: value['name']?.toString() ?? key,
      ratio: ratio,
      position: _asInt(value['position']) ?? 0,
    );
  }
}

class BaccaratRoundStatus {
  const BaccaratRoundStatus({
    required this.status,
    required this.remainingSeconds,
  });

  final String status;
  final int remainingSeconds;

  bool get isBetting => status == 'betting';

  factory BaccaratRoundStatus.fromApi(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map) {
      throw const FormatException('桌台状态响应缺少 data');
    }
    final lastRound = data['lastRound'];
    if (lastRound is! Map || lastRound['status'] == null) {
      throw const FormatException('桌台状态响应缺少 lastRound.status');
    }
    final seconds = _asInt(data['remaining_seconds']);
    if (seconds == null) {
      throw const FormatException('桌台状态响应缺少 remaining_seconds');
    }
    return BaccaratRoundStatus(
      status: lastRound['status'].toString(),
      remainingSeconds: seconds,
    );
  }
}

class BaccaratConfirmedBet {
  const BaccaratConfirmedBet({
    required this.resultId,
    required this.amount,
    required this.image,
  });

  final int resultId;
  final num amount;
  final String image;

  factory BaccaratConfirmedBet.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('已确认投注必须是对象');
    }
    final resultId = _asInt(value['result_id']);
    final amount = _asNum(value['amount']);
    if (resultId == null || amount == null) {
      throw const FormatException('已确认投注缺少 result_id 或 amount');
    }
    return BaccaratConfirmedBet(
      resultId: resultId,
      amount: amount,
      image: value['image']?.toString() ?? '',
    );
  }
}

class BaccaratConfirmedBets {
  const BaccaratConfirmedBets({
    required this.byResultKey,
    required this.totalAmount,
  });

  final Map<String, BaccaratConfirmedBet> byResultKey;
  final num totalAmount;

  factory BaccaratConfirmedBets.fromApi(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map) {
      return const BaccaratConfirmedBets(byResultKey: {}, totalAmount: 0);
    }
    final rawBets = data['confirmedBets'];
    final bets = <String, BaccaratConfirmedBet>{};
    if (rawBets is Map) {
      for (final entry in rawBets.entries) {
        bets[entry.key.toString()] = BaccaratConfirmedBet.fromJson(entry.value);
      }
    }
    return BaccaratConfirmedBets(
      byResultKey: Map.unmodifiable(bets),
      totalAmount: _asNum(data['totalBetAmount']) ?? 0,
    );
  }
}

class BaccaratCameraFeed {
  const BaccaratCameraFeed({
    required this.cameraId,
    required this.deskId,
    required this.cameraNumber,
    required this.url,
    required this.position,
  });

  final int cameraId;
  final int? deskId;
  final String cameraNumber;
  final String url;
  final int position;

  factory BaccaratCameraFeed.fromJson(Map<String, dynamic> json) {
    final id = _asInt(json['id']);
    final url = json['url']?.toString().trim() ?? '';
    if (id == null || url.isEmpty) {
      throw const FormatException('摄像头缺少 ID 或播放地址');
    }
    return BaccaratCameraFeed(
      cameraId: id,
      deskId: _asInt(json['desk_id']),
      cameraNumber: json['camera_no']?.toString() ?? '',
      url: url,
      position: _asInt(json['position']) ?? 0,
    );
  }
}

class BaccaratLedgerEntry {
  const BaccaratLedgerEntry({
    required this.id,
    required this.createdAt,
    required this.deskName,
    required this.result,
    required this.amount,
    required this.remainingAmount,
  });

  final int? id;
  final String createdAt;
  final String deskName;
  final String result;
  final num amount;
  final num? remainingAmount;

  factory BaccaratLedgerEntry.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('投注记录必须是对象');
    }
    return BaccaratLedgerEntry(
      id: _asInt(value['id']),
      createdAt:
          value['betting_time']?.toString() ??
          value['payment_time']?.toString() ??
          value['round_updated_at']?.toString() ??
          '',
      deskName: value['desk_name']?.toString() ?? '',
      result:
          value['actual_round_results']?.toString() ??
          value['bet_name']?.toString() ??
          '',
      amount: _asNum(value['betting_amount']) ?? 0,
      remainingAmount: _asNum(value['remaining_amount']),
    );
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

num? _asNum(Object? value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '');
}

bool _asBool(Object? value) => value == true || value == 1 || value == '1';
