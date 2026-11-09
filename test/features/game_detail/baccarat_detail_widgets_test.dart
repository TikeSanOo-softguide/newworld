import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newsworld/features/game_detail/baccarat_detail_models.dart';
import 'package:newsworld/features/game_detail/widgets/baccarat_betting_panel.dart';
import 'package:newsworld/features/game_detail/widgets/baccarat_roadmap_panel.dart';
import 'package:newsworld/features/game_detail/widgets/baccarat_video_panel.dart';
import 'package:newsworld/features/lobby/models/lobby_round_result.dart';
import 'package:newsworld/features/lobby/roadmap/roadmap_painter.dart';

void main() {
  testWidgets('betting panel fits a narrow mobile viewport and stages bets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    BaccaratResultOption? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              BaccaratBettingPanel(
                options: const [
                  BaccaratResultOption(
                    id: 1,
                    key: 'player',
                    name: '闲',
                    ratio: 1,
                    position: 1,
                  ),
                  BaccaratResultOption(
                    id: 2,
                    key: 'banker',
                    name: '庄',
                    ratio: 0.95,
                    position: 2,
                  ),
                  BaccaratResultOption(
                    id: 3,
                    key: 'tie',
                    name: '和',
                    ratio: 8,
                    position: 3,
                  ),
                  BaccaratResultOption(
                    id: 4,
                    key: 'playerPair',
                    name: '闲对',
                    ratio: 11,
                    position: 4,
                  ),
                  BaccaratResultOption(
                    id: 5,
                    key: 'bankerPair',
                    name: '庄对',
                    ratio: 11,
                    position: 5,
                  ),
                ],
                confirmedBets: const {},
                confirmedTotalAmount: 0,
                pendingBets: const {},
                poolTotals: const {},
                chipDenominations: const [100, 1000, 5000, 10000, 50000],
                selectedChip: 100,
                balance: 1000,
                minBet: 100,
                maxBet: 50000,
                bettingOpen: true,
                secondsRemaining: 20,
                submitting: false,
                canceling: false,
                onSelectChip: (_) {},
                onPlaceBet: (option) => selected = option,
                onSubmit: () {},
                onCancel: () {},
                onHistory: () {},
                onCustomerService: () {},
              ),
              BaccaratRoadmapPanel(
                results: List.generate(
                  40,
                  (index) => LobbyRoundResult(
                    deskId: 4,
                    roundId: index + 1,
                    key: index.isEven ? 'banker|bankerPair' : 'player',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('庄对'), findsWidgets);
    expect(find.bySemanticsLabel('筹码 100'), findsOneWidget);
    expect(find.bySemanticsLabel('筹码 1000'), findsOneWidget);
    expect(find.bySemanticsLabel('筹码 5000'), findsOneWidget);
    expect(find.bySemanticsLabel('筹码 10000'), findsOneWidget);
    expect(find.bySemanticsLabel('筹码 50000'), findsNothing);
    await tester.drag(
      find.byKey(const ValueKey('baccarat-chip-selector')),
      const Offset(-240, 0),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('筹码 50000'), findsOneWidget);

    await tester.tap(find.text('闲').first);
    expect(selected?.key, 'player');
  });

  testWidgets('video panel presents an explicit empty-source state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: BaccaratVideoPanel(
              deskName: '百家乐 A1',
              status: 'active',
              remainingSeconds: 0,
              streamUri: null,
              cameraLabel: '',
              cameraCount: 0,
              onBack: _noop,
              onSwitchTable: _noop,
              onSwitchCamera: _noop,
              soundEnabled: true,
              onSoundChanged: _noopBool,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('此桌暂时没有可播放的 HLS 视频源'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('video header shows round, ticker, and actionable controls', (
    tester,
  ) async {
    var soundEnabled = true;
    var backCount = 0;
    var tableSwitchCount = 0;
    var cameraSwitchCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BaccaratVideoPanel(
            deskName: '百家乐 A1',
            roundLabel: '第 7 局',
            status: 'betting',
            remainingSeconds: 9,
            ticker: '实时公告',
            streamUri: null,
            cameraLabel: '1/2',
            cameraCount: 2,
            onBack: () => backCount++,
            onSwitchTable: () => tableSwitchCount++,
            onSwitchCamera: () => cameraSwitchCount++,
            soundEnabled: soundEnabled,
            onSoundChanged: (enabled) => soundEnabled = enabled,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('第 7 局'), findsOneWidget);
    expect(find.text('实时公告'), findsOneWidget);
    expect(find.text('下注中 9s'), findsOneWidget);
    await tester.tap(find.byTooltip('声音'));
    await tester.tap(find.byTooltip('1/2'));
    await tester.tap(find.byTooltip('切换台桌'));
    await tester.tap(find.byTooltip('返回'));

    expect(soundEnabled, isFalse);
    expect(cameraSwitchCount, 1);
    expect(tableSwitchCount, 1);
    expect(backCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('roadmap columns extend and scroll without shrinking cells', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var results = List.generate(
      31,
      (index) => LobbyRoundResult(
        deskId: 4,
        roundId: index + 1,
        key: index.isEven ? 'banker' : 'player',
      ),
    );
    late StateSetter updateResults;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updateResults = setState;
              return BaccaratRoadmapPanel(results: results);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bigRoadFinder = find.byKey(const ValueKey('road-grid-big'));
    final scrollableFinder = find.descendant(
      of: bigRoadFinder,
      matching: find.byType(Scrollable),
    );
    expect(scrollableFinder, findsOneWidget);
    final scrollPosition = tester.state<ScrollableState>(scrollableFinder);
    expect(scrollPosition.position.maxScrollExtent, greaterThan(0));

    final initialPainter = tester.widget<CustomPaint>(
      find.descendant(of: bigRoadFinder, matching: find.byType(CustomPaint)),
    );
    final initialGrid = (initialPainter.painter! as RoadmapGridPainter).grid;
    final initialCellWidth =
        (initialPainter.painter! as RoadmapGridPainter).cellWidth;
    final initialBoardSize = tester.getSize(bigRoadFinder);
    expect(initialGrid.columnCount, 31);
    expect(find.text('最后10秒'), findsNothing);

    updateResults(() {
      results = [
        ...results,
        const LobbyRoundResult(deskId: 4, roundId: 32, key: 'player'),
      ];
    });
    await tester.pumpAndSettle();

    final updatedPainter = tester.widget<CustomPaint>(
      find.descendant(of: bigRoadFinder, matching: find.byType(CustomPaint)),
    );
    final updatedGrid = (updatedPainter.painter! as RoadmapGridPainter).grid;
    expect(updatedGrid.columnCount, 32);
    expect(updatedGrid.markers.keys, containsAll(initialGrid.markers.keys));
    expect(
      (updatedPainter.painter! as RoadmapGridPainter).cellWidth,
      initialCellWidth,
    );
    expect(tester.getSize(bigRoadFinder), initialBoardSize);
    expect(find.text('最后10秒'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}

void _noopBool(bool _) {}
