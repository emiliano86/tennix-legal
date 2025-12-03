import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tennis_score_input.dart';

class MatchScoreDialog extends StatefulWidget {
  final Map<String, dynamic> match;
  final Function onScoreUpdated;

  const MatchScoreDialog({
    Key? key,
    required this.match,
    required this.onScoreUpdated,
  }) : super(key: key);

  @override
  State<MatchScoreDialog> createState() => _MatchScoreDialogState();
}

class _MatchScoreDialogState extends State<MatchScoreDialog> {
  String _matchFormat = 'oneSet'; // oneSet, twoSets, longSet
  List<TextEditingController> player1Controllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  List<TextEditingController> player2Controllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool isLoading = false;
  bool isValidScore = true;

  @override
  void initState() {
    super.initState();
    // Se ci sono punteggi esistenti, parsificarli
    if (widget.match['player1_score'] != null) {
      final scores = widget.match['player1_score'].toString().split(', ');
      if (scores.length == 2) {
        _matchFormat = 'twoSets';
        final set1 = scores[0].split('-');
        final set2 = scores[1].split('-');
        player1Controllers[0].text = set1[0];
        player2Controllers[0].text = set1[1];
        player1Controllers[1].text = set2[0];
        player2Controllers[1].text = set2[1];
      } else {
        final set = scores[0].split('-');
        player1Controllers[0].text = set[0];
        player2Controllers[0].text = set[1];
      }
    }
  }

  @override
  void dispose() {
    for (var controller in [...player1Controllers, ...player2Controllers]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _validateScores() {
    try {
      for (int i = 0; i < (_matchFormat == 'twoSets' ? 2 : 1); i++) {
        final p1Score = int.parse(player1Controllers[i].text);
        final p2Score = int.parse(player2Controllers[i].text);

        // Verifica set standard (6 game)
        if (_matchFormat != 'longSet') {
          if (!((p1Score == 6 && p2Score < 5) ||
              (p2Score == 6 && p1Score < 5) ||
              (p1Score == 7 && p2Score == 5) ||
              (p2Score == 7 && p1Score == 5))) {
            return false;
          }
        } else {
          // Verifica set lungo (9 game)
          if (!((p1Score == 9 && p2Score <= 7) ||
              (p2Score == 9 && p1Score <= 7))) {
            return false;
          }
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _saveScore() async {
    if (!_validateScores()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Punteggio non valido per il formato selezionato'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Crea le stringhe dei punteggi separate per ogni giocatore
      final player1Score = _matchFormat == 'twoSets'
          ? '${player1Controllers[0].text}, ${player1Controllers[1].text}'
          : player1Controllers[0].text;

      final player2Score = _matchFormat == 'twoSets'
          ? '${player2Controllers[0].text}, ${player2Controllers[1].text}'
          : player2Controllers[0].text;

      // Determina il vincitore
      String? winnerId;
      if (_matchFormat == 'twoSets') {
        // Conta i set vinti
        int p1Sets = 0;
        for (int i = 0; i < 2; i++) {
          final p1Score = int.parse(player1Controllers[i].text);
          final p2Score = int.parse(player2Controllers[i].text);
          if (p1Score > p2Score) p1Sets++;
        }
        winnerId = p1Sets > 0
            ? widget.match['from_player_id']
            : widget.match['to_player_id'];
      } else {
        // Per set singolo o lungo
        final p1Score = int.parse(player1Controllers[0].text);
        final p2Score = int.parse(player2Controllers[0].text);
        winnerId = p1Score > p2Score
            ? widget.match['from_player_id']
            : widget.match['to_player_id'];
      }

      // Aggiorna il match
      await Supabase.instance.client
          .from('friendly_matches')
          .update({
            'player1_score': player1Score,
            'player2_score': player2Score,
            'winner_id': winnerId,
            'status': 'completed',
          })
          .eq('id', widget.match['id']);

      // Aggiunge 50 punti al vincitore e 20 punti al perdente
      final loserId = winnerId == widget.match['from_player_id']
          ? widget.match['to_player_id']
          : widget.match['from_player_id'];

      await _updatePlayerPoints(winnerId!, 50); // Vincitore: 50 punti
      await _updatePlayerPoints(loserId!, 20); // Perdente: 20 punti

      if (!mounted) return;
      Navigator.pop(context);
      widget.onScoreUpdated();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Punteggio salvato con successo! 🎾'),
          backgroundColor: Color(0xFF00E676),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _updatePlayerPoints(String playerId, int points) async {
    // Aggiorna leaderboard
    final currentPoints = await Supabase.instance.client
        .from('leaderboard')
        .select('points')
        .eq('player_id', playerId)
        .single();

    final newPoints = (currentPoints['points'] ?? 0) + points;

    await Supabase.instance.client.from('leaderboard').upsert({
      'player_id': playerId,
      'points': newPoints,
    });

    // Aggiorna anche la tabella players
    await Supabase.instance.client
        .from('players')
        .update({'points': newPoints})
        .eq('id', playerId);
  }

  Widget _buildScoreInput(
    int setIndex,
    String player1Name,
    String player2Name,
  ) {
    return RepaintBoundary(
      child: Column(
        children: [
          Text(
            setIndex == 0 ? 'Primo Set' : 'Secondo Set',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TennisScoreInputField(
                  controller: player1Controllers[setIndex],
                  playerName: player1Name,
                  onChanged: (_) =>
                      setState(() => isValidScore = _validateScores()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'VS',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF00E676),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: TennisScoreInputField(
                  controller: player2Controllers[setIndex],
                  playerName: player2Name,
                  onChanged: (_) =>
                      setState(() => isValidScore = _validateScores()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player1Name = widget.match['from_player']?['name'] ?? 'Giocatore 1';
    final player2Name = widget.match['to_player']?['name'] ?? 'Giocatore 2';

    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: RepaintBoundary(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Inserisci punteggio',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                // Formato partita
                DropdownButtonFormField<String>(
                  value: _matchFormat,
                  dropdownColor: const Color(0xFF2E2E2E),
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Formato partita',
                    labelStyle: GoogleFonts.poppins(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: const Color(0xFF00E676).withOpacity(0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: const Color(0xFF00E676).withOpacity(0.2),
                      ),
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'oneSet',
                      child: Text(
                        'Un set (6 game)',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'twoSets',
                      child: Text(
                        'Due set (6 game)',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'longSet',
                      child: Text(
                        'Set lungo (9 game)',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _matchFormat = value!;
                      // Reset dei punteggi quando cambia il formato
                      for (var controller in [
                        ...player1Controllers,
                        ...player2Controllers,
                      ]) {
                        controller.clear();
                      }
                    });
                  },
                ),
                const SizedBox(height: 24),
                // Primo set
                _buildScoreInput(0, player1Name, player2Name),
                // Secondo set (solo per formato due set)
                if (_matchFormat == 'twoSets') ...[
                  const SizedBox(height: 24),
                  _buildScoreInput(1, player1Name, player2Name),
                ],
                if (!isValidScore) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Punteggio non valido per il formato selezionato',
                    style: GoogleFonts.poppins(color: Colors.red, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => Navigator.pop(context),
                      child: Text(
                        'Annulla',
                        style: GoogleFonts.poppins(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: isLoading ? null : _saveScore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.black,
                                ),
                              ),
                            )
                          : Text(
                              'Salva',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
