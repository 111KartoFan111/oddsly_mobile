// oddsly/lib/models/match_model.dart

class MatchModel {
  final String id;
  final String team1Name;
  final String team2Name;
  final String league;
  final int team1Score;
  final int team2Score;
  final String time;
  final String status;
  final dynamic matchDate;
  final Map<String, dynamic> odds; // Изменено на Map напрямую

  MatchModel({
    required this.id,
    required this.team1Name,
    required this.team2Name,
    required this.league,
    required this.team1Score,
    required this.team2Score,
    required this.time,
    required this.status,
    required this.matchDate,
    required this.odds,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    return MatchModel(
      id: json['id'],
      team1Name: json['team1Name'],
      team2Name: json['team2Name'],
      league: json['league'],
      team1Score: json['team1Score'] ?? 0,
      team2Score: json['team2Score'] ?? 0,
      time: json['time'] ?? '00:00',
      status: json['status'],
      matchDate: json['matchDate'],
      odds: {
        'home': double.parse(json['odds']['home'].toString()),
        'draw': double.parse(json['odds']['draw'].toString()),
        'away': double.parse(json['odds']['away'].toString()),
      },
    );
  }

  bool get isLive => status == 'live';
  String get team1Logo => '';
  String get team2Logo => '';
}
