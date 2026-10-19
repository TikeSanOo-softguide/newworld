import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:newsworld/app.dart';
import 'package:newsworld/core/constants/app_constants.dart';
import 'package:newsworld/core/storage/local_storage.dart';
import 'package:newsworld/core/storage/secure_storage.dart';
import 'package:newsworld/features/init_loading/init_loading_page.dart';
import 'package:newsworld/features/ui_selection/ui_selection_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          flutterSecureStorageProvider.overrideWithValue(
            const FlutterSecureStorage(),
          ),
        ],
        child: const NewsworldApp(),
      ),
    );
  }

  testWidgets('splash fills gold loading bar over 10 seconds then navigates',
      (tester) async {
    await pumpApp(tester);
    await tester.pump();

    expect(find.byType(Image), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    final start = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(start.value, isNotNull);
    expect(start.value!, lessThan(0.05));

    await tester.pump(const Duration(seconds: 5));
    final mid = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(mid.value!, greaterThan(0.4));
    expect(mid.value!, lessThan(0.6));

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('请选择游戏类型'), findsOneWidget);
  });

  testWidgets('ui selection shows Chinese options and no confirm button',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(home: UiSelectionPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('请选择游戏类型'), findsOneWidget);
    expect(find.text('经典版'), findsOneWidget);
    expect(find.text('升级版'), findsOneWidget);
    expect(find.text('确认选择'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('init loading page shows Chinese initializing message',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: InitLoadingPage()));
    await tester.pump();

    expect(find.text('正在初始化游戏信息...'), findsOneWidget);
    expect(find.byIcon(Icons.sync), findsOneWidget);
    // Do not advance past displayDuration here — navigation needs GoRouter.
  });

  testWidgets('restores previous UI selection from SharedPreferences',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyUiStyle: UiStyle.u2.id,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(home: UiSelectionPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(prefs.getString(AppConstants.keyUiStyle), UiStyle.u2.id);
    final upgrade = tester.widget<Text>(find.text('升级版'));
    expect(upgrade.style?.color, const Color(0xFFD4AF37));
  });
}
