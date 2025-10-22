// lib/services/firebase_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oddsly/models/user_model.dart';
import 'package:oddsly/models/match_model.dart';
import 'package:oddsly/models/bet_history_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // ==================== USER OPERATIONS ====================

  /// Создать профиль пользователя в Firestore
  Future<Map<String, dynamic>> createUserProfile({
    required String email,
    String? displayName,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      await _firestore.collection('users').doc(userId).set({
        'email': email,
        'displayName': displayName ?? 'Пользователь',
        'balance': 1000.0, // Начальный баланс
        'totalBets': 0,
        'totalWins': 0,
        'totalLosses': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {'success': true, 'message': 'Profile created successfully'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Получить профиль пользователя
  Future<UserModel?> getUserProfile() async {
    try {
      final userId = currentUserId;
      if (userId == null) return null;

      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) {
        // Создать профиль если не существует
        await createUserProfile(
          email: _auth.currentUser!.email!,
          displayName: _auth.currentUser!.displayName,
        );
        return getUserProfile();
      }

      final data = doc.data()!;
      return UserModel(
        email: data['email'],
        balance: (data['balance'] as num).toDouble(),
      );
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  /// Обновить баланс пользователя
  Future<Map<String, dynamic>> updateUserBalance({
    required double amount,
    required bool isAddition,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      final userRef = _firestore.collection('users').doc(userId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) {
          throw Exception('User document does not exist');
        }

        final currentBalance = (snapshot.data()!['balance'] as num).toDouble();
        final newBalance = isAddition
            ? currentBalance + amount
            : currentBalance - amount;

        if (newBalance < 0) {
          throw Exception('Insufficient balance');
        }

        transaction.update(userRef, {
          'balance': newBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      final updatedUser = await getUserProfile();
      return {
        'success': true,
        'newBalance': updatedUser?.balance ?? 0,
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== BET OPERATIONS ====================

  /// Разместить ставку
  Future<Map<String, dynamic>> placeBet({
    required String matchId,
    required double amount,
    required String outcome,
    required double coefficient,
    required Map<String, dynamic> matchInfo,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      // Проверка баланса
      final userProfile = await getUserProfile();
      if (userProfile == null || userProfile.balance < amount) {
        return {'success': false, 'message': 'Недостаточно средств на балансе'};
      }

      // Создать ставку
      final betRef = _firestore.collection('bets').doc();
      final potentialWin = amount * coefficient;

      await _firestore.runTransaction((transaction) async {
        // Уменьшить баланс
        final userRef = _firestore.collection('users').doc(userId);
        final userSnapshot = await transaction.get(userRef);
        final currentBalance =
            (userSnapshot.data()!['balance'] as num).toDouble();
        
        if (currentBalance < amount) {
          throw Exception('Insufficient balance');
        }

        transaction.update(userRef, {
          'balance': currentBalance - amount,
          'totalBets': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Создать документ ставки
        transaction.set(betRef, {
          'userId': userId,
          'matchId': matchId,
          'amount': amount,
          'outcome': outcome,
          'coefficient': coefficient,
          'status': 'active',
          'potentialWin': potentialWin,
          'team1Name': matchInfo['team1Name'],
          'team2Name': matchInfo['team2Name'],
          'league': matchInfo['league'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      final updatedUser = await getUserProfile();
      return {
        'success': true,
        'betId': betRef.id,
        'newBalance': updatedUser?.balance ?? 0,
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Получить историю ставок
  Future<List<BetHistory>> getBetHistory() async {
    try {
      final userId = currentUserId;
      if (userId == null) return [];

      final querySnapshot = await _firestore
          .collection('bets')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return BetHistory(
          id: doc.id,
          amount: (data['amount'] as num).toDouble(),
          matchId: data['matchId'],
          outcome: data['outcome'],
          status: data['status'],
          createdAt: (data['createdAt'] as Timestamp?)?.toDate().toIso8601String() ?? '',
          team1Name: data['team1Name'],
          team2Name: data['team2Name'],
          league: data['league'],
        );
      }).toList();
    } catch (e) {
      print('Error getting bet history: $e');
      return [];
    }
  }

  // ==================== TRANSACTION OPERATIONS ====================

  /// Создать транзакцию депозита
  Future<Map<String, dynamic>> createDeposit({
    required double amount,
    required String method,
    String? cardNumber,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      // Создать транзакцию
      await _firestore.collection('transactions').add({
        'userId': userId,
        'type': 'deposit',
        'amount': amount,
        'method': method,
        'cardNumber': cardNumber != null ? _maskCardNumber(cardNumber) : null,
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Обновить баланс
      final result = await updateUserBalance(amount: amount, isAddition: true);
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Создать транзакцию вывода
  Future<Map<String, dynamic>> createWithdrawal({
    required double amount,
    required String cardNumber,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      // Проверка баланса
      final userProfile = await getUserProfile();
      if (userProfile == null || userProfile.balance < amount) {
        return {'success': false, 'message': 'Недостаточно средств на балансе'};
      }

      // Создать транзакцию
      await _firestore.collection('transactions').add({
        'userId': userId,
        'type': 'withdrawal',
        'amount': amount,
        'method': 'card',
        'cardNumber': _maskCardNumber(cardNumber),
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Обновить баланс
      final result = await updateUserBalance(amount: amount, isAddition: false);
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Получить историю транзакций
  Future<List<Map<String, dynamic>>> getTransactionHistory() async {
    try {
      final userId = currentUserId;
      if (userId == null) return [];

      final querySnapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': data['type'],
          'amount': data['amount'],
          'method': data['method'],
          'cardNumber': data['cardNumber'],
          'status': data['status'],
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate().toIso8601String(),
        };
      }).toList();
    } catch (e) {
      print('Error getting transaction history: $e');
      return [];
    }
  }

  // ==================== MATCH OPERATIONS ====================

  /// Получить матчи по виду спорта
  Future<List<MatchModel>> getMatches({
    String? sport,
    String? status,
  }) async {
    try {
      Query query = _firestore.collection('matches');

      if (sport != null) {
        query = query.where('sport', isEqualTo: sport);
      }
      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return MatchModel(
          id: doc.id,
          team1Name: data['team1Name'],
          team2Name: data['team2Name'],
          league: data['league'],
          team1Score: data['team1Score'] ?? 0,
          team2Score: data['team2Score'] ?? 0,
          time: data['time'] ?? '00:00',
          status: data['status'],
          matchDate: (data['matchDate'] as Timestamp).toDate(),
          odds: {
            'home': (data['odds']['home'] as num).toDouble(),
            'draw': (data['odds']['draw'] as num).toDouble(),
            'away': (data['odds']['away'] as num).toDouble(),
          },
        );
      }).toList();
    } catch (e) {
      print('Error getting matches: $e');
      return [];
    }
  }

  /// Добавить тестовые матчи (для демонстрации)
  Future<void> seedTestMatches() async {
    try {
      final matchesRef = _firestore.collection('matches');
      
      // Проверить, есть ли уже матчи
      final existingMatches = await matchesRef.limit(1).get();
      if (existingMatches.docs.isNotEmpty) {
        return; // Матчи уже существуют
      }

      // Добавить тестовые матчи
      final testMatches = [
        {
          'sport': 'football',
          'league': 'Premier League',
          'team1Name': 'Manchester United',
          'team2Name': 'Liverpool',
          'team1Score': 2,
          'team2Score': 1,
          'status': 'live',
          'time': '67:00',
          'matchDate': DateTime.now(),
          'odds': {'home': 2.1, 'draw': 3.4, 'away': 3.2},
        },
        {
          'sport': 'football',
          'league': 'La Liga',
          'team1Name': 'Real Madrid',
          'team2Name': 'Barcelona',
          'team1Score': 0,
          'team2Score': 0,
          'status': 'scheduled',
          'time': '20:00',
          'matchDate': DateTime.now().add(const Duration(hours: 2)),
          'odds': {'home': 2.3, 'draw': 3.1, 'away': 2.9},
        },
        {
          'sport': 'basketball',
          'league': 'NBA',
          'team1Name': 'Lakers',
          'team2Name': 'Warriors',
          'team1Score': 95,
          'team2Score': 92,
          'status': 'live',
          'time': 'Q4 5:30',
          'matchDate': DateTime.now(),
          'odds': {'home': 1.8, 'draw': 0, 'away': 2.1},
        },
      ];

      for (var match in testMatches) {
        await matchesRef.add({
          ...match,
          'matchDate': Timestamp.fromDate(match['matchDate'] as DateTime),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      print('Test matches seeded successfully');
    } catch (e) {
      print('Error seeding test matches: $e');
    }
  }

  // ==================== HELPER METHODS ====================

  String _maskCardNumber(String cardNumber) {
    if (cardNumber.length < 4) return cardNumber;
    return cardNumber.substring(cardNumber.length - 4);
  }

  /// Стрим для получения профиля пользователя в реальном времени
  Stream<UserModel?> getUserProfileStream() {
    final userId = currentUserId;
    if (userId == null) return Stream.value(null);

    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()!;
      return UserModel(
        email: data['email'],
        balance: (data['balance'] as num).toDouble(),
      );
    });
  }

  /// Стрим для получения ставок в реальном времени
  Stream<List<BetHistory>> getBetHistoryStream() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('bets')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return BetHistory(
          id: doc.id,
          amount: (data['amount'] as num).toDouble(),
          matchId: data['matchId'],
          outcome: data['outcome'],
          status: data['status'],
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate().toIso8601String() ??
                  '',
          team1Name: data['team1Name'],
          team2Name: data['team2Name'],
          league: data['league'],
        );
      }).toList();
    });
  }
}