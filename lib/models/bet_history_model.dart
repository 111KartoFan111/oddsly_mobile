class BetHistory {
  final String id;
  final double amount;
  final String matchId;
  final String outcome;
  final String status;
  final String createdAt;
  final String team1Name;
  final String team2Name;
  final String league;

  BetHistory({
    required this.id,
    required this.amount,
    required this.matchId,
    required this.outcome,
    required this.status,
    required this.createdAt,
    required this.team1Name,
    required this.team2Name,
    required this.league,
  });

  factory BetHistory.fromJson(Map<String, dynamic> json) {
    return BetHistory(
      id: json['id'],
      amount: (json['amount'] as num).toDouble(),
      matchId: json['matchId'],
      outcome: json['outcome'],
      status: json['status'],
      createdAt: json['createdAt'] ?? '',
      team1Name: json['team1Name'] ?? 'Unknown',
      team2Name: json['team2Name'] ?? 'Unknown',
      league: json['league'] ?? 'Unknown',
    );
  }
}
