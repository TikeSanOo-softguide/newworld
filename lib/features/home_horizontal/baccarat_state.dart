import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BetSpot { player, tie, banker, playerPair, bankerPair }

class BaccaratState {
  const BaccaratState({
    this.balance = 2000,
    this.selectedChip = 10,
    this.playerBet = 0,
    this.tieBet = 0,
    this.bankerBet = 0,
    this.playerPairBet = 0,
    this.bankerPairBet = 0,
    this.lastTotalBet = 0,
    this.selectedTable = 0,
    this.message,
    this.round = 20,
    this.shoe = 66206,
  });

  final int balance;
  final int selectedChip;
  final int playerBet;
  final int tieBet;
  final int bankerBet;
  final int playerPairBet;
  final int bankerPairBet;
  final int lastTotalBet;
  final int selectedTable;
  final String? message;
  final int round;
  final int shoe;

  int get totalBet =>
      playerBet + tieBet + bankerBet + playerPairBet + bankerPairBet;

  BaccaratState copyWith({
    int? balance,
    int? selectedChip,
    int? playerBet,
    int? tieBet,
    int? bankerBet,
    int? playerPairBet,
    int? bankerPairBet,
    int? lastTotalBet,
    int? selectedTable,
    String? message,
    bool clearMessage = false,
    int? round,
    int? shoe,
  }) {
    return BaccaratState(
      balance: balance ?? this.balance,
      selectedChip: selectedChip ?? this.selectedChip,
      playerBet: playerBet ?? this.playerBet,
      tieBet: tieBet ?? this.tieBet,
      bankerBet: bankerBet ?? this.bankerBet,
      playerPairBet: playerPairBet ?? this.playerPairBet,
      bankerPairBet: bankerPairBet ?? this.bankerPairBet,
      lastTotalBet: lastTotalBet ?? this.lastTotalBet,
      selectedTable: selectedTable ?? this.selectedTable,
      message: clearMessage ? null : (message ?? this.message),
      round: round ?? this.round,
      shoe: shoe ?? this.shoe,
    );
  }
}

class BaccaratNotifier extends Notifier<BaccaratState> {
  static const chips = [1, 5, 10, 50, 100, 500];
  static const demoStartBalance = 2000;

  @override
  BaccaratState build() => const BaccaratState();

  void selectTable(int index) {
    state = state.copyWith(selectedTable: index, clearMessage: true);
  }

  void selectChip(int value) {
    state = state.copyWith(selectedChip: value, clearMessage: true);
  }

  void placeBet(BetSpot spot) {
    final chip = state.selectedChip;
    if (chip > state.balance) {
      state = state.copyWith(message: '余额不足');
      return;
    }
    switch (spot) {
      case BetSpot.player:
        state = state.copyWith(
          balance: state.balance - chip,
          playerBet: state.playerBet + chip,
          clearMessage: true,
        );
      case BetSpot.tie:
        state = state.copyWith(
          balance: state.balance - chip,
          tieBet: state.tieBet + chip,
          clearMessage: true,
        );
      case BetSpot.banker:
        state = state.copyWith(
          balance: state.balance - chip,
          bankerBet: state.bankerBet + chip,
          clearMessage: true,
        );
      case BetSpot.playerPair:
        state = state.copyWith(
          balance: state.balance - chip,
          playerPairBet: state.playerPairBet + chip,
          clearMessage: true,
        );
      case BetSpot.bankerPair:
        state = state.copyWith(
          balance: state.balance - chip,
          bankerPairBet: state.bankerPairBet + chip,
          clearMessage: true,
        );
    }
  }

  void clearBets() {
    state = state.copyWith(
      balance: state.balance + state.totalBet,
      playerBet: 0,
      tieBet: 0,
      bankerBet: 0,
      playerPairBet: 0,
      bankerPairBet: 0,
      message: '已清除投注',
    );
  }

  /// 续投 — repeat last settled total as a simple demo re-bet on Player.
  void repeatBet() {
    final amount = state.lastTotalBet;
    if (amount <= 0) {
      state = state.copyWith(message: '暂无续投记录');
      return;
    }
    if (amount > state.balance) {
      state = state.copyWith(message: '余额不足');
      return;
    }
    state = state.copyWith(
      balance: state.balance - amount,
      playerBet: state.playerBet + amount,
      message: '已续投 $amount',
    );
  }

  void confirmRound() {
    if (state.totalBet <= 0) {
      state = state.copyWith(message: '请先投注');
      return;
    }
    final last = state.totalBet;
    final win = state.playerBet * 2;
    final refundTie = state.tieBet;
    final newBalance = state.balance + win + refundTie;
    state = BaccaratState(
      balance: newBalance,
      selectedChip: state.selectedChip,
      selectedTable: state.selectedTable,
      lastTotalBet: last,
      playerBet: 0,
      tieBet: 0,
      bankerBet: 0,
      playerPairBet: 0,
      bankerPairBet: 0,
      message: '演示回合结束 · 闲家胜',
      round: state.round + 1,
      shoe: state.shoe,
    );
  }

  void resetDemo() {
    state = const BaccaratState(message: '已重置演示账户');
  }
}

final baccaratProvider =
    NotifierProvider<BaccaratNotifier, BaccaratState>(BaccaratNotifier.new);
