// oddsly/lib/screens/deposit_screen.dart

import 'package:flutter/material.dart';
import 'package:oddsly/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:oddsly/screens/withdrawal_screen.dart';
import 'package:oddsly/screens/bet_history_screen.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _cardController = TextEditingController();
  bool _isLoading = false;
  bool _agreedToTerms = false;
  bool _isDepositSelected = true;
  bool _isCardPayment = true;

  @override
  void dispose() {
    _amountController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  void _handleDeposit() async {
    if (_isLoading) return;

    final amount = double.tryParse(_amountController.text);

    if (amount == null || amount <= 0) {
      _showError('Введите корректную сумму');
      return;
    }

    if (amount < 200) {
      _showError('Минимальная сумма пополнения 200₸');
      return;
    }

    if (_cardController.text.isEmpty) {
      _showError('Введите номер карты');
      return;
    }

    if (!_agreedToTerms) {
      _showError('Примите условия использования');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // choose method based on selected payment type
    final method = _isCardPayment ? 'card' : 'apple_pay';
    final result = await _apiService.depositBalance(
      amount,
      method,
      cardNumber: _isCardPayment ? _cardController.text : null,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.containsKey('newBalance')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Баланс пополнен! Новый баланс: ₸${result['newBalance'].toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      _showError(result['message'] ?? 'Ошибка пополнения');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'ПОПОЛНЕНИЕ',
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
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BetHistoryScreen()),
                );
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Balance display
            FutureBuilder(
              future: _apiService.getUserProfile(),
              builder: (context, snapshot) {
                final balance = snapshot.data?.balance ?? 12580;
                return Align(
                  alignment: Alignment.center,
                  child: Text(
                    '₸${NumberFormat('#,##0', 'ru_RU').format(balance)}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            
            // Segmented control for Deposit/Withdrawal
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                        onTap: () {
                          // already on DepositScreen — just ensure state
                          setState(() => _isDepositSelected = true);
                        },
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
                        onTap: () {
                          // navigate to Withdrawal screen
                          setState(() => _isDepositSelected = false);
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const WithdrawalScreen()),
                          );
                        },
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
            
            // Payment method selection
            // Payment method selection (tappable)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isCardPayment = true),
                    child: Container(
                      height: 127,
                      decoration: BoxDecoration(
                        color: _isCardPayment ? const Color(0xFFFF4B00) : const Color(0xFFF3F4F5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 16,
                            top: 16,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(Icons.credit_card, color: _isCardPayment ? Colors.black : Colors.black, size: 16),
                            ),
                          ),
                          Positioned(
                            right: 16,
                            top: 16,
                            child: Icon(_isCardPayment ? Icons.star : Icons.star_border, color: _isCardPayment ? Colors.white : Colors.black, size: 24),
                          ),
                          Positioned(
                            left: 16,
                            bottom: 27,
                            child: Text(
                              'Картой',
                              style: TextStyle(
                                color: _isCardPayment ? Colors.white : Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            bottom: 16,
                            child: Text(
                              'Коммиссия 5%',
                              style: TextStyle(
                                color: _isCardPayment ? Colors.white : Colors.black54,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isCardPayment = false),
                    child: Container(
                      height: 127,
                      decoration: BoxDecoration(
                        color: !_isCardPayment ? const Color(0xFFFF4B00) : const Color(0xFFF3F4F5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: 16,
                            top: 16,
                            child: Icon(!_isCardPayment ? Icons.star : Icons.star_border, color: !_isCardPayment ? Colors.white : Colors.black, size: 24),
                          ),
                          Positioned(
                            left: 16,
                            bottom: 27,
                            child: Text(
                              'Apple Pay',
                              style: TextStyle(
                                color: !_isCardPayment ? Colors.white : Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            bottom: 16,
                            child: Text(
                              'Коммиссия 0%',
                              style: TextStyle(
                                color: !_isCardPayment ? Colors.white70 : Colors.black54,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Card input (only when card selected)
            if (_isCardPayment)
              Container(
                height: 48,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: TextField(
                  controller: _cardController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '4567 •••• •••• 7702',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            
            // Amount input
            Container(
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '₸ 200',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Terms checkbox
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _agreedToTerms ? Colors.black : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black),
                    ),
                    child: _agreedToTerms
                        ? const Icon(Icons.check, color: Colors.white, size: 12)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'I agree to the terms of use of the "One click pay" services',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            
            // Deposit button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleDeposit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4B00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
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
                        'Пополнить депозит',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
