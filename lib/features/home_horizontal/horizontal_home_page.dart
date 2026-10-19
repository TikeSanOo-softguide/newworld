import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/baccarat_betting_board.dart';
import 'widgets/baccarat_bottom_bar.dart';
import 'widgets/baccarat_roadmap.dart';
import 'widgets/baccarat_side_panel.dart';
import 'widgets/baccarat_top_bar.dart';
import 'widgets/cctv_live_table.dart';

/// U1 landscape Baccarat home — matches classic casino table UI.
class HorizontalHomePage extends ConsumerStatefulWidget {
  const HorizontalHomePage({super.key});

  @override
  ConsumerState<HorizontalHomePage> createState() => _HorizontalHomePageState();
}

class _HorizontalHomePageState extends ConsumerState<HorizontalHomePage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1F14),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            const BaccaratTopBar(),
            Expanded(
              child: Row(
                children: [
                  const BaccaratLeftUrlStrip(),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final roadmapW =
                            (constraints.maxWidth * 0.46).clamp(180.0, 420.0);
                        return Row(
                          children: [
                            SizedBox(
                              width: roadmapW,
                              child: const BaccaratRoadmap(),
                            ),
                            const Expanded(
                              child: Column(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: CctvLiveTable(),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: BaccaratBettingBoard(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const BaccaratSidePanel(),
                ],
              ),
            ),
            const BaccaratBottomBar(),
          ],
        ),
      ),
    );
  }
}
