// lib/services/api_service.dart

import 'package:oddsly/models/user_model.dart';
import 'package:oddsly/models/match_model.dart';
import 'package:oddsly/services/firebase_service.dart';

class ApiService {
  final FirebaseService _firebaseService = FirebaseService();

  // Заглушка для совместимости (больше не используется)
  Future<void> saveToken(String token) async {
    // Token теперь управляется Firebase Auth
  }

  Future<String?> getToken() async {
    // Token теперь управляется Firebase Auth
    return null;
  }

  Future<void> clearToken() async {
    // Token теперь управляется Firebase Auth
  }

  // ==================== USER OPERATIONS ====================

  Future<UserModel?> getUserProfile() async {
    return await _firebaseService.getUserProfile();
  }

  // ==================== MATCH OPERATIONS ====================

  Future<List<MatchModel>> getMatches({String? status, String? league}) async {
    return await _firebaseService.getMatches(status: status);
  }

  Future<List<MatchModel>> getLiveMatches(String sport) async {
    final matches = await _firebaseService.getMatches(sport: sport);
    
    // Сортировка: live вверху, затем по дате
    matches.sort((a, b) {
      if (a.isLive && !b.isLive) return -1;
      if (!a.isLive && b.isLive) return 1;

      final dateA = a.matchDate is DateTime 
          ? a.matchDate as DateTime
          : DateTime.parse(a.matchDate.toString());
      final dateB = b.matchDate is DateTime
          ? b.matchDate as DateTime
          : DateTime.parse(b.matchDate.toString());
      return dateA.compareTo(dateB);
    });

    return matches;
  }

  Future<MatchModel?> getMatchDetails(String matchId) async {
    // В реальном приложении получать конкретный матч по ID
    final matches = await _firebaseService.getMatches();
    return matches.firstWhere(
      (match) => match.id == matchId,
      orElse: () => matches.first,
    );
  }

  // ==================== BET OPERATIONS ====================

  Future<Map<String, dynamic>> placeBet(
    String matchId,
    double amount,
    String outcome, {
    Map<String, dynamic>? matchInfo,
  }) async {
    // Извлечь коэффициент из outcome (например, "П1 - 2.1")
    final parts = outcome.split(' - ');
    double coefficient = 1.0;
    if (parts.length == 2) {
      coefficient = double.tryParse(parts[1]) ?? 1.0;
    }

    final result = await _firebaseService.placeBet(
      matchId: matchId,
      amount: amount,
      outcome: outcome,
      coefficient: coefficient,
      matchInfo: matchInfo ?? {},
    );

    return result;
  }

  Future<List<dynamic>> getBetHistory() async {
    final bets = await _firebaseService.getBetHistory();
    return bets.map((bet) => {
      'id': bet.id,
      'amount': bet.amount,
      'matchId': bet.matchId,
      'outcome': bet.outcome,
      'status': bet.status,
      'createdAt': bet.createdAt,
      'team1Name': bet.team1Name,
      'team2Name': bet.team2Name,
      'league': bet.league,
    }).toList();
  }

  // ==================== TRANSACTION OPERATIONS ====================

  Future<List<dynamic>> getTransactionHistory() async {
    return await _firebaseService.getTransactionHistory();
  }

  Future<Map<String, dynamic>> depositBalance(
    double amount,
    String method, {
    String? cardNumber,
  }) async {
    return await _firebaseService.createDeposit(
      amount: amount,
      method: method,
      cardNumber: cardNumber,
    );
  }

  Future<Map<String, dynamic>> withdrawBalance(
    double amount,
    String cardNumber,
  ) async {
    return await _firebaseService.createWithdrawal(
      amount: amount,
      cardNumber: cardNumber,
    );
  }

  // ==================== INITIALIZATION ====================

  /// Инициализация тестовых данных (вызывать один раз при первом запуске)
  Future<void> initializeTestData() async {
    await _firebaseService.seedTestMatches();
  }
}