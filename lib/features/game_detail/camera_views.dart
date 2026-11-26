import 'baccarat_detail_models.dart';

/// A camera choice on the game-detail video. `fullscreen` keeps the current feed.
enum DeskCameraView { panorama1, panorama2, cardFace, fullTable, fullscreen }

/// `manual` desks use the five-option row. Every other desk type, including
/// `scanner`, uses the four-option row.
List<String> cameraOptionLabels(String deskType) {
  if (deskType == 'manual') {
    return const ['全景1', '全景2', '牌面', '全台', '全屏'];
  }
  return const ['全景1', '全景2', '全台', '全屏'];
}

DeskCameraView? cameraViewForLabel(String label) {
  return switch (label) {
    '全景1' => DeskCameraView.panorama1,
    '全景2' => DeskCameraView.panorama2,
    '牌面' => DeskCameraView.cardFace,
    '全台' => DeskCameraView.fullTable,
    '全屏' => DeskCameraView.fullscreen,
    _ => null,
  };
}

/// `01` and `1` are the same camera number. Identity is the number, not the
/// row's place in the API list.
String normalizeCameraNo(String raw) {
  final number = int.tryParse(raw.trim());
  if (number == null) return raw.trim();
  return number.toString().padLeft(2, '0');
}

/// Hall views are the unassigned cameras (`desk_id` null) numbered 01 and 02.
/// Desk views are that desk's cameras numbered 01 (全台) and 02 (牌面).
/// Those numbers are the admin video slots: 全景一, 全景二, and 台面通道.
/// The public camera row has no view-name column.
BaccaratCameraFeed? cameraForDeskView({
  required Iterable<Map<String, dynamic>> cameras,
  required int deskId,
  required DeskCameraView view,
}) {
  final (int? desk, String number) = switch (view) {
    DeskCameraView.panorama1 => (null, '01'),
    DeskCameraView.panorama2 => (null, '02'),
    DeskCameraView.cardFace => (deskId, '02'),
    DeskCameraView.fullTable => (deskId, '01'),
    DeskCameraView.fullscreen => (null, ''),
  };
  if (view == DeskCameraView.fullscreen) return null;

  BaccaratCameraFeed? match;
  for (final camera in cameras) {
    final rawDesk = camera['desk_id'];
    final cameraDesk = rawDesk == null ? null : _asInt(rawDesk);
    final unassigned = rawDesk == null;
    if (desk == null) {
      if (!unassigned) continue;
    } else if (cameraDesk != desk) {
      continue;
    }
    if (normalizeCameraNo(camera['camera_no']?.toString() ?? '') != number) {
      continue;
    }
    final BaccaratCameraFeed feed;
    try {
      feed = BaccaratCameraFeed.fromJson(camera);
    } on FormatException {
      continue;
    }
    if (match == null || feed.cameraId < match.cameraId) match = feed;
  }
  return match;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
