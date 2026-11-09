import 'package:flutter_test/flutter_test.dart';
import 'package:newsworld/features/preload/lobby_preload.dart';

void main() {
  test(
    'camera preload retains only playback metadata and strips URL credentials',
    () {
      final projected = projectCameraRecord({
        'id': 5,
        'desk_id': 4,
        'camera_no': 'A',
        'position': 1,
        'url':
            'https://camera-user:camera-pass@camera.example.test/hls/live.m3u8',
        'camera_ip': '192.0.2.1',
        'account': 'private-account',
        'password': 'private-password',
      });

      expect(
        projected.keys,
        containsAll(['id', 'desk_id', 'camera_no', 'position', 'url']),
      );
      expect(projected.keys, isNot(contains('camera_ip')));
      expect(projected.keys, isNot(contains('account')));
      expect(projected.keys, isNot(contains('password')));
      expect(projected['url'], 'https://camera.example.test/hls/live.m3u8');
    },
  );
}
