// lib/services/api_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oddsly/models/user_model.dart';
import 'package:oddsly/models/match_model.dart';

class ApiService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Мок данные для пользователя
  Future<UserModel?> getUserProfile() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final user = _auth.currentUser;
    if (user == null) return null;

    // Получаем сохраненный баланс или используем начальный
    final prefs = await SharedPreferences.getInstance();
    final balance = prefs.getDouble('user_balance') ?? 10000.0;

    return UserModel(
      email: user.email ?? '',
      balance: balance,
    );
  }

  // Сохранить баланс локально
  Future<void> _saveBalance(double balance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('user_balance', balance);
  }

  // Получить баланс
  Future<double> _getBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('user_balance') ?? 10000.0;
  }

  // Мок данные матчей
  Future<List<MatchModel>> getMatches({String? status, String? league}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final allMatches = _getAllMockMatches();
    
    var filtered = allMatches;
    if (status != null) {
      filtered = filtered.where((m) => m.status == status).toList();
    }
    if (league != null) {
      filtered = filtered.where((m) => m.league == league).toList();
    }
    
    return filtered;
  }

  Future<List<MatchModel>> getLiveMatches(String sport) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final Map<String, List<MatchModel>> matchesBySport = {
      'football': _getFootballMatches(),
      'basketball': _getBasketballMatches(),
      'tennis': _getTennisMatches(),
      'hockey': _getHockeyMatches(),
    };

    return matchesBySport[sport] ?? _getFootballMatches();
  }

  Future<MatchModel?> getMatchDetails(String matchId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final allMatches = _getAllMockMatches();
    try {
      return allMatches.firstWhere((m) => m.id == matchId);
    } catch (e) {
      return null;
    }
  }

  // Сделать ставку
  Future<Map<String, dynamic>> placeBet(
    String matchId,
    double amount,
    String outcome, {
    Map<String, dynamic>? matchInfo,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (amount < 100) {
      return {'message': 'Минимальная ставка 100₸'};
    }

    final currentBalance = await _getBalance();
    
    if (currentBalance < amount) {
      return {'message': 'Недостаточно средств на балансе'};
    }

    final newBalance = currentBalance - amount;
    await _saveBalance(newBalance);

    // Сохраняем ставку локально
    final prefs = await SharedPreferences.getInstance();
    final betsJson = prefs.getString('user_bets') ?? '[]';
    final List<dynamic> bets = jsonDecode(betsJson);
    
    final bet = {
      'id': 'bet_${DateTime.now().millisecondsSinceEpoch}',
      'matchId': matchId,
      'amount': amount,
      'outcome': outcome,
      'status': 'active',
      'team1Name': matchInfo?['team1Name'] ?? '',
      'team2Name': matchInfo?['team2Name'] ?? '',
      'league': matchInfo?['league'] ?? '',
      'coefficient': _extractCoefficient(outcome),
      'createdAt': DateTime.now().toIso8601String(),
    };
    
    bets.insert(0, bet);
    await prefs.setString('user_bets', jsonEncode(bets));

    return {
      'betId': bet['id'],
      'newBalance': newBalance,
    };
  }

  double _extractCoefficient(String outcome) {
    try {
      final parts = outcome.split(' - ');
      if (parts.length == 2) {
        return double.parse(parts[1].trim());
      }
    } catch (e) {
      // ignore
    }
    return 1.0;
  }

  // История ставок
  Future<List<dynamic>> getBetHistory() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final prefs = await SharedPreferences.getInstance();
    final betsJson = prefs.getString('user_bets') ?? '[]';
    return jsonDecode(betsJson);
  }

  // Пополнение баланса
  Future<Map<String, dynamic>> depositBalance(
    double amount,
    String method, {
    String? cardNumber,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (amount < 200) {
      return {'message': 'Минимальная сумма пополнения 200₸'};
    }

    final currentBalance = await _getBalance();
    final newBalance = currentBalance + amount;
    await _saveBalance(newBalance);

    // Сохраняем транзакцию
    await _saveTransaction({
      'id': 'trans_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'deposit',
      'amount': amount,
      'status': 'completed',
      'cardNumber': cardNumber ?? '4567****7702',
      'method': method,
      'createdAt': DateTime.now().toIso8601String(),
    });

    return {
      'newBalance': newBalance,
    };
  }

  // Вывод средств
  Future<Map<String, dynamic>> withdrawBalance(
    double amount,
    String cardNumber,
  ) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (amount < 200) {
      return {'message': 'Минимальная сумма вывода 200₸'};
    }

    final currentBalance = await _getBalance();
    
    if (currentBalance < amount) {
      return {'message': 'Недостаточно средств на балансе'};
    }

    final newBalance = currentBalance - amount;
    await _saveBalance(newBalance);

    // Сохраняем транзакцию
    await _saveTransaction({
      'id': 'trans_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'withdrawal',
      'amount': amount,
      'status': 'completed',
      'cardNumber': cardNumber,
      'method': 'card',
      'createdAt': DateTime.now().toIso8601String(),
    });

    return {
      'newBalance': newBalance,
    };
  }

  // История транзакций
  Future<List<dynamic>> getTransactionHistory() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final prefs = await SharedPreferences.getInstance();
    final transJson = prefs.getString('user_transactions') ?? '[]';
    return jsonDecode(transJson);
  }

  Future<void> _saveTransaction(Map<String, dynamic> transaction) async {
    final prefs = await SharedPreferences.getInstance();
    final transJson = prefs.getString('user_transactions') ?? '[]';
    final List<dynamic> transactions = jsonDecode(transJson);
    transactions.insert(0, transaction);
    await prefs.setString('user_transactions', jsonEncode(transactions));
  }

  // Мок данные матчей
  List<MatchModel> _getFootballMatches() {
    return [
      MatchModel(
        id: 'match-1',
        team1Name: 'Манчестер Сити',
        team2Name: 'Ливерпуль',
        league: 'Premier League',
        team1Score: 2,
        team2Score: 1,
        time: '78:42',
        status: 'live',
        matchDate: DateTime.now().toIso8601String(),
        odds: {'home': 1.85, 'draw': 3.40, 'away': 4.20},
      ),
      MatchModel(
        id: 'match-2',
        team1Name: 'Барселона',
        team2Name: 'Бавария',
        league: 'UEFA Champions League',
        team1Score: 0,
        team2Score: 0,
        time: '20:00',
        status: 'scheduled',
        matchDate: DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
        odds: {'home': 2.10, 'draw': 3.20, 'away': 3.50},
      ),
      MatchModel(
        id: 'match-3',
        team1Name: 'Реал Мадрид',
        team2Name: 'Атлетико',
        league: 'La Liga',
        team1Score: 3,
        team2Score: 2,
        time: '65:23',
        status: 'live',
        matchDate: DateTime.now().toIso8601String(),
        odds: {'home': 1.65, 'draw': 3.80, 'away': 5.20},
      ),
      MatchModel(
        id: 'match-4',
        team1Name: 'Челси',
        team2Name: 'Арсенал',
        league: 'Premier League',
        team1Score: 1,
        team2Score: 1,
        time: '45:00',
        status: 'live',
        matchDate: DateTime.now().toIso8601String(),
        odds: {'home': 2.05, 'draw': 3.10, 'away': 3.75},
      ),
      MatchModel(
        id: 'match-5',
        team1Name: 'Ювентус',
        team2Name: 'Интер',
        league: 'Serie A',
        team1Score: 0,
        team2Score: 0,
        time: '22:45',
        status: 'scheduled',
        matchDate: DateTime.now().add(const Duration(hours: 4)).toIso8601String(),
        odds: {'home': 2.20, 'draw': 3.00, 'away': 3.40},
      ),
    ];
  }

  List<MatchModel> _getBasketballMatches() {
    return [
      MatchModel(
        id: 'match-6',
        team1Name: 'Lakers',
        team2Name: 'Warriors',
        league: 'NBA',
        team1Score: 95,
        team2Score: 88,
        time: 'Q3 5:42',
        status: 'live',
        matchDate: DateTime.now().toIso8601String(),
        odds: {'home': 1.75, 'draw': 15.0, 'away': 2.20},
      ),
      MatchModel(
        id: 'match-7',
        team1Name: 'Celtics',
        team2Name: 'Heat',
        league: 'NBA',
        team1Score: 0,
        team2Score: 0,
        time: '22:00',
        status: 'scheduled',
        matchDate: DateTime.now().add(const Duration(hours: 3)).toIso8601String(),
        odds: {'home': 1.90, 'draw': 12.0, 'away': 2.00},
      ),
      MatchModel(
        id: 'match-8',
        team1Name: 'Bucks',
        team2Name: 'Nets',
        league: 'NBA',
        team1Score: 102,
        team2Score: 98,
        time: 'Q4 2:15',
        status: 'live',
        matchDate: DateTime.now().toIso8601String(),
        odds: {'home': 1.85, 'draw': 13.0, 'away': 2.10},
      ),
    ];
  }

  List<MatchModel> _getTennisMatches() {
    return [
      MatchModel(
        id: 'match-9',
        team1Name: 'Джокович',
        team2Name: 'Надаль',
        league: 'ATP Tour',
        team1Score: 2,
        team2Score: 1,
        time: 'Set 3',
        status: 'live',
        matchDate: DateTime.now().toIso8601String(),
        odds: {'home': 1.55, 'draw': 1.0, 'away': 2.50},
      ),
      MatchModel(
        id: 'match-10',
        team1Name: 'Федерер',
        team2Name: 'Медведев',
        league: 'ATP Tour',
        team1Score: 0,
        team2Score: 0,
        time: '19:30',
        status: 'scheduled',
        matchDate: DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        odds: {'home': 1.70, 'draw': 1.0, 'away': 2.25},
      ),
    ];
  }

  List<MatchModel> _getHockeyMatches() {
    return [
      MatchModel(
        id: 'match-11',
        team1Name: 'Toronto Maple Leafs',
        team2Name: 'Montreal Canadiens',
        league: 'NHL',
        team1Score: 3,
        team2Score: 2,
        time: '2nd 12:34',
        status: 'live',
        matchDate: DateTime.now().toIso8601String(),
        odds: {'home': 1.80, 'draw': 4.50, 'away': 4.00},
      ),
      MatchModel(
        id: 'match-12',
        team1Name: 'Boston Bruins',
        team2Name: 'New York Rangers',
        league: 'NHL',
        team1Score: 1,
        team2Score: 1,
        time: '1st 8:20',
        status: 'live',
        matchDate: DateTime.now().toIso8601String(),
        odds: {'home': 1.95, 'draw': 4.20, 'away': 3.80},
      ),
    ];
  }

  List<MatchModel> _getAllMockMatches() {
    return [
      ..._getFootballMatches(),
      ..._getBasketballMatches(),
      ..._getTennisMatches(),
      ..._getHockeyMatches(),
    ];
  }
}
