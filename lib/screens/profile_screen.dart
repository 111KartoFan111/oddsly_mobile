// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oddsly/models/user_model.dart';
import 'package:oddsly/services/api_service.dart';
import 'package:oddsly/services/auth_service.dart';
import 'package:oddsly/auth_gate.dart';
import 'package:oddsly/screens/deposit_screen.dart';
import 'package:oddsly/screens/withdrawal_screen.dart';
import 'package:oddsly/screens/balance_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  Future<UserModel?>? _userFuture;
  User? _firebaseUser;

  @override
  void initState() {
    super.initState();
    _firebaseUser = _authService.currentUser;
    refreshUser();
  }

  Future<void> refreshUser() async {
    setState(() {
      _userFuture = _apiService.getUserProfile();
    });
  }

  void _logout() async {
    // Показываем диалог подтверждения
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти из аккаунта?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Выйти',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      // Выходим из Firebase
      await _authService.signOut();
      // Очищаем токен API
      await _apiService.clearToken();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthGate()),
          (route) => false,
        );
      }
    }
  }

  void _showEditProfileDialog() {
    final TextEditingController nameController = TextEditingController(
      text: _firebaseUser?.displayName ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать профиль'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Имя',
            hintText: 'Введите ваше имя',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              await _authService.updateProfile(
                displayName: nameController.text.trim(),
              );
              setState(() {
                _firebaseUser = _authService.currentUser;
              });
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('ПРОФИЛЬ'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _logout,
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshUser,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // Карточка профиля
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Аватар
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.orange.withOpacity(0.1),
                    backgroundImage: _firebaseUser?.photoURL != null
                        ? NetworkImage(_firebaseUser!.photoURL!)
                        : null,
                    child: _firebaseUser?.photoURL == null
                        ? Text(
                            (_firebaseUser?.displayName?.isNotEmpty == true
                                    ? _firebaseUser!.displayName![0]
                                    : _firebaseUser?.email?[0] ?? 'U')
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Имя пользователя
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _firebaseUser?.displayName ?? 'Пользователь',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: _showEditProfileDialog,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Email
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _firebaseUser?.email ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (_firebaseUser?.emailVerified == true) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.verified,
                          size: 18,
                          color: Colors.blue[600],
                        ),
                      ],
                    ],
                  ),
                  
                  // Кнопка верификации email если не подтвержден
                  if (_firebaseUser?.emailVerified == false) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () async {
                        final result = await _authService.sendEmailVerification();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result['message'] ?? ''),
                              backgroundColor: result['success'] == true
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.email, size: 16),
                      label: const Text('Подтвердить email'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildMenuTile(
              icon: Icons.security,
              title: 'Безопасность',
              onTap: () {
                _showSecurityOptions();
              },
            ),
            const SizedBox(height: 12),
            _buildMenuTile(
              icon: Icons.settings,
              title: 'Настройки',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('В разработке')),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildMenuTile(
              icon: Icons.help_outline,
              title: 'Помощь и поддержка',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('В разработке')),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildMenuTile(
              icon: Icons.info_outline,
              title: 'О приложении',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Oddsly',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Icon(
                    Icons.sports_soccer,
                    size: 48,
                    color: Colors.orange,
                  ),
                  children: const [
                    Text('Лучшее приложение для ставок на спорт.'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showSecurityOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Безопасность',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.lock_reset, color: Colors.orange),
              title: const Text('Изменить пароль'),
              onTap: () async {
                Navigator.of(context).pop();
                final result = await _authService.resetPassword(
                  _firebaseUser?.email ?? '',
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? ''),
                      backgroundColor:
                          result['success'] == true ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Удалить аккаунт'),
              onTap: () async {
                Navigator.of(context).pop();
                final shouldDelete = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Удаление аккаунта'),
                    content: const Text(
                      'Это действие необратимо. Все ваши данные будут удалены. Вы уверены?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Отмена'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text(
                          'Удалить',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                
                if (shouldDelete == true) {
                  final result = await _authService.deleteAccount();
                  if (context.mounted) {
                    if (result['success'] == true) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const AuthGate()),
                        (route) => false,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result['message'] ?? ''),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}