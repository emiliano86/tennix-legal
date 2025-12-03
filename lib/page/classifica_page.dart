import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _players = [];
  List<Map<String, dynamic>> _myTournaments = [];
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not found');

      // Carica la classifica generale
      final rankingsResponse = await supabase
          .from('players')
          .select()
          .order('points', ascending: false);

      // Carica i tornei dell'utente con le classifiche
      debugPrint('Caricamento tornei per utente: ${user.id}');

      // Prima otteniamo gli ID dei tornei dell'utente
      final userTournamentsResponse = await supabase
          .from('tournaments_user')
          .select('tournament_id')
          .eq('user_id', user.id)
          .eq('active', true);

      debugPrint('Relazioni tornei trovate: ${userTournamentsResponse.length}');

      // Poi otteniamo i dettagli dei tornei
      final tournamentIds = userTournamentsResponse
          .map((t) => t['tournament_id'].toString())
          .toList();

      debugPrint('ID dei tornei: $tournamentIds');

      final tournamentsResponse = tournamentIds.isNotEmpty
          ? await supabase
                .from('tournaments')
                .select('id, name, start_date, image_url, status')
                .inFilter('id', tournamentIds)
                .not('status', 'in', ['completed', 'archived'])
          : [];

      debugPrint('Tornei trovati: ${tournamentsResponse.length}');
      debugPrint('Dati tornei: $tournamentsResponse');
      debugPrint(
        'Dettagli primo torneo: ${tournamentsResponse.isNotEmpty ? tournamentsResponse.first : 'Nessun torneo'}',
      );

      if (mounted) {
        setState(() {
          _players = List<Map<String, dynamic>>.from(rankingsResponse);
          _myTournaments = List<Map<String, dynamic>>.from(tournamentsResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Errore nel caricamento dei dati: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            'Classifiche',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            onTap: (index) => setState(() => _selectedTab = index),
            indicatorColor: const Color(0xFF00E676),
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            labelColor: const Color(0xFF00E676),
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'Classifica Generale'),
              Tab(text: 'I Miei Tornei'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E676)),
              )
            : TabBarView(
                children: [_buildGeneralRanking(), _buildTournamentRankings()],
              ),
      ),
    );
  }

  Widget _buildGeneralRanking() {
    if (_players.isEmpty) {
      return Center(
        child: Text(
          'Nessun giocatore in classifica',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _players.length,
      itemBuilder: (context, index) {
        final player = _players[index];
        final isCurrentUser = player['id'] == supabase.auth.currentUser?.id;
        final isTopThree = index < 3;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isCurrentUser ? const Color(0xFF1E1E1E) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCurrentUser ? const Color(0xFF00E676) : Colors.white24,
              width: isCurrentUser ? 2 : 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: isTopThree
                  ? _getTopThreeColor(index)
                  : Colors.white12,
              child: isTopThree
                  ? Icon(_getTopThreeIcon(index), color: Colors.white, size: 20)
                  : Text(
                      '${index + 1}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            title: Row(
              children: [
                if (player['avatar_url'] != null)
                  Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: NetworkImage(player['avatar_url']),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player['name'] ?? 'Giocatore',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (player['city'] != null)
                        Text(
                          player['city'],
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${player['points']} pts',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF00E676),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTournamentRankings() {
    if (_myTournaments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 64,
                color: Colors.white.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Non sei iscritto a nessun torneo',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myTournaments.length,
      itemBuilder: (context, index) {
        final tournament = _myTournaments[index];
        final tournamentData = tournament;
        debugPrint('Dati torneo corrente: $tournamentData');
        // Per ora, usiamo un ranking fittizio finché non implementiamo la tabella delle classifiche
        final ranking = null;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header del torneo
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    if (tournamentData['image_url'] != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                        ),
                        child: Image.network(
                          tournamentData['image_url'],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tournamentData['name'] ?? 'Torneo',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tournamentData['date'] != null
                                  ? DateTime.parse(tournamentData['date'])
                                        .toLocal()
                                        .toString()
                                        .split(' ')[0]
                                        .split('-')
                                        .reversed
                                        .join('/')
                                  : 'Data da definire',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Posizione e punti nel torneo
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Posizione',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ranking != null
                              ? '${ranking['position']}° posto'
                              : 'In corso',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (ranking != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '+${ranking['points']} pts',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF00E676),
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getTopThreeColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber; // Oro
      case 1:
        return Colors.grey.shade300; // Argento
      case 2:
        return Colors.brown.shade300; // Bronzo
      default:
        return Colors.white12;
    }
  }

  IconData _getTopThreeIcon(int index) {
    switch (index) {
      case 0:
        return Icons.emoji_events;
      case 1:
        return Icons.workspace_premium;
      case 2:
        return Icons.military_tech;
      default:
        return Icons.emoji_events;
    }
  }
}
