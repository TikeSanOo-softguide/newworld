import '../roadmap/roadmap_models.dart';

class LobbyGameCategory {
  const LobbyGameCategory({
    required this.id,
    required this.name,
    required this.type,
  });

  final int id;
  final String name;
  final String type;
}

class LobbyOutcomeStat {
  const LobbyOutcomeStat({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final RoadmapMarkerColor color;
}

class LobbyDeskDashboardData {
  const LobbyDeskDashboardData({
    required this.id,
    required this.name,
    required this.gameName,
    required this.gameType,
    required this.status,
    required this.statusLabel,
    required this.minBet,
    required this.maxBet,
    required this.resultCount,
    required this.statistics,
    required this.markerRoad,
    required this.bigRoad,
    required this.bigEyeRoad,
    required this.smallRoad,
    required this.cockroachRoad,
    required this.secondBigRoad,
  });

  final int id;
  final String name;
  final String gameName;
  final String gameType;
  final String? status;
  final String statusLabel;
  final int minBet;
  final int maxBet;
  final int resultCount;
  final List<LobbyOutcomeStat> statistics;
  final RoadmapGrid markerRoad;
  final RoadmapGrid bigRoad;
  final RoadmapGrid bigEyeRoad;
  final RoadmapGrid smallRoad;
  final RoadmapGrid cockroachRoad;
  final RoadmapGrid secondBigRoad;
}
