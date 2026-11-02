import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/router/app_router.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_dialog.dart';
import '../auth/auth_service.dart';
import '../preload/lobby_preload.dart';

class LobbyPage extends ConsumerStatefulWidget {
  const LobbyPage({super.key, this.showNotice = false});

  final bool showNotice;

  @override
  ConsumerState<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends ConsumerState<LobbyPage> {
  String _account = '';
  String _balance = '0';
  bool _trial = false;
  int _gameId = 0;
  bool _noticeShown = false;
  bool _kicking = false;
  Map<int, _RoundLive> _rounds = {};

  @override
  void initState() {
    super.initState();
    _loadMember();
  }

  Future<void> _loadMember() async {
    final storage = ref.read(secureStorageProvider);
    final account = await storage.getAccount() ?? '';
    final balance = await storage.getBalance();
    final trial = await storage.getTrialUser();
    if (!mounted) return;
    setState(() {
      _account = account;
      _balance = balance;
      _trial = trial;
    });
    final kicked = await _syncLobby();
    if (!mounted || kicked) return;
    if (!widget.showNotice || _noticeShown) return;
    _noticeShown = true;
    final notice =
        ref.read(lobbyPreloadProvider).setting('pc_popup_announcement');
    if (notice == null || notice.trim().isEmpty) return;
    await showGoldDialog(
      context: context,
      kind: GoldDialogKind.info,
      title: '提示',
      message: notice.trim(),
    );
    if (mounted) context.go(AppRoutes.lobby);
  }

  Future<bool> _syncLobby() async {
    final storage = ref.read(secureStorageProvider);
    final api = ref.read(apiClientProvider);
    final token = await storage.getAuthToken();
    final csrf = await storage.getCsrfToken();
    if (token == null || token.isEmpty) return false;
    try {
      await api.getJson(AppConstants.verifyPath, token: token);
    } on ApiException catch (error) {
      if (error.code == 'SESSION_SUPERSEDED') {
        await _kickSuperseded(error.supersededIp);
        return true;
      }
      if (error.statusCode == 401 || error.statusCode == 403) {
        await ref.read(authServiceProvider).logout();
        if (mounted) context.go(AppRoutes.login);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
    try {
      await api.patchJson(
        AppConstants.roomPath,
        token: token,
        csrfToken: csrf,
        body: const {'room': 'home'},
      );
    } on ApiException catch (error) {
      if (error.code == 'SESSION_SUPERSEDED') {
        await _kickSuperseded(error.supersededIp);
        return true;
      }
    } catch (_) {}
    await _loadRoundStatus(api, token);
    return false;
  }

  Future<void> _kickSuperseded(String? ip) async {
    if (_kicking) return;
    _kicking = true;
    final where = ip?.trim() ?? '';
    final message = where.isEmpty
        ? '此账号在其他处登录，你将被踢出系统'
        : '此账号在$where处登录，你将被踢出系统';
    if (mounted) {
      await showGoldDialog(
        context: context,
        kind: GoldDialogKind.error,
        title: '提示',
        message: message,
      );
    }
    await ref.read(authServiceProvider).logout();
    if (mounted) context.go(AppRoutes.login);
  }

  Future<void> _loadRoundStatus(ApiClient api, String token) async {
    final desks = ref.read(lobbyPreloadProvider).desks;
    final next = <int, _RoundLive>{};
    await Future.wait(desks.map((row) async {
      final id = _asInt(row['id']);
      if (id == null) return;
      try {
        final json = await api.getJson(
          '${AppConstants.lastRoundStatusPath}/$id',
          token: token,
        );
        final data = json['data'];
        if (data is! Map) return;
        final lastRound = data['lastRound'];
        final status =
            lastRound is Map ? lastRound['status']?.toString() : null;
        next[id] = _RoundLive(
          status: status,
          seconds: _asInt(data['remaining_seconds']) ?? 0,
        );
      } on ApiException catch (error) {
        if (error.code == 'SESSION_SUPERSEDED') {
          await _kickSuperseded(error.supersededIp);
          return;
        }
      } catch (_) {}
    }));
    if (mounted) setState(() => _rounds = next);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(lobbyPreloadProvider);
    final games = _games(snapshot.games);
    final desks = _desks(snapshot.desks, games, _gameId, _rounds);
    final ticker = snapshot.setting('phone_bet_announcement') ?? '';

    return GoldenDarkBackground(
      child: Column(
        children: [
          _LobbyHeader(
            account: _account,
            balance: _balance,
            trial: _trial,
            onSettings: () => context.push(AppRoutes.settings),
          ),
          if (ticker.trim().isNotEmpty) _AnnouncementBar(text: ticker.trim()),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              children: [
                _GameChip(
                  label: '全部',
                  selected: _gameId == 0,
                  onTap: () => setState(() => _gameId = 0),
                ),
                for (final game in games)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: _GameChip(
                      label: game.name,
                      selected: _gameId == game.id,
                      onTap: () => setState(() => _gameId = game.id),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: desks.isEmpty
                ? const Center(
                    child: Text(
                      '暂无台桌',
                      style: TextStyle(color: CasinoColors.muted, fontSize: 15),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: desks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final desk = desks[index];
                      return _DeskCard(
                        desk: desk,
                        trial: _trial,
                        onEnter: () => showGoldDialog(
                          context: context,
                          kind: GoldDialogKind.info,
                          title: desk.name,
                          message: '投注将在下一阶段接入',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LobbyHeader extends StatelessWidget {
  const _LobbyHeader({
    required this.account,
    required this.balance,
    required this.trial,
    required this.onSettings,
  });

  final String account;
  final String balance;
  final bool trial;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x66C6A15B)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC2A2214), Color(0xCC14110C)],
        ),
      ),
      child: Row(
        children: [
          Image.asset(AppAssets.logo, width: 46),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.isEmpty ? '会员' : account,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '余额 $balance',
                  style: const TextStyle(
                    color: CasinoColors.gold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (trial)
            Container(
              margin: const EdgeInsets.only(right: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x33C41E3A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFB4B4)),
              ),
              child: const Text(
                '试玩中',
                style: TextStyle(
                  color: Color(0xFFFFD0D0),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          IconButton(
            onPressed: onSettings,
            icon: const Icon(
              Icons.settings_outlined,
              color: CasinoColors.gold,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementBar extends StatefulWidget {
  const _AnnouncementBar({required this.text});

  final String text;

  @override
  State<_AnnouncementBar> createState() => _AnnouncementBarState();
}

class _AnnouncementBarState extends State<_AnnouncementBar>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() => _elapsed = elapsed);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Color(0xFFF6E7C1),
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
    );
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    const gap = 56.0;
    final loop = painter.width + gap;
    final shift = loop <= 0
        ? 0.0
        : (_elapsed.inMilliseconds / 1000 * 42) % loop;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          SizedBox(
            height: 26,
            child: Row(
              children: [
                const Text(
                  '公告',
                  style: TextStyle(
                    color: Color(0xFFE8C872),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRect(
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0, 0.06, 0.94, 1],
                        ).createShader(bounds);
                      },
                      child: Transform.translate(
                        offset: Offset(-shift, 0),
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          minWidth: 0,
                          maxWidth: double.infinity,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(widget.text, maxLines: 1, style: style),
                              const SizedBox(width: gap),
                              Text(widget.text, maxLines: 1, style: style),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          const SizedBox(
            height: 1,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0x00E8C872),
                    Color(0xCCE8C872),
                    Color(0x00E8C872),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameChip extends StatelessWidget {
  const _GameChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor:
            selected ? const Color(0xFF8C6424) : const Color(0xFF241C12),
        foregroundColor: selected ? const Color(0xFFFFF6E0) : CasinoColors.muted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? const Color(0xFFE8C872) : const Color(0x66C6A15B),
          ),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DeskCard extends StatelessWidget {
  const _DeskCard({
    required this.desk,
    required this.trial,
    required this.onEnter,
  });

  final _DeskItem desk;
  final bool trial;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final accent =
        desk.baccarat ? const Color(0xFF2EAE55) : const Color(0xFFE07090);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x66C6A15B)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF22A2216), Color(0xF0100E0C)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    desk.gameName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CasinoColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(label: desk.statusLabel, status: desk.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              desk.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(text: '限红 ${desk.minBet}-${desk.maxBet}'),
                _MetaChip(text: '${desk.resultCount} 局'),
                if (trial) const _MetaChip(text: '试玩中', alert: true),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: TextButton(
                onPressed: onEnter,
                style: TextButton.styleFrom(
                  backgroundColor: desk.baccarat
                      ? const Color(0xFF015D33)
                      : const Color(0xFFC3167A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0x99E8C872)),
                  ),
                ),
                child: const Text(
                  '开始游戏',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.status});

  final String label;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final betting = status == 'betting';
    final dealing = status == 'dealing';
    final background = betting
        ? const Color(0xFF146B34)
        : dealing
            ? const Color(0xFF8A2E24)
            : const Color(0xFF3A3120);
    final foreground = betting || dealing
        ? Colors.white
        : const Color(0xFFE8C872);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.text, this.alert = false});

  final String text;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: alert ? const Color(0x33C41E3A) : const Color(0x332A2114),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: alert ? const Color(0xFFFFB4B4) : const Color(0x55C6A15B),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: alert ? const Color(0xFFFFD0D0) : const Color(0xFFE6D7B8),
          fontSize: 12,
        ),
      ),
    );
  }
}

class _GameItem {
  const _GameItem({
    required this.id,
    required this.name,
    required this.type,
    required this.position,
  });

  final int id;
  final String name;
  final String type;
  final int position;
}

class _DeskItem {
  const _DeskItem({
    required this.id,
    required this.name,
    required this.gameName,
    required this.gameType,
    required this.gamePosition,
    required this.position,
    required this.minBet,
    required this.maxBet,
    required this.resultCount,
    required this.status,
    required this.statusLabel,
  });

  final int id;
  final String name;
  final String gameName;
  final String gameType;
  final int gamePosition;
  final int position;
  final int minBet;
  final int maxBet;
  final int resultCount;
  final String? status;
  final String statusLabel;

  bool get baccarat => gameType.toUpperCase() == 'BACCARAT';
}

List<_GameItem> _games(List<Map<String, dynamic>> raw) {
  final games = <_GameItem>[];
  for (final row in raw) {
    final type = row['type']?.toString() ?? '';
    if (type.toUpperCase() == 'NIUNIU') continue;
    final id = _asInt(row['id']);
    if (id == null) continue;
    games.add(
      _GameItem(
        id: id,
        name: row['name']?.toString() ?? '',
        type: type,
        position: _asInt(row['position']) ?? 1 << 20,
      ),
    );
  }
  games.sort((a, b) => a.position.compareTo(b.position));
  return games;
}

List<_DeskItem> _desks(
  List<Map<String, dynamic>> raw,
  List<_GameItem> games,
  int gameId,
  Map<int, _RoundLive> rounds,
) {
  final gameById = {for (final game in games) game.id: game};
  String? selectedType;
  if (gameId != 0) {
    selectedType = gameById[gameId]?.type;
  }
  final desks = <_DeskItem>[];
  for (final row in raw) {
    final game = row['game'];
    final gameMap = game is Map ? Map<String, dynamic>.from(game) : null;
    final type = gameMap?['type']?.toString() ?? '';
    if (selectedType != null && type != selectedType) continue;
    final gameIdValue = _asInt(row['game_id']);
    final known = gameIdValue == null ? null : gameById[gameIdValue];
    final results = row['results'];
    final id = _asInt(row['id']);
    if (id == null) continue;
    final lastRound = row['last_round'];
    final fallback = lastRound is Map ? lastRound['status']?.toString() : null;
    final live = rounds[id];
    final status = live?.status ?? fallback;
    desks.add(
      _DeskItem(
        id: id,
        name: row['name']?.toString() ?? '台桌',
        gameName: gameMap?['name']?.toString() ?? known?.name ?? '',
        gameType: type,
        gamePosition: _asInt(gameMap?['position']) ?? known?.position ?? 1 << 20,
        position: _asInt(row['position']) ?? 0,
        minBet: _asInt(row['min_bet']) ?? 0,
        maxBet: _asInt(row['max_bet']) ?? 0,
        resultCount: results is List ? results.length : 0,
        status: status,
        statusLabel: _statusLabel(status, live?.seconds ?? 0),
      ),
    );
  }
  desks.sort((a, b) {
    final byGame = a.gamePosition.compareTo(b.gamePosition);
    if (byGame != 0) return byGame;
    return a.position.compareTo(b.position);
  });
  return desks;
}

String _statusLabel(String? status, int seconds) {
  final label = switch (status) {
    'betting' => '开始下注',
    'dealing' => '停止下注',
    'finished' || 'active' => '等待开局',
    _ => '等待开局',
  };
  if (status == 'betting' && seconds > 0) return '$label $seconds';
  return label;
}

class _RoundLive {
  const _RoundLive({required this.status, required this.seconds});

  final String? status;
  final int seconds;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
