import 'package:flutter/material.dart';

import '../baccarat_detail_models.dart';

class BaccaratBettingPanel extends StatelessWidget {
  const BaccaratBettingPanel({
    super.key,
    required this.options,
    required this.confirmedBets,
    required this.confirmedTotalAmount,
    required this.pendingBets,
    required this.poolTotals,
    required this.chipDenominations,
    required this.selectedChip,
    required this.balance,
    required this.minBet,
    required this.maxBet,
    required this.bettingOpen,
    required this.secondsRemaining,
    required this.submitting,
    required this.canceling,
    required this.onSelectChip,
    required this.onPlaceBet,
    required this.onSubmit,
    required this.onCancel,
    required this.onHistory,
    required this.onCustomerService,
  });

  final List<BaccaratResultOption> options;
  final Map<String, BaccaratConfirmedBet> confirmedBets;
  final num confirmedTotalAmount;
  final Map<int, num> pendingBets;
  final Map<String, num> poolTotals;
  final List<int> chipDenominations;
  final int? selectedChip;
  final num balance;
  final num minBet;
  final num maxBet;
  final bool bettingOpen;
  final int secondsRemaining;
  final bool submitting;
  final bool canceling;
  final ValueChanged<int> onSelectChip;
  final ValueChanged<BaccaratResultOption> onPlaceBet;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final VoidCallback onHistory;
  final VoidCallback onCustomerService;

  @override
  Widget build(BuildContext context) {
    final totalPending = pendingBets.values.fold<num>(0, (a, b) => a + b);
    final totalBet = confirmedTotalAmount + totalPending;
    final optionsByKey = {for (final option in options) option.key: option};
    final allowCancelConfirmed =
        bettingOpen && secondsRemaining > 5 && confirmedBets.isNotEmpty;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF18283D), Color(0xFF101D30)],
            ),
            border: Border(
              top: BorderSide(color: Color(0xFF344A62)),
              bottom: BorderSide(color: Color(0xFF344A62)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _AmountMetric(
                  label: '总分',
                  value: _formatAmount(balance),
                ),
              ),
              Expanded(
                child: _AmountMetric(
                  label: '投注',
                  value: _formatAmount(totalBet),
                ),
              ),
              _ActionIconButton(
                label: '在线客服',
                icon: Icons.support_agent,
                onPressed: onCustomerService,
              ),
              const SizedBox(width: 4),
              _ActionIconButton(
                label: '下注记录',
                icon: Icons.receipt_long,
                onPressed: onHistory,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 7, 6, 2),
          child: AspectRatio(
            aspectRatio: 2.48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF17456A), Color(0xFF123552)],
                ),
                border: Border.all(color: const Color(0xFF48B8F4), width: 1.5),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3318B7FF),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _BetZone(
                          option: optionsByKey['player'],
                          label: '闲',
                          color: const Color(0xFF2488C1),
                          confirmed: confirmedBets['player']?.amount ?? 0,
                          pending: pendingBets[optionsByKey['player']?.id] ?? 0,
                          poolAmount: _poolAmount(
                            optionsByKey['player'],
                            poolTotals,
                          ),
                          enabled: bettingOpen,
                          onTap: () {
                            final option = optionsByKey['player'];
                            if (option != null) onPlaceBet(option);
                          },
                        ),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _BetZone(
                                      option: optionsByKey['playerPair'],
                                      label: '闲对',
                                      color: const Color(0xFF2488C1),
                                      confirmed:
                                          confirmedBets['playerPair']?.amount ??
                                          0,
                                      pending:
                                          pendingBets[optionsByKey['playerPair']
                                              ?.id] ??
                                          0,
                                      poolAmount: _poolAmount(
                                        optionsByKey['playerPair'],
                                        poolTotals,
                                      ),
                                      enabled: bettingOpen,
                                      onTap: () {
                                        final option =
                                            optionsByKey['playerPair'];
                                        if (option != null) onPlaceBet(option);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: _BetZone(
                                      option: optionsByKey['bankerPair'],
                                      label: '庄对',
                                      color: const Color(0xFFE82031),
                                      confirmed:
                                          confirmedBets['bankerPair']?.amount ??
                                          0,
                                      pending:
                                          pendingBets[optionsByKey['bankerPair']
                                              ?.id] ??
                                          0,
                                      poolAmount: _poolAmount(
                                        optionsByKey['bankerPair'],
                                        poolTotals,
                                      ),
                                      enabled: bettingOpen,
                                      onTap: () {
                                        final option =
                                            optionsByKey['bankerPair'];
                                        if (option != null) onPlaceBet(option);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Expanded(
                              child: _BetZone(
                                option: optionsByKey['tie'],
                                label: '和',
                                color: const Color(0xFF22B563),
                                confirmed: confirmedBets['tie']?.amount ?? 0,
                                pending:
                                    pendingBets[optionsByKey['tie']?.id] ?? 0,
                                poolAmount: _poolAmount(
                                  optionsByKey['tie'],
                                  poolTotals,
                                ),
                                enabled: bettingOpen,
                                onTap: () {
                                  final option = optionsByKey['tie'];
                                  if (option != null) onPlaceBet(option);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        flex: 2,
                        child: _BetZone(
                          option: optionsByKey['banker'],
                          label: '庄',
                          color: const Color(0xFFE82031),
                          confirmed: confirmedBets['banker']?.amount ?? 0,
                          pending: pendingBets[optionsByKey['banker']?.id] ?? 0,
                          poolAmount: _poolAmount(
                            optionsByKey['banker'],
                            poolTotals,
                          ),
                          enabled: bettingOpen,
                          onTap: () {
                            final option = optionsByKey['banker'];
                            if (option != null) onPlaceBet(option);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
          child: SizedBox(
            height: 52,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final actionWidth = constraints.maxWidth * 0.145;
                final chipWidth = constraints.maxWidth - actionWidth * 3 - 8;
                final itemExtent = chipWidth / 4;
                return Row(
                  children: [
                    SizedBox(
                      width: chipWidth,
                      child: chipDenominations.isEmpty
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : ListView.builder(
                              key: const ValueKey('baccarat-chip-selector'),
                              scrollDirection: Axis.horizontal,
                              itemExtent: itemExtent,
                              itemCount: chipDenominations.length,
                              itemBuilder: (context, index) {
                                final chip = chipDenominations[index];
                                return Center(
                                  child: _ChipButton(
                                    value: chip,
                                    selected: chip == selectedChip,
                                    onTap: bettingOpen
                                        ? () => onSelectChip(chip)
                                        : null,
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(width: 2),
                    SizedBox(
                      width: actionWidth,
                      child: _BetActionButton(
                        label: '取消',
                        icon: Icons.close,
                        color: const Color(0xFFE21B24),
                        enabled:
                            !canceling &&
                            (pendingBets.isNotEmpty || allowCancelConfirmed),
                        loading: canceling,
                        onPressed: onCancel,
                      ),
                    ),
                    const SizedBox(width: 2),
                    SizedBox(
                      width: actionWidth,
                      child: _BetActionButton(
                        label: '下注',
                        amount: totalPending > 0
                            ? _formatAmount(totalPending)
                            : null,
                        icon: Icons.check,
                        color: const Color(0xFF168EC5),
                        enabled:
                            bettingOpen &&
                            pendingBets.isNotEmpty &&
                            !submitting,
                        loading: submitting,
                        onPressed: onSubmit,
                      ),
                    ),
                    const SizedBox(width: 2),
                    SizedBox(
                      width: actionWidth,
                      child: Tooltip(
                        message: '参考网站当前没有续投功能',
                        child: _BetActionButton(
                          label: '续投',
                          icon: Icons.replay,
                          color: const Color(0xFFD4A52B),
                          enabled: false,
                          loading: false,
                          onPressed: () {},
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 5),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  bettingOpen ? _limitText : '停止下注',
                  style: TextStyle(
                    color: bettingOpen
                        ? const Color(0xFF9CB6C9)
                        : const Color(0xFFFF6A66),
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                '已下注 ${_formatAmount(totalBet)}',
                style: const TextStyle(color: Color(0xFFD7E1EA), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String get _limitText {
    if (minBet <= 0 && maxBet <= 0) return '限红以服务器设置为准';
    final minimum = minBet > 0 ? _formatAmount(minBet) : '0';
    final maximum = maxBet > 0 ? _formatAmount(maxBet) : '∞';
    return '限红 $minimum-$maximum';
  }
}

class _BetZone extends StatelessWidget {
  const _BetZone({
    required this.option,
    required this.label,
    required this.color,
    required this.confirmed,
    required this.pending,
    required this.poolAmount,
    required this.enabled,
    required this.onTap,
  });

  final BaccaratResultOption? option;
  final String label;
  final Color color;
  final num confirmed;
  final num pending;
  final num? poolAmount;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF12334A),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: enabled && option != null ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: enabled ? 0.13 : 0.07),
                const Color(0xFF12334A),
              ],
            ),
            border: Border.all(color: color.withValues(alpha: 0.42), width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.all(2),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: enabled ? color : color.withValues(alpha: 0.55),
                      fontSize: label.length == 1 ? 44 : 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (option != null)
                    Text(
                      '1:${_formatOdds(option!.ratio)}',
                      style: TextStyle(
                        color: enabled ? color : color.withValues(alpha: 0.55),
                        fontSize: label.length == 1 ? 19 : 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (confirmed + pending > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _formatAmount(confirmed + pending),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (poolAmount != null && poolAmount! > 0)
                    Text(
                      '台面 ${_formatAmount(poolAmount!)}',
                      style: const TextStyle(
                        color: Color(0xFFBDCCD8),
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BetActionButton extends StatelessWidget {
  const _BetActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.loading,
    required this.onPressed,
    this.amount,
  });

  final String label;
  final String? amount;
  final IconData icon;
  final Color color;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final activeColor = enabled ? color : color.withValues(alpha: 0.48);
    return Semantics(
      button: true,
      enabled: enabled,
      label: amount == null ? label : '$label $amount',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(7),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  activeColor.withValues(alpha: enabled ? 0.95 : 0.35),
                  activeColor.withValues(alpha: enabled ? 0.65 : 0.22),
                ],
              ),
              border: Border.all(color: activeColor, width: 1.3),
              borderRadius: BorderRadius.circular(7),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.22),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 14, color: Colors.white),
                          const SizedBox(width: 2),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (amount != null)
                                Text(
                                  amount!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '筹码 $value',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/coins/${value}chip.png',
                fit: BoxFit.contain,
              ),
              if (selected)
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFE190),
                      width: 3,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x88F3C85C), blurRadius: 9),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountMetric extends StatelessWidget {
  const _AmountMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      alignment: Alignment.centerLeft,
      fit: BoxFit.scaleDown,
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 15),
          children: [
            TextSpan(text: '$label:'),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        backgroundColor: const Color(0xFF08669A),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}

String _formatAmount(num amount) =>
    amount == amount.roundToDouble() ? amount.toInt().toString() : '$amount';

String _formatOdds(num odds) {
  final value = odds.toString();
  return value.endsWith('.0') ? value.substring(0, value.length - 2) : value;
}

num? _poolAmount(BaccaratResultOption? option, Map<String, num> totals) {
  if (option == null) return null;
  return totals[option.key] ?? totals['${option.id}'];
}
