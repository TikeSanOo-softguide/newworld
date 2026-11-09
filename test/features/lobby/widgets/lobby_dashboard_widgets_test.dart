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

    testWidgets('announcement marquee stays within bounds with large text', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: LobbyAnnouncementBanner(
                  text: '实时连接失败，正在尝试重新连接，请稍后重试并检查网络连接',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
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
        const rowWidth = 357.0;
        const markerWidth = rowWidth * 0.31;
        final rightWidth = rowWidth - markerWidth - 2;
        final wideRoadWidth = rightWidth * bigEyeBoyColumns / bigRoadColumns;
        final narrowRoadWidth = rightWidth - wideRoadWidth;
        final gridWidths = <double>[];
        for (var index = 0; index < 6; index++) {
          final painterFinder = find.descendant(
            of: roadViews.at(index),
            matching: find.byType(CustomPaint),
          );
          expect(painterFinder, findsOneWidget);
          final painter = tester.widget<CustomPaint>(painterFinder);
          final gridPainter = painter.painter! as RoadmapGridPainter;
          expect(gridPainter.visualRows, index <= 1 ? 6 : 3);
          expect(gridPainter.grid.columnCount, switch (index) {
            0 => beadPlateColumns,
            1 => bigRoadColumns,
            2 => bigEyeBoyColumns,
            3 => cockroachPigColumns,
            4 => smallRoadColumns,
            _ => secondBigRoadColumns,
          });
          final expectedGridWidth = switch (index) {
            0 => markerWidth,
            1 => rightWidth,
            2 || 4 => wideRoadWidth,
            _ => narrowRoadWidth,
          };
          expect(
            tester.getSize(roadViews.at(index)).width,
            closeTo(expectedGridWidth, 0.01),
          );
          gridWidths.add(gridPainter.cellWidth * gridPainter.grid.columnCount);
          final expectedCellSize = switch (index) {
            0 => markerWidth / beadPlateColumns,
            1 => rightWidth / bigRoadColumns,
            2 || 4 => wideRoadWidth / bigEyeBoyColumns,
            _ => narrowRoadWidth / cockroachPigColumns,
          };
          expect(gridPainter.cellWidth, closeTo(expectedCellSize, 0.01));
          final expectedCellHeight = switch (index) {
            0 || 1 || 2 || 4 => expectedCellSize,
            _ => rightWidth / bigRoadColumns,
          };
          expect(gridPainter.cellHeight, closeTo(expectedCellHeight, 0.01));
          expect(
            find.descendant(
              of: roadViews.at(index),
              matching: find.byType(Scrollable),
            ),
            findsNothing,
          );
        }
        expect(gridWidths[1], closeTo(rightWidth, 0.01));
        expect(gridWidths[2], closeTo(wideRoadWidth, 0.01));
        expect(gridWidths[3], closeTo(narrowRoadWidth, 0.01));
        expect(gridWidths[4], closeTo(wideRoadWidth, 0.01));
        expect(gridWidths[5], closeTo(narrowRoadWidth, 0.01));
        expect(gridWidths[2], closeTo(gridWidths[4], 0.01));
        expect(gridWidths[3], closeTo(gridWidths[5], 0.01));
        expect(gridWidths[1], greaterThan(gridWidths[3]));
        for (var index = 3; index < 6; index++) {
          expect(
            tester.getSize(roadViews.at(index)).height,
            closeTo(tester.getSize(roadViews.at(2)).height, 0.01),
          );
        }

        final watermarkText = find.text('试玩中');
        final watermarkContainerFinder = find
            .ancestor(of: watermarkText, matching: find.byType(Container))
            .first;
        final watermarkContainer = tester.widget<Container>(
          watermarkContainerFinder,
        );
        final watermarkDecoration =
            watermarkContainer.decoration! as BoxDecoration;
        expect(watermarkDecoration.color, isNull);
        expect(watermarkDecoration.border, isNotNull);
        final watermarkTextWidget = tester.widget<Text>(watermarkText);
        expect(watermarkTextWidget.style!.color!.a, lessThan(1));
        expect(
          (watermarkDecoration.border! as Border).top.color.a,
          lessThan(1),
        );
        expect(
          tester.getCenter(watermarkText).dx,
          closeTo(
            tester.getCenter(find.byType(LobbyGameTableSection)).dx - 1.5,
            0.1,
          ),
        );
        final watermarkIgnorePointer = tester.widget<IgnorePointer>(
          find
              .ancestor(of: watermarkText, matching: find.byType(IgnorePointer))
              .first,
        );
        expect(watermarkIgnorePointer.ignoring, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('all six List Page roads use fixed sliding column windows', (
      tester,
    ) async {
      final configurations = [
        (RoadmapType.marker, beadPlateRows, beadPlateColumns),
        (RoadmapType.big, bigRoadRows, bigRoadColumns),
        (RoadmapType.bigEye, bigEyeBoyRows, bigEyeBoyColumns),
        (RoadmapType.cockroach, cockroachPigRows, cockroachPigColumns),
        (RoadmapType.small, smallRoadRows, smallRoadColumns),
        (RoadmapType.secondBig, secondBigRoadRows, secondBigRoadColumns),
      ];

      for (final (type, rows, columns) in configurations) {
        for (final dataColumns in [columns - 1, columns, columns + 2]) {
          final source = RoadmapGrid(
            type: type,
            rowCount: rows,
            columnCount: dataColumns + 4,
            markers: {
              for (var col = 0; col < dataColumns; col++)
                RoadmapPosition(col: col, row: 0): RoadmapMarker(
                  shape: RoadmapMarkerShape.ring,
                  color: RoadmapMarkerColor.blue,
                  sourceKey: 'column-$col',
                ),
            },
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: columns * 10,
                  child: RoadmapGridView(
                    grid: source,
                    cellWidth: 12,
                    cellHeight: 10,
                    visibleRows: rows,
                    visibleColumns: columns,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          final view = find.byType(RoadmapGridView);
          final painterFinder = find.descendant(
            of: view,
            matching: find.byType(CustomPaint),
          );
          final painter = tester.widget<CustomPaint>(painterFinder);
          final gridPainter = painter.painter! as RoadmapGridPainter;
          final firstVisibleColumn = dataColumns > columns
              ? dataColumns - columns
              : 0;
          expect(gridPainter.grid.columnCount, columns);
          expect(gridPainter.visualRows, rows);
          expect(
            gridPainter.grid.markers.length,
            dataColumns > columns ? columns : dataColumns,
          );
          expect(
            gridPainter.grid.markers.values.first.sourceKey,
            'column-$firstVisibleColumn',
          );
          expect(gridPainter.grid.markers.keys.first.col, 0);
          expect(
            gridPainter.grid.markers.values.last.sourceKey,
            'column-${dataColumns - 1}',
          );
          expect(source.markers.length, dataColumns);
          expect(gridPainter.cellWidth, 10);
          expect(gridPainter.cellHeight, 10);
          expect(tester.getSize(painterFinder).width, columns * 10);
          expect(tester.getSize(view).width, columns * 10);
          expect(
            find.descendant(of: view, matching: find.byType(Scrollable)),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets(
      'List Page uses a compact reference-proportioned table header',
      (tester) async {
        final desk = _deskData(resultKeys: const ['banker', 'player', 'tie']);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 380,
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

        expect(find.text('百家乐5'), findsOneWidget);
        for (final label in ['庄 2', '闲 3', '和 1']) {
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.label == label,
            ),
            findsOneWidget,
          );
        }
        expect(find.text('开始下注 12'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('table roadmaps leave vertical scrolling to the page', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final desk = _deskData(
        resultKeys: List.generate(
          72,
          (index) => index.isEven ? 'banker' : 'player',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: List.generate(
                5,
                (_) => LobbyGameTableSection(
                  desk: desk,
                  isTrial: false,
                  onEnter: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ListView), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LobbyGameTableSection).first,
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      final pageScroll = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(pageScroll.position.axisDirection, AxisDirection.down);
      expect(pageScroll.position.maxScrollExtent, greaterThan(0));
      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(pageScroll.position.pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

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
