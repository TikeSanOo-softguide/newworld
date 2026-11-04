import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newsworld/features/lobby/models/lobby_dashboard_data.dart';
import 'package:newsworld/features/lobby/roadmap/roadmap_calculations.dart';
import 'package:newsworld/features/lobby/roadmap/roadmap_models.dart';
import 'package:newsworld/features/lobby/roadmap/roadmap_painter.dart';
import 'package:newsworld/features/lobby/widgets/lobby_dashboard_widgets.dart';

void main() {
  group('Lobby dashboard widgets', () {
    testWidgets('header shows account and points and opens its menu', (
      tester,
    ) async {
      var menuOpened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LobbyDashboardHeader(
              account: 'member01',
              balance: '293.48',
              onMenu: () => menuOpened = true,
            ),
          ),
        ),
      );

      expect(find.text('用户：member01'), findsOneWidget);
      expect(find.text('总分：293.48'), findsOneWidget);
      expect(find.text('新世界在线'), findsOneWidget);
      await tester.tap(find.byTooltip('菜单'));
      expect(menuOpened, isTrue);
    });

    testWidgets('announcement shows real text or an explicit empty state', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LobbyAnnouncementBanner(text: '比赛公告和联系信息')),
        ),
      );
      expect(find.text('比赛公告和联系信息'), findsOneWidget);
      expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LobbyAnnouncementBanner(text: null)),
        ),
      );
      expect(find.text('暂无公告'), findsOneWidget);
    });

    testWidgets('category tabs return the selected real category id', (
      tester,
    ) async {
      var selectedId = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => LobbyGameCategoryTabs(
                categories: const [
                  LobbyGameCategory(id: 5, name: '百家乐', type: 'BACCARAT'),
                  LobbyGameCategory(id: 9, name: '龙虎', type: 'LONGHU'),
                ],
                selectedId: selectedId,
                onSelected: (id) => setState(() => selectedId = id),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('龙虎'));
      await tester.pump();
      expect(selectedId, 9);
      await tester.tap(find.text('全部'));
      await tester.pump();
      expect(selectedId, 0);
    });

    testWidgets(
      'table section renders all six roadmap painters and live data',
      (tester) async {
        final desk = _deskData(
          resultKeys: const [
            'banker|bankerPair',
            'banker',
            'player',
            'tie',
            'player|playerPair',
            'player',
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                child: LobbyGameTableSection(
                  desk: desk,
                  isTrial: true,
                  onEnter: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('百家乐5'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.label == '庄 2',
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.label == '闲 3',
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.label == '和 1',
          ),
          findsOneWidget,
        );
        expect(find.text('试玩中'), findsOneWidget);
        expect(find.text('限红 10-500000'), findsOneWidget);
        expect(find.text('共 6 局'), findsOneWidget);
        expect(find.text('进入牌桌'), findsOneWidget);
        final roadViews = find.byType(RoadmapGridView);
        expect(roadViews, findsNWidgets(6));
        for (var index = 0; index < 6; index++) {
          expect(
            find.descendant(
              of: roadViews.at(index),
              matching: find.byType(CustomPaint),
            ),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('empty and error states expose readable retry behavior', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LobbyStateMessage(
              message: '暂无可用台桌',
              onRetry: () => retries++,
            ),
          ),
        ),
      );
      expect(find.text('暂无可用台桌'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      await tester.tap(find.text('重试'));
      expect(retries, 1);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LobbyStateMessage(message: '大厅数据加载失败，请重试', error: true),
          ),
        ),
      );
      expect(find.text('大厅数据加载失败，请重试'), findsOneWidget);
    });

    for (final width in [320.0, 768.0]) {
      testWidgets('table roadmap remains within a ${width.toInt()}px layout', (
        tester,
      ) async {
        final desk = _deskData(
          resultKeys: List.generate(
            40,
            (index) => index.isEven ? 'banker' : 'player',
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                child: LobbyGameTableSection(
                  desk: desk,
                  isTrial: false,
                  onEnter: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(RoadmapGridView), findsNWidgets(6));
        expect(tester.takeException(), isNull);
      });
    }
  });
}

LobbyDeskDashboardData _deskData({required List<String> resultKeys}) {
  final results = resultKeys
      .map((key) => RoadmapResult(key: key))
      .toList(growable: false);
  return LobbyDeskDashboardData(
    id: 5,
    name: '5',
    gameName: '百家乐',
    gameType: 'BACCARAT',
    status: 'betting',
    statusLabel: '开始下注 12',
    minBet: 10,
    maxBet: 500000,
    resultCount: results.length,
    statistics: const [
      LobbyOutcomeStat(label: '庄', count: 2, color: RoadmapMarkerColor.red),
      LobbyOutcomeStat(label: '闲', count: 3, color: RoadmapMarkerColor.blue),
      LobbyOutcomeStat(label: '和', count: 1, color: RoadmapMarkerColor.green),
    ],
    markerRoad: calculateMarkerRoad(results),
    bigRoad: calculateBigRoad(results),
    bigEyeRoad: calculateBigEyeRoad(results),
    smallRoad: calculateSmallRoad(results),
    cockroachRoad: calculateCockroachRoad(results),
    secondBigRoad: calculateSecondBigRoad(results),
  );
}
