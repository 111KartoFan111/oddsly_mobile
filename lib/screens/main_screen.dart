import 'package:flutter/material.dart';
import 'package:oddsly/screens/balance_history_screen.dart';
import 'package:oddsly/screens/live_screen.dart';
import 'package:oddsly/screens/home_screen.dart';
import 'package:oddsly/screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1;
  final GlobalKey<ProfileScreenState> _profileKey =
      GlobalKey<ProfileScreenState>();

  void _refreshProfile() {
    _profileKey.currentState?.refreshUser();
  }

  late final List<Widget> _widgetOptions = <Widget>[
    const HomeScreen(),
    LiveScreen(onBetPlaced: _refreshProfile),
    const BalanceHistoryScreen(),
    ProfileScreen(key: _profileKey),
  ];

  void _onItemTapped(int index) {
    if (index == 3) {
      _refreshProfile();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _widgetOptions),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.whatshot), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.sports_soccer), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: ''),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }
}
