// lib/services/firebase_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Получить текущего пользователя
  User? get currentUser => _auth.currentUser;

  // Создание профиля пользователя
  Future<void> createUserProfile({
    required String uid,
    required String email,
    String? displayName,
    String? photoURL,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'email': email,
        'displayName': displayName ?? '',
        'photoURL': photoURL ?? '',
        'balance': 0.0,
        'totalBets': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating user profile: $e');
      rethrow;
    }
  }

  // Получение профиля пользователя
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Обновление баланса
  Future<void> updateBalance(String uid, double newBalance) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'balance': newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating balance: $e');
      rethrow;
    }
  }

  // Добавление транзакции
  Future<String> addTransaction({
    required String uid,
    required String type, // 'deposit' or 'withdrawal'
    required double amount,
    required String status, // 'pending', 'completed', 'failed'
    String? cardNumber,
    String? method,
  }) async {
    try {
      final docRef = await _firestore.collection('transactions').add({
        'uid': uid,
        'type': type,
        'amount': amount,
        'status': status,
        'cardNumber': cardNumber ?? '',
        'method': method ?? 'card',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      print('Error adding transaction: $e');
      rethrow;
    }
  }

  // Получение истории транзакций
  Future<List<Map<String, dynamic>>> getTransactionHistory(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('transactions')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate().toIso8601String() ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error getting transaction history: $e');
      return [];
    }
  }

  // Создание ставки
  Future<String> placeBet({
    required String uid,
    required String matchId,
    required double amount,
    required String outcome,
    required Map<String, dynamic> matchInfo,
  }) async {
    try {
      // Создаем ставку
      final docRef = await _firestore.collection('bets').add({
        'uid': uid,
        'matchId': matchId,
        'amount': amount,
        'outcome': outcome,
        'status': 'active', // active, won, lost
        'team1Name': matchInfo['team1Name'] ?? '',
        'team2Name': matchInfo['team2Name'] ?? '',
        'league': matchInfo['league'] ?? '',
        'coefficient': _extractCoefficient(outcome),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Обновляем статистику пользователя
      await _firestore.collection('users').doc(uid).update({
        'totalBets': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      print('Error placing bet: $e');
      rethrow;
    }
  }

  // Извлечение коэффициента из строки outcome (например "П1 - 1.5")
  double _extractCoefficient(String outcome) {
    try {
      final parts = outcome.split(' - ');
      if (parts.length == 2) {
        return double.parse(parts[1].trim());
      }
    } catch (e) {
      print('Error extracting coefficient: $e');
    }
    return 1.0;
  }

  // Получение истории ставок
  Future<List<Map<String, dynamic>>> getBetHistory(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('bets')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate().toIso8601String() ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error getting bet history: $e');
      return [];
    }
  }

  // Обновление статуса ставки
  Future<void> updateBetStatus(String betId, String status) async {
    try {
      await _firestore.collection('bets').doc(betId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating bet status: $e');
      rethrow;
    }
  }

  // Создание депозита
  Future<String> createDeposit({
    required String uid,
    required double amount,
    required String method,
    String? cardNumber,
  }) async {
    try {
      return await addTransaction(
        uid: uid,
        type: 'deposit',
        amount: amount,
        status: 'completed',
        cardNumber: cardNumber,
        method: method,
      );
    } catch (e) {
      print('Error creating deposit: $e');
      rethrow;
    }
  }

  // Создание вывода средств
  Future<String> createWithdrawal({
    required String uid,
    required double amount,
    required String cardNumber,
  }) async {
    try {
      return await addTransaction(
        uid: uid,
        type: 'withdrawal',
        amount: amount,
        status: 'pending',
        cardNumber: cardNumber,
        method: 'card',
      );
    } catch (e) {
      print('Error creating withdrawal: $e');
      rethrow;
    }
  }

  // Получение матчей
  Future<List<Map<String, dynamic>>> getMatches({
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

      final snapshot = await query.orderBy('matchDate').get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
          'matchDate': (data['matchDate'] as Timestamp).toDate(),
        };
      }).toList();
    } catch (e) {
      print('Error getting matches: $e');
      return [];
    }
  }

  // Получение лайв матчей
  Stream<List<Map<String, dynamic>>> getLiveMatchesStream(String sport) {
    try {
      return _firestore
          .collection('matches')
          .where('sport', isEqualTo: sport)
          .where('status', isEqualTo: 'live')
          .orderBy('matchDate')
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
            'matchDate': (data['matchDate'] as Timestamp).toDate(),
          };
        }).toList();
      });
    } catch (e) {
      print('Error getting live matches stream: $e');
      return Stream.value([]);
    }
  }

  // Создание матча (для админов)
  Future<String> createMatch(Map<String, dynamic> match) async {
    try {
      final docRef = await _firestore.collection('matches').add({
        'sport': match['sport'] ?? 'football',
        'league': match['league'] ?? '',
        'team1Name': match['team1Name'] ?? '',
        'team2Name': match['team2Name'] ?? '',
        'team1Score': match['team1Score'] ?? 0,
        'team2Score': match['team2Score'] ?? 0,
        'team1Logo': match['team1Logo'] ?? '',
        'team2Logo': match['team2Logo'] ?? '',
        'status': match['status'] ?? 'scheduled', // scheduled, live, finished
        'time': match['time'] ?? '00:00',
        'odds': match['odds'] ?? {
          'home': 1.0,
          'draw': 1.0,
          'away': 1.0,
        },
        'matchDate': Timestamp.fromDate(match['matchDate'] as DateTime),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      print('Error creating match: $e');
      rethrow;
    }
  }

  // Обновление счета матча
  Future<void> updateMatchScore({
    required String matchId,
    required int team1Score,
    required int team2Score,
  }) async {
    try {
      await _firestore.collection('matches').doc(matchId).update({
        'team1Score': team1Score,
        'team2Score': team2Score,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating match score: $e');
      rethrow;
    }
  }

  // Обновление статуса матча
  Future<void> updateMatchStatus({
    required String matchId,
    required String status,
  }) async {
    try {
      await _firestore.collection('matches').doc(matchId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating match status: $e');
      rethrow;
    }
  }

  // Получение всех ставок на матч (для админов)
  Future<List<Map<String, dynamic>>> getBetsByMatch(String matchId) async {
    try {
      final snapshot = await _firestore
          .collection('bets')
          .where('matchId', isEqualTo: matchId)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'createdAt':
              (data['createdAt'] as Timestamp?)?.toDate().toIso8601String() ??
                  '',
        };
      }).toList();
    } catch (e) {
      print('Error getting bets by match: $e');
      return [];
    }
  }
}