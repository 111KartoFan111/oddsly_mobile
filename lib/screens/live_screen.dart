import 'package:flutter/material.dart';
import 'package:oddsly/models/match_model.dart';
import 'package:oddsly/screens/match_detail_screen.dart';
import 'package:oddsly/services/api_service.dart';
import 'dart:async';

class LiveScreen extends StatefulWidget {
  final VoidCallback onBetPlaced;

  const LiveScreen({super.key, required this.onBetPlaced});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final ApiService _apiService = ApiService();
  String _selectedSport = 'football';
  String _selectedStatus = 'all'; // all, live, scheduled, finished
  Future<List<MatchModel>>? _matchesFuture;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadMatches();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadMatches();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _loadMatches() {
    setState(() {
      _matchesFuture = _apiService.getLiveMatches(_selectedSport);
    });
  }

  void _changeSport(String sport) {
    setState(() {
      _selectedSport = sport;
      _loadMatches();
    });
  }

  void _changeStatus(String status) {
    setState(() {
      _selectedStatus = status;
    });
  }

  List<MatchModel> _filterMatches(List<MatchModel> matches) {
    if (_selectedStatus == 'all') return matches;
    return matches.where((m) => m.status == _selectedStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.grey[100],
        title: Row(
          children: const [
            Text(
              '● LIVE',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            SizedBox(width: 16),
            Text(
              'LINE',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadMatches,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск по ивенту, команде',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                SportChip(
                  icon: Icons.sports_soccer,
                  label: 'Футбол',
                  isSelected: _selectedSport == 'football',
                  onTap: () => _changeSport('football'),
                ),
                const SizedBox(width: 10),
                SportChip(
                  icon: Icons.sports_basketball,
                  label: 'Баскетбол',
                  isSelected: _selectedSport == 'basketball',
                  onTap: () => _changeSport('basketball'),
                ),
                const SizedBox(width: 10),
                SportChip(
                  icon: Icons.sports_tennis,
                  label: 'Теннис',
                  isSelected: _selectedSport == 'tennis',
                  onTap: () => _changeSport('tennis'),
                ),
                const SizedBox(width: 10),
                SportChip(
                  icon: Icons.sports_hockey,
                  label: 'Хоккей',
                  isSelected: _selectedSport == 'hockey',
                  onTap: () => _changeSport('hockey'),
                ),    
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  label: 'Все',
                  selected: _selectedStatus == 'all',
                  onSelected: (_) => _changeStatus('all'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: 'Live',
                  selected: _selectedStatus == 'live',
                  onSelected: (_) => _changeStatus('live'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: 'Скоро',
                  selected: _selectedStatus == 'scheduled',
                  onSelected: (_) => _changeStatus('scheduled'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: 'Завершено',
                  selected: _selectedStatus == 'finished',
                  onSelected: (_) => _changeStatus('finished'),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<MatchModel>>(
              future: _matchesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Нет доступных матчей'));
                }

                final filteredMatches = _filterMatches(snapshot.data!);

                if (filteredMatches.isEmpty) {
                  return const Center(
                    child: Text('Нет матчей с выбранным фильтром'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    _loadMatches();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredMatches.length,
                    itemBuilder: (context, index) {
                      final match = filteredMatches[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => MatchDetailScreen(
                                  onBetPlaced: widget.onBetPlaced,
                                  match: {
                                    'id': match.id,
                                    'team1Name': match.team1Name,
                                    'team2Name': match.team2Name,
                                    'league': match.league,
                                    'odds': {
                                      'home': match.odds['home'],
                                      'draw': match.odds['draw'],
                                      'away': match.odds['away'],
                                    },
                                  },
                                ),
                              ),
                            );
                          },
                          child: MatchCard(match: match),
                        ),
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

class FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Function(bool) onSelected;

  const FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: Colors.orange,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black,
        fontWeight: FontWeight.bold,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class SportChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const SportChip({
    super.key,
    required this.icon,
    required this.label,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        avatar: Icon(icon, color: isSelected ? Colors.white : Colors.black),
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isSelected ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class MatchCard extends StatelessWidget {
  final MatchModel match;

  const MatchCard({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(match.league, style: const TextStyle(color: Colors.grey)),
              const Spacer(),
              if (match.status == 'live')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (match.team1Logo.isNotEmpty)
                        Image.network(
                          match.team1Logo,
                          width: 24,
                          height: 24,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.shield, color: Colors.blue),
                        )
                      else
                        const Icon(Icons.shield, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        match.team1Name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (match.team2Logo.isNotEmpty)
                        Image.network(
                          match.team2Logo,
                          width: 24,
                          height: 24,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.shield, color: Colors.red),
                        )
                      else
                        const Icon(Icons.shield, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        match.team2Name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Column(
                children: [
                  Text(
                    match.team1Score.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    match.team2Score.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.grey, size: 16),
              const SizedBox(width: 4),
              Text(match.time, style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: BetButton(text: 'П1 - ${match.odds['home'] ?? '0'}'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BetButton(text: 'X - ${match.odds['draw'] ?? '0'}'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BetButton(text: 'П2 - ${match.odds['away'] ?? '0'}'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BetButton extends StatelessWidget {
  final String text;
  const BetButton({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[200],
        foregroundColor: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(text),
    );
  }
}
