
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oddsly/models/user_model.dart';
import 'package:oddsly/models/match_model.dart';

class ApiService {
  final String _baseUrl = 'http://localhost:3000';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_token', token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_token');
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_token');
  }

  Future<Map<String, dynamic>> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'message': 'Connection error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      final data = jsonDecode(response.body);
      if (data.containsKey('token')) {
        await saveToken(data['token']);
      }
      return data;
    } catch (e) {
      return {'message': 'Connection error: ${e.toString()}'};
    }
  }

  Future<UserModel?> getUserProfile() async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return UserModel.fromJson(jsonDecode(response.body));
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<List<MatchModel>> getMatches({String? status, String? league}) async {
    try {
      final Map<String, String> queryParams = {};
      if (status != null) queryParams['status'] = status;
      if (league != null) queryParams['league'] = league;

      final uri = Uri.parse(
        '$_baseUrl/matches',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => MatchModel.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getTransactionHistory() async {
    final token = await getToken();
    if (token == null) throw Exception('User not authenticated');

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/transactions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> withdrawBalance(
    double amount,
    String cardNumber,
  ) async {
    final token = await getToken();
    if (token == null) {
      return {'message': 'User not authenticated.'};
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/withdraw'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'amount': amount, 'cardNumber': cardNumber}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'message': 'Connection error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> depositBalance(
    double amount,
    String method, {
    String? cardNumber,
  }) async {
    final token = await getToken();
    if (token == null) {
      return {'message': 'User not authenticated.'};
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/deposit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': amount,
          'method': method,
          'cardNumber': cardNumber,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'message': 'Connection error: ${e.toString()}'};
    }
  }

  Future<List<MatchModel>> getLiveMatches(String sport) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/matches/live?sport=$sport'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final matches = data.map((json) => MatchModel.fromJson(json)).toList();

        // Сортировка: live вверху, затем по дате
        matches.sort((a, b) {
          if (a.isLive && !b.isLive) return -1;
          if (!a.isLive && b.isLive) return 1;

          final dateA = DateTime.parse(a.matchDate.toString());
          final dateB = DateTime.parse(b.matchDate.toString());
          return dateA.compareTo(dateB);
        });

        return matches;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<MatchModel?> getMatchDetails(String matchId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/matches/$matchId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return MatchModel.fromJson(jsonDecode(response.body));
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> placeBet(
    String matchId,
    double amount,
    String outcome, {
    Map<String, dynamic>? matchInfo,
  }) async {
    final token = await getToken();
    if (token == null) {
      return {'message': 'User not authenticated.'};
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/bet'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'matchId': matchId,
          'amount': amount,
          'outcome': outcome,
          'matchInfo': matchInfo,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'message': 'Connection error: ${e.toString()}'};
    }
  }

  Future<List<dynamic>> getBetHistory() async {
    final token = await getToken();
    if (token == null) throw Exception('User not authenticated');

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/my-bets'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}
