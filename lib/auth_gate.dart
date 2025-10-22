// lib/auth_gate.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oddsly/screens/login_screen.dart';
import 'package:oddsly/screens/main_screen.dart';
import 'package:oddsly/services/auth_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // Показываем загрузку пока проверяется статус авторизации
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sports_soccer,
                    size: 80,
                    color: Colors.orange,
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(
                    color: Colors.orange,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Загрузка...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Если пользователь авторизован
        if (snapshot.hasData) {
          return const MainScreen();
        }

        // Если пользователь не авторизован
        return const LoginScreen();
      },
    );
  }
}