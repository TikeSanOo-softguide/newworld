import 'package:flutter/services.dart';

/// Android 15+ ignores [SystemUiMode.immersiveSticky] when the app targets
/// SDK 35 or newer. This channel hides the bars with WindowInsetsController.
const landscapeSystemBarsChannel = MethodChannel('newsworld/system_bars');

/// Portrait is the app default. Landscape is requested only for the video.
class DetailOrientationLock {
  bool get landscape => _landscape;
  bool _landscape = false;
  int _generation = 0;

  Future<void> enterLandscape() async {
    final generation = ++_generation;
    _landscape = true;
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (generation != _generation) return;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (generation != _generation) return;
    await _setSystemBarsHidden(true);
  }

  Future<void> restorePortrait() async {
    final generation = ++_generation;
    _landscape = false;
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    if (generation != _generation) return;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (generation != _generation) return;
    await _setSystemBarsHidden(false);
  }

  Future<void> _setSystemBarsHidden(bool hidden) async {
    try {
      await landscapeSystemBarsChannel.invokeMethod<void>(
        hidden ? 'hide' : 'show',
      );
    } on MissingPluginException {
      // Widget tests and platforms without the Android activity hook.
    } on PlatformException {
      // The activity can finish while the call is in flight.
    }
  }
}
