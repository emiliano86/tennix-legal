import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tournament_bracket_page.dart';

class TournamentGroupsPage extends StatefulWidget {
  final Map<String, dynamic> tournament;
  final bool isOrganizer;

  const TournamentGroupsPage({
    super.key,
    required this.tournament,
    this.isOrganizer = false,
  });

  @override
  State<TournamentGroupsPage> createState() => TournamentGroupsPageState();
}

class TournamentGroupsPageState extends State<TournamentGroupsPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _matches = [];
  bool _isKnockoutPhase = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('Caricamento gironi per torneo: ${widget.tournament['id']}');

      // Carica i gironi con i membri
      final groupsResponse = await supabase
          .from('tournament_groups')
          .select('*')
          .eq('tournament_id', widget.tournament['id']);

      debugPrint('Gironi trovati: ${groupsResponse.length}');

      final List<Map<String, dynamic>> groupsWithPlayers = [];

      for (final group in groupsResponse) {
        debugPrint('Caricamento membri per girone: ${group['id']}');

        // Carica i membri di ogni girone con i dati del giocatore
        final membersResponse = await supabase
            .from('tournament_group_members')
            .select('*')
            .eq('group_id', group['id']);

        // Ordina i membri per punti manualmente
        membersResponse.sort(
          (a, b) =>
              (b['points'] as int? ?? 0).compareTo(a['points'] as int? ?? 0),
        );

        // Carica i dati dei giocatori per ogni membro
        final List<Map<String, dynamic>> membersWithPlayers = [];
        for (final member in membersResponse) {
          try {
            final playerData = await supabase
                .from('players')
                .select('id, name, avatar_url, level')
                .eq('id', member['player_id'])
                .single();

            membersWithPlayers.add({...member, 'players': playerData});
          } catch (e) {
            debugPrint(
              'Errore caricamento giocatore ${member['player_id']}: $e',
            );
          }
        }

        groupsWithPlayers.add({...group, 'group_players': membersWithPlayers});
      }

      debugPrint('Caricamento match...');

      // Carica le partite con il campo round
      final List<Map<String, dynamic>> matchesWithPlayers = [];
      try {
        final matchesResponse = await supabase
            .from('tournament_matches')
            .select('*, round')
            .eq('tournament_id', widget.tournament['id']);

        debugPrint('Match trovati: ${matchesResponse.length}');
        debugPrint(
          'Match knockout: ${matchesResponse.where((m) => m['phase'] == 'knockout').length}',
        );

        // Debug: mostra i dettagli dei match knockout
        final knockoutMatches = matchesResponse
            .where((m) => m['phase'] == 'knockout')
            .toList();
        for (final km in knockoutMatches) {
          debugPrint(
            'Knockout match: phase=${km['phase']}, round=${km['round']}, id=${km['id']}',
          );
        }

        // Carica i dati dei giocatori per ogni match
        for (final match in matchesResponse) {
          try {
            final player1 = await supabase
                .from('players')
                .select('id, name, avatar_url')
                .eq('id', match['player1_id'])
                .single();

            final player2 = await supabase
                .from('players')
                .select('id, name, avatar_url')
                .eq('id', match['player2_id'])
                .single();

            // Carica il vincitore solo se esiste e il match è completato
            Map<String, dynamic>? winner;
            if (match['winner_id'] != null && match['status'] == 'completed') {
              try {
                winner = await supabase
                    .from('players')
                    .select('id, name, avatar_url')
                    .eq('id', match['winner_id'])
                    .single();
              } catch (e) {
                debugPrint('Errore caricamento vincitore: $e');
                winner = null;
              }
            }

            matchesWithPlayers.add({
              ...match,
              'player1': player1,
              'player2': player2,
              'winner': winner,
            });
          } catch (e) {
            debugPrint('Errore caricamento dati match: $e');
          }
        }

        debugPrint('Match con dati giocatori: ${matchesWithPlayers.length}');
      } catch (e) {
        debugPrint('❌ Errore durante caricamento match: $e');
      }

      debugPrint('Caricamento fase torneo...');

      // Verifica se siamo nella fase a eliminazione diretta
      try {
        final tournamentResponse = await supabase
            .from('tournaments')
            .select('current_phase, status')
            .eq('id', widget.tournament['id'])
            .single();

        final currentPhase =
            tournamentResponse['current_phase'] ?? 'registration';
        _isKnockoutPhase =
            currentPhase != 'registration' && currentPhase != 'group_stage';

        debugPrint('Fase corrente: $currentPhase');

        if (mounted) {
          setState(() {
            _groups = groupsWithPlayers;
            _matches = matchesWithPlayers;
            _isLoading = false;
          });
        }

        debugPrint('✅ Caricamento completato con successo');
      } catch (e) {
        debugPrint('❌ Errore durante caricamento fase torneo: $e');

        // Anche se c'è un errore, mostra almeno i gironi
        if (mounted) {
          setState(() {
            _groups = groupsWithPlayers;
            _matches = matchesWithPlayers;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Errore nel caricamento dei gironi: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> generateGroups() async {
    try {
      // 🚫 CONTROLLO: Verifica se i gironi sono già stati creati
      final existingGroups = await supabase
          .from('tournament_groups')
          .select('id')
          .eq('tournament_id', widget.tournament['id']);

      if (existingGroups.isNotEmpty) {
        debugPrint(
          '⚠️ STOP: Gironi già esistenti per questo torneo (${existingGroups.length} gironi)',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('I gironi sono già stati creati per questo torneo'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // 1. Ottieni tutti i partecipanti
      final participantsResponse = await supabase
          .from('tournament_user')
          .select('user_id')
          .eq('tournament_id', widget.tournament['id']);

      final participants = List<String>.from(
        participantsResponse.map((p) => p['user_id']),
      );

      // 2. Calcola il numero di gironi necessari (circa 4-5 giocatori per girone)
      final groupSize = 4; // Fisso a 4 giocatori per girone
      final numGroups = (participants.length / groupSize).ceil();

      // 3. Mischia casualmente i partecipanti
      participants.shuffle();

      // 4. Crea i gironi
      for (var i = 0; i < numGroups; i++) {
        final groupName = String.fromCharCode(65 + i); // A, B, C, ...
        final groupResponse = await supabase
            .from('tournament_groups')
            .insert({
              'tournament_id': widget.tournament['id'],
              'name': 'Girone $groupName',
              'created_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        final groupId = groupResponse['id'];
        final start = i * groupSize;
        final end = (i + 1) * groupSize;
        final groupParticipants = participants.sublist(
          start,
          end > participants.length ? participants.length : end,
        );

        // 5. Aggiungi i giocatori al girone
        for (final playerId in groupParticipants) {
          await supabase.from('group_players').insert({
            'group_id': groupId,
            'player_id': playerId,
            'points': 0,
            'matches_played': 0,
            'matches_won': 0,
          });
        }

        // 6. Genera le partite del girone
        for (var j = 0; j < groupParticipants.length; j++) {
          for (var k = j + 1; k < groupParticipants.length; k++) {
            await supabase.from('tournament_matches').insert({
              'tournament_id': widget.tournament['id'],
              'group_id': groupId,
              'player1_id': groupParticipants[j],
              'player2_id': groupParticipants[k],
              'phase': 'group',
              'round': 1,
            });
          }
        }
      }

      // 7. Marca il torneo come avente i gironi creati
      // Il trigger SQL di Supabase creerà automaticamente il prossimo torneo
      await supabase
          .from('tournaments')
          .update({'groups_created': true})
          .eq('id', widget.tournament['id']);
    } catch (e) {
      debugPrint('Errore nella generazione dei gironi: $e');
      rethrow;
    }
  }

  Future<void> _updateMatchResult(Map<String, dynamic> match) async {
    // Mostra il dialog per inserire il risultato
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _MatchResultDialog(
        player1Name: match['player1']['name'],
        player2Name: match['player2']['name'],
      ),
    );

    if (result != null) {
      try {
        final winnerId = result['winner'] == 1
            ? match['player1_id']
            : match['player2_id'];

        // Conta i set vinti da ogni giocatore dal punteggio
        final score = result['score'] as String;
        final sets = score.split(',');
        int player1Sets = 0;
        int player2Sets = 0;

        for (final set in sets) {
          final games = set.trim().split('-');
          if (games.length == 2) {
            final p1Games = int.tryParse(games[0]) ?? 0;
            final p2Games = int.tryParse(games[1]) ?? 0;
            if (p1Games > p2Games) {
              player1Sets++;
            } else {
              player2Sets++;
            }
          }
        }

        // Aggiorna il risultato della partita
        await supabase
            .from('tournament_matches')
            .update({
              'player1_score': score,
              'player2_score': score,
              'player1_sets': player1Sets,
              'player2_sets': player2Sets,
              'winner_id': winnerId,
              'status': 'completed',
              'player_at': DateTime.now().toIso8601String(),
            })
            .eq('id', match['id']);

        // Il trigger aggiornerà automaticamente le statistiche del girone!

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Risultato salvato con successo!'),
              backgroundColor: Color(0xFF00E676),
            ),
          );
        }

        await _loadGroups();
      } catch (e) {
        debugPrint('Errore aggiornamento risultato: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Errore: $e')));
        }
      }
    }
  }

  Future<void> _startKnockoutPhase() async {
    try {
      debugPrint('=== AVVIO FASE KNOCKOUT ===');

      // Verifica che tutti i match dei gironi siano completati
      final groupMatches = _matches
          .where((m) => m['phase'] == 'group')
          .toList();
      final incompleteMatches = groupMatches
          .where((m) => m['status'] != 'completed')
          .length;

      if (incompleteMatches > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ci sono ancora $incompleteMatches partite da completare!',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 1. Prendi i primi 2 giocatori da ogni girone (ordinati per punti)
      final qualifiedPlayers = <Map<String, dynamic>>[];

      for (final group in _groups) {
        final members = List<Map<String, dynamic>>.from(
          group['group_players'] as List,
        );

        // Ordina per punti (decrescente)
        members.sort((a, b) {
          final pointsA = (a['points'] as int?) ?? 0;
          final pointsB = (b['points'] as int?) ?? 0;
          return pointsB.compareTo(pointsA);
        });

        // Prendi i primi 2
        if (members.length >= 2) {
          debugPrint(
            'Girone ${group['group_name']}: ${members[0]['players']?['name']} e ${members[1]['players']?['name']} qualificati',
          );
          qualifiedPlayers.add({
            'player_id': members[0]['player_id'],
            'name': members[0]['players']?['name'] ?? 'Giocatore',
            'points': members[0]['points'],
          });
          qualifiedPlayers.add({
            'player_id': members[1]['player_id'],
            'name': members[1]['players']?['name'] ?? 'Giocatore',
            'points': members[1]['points'],
          });
        }
      }

      if (qualifiedPlayers.length != 8) {
        throw Exception(
          'Dovrebbero esserci 8 giocatori qualificati, ma ce ne sono ${qualifiedPlayers.length}',
        );
      }

      debugPrint('✅ 8 giocatori qualificati per la fase knockout');

      // 2. Mischia i giocatori qualificati per creare accoppiamenti casuali
      qualifiedPlayers.shuffle();

      // 3. Crea i quarti di finale (4 partite)
      debugPrint('📊 Creazione quarti di finale...');
      for (var i = 0; i < qualifiedPlayers.length; i += 2) {
        if (i + 1 < qualifiedPlayers.length) {
          await supabase.from('tournament_matches').insert({
            'tournament_id': widget.tournament['id'],
            'player1_id': qualifiedPlayers[i]['player_id'],
            'player2_id': qualifiedPlayers[i + 1]['player_id'],
            'phase': 'knockout',
            'round': 1, // Quarti di finale
            'status': 'scheduled',
          });

          debugPrint(
            '  Match ${i ~/ 2 + 1}: ${qualifiedPlayers[i]['name']} vs ${qualifiedPlayers[i + 1]['name']}',
          );
        }
      }

      // 4. Aggiorna lo stato del torneo
      await supabase
          .from('tournaments')
          .update({'current_phase': 'knockout', 'status': 'in_progress'})
          .eq('id', widget.tournament['id']);

      debugPrint('✅ Fase knockout avviata con successo!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Fase knockout avviata! 8 giocatori nei quarti di finale.',
            ),
            backgroundColor: Color(0xFF00E676),
          ),
        );
      }

      await _loadGroups();
    } catch (e) {
      debugPrint('❌ Errore nell\'avvio della fase ad eliminazione: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E676)),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            indicatorColor: const Color(0xFF00E676),
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            labelColor: const Color(0xFF00E676),
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'Gironi'),
              Tab(text: 'Partite'),
              Tab(text: 'Tabellone'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildGroupsTab(),
                _buildMatchesTab(),
                _buildBracketTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsTab() {
    if (_groups.isEmpty) {
      return Center(
        child: Text(
          'Nessun girone creato',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        final players = List<Map<String, dynamic>>.from(group['group_players'])
          ..sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  (group['name'] as String?) ??
                      (group['group_name'] as String?) ??
                      'Girone',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: players.length,
                itemBuilder: (context, playerIndex) {
                  final player =
                      players[playerIndex]['players'] as Map<String, dynamic>?;
                  final stats = players[playerIndex];
                  // I primi 2 sono sempre qualificati per il knockout
                  final isQualified = playerIndex < 2;
                  final isTopTwo = playerIndex < 2;

                  // Se mancano i dati del giocatore, mostra un placeholder
                  if (player == null) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Caricamento giocatore...',
                        style: GoogleFonts.poppins(color: Colors.white70),
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      // Evidenzia i primi 2 con sfondo verde chiaro
                      color: isTopTwo
                          ? const Color(0xFF00E676).withOpacity(0.1)
                          : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white24,
                          width: playerIndex < players.length - 1 ? 1 : 0,
                        ),
                        left: isTopTwo
                            ? BorderSide(
                                color: const Color(0xFF00E676),
                                width: 4,
                              )
                            : BorderSide.none,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: player['avatar_url'] != null
                              ? NetworkImage(player['avatar_url'] as String)
                              : null,
                          child: player['avatar_url'] == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    (player['name'] as String?) ?? 'Giocatore',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (isQualified) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.check_circle,
                                      color: const Color(0xFF00E676),
                                      size: 16,
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '${stats['matches_won'] ?? 0}/${stats['matches_played'] ?? 0} partite vinte',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${stats['points'] ?? 0} pts',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF00E676),
                              fontWeight: FontWeight.w600,
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
      },
    );
  }

  Widget _buildMatchesTab() {
    if (_matches.isEmpty) {
      return Center(
        child: Text(
          'Nessuna partita programmata',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
      );
    }

    // Raggruppa le partite per fase
    final groupMatches = _matches.where((m) => m['phase'] == 'group').toList();
    final knockoutMatches = _matches
        .where((m) => m['phase'] == 'knockout')
        .toList();

    debugPrint(
      'UI: Group matches: ${groupMatches.length}, Knockout matches: ${knockoutMatches.length}',
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (groupMatches.isNotEmpty) ...[
          Text(
            'Fase a Gironi',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...groupMatches.map((match) => _buildMatchCard(match)),
          const SizedBox(height: 24),
        ],
        if (knockoutMatches.isNotEmpty) ...[
          Text(
            'Fase ad Eliminazione Diretta',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Quarti di finale
          ...(() {
            final quarterFinals = knockoutMatches
                .where((m) => m['round'] == 'quarter_final')
                .toList();
            if (quarterFinals.isEmpty) return <Widget>[];
            return [
              Text(
                'Quarti di Finale',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF00E676),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...quarterFinals.map((match) => _buildMatchCard(match)),
              const SizedBox(height: 16),
            ];
          })(),

          // Semifinali
          ...(() {
            final semiFinals = knockoutMatches
                .where((m) => m['round'] == 'semi_final')
                .toList();
            if (semiFinals.isEmpty) return <Widget>[];
            return [
              Text(
                'Semifinali',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF00E676),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...semiFinals.map((match) => _buildMatchCard(match)),
              const SizedBox(height: 16),
            ];
          })(),

          // Finale
          ...(() {
            final finals = knockoutMatches
                .where((m) => m['round'] == 'final')
                .toList();
            if (finals.isEmpty) return <Widget>[];
            return [
              Text(
                'Finale',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF00E676),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...finals.map((match) => _buildMatchCard(match)),
            ];
          })(),
        ],

        // Mostra il pulsante solo se:
        // 1. L'utente è organizzatore
        // 2. Non siamo già nella fase knockout
        // 3. Tutte le partite dei gironi sono completate
        if (widget.isOrganizer &&
            !_isKnockoutPhase &&
            groupMatches.isNotEmpty &&
            groupMatches.every((m) => m['status'] == 'completed')) ...[
          const SizedBox(height: 24),

          // Mostra statistiche prima del pulsante
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00E676), width: 2),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.emoji_events,
                  color: const Color(0xFF00E676),
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'Fase Gironi Completata!',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tutte le ${groupMatches.length} partite sono state giocate.\nI primi 2 di ogni girone (8 giocatori) sono pronti per i quarti di finale.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _startKnockoutPhase,
            icon: const Icon(Icons.rocket_launch),
            label: Text(
              'Avvia Quarti di Finale',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],

        // Mostra messaggio se ci sono ancora partite da completare
        if (widget.isOrganizer &&
            !_isKnockoutPhase &&
            groupMatches.isNotEmpty &&
            groupMatches.any((m) => m['status'] != 'completed')) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange, width: 2),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, color: Colors.orange, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fase Gironi in Corso',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${groupMatches.where((m) => m['status'] == 'completed').length}/${groupMatches.length} partite completate',
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
        ],
      ],
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match) {
    final player1 = match['player1'] as Map<String, dynamic>?;
    final player2 = match['player2'] as Map<String, dynamic>?;
    final winner = match['winner'] as Map<String, dynamic>?;
    final isPlayed = match['status'] == 'completed';

    // Estrai i punteggi separati
    final player1Score = match['player1_score']?.toString();
    final player2Score = match['player2_score']?.toString();
    final hasScore = player1Score != null && player2Score != null;

    // Se mancano i dati dei giocatori, non mostrare il match
    if (player1 == null || player2 == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: widget.isOrganizer && !isPlayed
            ? () => _updateMatchResult(match)
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildPlayerInfo(
                      player1,
                      score: player1Score,
                      isWinner: winner?['id'] == player1['id'],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isPlayed
                          ? const Color(0xFF00E676).withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isPlayed && hasScore ? 'VS' : 'Da giocare',
                      style: GoogleFonts.poppins(
                        color: isPlayed
                            ? const Color(0xFF00E676)
                            : Colors.orange,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildPlayerInfo(
                      player2,
                      score: player2Score,
                      isWinner: winner?['id'] == player2['id'],
                      alignment: CrossAxisAlignment.end,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerInfo(
    Map<String, dynamic>? player, {
    String? score,
    bool isWinner = false,
    CrossAxisAlignment alignment = CrossAxisAlignment.start,
  }) {
    // Gestisci il caso in cui player sia null
    final playerName = player?['name'] as String? ?? 'Giocatore';

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          playerName,
          style: GoogleFonts.poppins(
            color: isWinner ? const Color(0xFF00E676) : Colors.white,
            fontWeight: isWinner ? FontWeight.bold : FontWeight.w500,
          ),
          textAlign: alignment == CrossAxisAlignment.end
              ? TextAlign.right
              : TextAlign.left,
        ),
        const SizedBox(height: 4),
        if (score != null)
          Text(
            score,
            style: GoogleFonts.poppins(
              color: isWinner ? const Color(0xFF00E676) : Colors.white70,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        if (isWinner && score != null) const SizedBox(height: 4),
        if (isWinner && score != null)
          Icon(Icons.emoji_events, color: const Color(0xFF00E676), size: 20),
      ],
    );
  }

  Widget _buildBracketTab() {
    return TournamentBracketPage(
      tournamentId: widget.tournament['id'].toString(),
      tournamentName: widget.tournament['name'] ?? 'Torneo',
      onResultSaved: () {
        // Quando viene salvato un risultato nel bracket, ricarica tutto
        _loadGroups();
      },
    );
  }
}

class _MatchResultDialog extends StatefulWidget {
  final String player1Name;
  final String player2Name;

  const _MatchResultDialog({
    required this.player1Name,
    required this.player2Name,
  });

  @override
  State<_MatchResultDialog> createState() => _MatchResultDialogState();
}

class _MatchResultDialogState extends State<_MatchResultDialog> {
  final _formKey = GlobalKey<FormState>();
  final _scoreController = TextEditingController();
  int _winner = 1;

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

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
            // Seleziona vincitore
            Text(
              'Vincitore',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 1,
                  label: Text(widget.player1Name, style: GoogleFonts.poppins()),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text(widget.player2Name, style: GoogleFonts.poppins()),
                ),
              ],
              selected: {_winner},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() => _winner = newSelection.first);
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith<Color>((
                  Set<MaterialState> states,
                ) {
                  if (states.contains(MaterialState.selected)) {
                    return const Color(0xFF00E676);
                  }
                  return Colors.transparent;
                }),
              ),
            ),
            const SizedBox(height: 16),
            // Inserisci punteggio
            TextFormField(
              controller: _scoreController,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Punteggio (es. 6-4,7-5)',
                labelStyle: GoogleFonts.poppins(color: Colors.white70),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF00E676)),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Inserisci il punteggio';
                }
                // Verifica il formato del punteggio
                final sets = value.split(',');
                for (final set in sets) {
                  final games = set.split('-');
                  if (games.length != 2) return 'Formato non valido';
                  if (int.tryParse(games[0]) == null ||
                      int.tryParse(games[1]) == null) {
                    return 'Formato non valido';
                  }
                }
                return null;
              },
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
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(
                context,
              ).pop({'winner': _winner, 'score': _scoreController.text});
            }
          },
          child: Text(
            'Salva',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
