import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

class TournamentBracketPage extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;
  final VoidCallback? onResultSaved;

  const TournamentBracketPage({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    this.onResultSaved,
  });

  @override
  State<TournamentBracketPage> createState() => _TournamentBracketPageState();
}

class _TournamentBracketPageState extends State<TournamentBracketPage>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> quarterFinals = [];
  List<Map<String, dynamic>> semiFinals = [];
  Map<String, dynamic>? final_;
  Map<String, dynamic>? champion;
  bool loading = true;
  late AnimationController _confettiController;
  late AnimationController _trophyController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _trophyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _loadBracket();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _trophyController.dispose();
    super.dispose();
  }

  Future<void> _showMatchResultDialog(Map<String, dynamic> match) async {
    final player1 = match['player1'];
    final player2 = match['player2'];

    final score1Controller = TextEditingController();
    final score2Controller = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: Text(
          'Inserisci Risultato',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Player 1
            Row(
              children: [
                Expanded(
                  child: Text(
                    player1['name'] ?? 'Player 1',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: score1Controller,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: GoogleFonts.poppins(color: Colors.white30),
                      filled: true,
                      fillColor: const Color(0xFF1A1A2E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Player 2
            Row(
              children: [
                Expanded(
                  child: Text(
                    player2['name'] ?? 'Player 2',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: score2Controller,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: GoogleFonts.poppins(color: Colors.white30),
                      filled: true,
                      fillColor: const Color(0xFF1A1A2E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annulla',
              style: GoogleFonts.poppins(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final score1 = int.tryParse(score1Controller.text);
              final score2 = int.tryParse(score2Controller.text);

              if (score1 == null || score2 == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Inserisci punteggi validi'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (score1 == score2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Non può esserci pareggio'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context, {'score1': score1, 'score2': score2});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
            ),
            child: Text(
              'Salva',
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      await _saveMatchResult(
        match['id'].toString(),
        result['score1'],
        result['score2'],
        match,
      );
    }
  }

  Future<void> _saveMatchResult(
    String matchId,
    int score1,
    int score2,
    Map<String, dynamic> match,
  ) async {
    try {
      debugPrint('=== Salvataggio risultato ===');
      debugPrint('Match: $match');
      debugPrint('Score: $score1 - $score2');

      final winnerId = score1 > score2
          ? match['player1_id']
          : match['player2_id'];

      debugPrint('Winner ID: $winnerId');

      // Usa lo stesso approccio della fase a gironi - usa direttamente match['id']
      final response = await supabase
          .from('tournament_matches')
          .update({
            'player1_score': score1,
            'player2_score': score2,
            'winner_id': winnerId,
            'status': 'completed',
          })
          .eq('id', match['id'])
          .select();

      debugPrint('Update response: $response');

      if (response.isEmpty) {
        throw Exception('Nessuna riga aggiornata. Problema RLS o ID errato.');
      }

      debugPrint('✅ Risultato salvato! Aspetto 500ms per i trigger SQL...');

      // Aspetta un attimo per dare tempo ai trigger SQL di eseguire
      await Future.delayed(const Duration(milliseconds: 500));

      // Ricarica il tabellone
      if (mounted) {
        setState(() {
          loading = true;
        });
      }

      await _loadBracket();

      debugPrint('🔄 Tabellone ricaricato dopo trigger');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Risultato salvato! Verifica semifinale...'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Notifica la pagina padre per aggiornare classifica e altre partite
      widget.onResultSaved?.call();
    } catch (e) {
      debugPrint('Errore salvataggio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadBracket() async {
    try {
      setState(() => loading = true);

      debugPrint('=== Caricamento tabellone ===');
      debugPrint('Tournament ID: ${widget.tournamentId}');

      // Carica tutte le partite knockout
      final matches = await supabase
          .from('tournament_matches')
          .select('''
            id,
            player1_id,
            player2_id,
            player1_score,
            player2_score,
            winner_id,
            status,
            phase,
            round
          ''')
          .eq('tournament_id', widget.tournamentId)
          .eq('phase', 'knockout')
          .order('round', ascending: true);

      debugPrint('Partite knockout trovate: ${matches.length}');
      for (var match in matches) {
        debugPrint('  Round: ${match['round']}, Status: ${match['status']}');
      }

      // Carica i dati dei giocatori per ogni partita
      for (var match in matches) {
        if (match['player1_id'] != null) {
          final player1 = await supabase
              .from('players')
              .select('id, name, avatar_url, level')
              .eq('id', match['player1_id'])
              .single();
          match['player1'] = player1;
        }

        if (match['player2_id'] != null) {
          final player2 = await supabase
              .from('players')
              .select('id, name, avatar_url, level')
              .eq('id', match['player2_id'])
              .single();
          match['player2'] = player2;
        }
      }

      // Separa per round
      quarterFinals = matches
          .where((m) => m['round'] == 'quarter_final')
          .cast<Map<String, dynamic>>()
          .toList();

      debugPrint('Quarti di finale: ${quarterFinals.length}');

      semiFinals = matches
          .where((m) => m['round'] == 'semi_final')
          .cast<Map<String, dynamic>>()
          .toList();

      debugPrint('Semifinali: ${semiFinals.length}');

      final finals = matches.where((m) => m['round'] == 'final').toList();
      debugPrint('Finale: ${finals.length}');

      if (finals.isNotEmpty) {
        final_ = finals.first;

        // Se la finale è completata, identifica il campione
        if (final_!['status'] == 'completed' && final_!['winner_id'] != null) {
          final winnerId = final_!['winner_id'];
          if (winnerId == final_!['player1_id']) {
            champion = final_!['player1'];
          } else {
            champion = final_!['player2'];
          }
          // Avvia l'animazione quando il campione viene caricato
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _confettiController.forward();
              _trophyController.repeat(reverse: true);
            }
          });
        }
      }

      setState(() => loading = false);
    } catch (e) {
      debugPrint('Errore caricamento tabellone: $e');
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          widget.tournamentName,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Titolo
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Color(0xFFFFD700),
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'TABELLONE',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tabellone a piramide
                  if (quarterFinals.isEmpty &&
                      semiFinals.isEmpty &&
                      final_ == null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Tabellone non ancora generato',
                          style: GoogleFonts.poppins(
                            color: Colors.white60,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                  else
                    _buildBracketPyramid(),
                ],
              ),
            ),
    );
  }

  Widget _buildBracketPyramid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // Campione (se esiste)
            if (champion != null) ...[
              _buildChampionSection(),
              const SizedBox(height: 32),
            ],

            // Layout orizzontale: Quarti | Semifinali | Finale | Semifinali | Quarti
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // QUARTI SINISTRA (match 1 e 2)
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildRoundLabel('QUARTI'),
                      const SizedBox(height: 16),
                      if (quarterFinals.length > 0)
                        _buildMatchCard(quarterFinals[0], isLeft: true),
                      const SizedBox(height: 40),
                      if (quarterFinals.length > 1)
                        _buildMatchCard(quarterFinals[1], isLeft: true),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // SEMIFINALE SINISTRA
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildRoundLabel('SEMI'),
                      const SizedBox(height: 90),
                      if (semiFinals.isNotEmpty)
                        _buildMatchCard(semiFinals[0], isLeft: true),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // FINALE (centro)
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildRoundLabel('FINALE', isCenter: true),
                      const SizedBox(height: 164),
                      if (final_ != null)
                        _buildMatchCard(final_!, isCenter: true),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // SEMIFINALE DESTRA
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildRoundLabel('SEMI'),
                      const SizedBox(height: 90),
                      if (semiFinals.length > 1)
                        _buildMatchCard(semiFinals[1], isRight: true),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // QUARTI DESTRA (match 3 e 4)
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildRoundLabel('QUARTI'),
                      const SizedBox(height: 16),
                      if (quarterFinals.length > 2)
                        _buildMatchCard(quarterFinals[2], isRight: true),
                      const SizedBox(height: 40),
                      if (quarterFinals.length > 3)
                        _buildMatchCard(quarterFinals[3], isRight: true),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildChampionSection() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Fuochi d'artificio (coriandoli che cadono)
        ...List.generate(30, (index) {
          return AnimatedBuilder(
            animation: _confettiController,
            builder: (context, child) {
              final progress = _confettiController.value;
              final distance = progress * 200;
              final x = distance * (index % 2 == 0 ? 1 : -1) * (index / 15);
              final y = progress * 300 + (index * 10);
              final opacity = 1.0 - progress;

              return Positioned(
                left: MediaQuery.of(context).size.width / 2 + x,
                top: y,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: [
                        Colors.yellow,
                        Colors.orange,
                        const Color(0xFFFFD700),
                        Colors.red,
                        Colors.blue,
                      ][index % 5],
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          );
        }),

        // Container del campione
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFFD700).withOpacity(0.3),
                const Color(0xFFFFA500).withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFD700), width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              // Coppa animata più grande
              AnimatedBuilder(
                animation: _trophyController,
                builder: (context, child) {
                  final scale = 1.0 + (_trophyController.value * 0.1);
                  return Transform.scale(scale: scale, child: child);
                },
                child: const Icon(
                  Icons.emoji_events,
                  color: Color(0xFFFFD700),
                  size: 80,
                  shadows: [Shadow(color: Color(0xFFFFD700), blurRadius: 20)],
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stars, color: Color(0xFFFFD700), size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'CAMPIONE',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFFD700),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.stars, color: Color(0xFFFFD700), size: 24),
                ],
              ),
              const SizedBox(height: 20),

              // Avatar del campione
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFD700), width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.5),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage:
                      champion!['avatar_url'] != null &&
                          champion!['avatar_url'].toString().isNotEmpty
                      ? NetworkImage(champion!['avatar_url'])
                      : null,
                  backgroundColor: const Color(0xFF16213E),
                  child:
                      champion!['avatar_url'] == null ||
                          champion!['avatar_url'].toString().isEmpty
                      ? Text(
                          (champion!['name'] ?? 'C')[0].toUpperCase(),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              // Nome del campione
              Text(
                champion!['name'] ?? 'Campione',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Livello
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.military_tech,
                    color: Color(0xFFFFD700),
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Livello ${champion!['level'] ?? 1}',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFFD700),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoundLabel(String label, {bool isCenter = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isCenter
            ? const Color(0xFFFFD700).withOpacity(0.2)
            : const Color(0xFF00E676).withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCenter ? const Color(0xFFFFD700) : const Color(0xFF00E676),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: isCenter ? const Color(0xFFFFD700) : const Color(0xFF00E676),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMatchCard(
    Map<String, dynamic> match, {
    bool isLeft = false,
    bool isRight = false,
    bool isCenter = false,
  }) {
    final player1 = match['player1'];
    final player2 = match['player2'];
    final status = match['status'];
    final winnerId = match['winner_id'];

    final player1Won =
        winnerId != null && player1 != null && winnerId == player1['id'];
    final player2Won =
        winnerId != null && player2 != null && winnerId == player2['id'];

    final score1 = match['player1_score'] is int
        ? match['player1_score']
        : (match['player1_score'] != null
              ? int.tryParse(match['player1_score'].toString())
              : null);

    final score2 = match['player2_score'] is int
        ? match['player2_score']
        : (match['player2_score'] != null
              ? int.tryParse(match['player2_score'].toString())
              : null);

    // Controlla se l'utente corrente è uno dei due giocatori
    final user = supabase.auth.currentUser;
    final isPlayer1 =
        user != null && player1 != null && user.id == player1['id'];
    final isPlayer2 =
        user != null && player2 != null && user.id == player2['id'];
    final canUpdateResult = isPlayer1 || isPlayer2;

    return GestureDetector(
      onTap: status == 'scheduled' && canUpdateResult
          ? () => _showMatchResultDialog(match)
          : null,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCenter
                ? const Color(0xFFFFD700).withOpacity(0.5)
                : const Color(0xFF00E676).withOpacity(0.3),
            width: status == 'completed' ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (isCenter ? const Color(0xFFFFD700) : const Color(0xFF00E676))
                      .withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Player 1 - Avatar e Nome
            _buildPlayerInfo(player1, player1Won),

            const SizedBox(height: 3),

            // Risultato al centro
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Score Player 1
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: player1Won
                        ? const Color(0xFF00E676)
                        : Colors.white12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    score1?.toString() ?? '-',
                    style: GoogleFonts.poppins(
                      color: player1Won ? Colors.black : Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(width: 3),

                // Separatore
                Text(
                  ':',
                  style: GoogleFonts.poppins(
                    color: Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(width: 3),

                // Score Player 2
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: player2Won
                        ? const Color(0xFF00E676)
                        : Colors.white12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    score2?.toString() ?? '-',
                    style: GoogleFonts.poppins(
                      color: player2Won ? Colors.black : Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 3),

            // Player 2 - Avatar e Nome
            _buildPlayerInfo(player2, player2Won),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerInfo(Map<String, dynamic>? player, bool isWinner) {
    // Se il giocatore è null, mostra "In attesa..."
    if (player == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: const Color(0xFF16213E),
            child: Icon(Icons.hourglass_empty, color: Colors.white38, size: 12),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: 50,
            child: Text(
              'In attesa...',
              style: GoogleFonts.poppins(
                color: Colors.white38,
                fontSize: 7,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 52),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
          color: isWinner
              ? const Color(0xFF00E676).withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar
            CircleAvatar(
              radius: 10,
              backgroundImage:
                  player['avatar_url'] != null &&
                      player['avatar_url'].toString().isNotEmpty
                  ? NetworkImage(player['avatar_url'])
                  : null,
              backgroundColor: const Color(0xFF16213E),
              child:
                  player['avatar_url'] == null ||
                      player['avatar_url'].toString().isEmpty
                  ? Text(
                      (player['name'] ?? 'P')[0].toUpperCase(),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 2),

            // Nome sotto l'avatar (senza icona per risparmiare spazio)
            SizedBox(
              width: 48, // Larghezza massima per il nome
              child: Text(
                player['name'] ?? 'Giocatore',
                style: GoogleFonts.poppins(
                  color: isWinner ? const Color(0xFF00E676) : Colors.white,
                  fontSize: 6.5,
                  fontWeight: isWinner ? FontWeight.bold : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
