import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'doubles_tournament_register_page.dart';
import 'doubles_match_result_page.dart';

class DoublesTournamentPage extends StatefulWidget {
  final String tournamentId;

  const DoublesTournamentPage({Key? key, required this.tournamentId})
    : super(key: key);

  @override
  State<DoublesTournamentPage> createState() => _DoublesTournamentPageState();
}

class _DoublesTournamentPageState extends State<DoublesTournamentPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _tournament;
  List<Map<String, dynamic>> _pairs = [];
  Map<String, List<Map<String, dynamic>>> _groupStandings = {};
  List<Map<String, dynamic>> _knockoutMatches = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTournamentData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTournamentData() async {
    setState(() => _isLoading = true);

    try {
      // Carica info torneo
      final tournamentResponse = await supabase
          .from('tournaments')
          .select()
          .eq('id', widget.tournamentId)
          .single();

      // Carica coppie con info giocatori
      final pairsResponse = await supabase
          .from('tournament_pairs')
          .select('''
            *,
            player1:players!tournament_pairs_player1_id_fkey(id, name, avatar_url),
            player2:players!tournament_pairs_player2_id_fkey(id, name, avatar_url)
          ''')
          .eq('tournament_id', widget.tournamentId);

      // Carica classifiche gironi
      if (tournamentResponse['phase'] == 'group') {
        final groupsResponse = await supabase
            .from('tournament_group_pairs')
            .select('''
              *,
              pair:tournament_pairs!tournament_group_pairs_pair_id_fkey(
                *,
                player1:players!tournament_pairs_player1_id_fkey(id, name, avatar_url),
                player2:players!tournament_pairs_player2_id_fkey(id, name, avatar_url)
              )
            ''')
            .eq('tournament_id', widget.tournamentId)
            .order('group_name')
            .order('points', ascending: false)
            .order('sets_won', ascending: false);

        // Organizza per girone
        final groupsMap = <String, List<Map<String, dynamic>>>{};
        for (var item in groupsResponse) {
          final groupName = item['group_name'] as String;
          if (!groupsMap.containsKey(groupName)) {
            groupsMap[groupName] = [];
          }
          groupsMap[groupName]!.add(item);
        }

        setState(() {
          _groupStandings = groupsMap;
        });
      }

      // Carica partite knockout
      if (tournamentResponse['phase'] == 'knockout' ||
          tournamentResponse['phase'] == 'completed') {
        final knockoutResponse = await supabase
            .from('tournament_doubles_matches')
            .select('''
              *,
              pair1:tournament_pairs!tournament_doubles_matches_pair1_id_fkey(
                *,
                player1:players!tournament_pairs_player1_id_fkey(id, name, avatar_url),
                player2:players!tournament_pairs_player2_id_fkey(id, name, avatar_url)
              ),
              pair2:tournament_pairs!tournament_doubles_matches_pair2_id_fkey(
                *,
                player1:players!tournament_pairs_player1_id_fkey(id, name, avatar_url),
                player2:players!tournament_pairs_player2_id_fkey(id, name, avatar_url)
              )
            ''')
            .eq('tournament_id', widget.tournamentId)
            .eq('phase', 'knockout')
            .order('match_date', ascending: false);

        setState(() {
          _knockoutMatches = (knockoutResponse as List)
              .cast<Map<String, dynamic>>();
        });
      }

      setState(() {
        _tournament = tournamentResponse;
        _pairs = (pairsResponse as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Errore caricamento torneo: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _registerPair() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DoublesTournamentRegisterPage(tournament: _tournament!),
      ),
    );

    if (result == true) {
      _loadTournamentData();
    }
  }

  String _getPairDisplayName(Map<String, dynamic> pair) {
    if (pair['pair_name'] != null && pair['pair_name'].toString().isNotEmpty) {
      return pair['pair_name'];
    }
    final player1Name = pair['player1']?['name'] ?? 'Giocatore 1';
    final player2Name = pair['player2']?['name'] ?? 'Giocatore 2';
    return '$player1Name / $player2Name';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          _tournament?['name'] ?? 'Torneo Doppio',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00E676),
          labelColor: const Color(0xFF00E676),
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Coppie'),
            Tab(text: 'Gironi'),
            Tab(text: 'Knockout'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPairsTab(),
                _buildGroupsTab(),
                _buildKnockoutTab(),
              ],
            ),
      floatingActionButton:
          _tournament != null && _tournament!['phase'] == 'registration'
          ? FloatingActionButton.extended(
              onPressed: _registerPair,
              backgroundColor: const Color(0xFF00E676),
              icon: const Icon(Icons.add, color: Colors.black),
              label: Text(
                'Registra Coppia',
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildPairsTab() {
    return RefreshIndicator(
      onRefresh: _loadTournamentData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _tournament?['phase'] == 'registration'
                      ? Icons.app_registration
                      : _tournament?['phase'] == 'group'
                      ? Icons.groups
                      : Icons.emoji_events,
                  color: const Color(0xFF00E676),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_pairs.length}/16 Coppie',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _tournament?['phase'] == 'registration'
                            ? 'Registrazioni aperte'
                            : _tournament?['phase'] == 'group'
                            ? 'Fase a gironi'
                            : _tournament?['phase'] == 'knockout'
                            ? 'Fase a eliminazione diretta'
                            : 'Torneo completato',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Lista coppie
          if (_pairs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Nessuna coppia registrata',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else
            ..._pairs.asMap().entries.map((entry) {
              final index = entry.key;
              final pair = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // Numero
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF00E676),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (pair['pair_name'] != null &&
                              pair['pair_name'].toString().isNotEmpty)
                            Text(
                              pair['pair_name'],
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF00E676),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          Text(
                            '${pair['player1']?['name'] ?? 'Giocatore 1'} / ${pair['player2']?['name'] ?? 'Giocatore 2'}',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildGroupsTab() {
    if (_tournament?['phase'] == 'registration') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'I gironi saranno creati automaticamente\nquando si registrano 16 coppie',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    if (_groupStandings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadTournamentData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: _groupStandings.entries.map((entry) {
          final groupName = entry.key;
          final standings = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Header girone
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E676),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.groups, color: Colors.black),
                      const SizedBox(width: 8),
                      Text(
                        groupName,
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Classifiche
                ...standings.asMap().entries.map((entry) {
                  final position = entry.key + 1;
                  final item = entry.value;
                  final pair = item['pair'];
                  final isQualified = position <= 2;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Posizione
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isQualified
                                ? const Color(0xFF00E676).withOpacity(0.2)
                                : Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$position',
                              style: GoogleFonts.poppins(
                                color: isQualified
                                    ? const Color(0xFF00E676)
                                    : Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Nome coppia
                        Expanded(
                          child: Text(
                            _getPairDisplayName(pair),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        // Statistiche
                        Row(
                          children: [
                            _buildStatChip('P', item['points'].toString()),
                            const SizedBox(width: 8),
                            _buildStatChip('V', item['wins'].toString()),
                            const SizedBox(width: 8),
                            _buildStatChip(
                              'S',
                              '${item['sets_won']}-${item['sets_lost']}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKnockoutTab() {
    if (_tournament?['phase'] == 'registration' ||
        _tournament?['phase'] == 'group') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'La fase a eliminazione diretta\ninizia dopo i gironi',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    final quarters = _knockoutMatches
        .where((m) => m['round'] == 'quarters')
        .toList();
    final semis = _knockoutMatches.where((m) => m['round'] == 'semis').toList();
    final finalMatch = _knockoutMatches
        .where((m) => m['round'] == 'final')
        .toList();

    return RefreshIndicator(
      onRefresh: _loadTournamentData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (quarters.isNotEmpty) ...[
            _buildRoundHeader('Quarti di Finale'),
            ...quarters.map((match) => _buildMatchCard(match)).toList(),
            const SizedBox(height: 20),
          ],
          if (semis.isNotEmpty) ...[
            _buildRoundHeader('Semifinali'),
            ...semis.map((match) => _buildMatchCard(match)).toList(),
            const SizedBox(height: 20),
          ],
          if (finalMatch.isNotEmpty) ...[
            _buildRoundHeader('Finale'),
            ...finalMatch.map((match) => _buildMatchCard(match)).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildRoundHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: Color(0xFF00E676)),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match) {
    final pair1 = match['pair1'];
    final pair2 = match['pair2'];
    final winnerId = match['winner_id'];
    final isCompleted = winnerId != null;

    return GestureDetector(
      onTap: () {
        if (!isCompleted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DoublesMatchResultPage(
                match: match,
                onResultSubmitted: _loadTournamentData,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: isCompleted
              ? null
              : Border.all(color: const Color(0xFF00E676), width: 2),
        ),
        child: Column(
          children: [
            _buildMatchPairRow(pair1, match, true),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'VS',
                style: GoogleFonts.poppins(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildMatchPairRow(pair2, match, false),
            if (!isCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Tap per inserire risultato',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF00E676),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchPairRow(
    Map<String, dynamic> pair,
    Map<String, dynamic> match,
    bool isPair1,
  ) {
    final isWinner = match['winner_id'] == pair['id'];
    final score1 = isPair1 ? match['pair1_set1'] : match['pair2_set1'];
    final score2 = isPair1 ? match['pair1_set2'] : match['pair2_set2'];
    final score3 = isPair1 ? match['pair1_set3'] : match['pair2_set3'];

    return Row(
      children: [
        Expanded(
          child: Text(
            _getPairDisplayName(pair),
            style: GoogleFonts.poppins(
              color: isWinner ? const Color(0xFF00E676) : Colors.white,
              fontSize: 15,
              fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        if (score1 != null)
          Row(
            children: [
              Text(
                score1.toString(),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (score2 != null) ...[
                const SizedBox(width: 8),
                Text(
                  score2.toString(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              if (score3 != null) ...[
                const SizedBox(width: 8),
                Text(
                  score3.toString(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        if (isWinner)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.emoji_events, color: Color(0xFF00E676), size: 20),
          ),
      ],
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
