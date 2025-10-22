import 'package:flutter/material.dart';
import 'package:oddsly/services/api_service.dart';

class MatchDetailScreen extends StatefulWidget {
  final VoidCallback onBetPlaced;
  final Map<String, dynamic> match;

  const MatchDetailScreen({
    super.key,
    required this.onBetPlaced,
    required this.match,
  });

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _amountController = TextEditingController(
    text: '200',
  );
  bool _isLoading = false;
  String _selectedOutcome = 'home';

  String _getOutcomeLabel() {
    final match = widget.match;
    switch (_selectedOutcome) {
      case 'home':
        return 'П1 - ${match['odds']['home']}';
      case 'draw':
        return 'X - ${match['odds']['draw']}';
      case 'away':
        return 'П2 - ${match['odds']['away']}';
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() {
      setState(() {}); 
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _handlePlaceBet() async {
    if (_isLoading) return;

    final amount = double.tryParse(_amountController.text);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите корректную сумму'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (amount < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Минимальная ставка 100₸'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final match = widget.match;

    final result = await _apiService.placeBet(
      match['id'],
      amount,
      _getOutcomeLabel(),
      matchInfo: {
        'team1Name': match['team1Name'],
        'team2Name': match['team2Name'],
        'league': match['league'],
      },
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result.containsKey('betId')) {
      widget.onBetPlaced();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ставка принята! Новый баланс: ₸${result['newBalance'].toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } else {
      final message = result['message'] ?? 'Ошибка';
      final isInsufficientFunds =
          message.contains('Недостаточно') || message.contains('Insufficient');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isInsufficientFunds
                ? 'Недостаточно средств на балансе'
                : 'Ошибка: $message',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          match['league']?.toUpperCase() ?? 'МАТЧ',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 20),
              TeamInfoRow(teamName: match['team1Name'] ?? 'Team 1', score: 0),
              const SizedBox(height: 10),
              TeamInfoRow(teamName: match['team2Name'] ?? 'Team 2', score: 0),
              const SizedBox(height: 10),
              const Text(
                '00:00',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: const [
                    StatsRow(
                      title: 'Атаки',
                      value1: 0,
                      value2: 0,
                      progress1: 0.5,
                    ),
                    SizedBox(height: 8),
                    StatsRow(
                      title: 'Удары',
                      value1: 0,
                      value2: 0,
                      progress1: 0.5,
                    ),
                    SizedBox(height: 8),
                    StatsRow(
                      title: 'Владение мячем',
                      value1: 50,
                      value2: 50,
                      progress1: 0.5,
                      isPercent: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.55,
            maxChildSize: 0.8,
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Результаты матча',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: BetOption(
                            label: '1',
                            value: match['odds']['home'] ?? '1.0',
                            isSelected: _selectedOutcome == 'home',
                            onTap: () {
                              setState(() {
                                _selectedOutcome = 'home';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: BetOption(
                            label: 'X',
                            value: match['odds']['draw'] ?? '1.0',
                            isSelected: _selectedOutcome == 'draw',
                            onTap: () {
                              setState(() {
                                _selectedOutcome = 'draw';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: BetOption(
                            label: '2',
                            value: match['odds']['away'] ?? '1.0',
                            isSelected: _selectedOutcome == 'away',
                            onTap: () {
                              setState(() {
                                _selectedOutcome = 'away';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Сумма ставки',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '₸ 200',
                        prefixText: '₸ ',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Исход:',
                                style: TextStyle(fontSize: 14),
                              ),
                              Text(
                                _getOutcomeLabel(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Возможный выигрыш:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '₸ ${_calculatePotentialWin()}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handlePlaceBet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Сделать ставку',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _calculatePotentialWin() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final match = widget.match;

    double coefficient = 1.0;
    final odds = match['odds'];

    switch (_selectedOutcome) {
      case 'home':
        coefficient = odds['home'] is String
            ? double.tryParse(odds['home']) ?? 1.0
            : (odds['home'] as num).toDouble();
        break;
      case 'draw':
        coefficient = odds['draw'] is String
            ? double.tryParse(odds['draw']) ?? 1.0
            : (odds['draw'] as num).toDouble();
        break;
      case 'away':
        coefficient = odds['away'] is String
            ? double.tryParse(odds['away']) ?? 1.0
            : (odds['away'] as num).toDouble();
        break;
    }

    return (amount * coefficient).toStringAsFixed(0);
  }
}

class TeamInfoRow extends StatelessWidget {
  final String teamName;
  final int score;

  const TeamInfoRow({super.key, required this.teamName, required this.score});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          const Icon(Icons.shield, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              teamName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            score.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class StatsRow extends StatelessWidget {
  final String title;
  final int value1;
  final int value2;
  final double progress1;
  final bool isPercent;

  const StatsRow({
    super.key,
    required this.title,
    required this.value1,
    required this.value2,
    required this.progress1,
    this.isPercent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$value1${isPercent ? "%" : ""}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(title, style: TextStyle(color: Colors.grey[400])),
            Text(
              '$value2${isPercent ? "%" : ""}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: RotatedBox(
                quarterTurns: 2,
                child: LinearProgressIndicator(
                  value: progress1,
                  backgroundColor: Colors.grey[700],
                  color: Colors.orange,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LinearProgressIndicator(
                value: 1 - progress1,
                backgroundColor: Colors.grey[700],
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class BetOption extends StatelessWidget {
  final String label;
  final dynamic value; 
  final bool isSelected;
  final VoidCallback onTap;

  const BetOption({
    super.key,
    required this.label,
    required this.value,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value is String ? value : value.toStringAsFixed(2);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
