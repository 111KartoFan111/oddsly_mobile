// oddsly/lib/screens/balance_history_screen.dart

import 'package:flutter/material.dart';
import 'package:oddsly/services/api_service.dart';
import 'package:oddsly/screens/deposit_screen.dart';
import 'package:oddsly/screens/withdrawal_screen.dart';
import 'package:intl/intl.dart';

class BalanceHistoryScreen extends StatefulWidget {
  const BalanceHistoryScreen({super.key});

  @override
  State<BalanceHistoryScreen> createState() => _BalanceHistoryScreenState();
}

class _BalanceHistoryScreenState extends State<BalanceHistoryScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _transactionsFuture;
  bool _isDepositSelected = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  void _loadTransactions() {
    setState(() {
      _transactionsFuture = _apiService.getTransactionHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('БАЛАНС'),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.settings, size: 20, color: Colors.black),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // Balance display
          FutureBuilder(
            future: _apiService.getUserProfile(),
            builder: (context, snapshot) {
              final balance = snapshot.data?.balance ?? 0;
              return Text(
                '₸${NumberFormat('#,##0', 'ru_RU').format(balance)}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          
          // Segmented control for Deposit/Withdrawal
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isDepositSelected = true),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isDepositSelected ? Colors.black : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          bottomLeft: Radius.circular(6),
                        ),
                        border: _isDepositSelected 
                            ? null 
                            : const Border(
                                right: BorderSide(color: Colors.black, width: 1),
                              ),
                      ),
                      child: Center(
                        child: Text(
                          'Пополнение',
                          style: TextStyle(
                            color: _isDepositSelected ? Colors.white : Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isDepositSelected = false),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isDepositSelected ? Colors.transparent : Colors.black,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                        border: _isDepositSelected 
                            ? const Border(
                                left: BorderSide(color: Colors.black, width: 1),
                              )
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'Вывод',
                          style: TextStyle(
                            color: _isDepositSelected ? Colors.black : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Transaction list
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _transactionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Ошибка загрузки. Потяните, чтобы обновить.'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('История транзакций пуста'));
                }

                final transactions = snapshot.data!;
                final filteredTransactions = transactions.where((transaction) {
                  final type = transaction['type']?.toString().toLowerCase() ?? '';
                  return _isDepositSelected ? type == 'deposit' : type == 'withdrawal';
                }).toList();

                return RefreshIndicator(
                  onRefresh: () async {
                    _loadTransactions();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    itemCount: filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = filteredTransactions[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TransactionHistoryItem(transaction: transaction),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TransactionHistoryItem extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const TransactionHistoryItem({super.key, required this.transaction});

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '05.10.2025';
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd.MM.yyyy').format(date);
    } catch (e) {
      return '05.10.2025';
    }
  }

  String _formatTime(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '22:00';
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('HH:mm').format(date);
    } catch (e) {
      return '22:00';
    }
  }

  Color _getBorderColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF50DA8F);
      case 'failed':
      case 'cancelled':
        return const Color(0xFFE15007);
      case 'pending':
        return const Color(0xFFE4E5E5);
      default:
        return const Color(0xFFE4E5E5);
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Выплачено';
      case 'pending':
        return 'В обработке';
      case 'failed':
      case 'cancelled':
        return 'Отменено';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF50DA8F);
      case 'failed':
      case 'cancelled':
        return const Color(0xFFEE120B);
      case 'pending':
        return const Color(0xFF6C6C6C);
      default:
        return const Color(0xFF6C6C6C);
    }
  }

  String _getTransactionType(String type) {
    switch (type.toLowerCase()) {
      case 'deposit':
        return 'На баланс';
      case 'withdrawal':
        return 'На карту';
      default:
        return 'Транзакция';
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = transaction['type'] ?? 'transaction';
    final status = transaction['status'] ?? 'completed';
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
    final cardNumber = transaction['cardNumber'] ?? '';
    final createdAt = transaction['createdAt'];
    final borderColor = _getBorderColor(status);
    final statusColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 5),
      ),
      child: Column(
        children: [
          // Main transaction info
          SizedBox(
            height: 47,
            child: Row(
              children: [
                // Card icon and number
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.credit_card, color: Colors.white, size: 12),
                ),
                const SizedBox(width: 9),
                Text(
                  cardNumber.isNotEmpty ? '+7 •••• ${cardNumber.substring(cardNumber.length - 4)}' : '+7 •••• 7702',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Amount
                Text(
                  '₸ ${NumberFormat('#,##0', 'ru_RU').format(amount)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Status row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getTransactionType(type),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black54,
                ),
              ),
              Text(
                _getStatusText(status),
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Date and time
          Row(
            children: [
              Text(
                _formatDate(createdAt),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(createdAt),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

