import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class MyMatchesPage extends StatefulWidget {
  const MyMatchesPage({super.key});

  @override
  State<MyMatchesPage> createState() => _MyMatchesPageState();
}

class _MyMatchesPageState extends State<MyMatchesPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _myMatches = [];

  @override
  void initState() {
    super.initState();
    _loadMyMatches();
  }

  Future<void> _loadMyMatches() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      debugPrint('Caricamento partite per utente: ${user.id}');

      // Carica tutte le partite dove l'utente è player1 o player2
      final matchesResponse = await supabase
          .from('tournament_matches')
          .select('*')
          .or('player1_id.eq.${user.id},player2_id.eq.${user.id}');

      debugPrint('Partite trovate: ${matchesResponse.length}');

      // Carica i dati dei giocatori e del torneo per ogni match
      final List<Map<String, dynamic>> matchesWithDetails = [];
      for (final match in matchesResponse) {
        try {
          // Carica dati player1
          final player1 = await supabase
              .from('players')
              .select('id, name, avatar_url, phone')
              .eq('id', match['player1_id'])
              .single();

          // Carica dati player2
          final player2 = await supabase
              .from('players')
              .select('id, name, avatar_url, phone')
              .eq('id', match['player2_id'])
              .single();

          // Carica dati torneo
          final tournament = await supabase
              .from('tournaments')
              .select('id, name, image_url')
              .eq('id', match['tournament_id'])
              .single();

          // Carica dati girone se esiste
          Map<String, dynamic>? groupData;
          if (match['group_id'] != null) {
            groupData = await supabase
                .from('tournament_groups')
                .select('group_name')
                .eq('id', match['group_id'])
                .single();
          }

          matchesWithDetails.add({
            ...match,
            'player1': player1,
            'player2': player2,
            'tournament': tournament,
            'group': groupData,
          });
        } catch (e) {
          debugPrint('Errore caricamento dettagli match: $e');
        }
      }

      // Ordina: prima le partite da giocare, poi quelle completate
      matchesWithDetails.sort((a, b) {
        final statusA = a['status'] ?? 'scheduled';
        final statusB = b['status'] ?? 'scheduled';
        if (statusA == 'completed' && statusB != 'completed') return 1;
        if (statusA != 'completed' && statusB == 'completed') return -1;
        return 0;
      });

      if (mounted) {
        setState(() {
          _myMatches = matchesWithDetails;
          _isLoading = false;
        });
      }

      debugPrint('✅ Caricamento completato: ${_myMatches.length} partite');
    } catch (e) {
      debugPrint('❌ Errore caricamento partite: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _insertMatchResult(Map<String, dynamic> match) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final isPlayer1 = match['player1_id'] == user.id;
    final myName = isPlayer1
        ? match['player1']['name']
        : match['player2']['name'];
    final opponentName = isPlayer1
        ? match['player2']['name']
        : match['player1']['name'];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _MatchResultDialog(myName: myName, opponentName: opponentName),
    );

    if (result != null) {
      try {
        final myScore = result['myScore'] as int;
        final opponentScore = result['opponentScore'] as int;

        // Determina chi è player1 e chi è player2
        final player1Score = isPlayer1 ? myScore : opponentScore;
        final player2Score = isPlayer1 ? opponentScore : myScore;

        // Determina il vincitore basandosi sugli score
        final winnerId = player1Score > player2Score
            ? match['player1_id']
            : match['player2_id'];

        // Aggiorna il match nel database con score separati
        await supabase
            .from('tournament_matches')
            .update({
              'player1_score': player1Score.toString(),
              'player2_score': player2Score.toString(),
              'player1_sets': player1Score,
              'player2_sets': player2Score,
              'winner_id': winnerId,
              'status': 'completed',
              'played_date': DateTime.now().toIso8601String(),
            })
            .eq('id', match['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Risultato salvato con successo!'),
              backgroundColor: Color(0xFF00E676),
            ),
          );
        }

        // Ricarica le partite
        await _loadMyMatches();
      } catch (e) {
        debugPrint('❌ Errore salvataggio risultato: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _callOpponent(Map<String, dynamic> opponent) async {
    final phone = opponent['phone'] as String?;

    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${opponent['name']} non ha un numero di telefono'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Rimuovi spazi e caratteri speciali dal numero
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri telUri = Uri.parse('tel:$cleanPhone');

    try {
      await launchUrl(telUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Telefono: $cleanPhone\nCopia il numero per chiamare',
            ),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Copia',
              textColor: Colors.white,
              onPressed: () {
                // Copia il numero negli appunti
                debugPrint('Numero da copiare: $cleanPhone');
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _openWhatsApp(Map<String, dynamic> opponent) async {
    final phone = opponent['phone'] as String?;

    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${opponent['name']} non ha un numero di telefono'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Rimuovi spazi, trattini e caratteri speciali, ma mantieni il prefisso +
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    final whatsappPhone = cleanPhone.startsWith('+')
        ? cleanPhone.substring(1)
        : cleanPhone;

    // Messaggio predefinito
    final message = Uri.encodeComponent(
      'Ciao ${opponent['name']}, ti contatto per organizzare la nostra partita di tennis!',
    );

    final Uri whatsappUri = Uri.parse(
      'https://wa.me/$whatsappPhone?text=$message',
    );

    try {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('WhatsApp non disponibile\nNumero: $cleanPhone'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Le Mie Partite',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            )
          : _myMatches.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports_tennis, size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  Text(
                    'Nessuna partita programmata',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFF00E676),
              onRefresh: _loadMyMatches,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _myMatches.length,
                itemBuilder: (context, index) {
                  final match = _myMatches[index];
                  return _buildMatchCard(match);
                },
              ),
            ),
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match) {
    final user = supabase.auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final isPlayer1 = match['player1_id'] == user.id;
    final me = isPlayer1 ? match['player1'] : match['player2'];
    final opponent = isPlayer1 ? match['player2'] : match['player1'];
    final isCompleted = match['status'] == 'completed';
    final tournament = match['tournament'];
    final group = match['group'];

    // Estrai il punteggio se la partita è completata
    String? myScore;
    String? opponentScore;
    bool? iWon;

    if (isCompleted) {
      // I punteggi sono salvati separatamente in player1_score e player2_score
      final p1Score = match['player1_score']?.toString();
      final p2Score = match['player2_score']?.toString();

      if (p1Score != null && p2Score != null) {
        myScore = isPlayer1 ? p1Score : p2Score;
        opponentScore = isPlayer1 ? p2Score : p1Score;
        iWon = match['winner_id'] == user.id;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? (iWon == true ? const Color(0xFF00E676) : Colors.red)
              : Colors.orange,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con torneo e girone
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                if (tournament?['image_url'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      tournament['image_url'],
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournament?['name'] ?? 'Torneo',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (group != null)
                        Text(
                          group['group_name'] ?? 'Girone',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusBadge(isCompleted, iWon),
              ],
            ),
          ),

          // Match details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Me
                Expanded(
                  child: _buildPlayerSection(
                    me,
                    myScore,
                    isCompleted && iWon == true,
                  ),
                ),

                // VS o Punteggio
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: isCompleted && myScore != null && opponentScore != null
                      ? Column(
                          children: [
                            Text(
                              '$myScore',
                              style: GoogleFonts.poppins(
                                color: iWon == true
                                    ? const Color(0xFF00E676)
                                    : Colors.red,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'VS',
                              style: GoogleFonts.poppins(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '$opponentScore',
                              style: GoogleFonts.poppins(
                                color: iWon == false
                                    ? const Color(0xFF00E676)
                                    : Colors.red,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'VS',
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),

                // Opponent
                Expanded(
                  child: _buildPlayerSection(
                    opponent,
                    opponentScore,
                    isCompleted && iWon == false,
                  ),
                ),
              ],
            ),
          ),

          // Pulsante per inserire risultato (solo se non completata)
          if (!isCompleted) ...[
            const Divider(color: Colors.white24, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Titolo sezione contatti
                  Text(
                    'Contatta l\'avversario',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Pulsanti per contattare l'avversario
                  Row(
                    children: [
                      // Pulsante Chiama
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E676),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => _callOpponent(opponent),
                          icon: const Icon(Icons.phone, size: 20),
                          label: Text(
                            'Chiama',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Pulsante WhatsApp
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => _openWhatsApp(opponent),
                          icon: const Icon(Icons.chat, size: 20),
                          label: Text(
                            'WhatsApp',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 16),
                  // Pulsante Inserisci Risultato
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 52),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _insertMatchResult(match),
                    icon: const Icon(Icons.emoji_events, size: 22),
                    label: Text(
                      'Inserisci Risultato',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isCompleted, bool? iWon) {
    if (isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: (iWon == true ? const Color(0xFF00E676) : Colors.red)
              .withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              iWon == true ? Icons.emoji_events : Icons.close,
              color: iWon == true ? const Color(0xFF00E676) : Colors.red,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              iWon == true ? 'Vittoria' : 'Sconfitta',
              style: GoogleFonts.poppins(
                color: iWon == true ? const Color(0xFF00E676) : Colors.red,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule, color: Colors.orange, size: 16),
            const SizedBox(width: 4),
            Text(
              'Da giocare',
              style: GoogleFonts.poppins(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildPlayerSection(
    Map<String, dynamic>? player,
    String? score,
    bool isWinner,
  ) {
    return Column(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: isWinner
              ? const Color(0xFF00E676).withOpacity(0.3)
              : Colors.white12,
          backgroundImage: player?['avatar_url'] != null
              ? NetworkImage(player!['avatar_url'] as String)
              : null,
          child: player?['avatar_url'] == null
              ? const Icon(Icons.person, color: Colors.white54, size: 32)
              : null,
        ),
        const SizedBox(height: 8),
        Text(
          (player?['name'] as String?) ?? 'Giocatore',
          style: GoogleFonts.poppins(
            color: isWinner ? const Color(0xFF00E676) : Colors.white,
            fontWeight: isWinner ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _MatchResultDialog extends StatefulWidget {
  final String myName;
  final String opponentName;

  const _MatchResultDialog({required this.myName, required this.opponentName});

  @override
  State<_MatchResultDialog> createState() => _MatchResultDialogState();
}

class _MatchResultDialogState extends State<_MatchResultDialog> {
  final _formKey = GlobalKey<FormState>();
  int _myScore = 9;
  int _opponentScore = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(
        'Inserisci Risultato',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Set lungo fino a 9 punti',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Il mio punteggio
            Text(
              widget.myName,
              style: GoogleFonts.poppins(
                color: const Color(0xFF00E676),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    if (_myScore > 0) setState(() => _myScore--);
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.white,
                  iconSize: 32,
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF00E676),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$_myScore',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (_myScore < 9) setState(() => _myScore++);
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  color: Colors.white,
                  iconSize: 32,
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(color: Colors.white24),
            const SizedBox(height: 24),

            // Punteggio avversario
            Text(
              widget.opponentName,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    if (_opponentScore > 0) setState(() => _opponentScore--);
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.white,
                  iconSize: 32,
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '$_opponentScore',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (_opponentScore < 9) setState(() => _opponentScore++);
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  color: Colors.white,
                  iconSize: 32,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Messaggio di validazione
            if (_myScore == _opponentScore)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Il punteggio non può essere pari',
                        style: GoogleFonts.poppins(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Annulla',
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E676),
            foregroundColor: Colors.black,
            disabledBackgroundColor: Colors.grey,
          ),
          onPressed: _myScore != _opponentScore
              ? () {
                  Navigator.of(
                    context,
                  ).pop({'myScore': _myScore, 'opponentScore': _opponentScore});
                }
              : null,
          child: Text(
            'Salva',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
