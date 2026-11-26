import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'voice_announcement.dart';

/// One announcement player. A new clip replaces the one still playing.
class VoicePlayback {
  AudioPlayer? _player;

  Future<void> play(VoiceCue cue) async {
    try {
      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.setVolume(1);
      await player.play(AssetSource(cue.asset));
    } catch (error) {
      debugPrint('[Voice] playback failed: $error');
    }
  }

  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (error) {
      debugPrint('[Voice] stop failed: $error');
    }
  }

  Future<void> dispose() async {
    final player = _player;
    _player = null;
    try {
      await player?.dispose();
    } catch (error) {
      debugPrint('[Voice] dispose failed: $error');
    }
  }
}
