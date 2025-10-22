import 'package:flutter/material.dart';
import 'package:oddsly/models/bet_history_model.dart';
import 'package:oddsly/services/api_service.dart';
import 'package:intl/intl.dart';

class BetHistoryScreen extends StatefulWidget {
  const BetHistoryScreen({super.key});

  @override
  State<BetHistoryScreen> createState() => _BetHistoryScreenState();
}

class _BetHistoryScreenState extends State<BetHistoryScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _betHistoryFuture;

  @override
  void initState() {
    super.initState();
    _refreshHistory();
  }

  Future<void> _refreshHistory() async {
    setState(() {
      _betHistoryFuture = _apiService.getBetHistory();
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return const Color(0xFF50DA8F);
      case 'lost':
        return const Color(0xFFEE120B);
      case 'won':
        return const Color(0xFF50DA8F);
      default:
        return const Color(0xFF6C6C6C);
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Активно';
      case 'lost':
        return 'Проиграно';
      case 'won':
        return 'Выиграно';
      default:
        return 'Продано';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ИСТОРИЯ СТАВОК',
          style: TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.sports_basketball, color: Colors.black, size: 20),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshHistory,
        child: FutureBuilder<List<dynamic>>(
          future: _betHistoryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return const Center(
                child: Text('История ставок пуста. Потяните, чтобы обновить.'),
              );
            }

            final bets = snapshot.data!
                .map((json) => BetHistory.fromJson(json))
                .toList();

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              itemCount: bets.length,
              itemBuilder: (context, index) {
                final bet = bets[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: BetHistoryCard(
                    bet: bet,
                    color: _getStatusColor(bet.status),
                    statusText: _getStatusText(bet.status),
                  ),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: Container(
        height: 75,
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(Icons.whatshot, 'Live', true),
            _buildNavItem(Icons.sports_soccer, 'Спорт', false),
            _buildNavItem(Icons.payment, 'Платежи', false),
            _buildNavItem(Icons.more_vert, 'Еще', false),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: isActive ? Colors.black : Colors.grey,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class BetHistoryCard extends StatelessWidget {
  final BetHistory bet;
  final Color color;
  final String statusText;

  const BetHistoryCard({
    super.key,
    required this.bet,
    required this.color,
    required this.statusText,
  });

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '88:42';
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('HH:mm').format(date);
    } catch (e) {
      return '88:42';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 176,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 5),
      ),
      child: Stack(
        children: [
          // League name
          Positioned(
            left: 16,
            top: 6,
            child: Text(
              bet.league,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.1,
              ),
            ),
          ),
          
          // Status
          Positioned(
            right: 16,
            top: 6,
            child: Text(
              statusText,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          
          // Team 1
          Positioned(
            left: 16,
            top: 26,
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  bet.team1Name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '0',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          
          // Team 2
          Positioned(
            left: 16,
            top: 56,
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  bet.team2Name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '1',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          
          // Time and live indicator
          Positioned(
            left: 16,
            top: 85,
            child: Row(
              children: [
                const Icon(
                  Icons.play_circle_outline,
                  size: 16,
                  color: Colors.black,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(bet.createdAt),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          
          // Live indicator
          if (statusText == 'Активно')
            Positioned(
              left: 16,
              bottom: 34,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Live',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Coefficient button
          Positioned(
            right: 16,
            top: 50,
            child: Container(
              width: 83,
              height: 34,
              decoration: BoxDecoration(
                color: statusText == 'Активно' ? const Color(0xFF50DA8F) : const Color(0xFFF3F4F5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0x0D000000),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  '${bet.outcome} - ${bet.coefficient?.toStringAsFixed(1) ?? '14.2'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusText == 'Активно' ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ),
          
          // Sell button (for active bets)
          if (statusText == 'Активно')
            Positioned(
              right: 16,
              bottom: 34,
              child: Container(
                width: 83,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFED1C24),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0x0D000000),
                    width: 0.5,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Продать',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
