import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tennix/page/profil_setup_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tennix/page/tournament_detail_page_new.dart';
import 'package:tennix/page/tounaments_page.dart';
import 'package:tennix/widget/match_score_dialog.dart';
import 'package:tennix/services/notification_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

class TennixHomePage extends StatefulWidget {
  const TennixHomePage({super.key});

  @override
  State<TennixHomePage> createState() => _TennixHomePageState();
}

class _TennixHomePageState extends State<TennixHomePage> {
  /// Salva il token FCM dell'utente su Supabase (da chiamare dopo login o dopo il setup profilo)
  Future<void> saveFcmToken() async {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    final userId = supabase.auth.currentUser?.id;
    if (fcmToken != null && userId != null) {
      await supabase.from('user_tokens').upsert({
        'user_id': userId,
        'fcm_token': fcmToken,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  // Dopo login o dopo il setup profilo, chiama:
  // await saveFcmToken();

  /// Salva una richiesta di gioco su Supabase
  Future<void> sendGameRequest({
    required DateTime matchDate,
    required String matchTime,
    required String location,
    bool isOpenRequest = true,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final response = await supabase.from('friendly_matches').insert({
      'from_player_id': user.id,
      'match_date': matchDate.toIso8601String().split('T')[0],
      'match_time': matchTime,
      'location': location,
      'status': 'pending',
      'is_open_request': isOpenRequest,
    });
    // Qui puoi mostrare un messaggio di conferma o gestire errori
  }

  Future<void> _checkFirstLoginAndProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLoginDone = prefs.getBool('isFirstLoginDone') ?? false;
    final isProfileSetupDone = prefs.getBool('isProfileSetupDone') ?? false;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    if (!isFirstLoginDone) {
      // Mostra login solo la prima volta (qui puoi mettere la tua logica di login se serve)
      await prefs.setBool('isFirstLoginDone', true);
    }
    if (!isProfileSetupDone) {
      // Mostra la pagina di setup profilo solo la prima volta
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const ProfileSetupPage()),
        );
        if (result == true) {
          await prefs.setBool('isProfileSetupDone', true);
        }
      });
    }
  }

  final supabase = Supabase.instance.client;
  Map<String, dynamic>? player;
  List<Map<String, dynamic>> leaderboard = [];
  var tournaments = <Map<String, dynamic>>[];
  var friendlyMatches = <Map<String, dynamic>>[];
  var friendlyRequests = <Map<String, dynamic>>[];
  var openRequests =
      <Map<String, dynamic>>[]; // Richieste aperte da altri giocatori
  bool loading = true;

  RealtimeChannel? playerSub;
  RealtimeChannel? leaderboardSub;
  RealtimeChannel? playersSub;
  RealtimeChannel? tournamentsSub;
  RealtimeChannel? friendlyMatchesSub;

  Future<void> _loadFriendlyMatches() async {
    debugPrint('=== Inizio caricamento partite amichevoli ===');
    final user = supabase.auth.currentUser;
    if (user == null) {
      debugPrint('Nessun utente autenticato');
      return;
    }
    debugPrint('User ID: ${user.id}');
    debugPrint('Timestamp corrente: ${DateTime.now().toIso8601String()}');

    try {
      debugPrint('Caricamento richieste inviate...');
      debugPrint('=== Dettagli query richieste inviate ===');
      debugPrint('User ID: ${user.id}');
      debugPrint(
        'Data minima: ${DateTime.now().toIso8601String().split('T')[0]}',
      );

      // Carica le richieste inviate dall'utente e i match confermati
      final sentRequests = await supabase
          .from('friendly_matches')
          .select('''
            id,
            match_date,
            match_time,
            status,
            location,
            from_player_id,
            to_player_id,
            player1_score,
            player2_score,
            from_player:players!from_player_id(
              id, 
              name, 
              avatar_url, 
              level,
              city,
              phone
            ),
            to_player:players!to_player_id(
              id, 
              name, 
              avatar_url, 
              level,
              city,
              phone
            )
          ''')
          .eq('from_player_id', user.id)
          .or('status.eq.pending,status.eq.confirmed,status.eq.completed')
          .gte('match_date', DateTime.now().toIso8601String().split('T')[0])
          .order('match_date', ascending: true);

      // Log della query eseguita
      debugPrint('Query richieste inviate eseguita');

      debugPrint('Richieste inviate trovate: ${sentRequests.length}');
      debugPrint('Dettagli richieste inviate: $sentRequests');

      debugPrint('Caricamento richieste ricevute...');
      debugPrint('=== Dettagli query richieste ricevute ===');

      // Carica le richieste ricevute e i match confermati dell'utente
      final receivedRequests = await supabase
          .from('friendly_matches')
          .select('''
            id,
            match_date,
            match_time,
            status,
            location,
            from_player_id,
            to_player_id,
            player1_score,
            player2_score,
            from_player:players!from_player_id(
              id, 
              name, 
              avatar_url, 
              level,
              city,
              phone
            ),
            to_player:players!to_player_id(
              id, 
              name, 
              avatar_url, 
              level,
              city,
              phone
            )
          ''')
          .eq('to_player_id', user.id)
          .or('status.eq.pending,status.eq.confirmed,status.eq.completed')
          .gte('match_date', DateTime.now().toIso8601String().split('T')[0])
          .order('match_date', ascending: true);

      debugPrint('Query richieste ricevute eseguita');

      // Log dettagliato delle richieste
      if (receivedRequests.isNotEmpty) {
        debugPrint('Dettagli delle richieste ricevute:');
        for (var request in receivedRequests) {
          debugPrint('ID: ${request['id']}');
          debugPrint('Data: ${request['match_date']}');
          debugPrint('Stato: ${request['status']}');
          debugPrint('Da: ${request['from_player']?['name']}');
        }
      }

      debugPrint('Richieste ricevute trovate: ${receivedRequests.length}');
      debugPrint('Dettagli richieste ricevute: $receivedRequests');

      if (mounted) {
        debugPrint('=== Aggiornamento stato partite ===');
        debugPrint('Richieste inviate da caricare: ${sentRequests.length}');
        debugPrint(
          'Richieste ricevute da caricare: ${receivedRequests.length}',
        );

        // Debug delle partite per stato
        for (var match in sentRequests) {
          debugPrint(
            'Partita inviata - ID: ${match['id']}, Stato: ${match['status']}',
          );
        }
        for (var match in receivedRequests) {
          debugPrint(
            'Partita ricevuta - ID: ${match['id']}, Stato: ${match['status']}',
          );
        }

        // Carica le richieste aperte da altri giocatori
        debugPrint('Caricamento richieste aperte...');
        final openRequestsQuery = await supabase
            .from('friendly_matches')
            .select('''
              id,
              match_date,
              match_time,
              status,
              location,
              from_player_id,
              is_open_request,
              from_player:players!from_player_id(
                id, 
                name, 
                avatar_url, 
                level,
                city,
                phone
              )
            ''')
            .eq('is_open_request', true)
            .eq('status', 'pending')
            .neq('from_player_id', user.id)
            .gte('match_date', DateTime.now().toIso8601String().split('T')[0])
            .order('match_date', ascending: true);

        debugPrint('Richieste aperte trovate: ${openRequestsQuery.length}');

        setState(() {
          // Separa le partite confermate/completate dalle richieste in sospeso
          final confirmedMatches = [
            ...sentRequests.where(
              (r) => r['status'] == 'confirmed' || r['status'] == 'completed',
            ),
            ...receivedRequests.where(
              (r) => r['status'] == 'confirmed' || r['status'] == 'completed',
            ),
          ];

          // Le richieste in sospeso vanno in friendlyRequests
          friendlyRequests = List<Map<String, dynamic>>.from(
            receivedRequests.where((r) => r['status'] == 'pending'),
          );

          // Assegna le richieste aperte
          openRequests = List<Map<String, dynamic>>.from(openRequestsQuery);

          // Le partite confermate/completate vanno in friendlyMatches
          friendlyMatches = confirmedMatches;

          debugPrint('=== Stato aggiornato ===');
          debugPrint(
            'Partite confermate/completate: ${confirmedMatches.length}',
          );
          debugPrint('Richieste in sospeso: ${friendlyRequests.length}');
        });
        debugPrint(
          'Partite caricate in friendlyMatches: ${friendlyMatches.length}',
        );
        debugPrint('Partite trovate: ${friendlyMatches.length}');
        for (var match in friendlyMatches) {
          debugPrint(
            'Partita: ${match['match_date']} - Stato: ${match['status']} - Con: ${match['to_player']['name']}',
          );
        }
        debugPrint('Richieste trovate: ${friendlyRequests.length}');
        for (var request in friendlyRequests) {
          debugPrint(
            'Richiesta: ${request['match_date']} - Da: ${request['from_player']['name']}',
          );
        }
      }
    } catch (e) {
      debugPrint('Errore dettagliato caricamento partite amichevoli: $e');
      debugPrint(
        'Stack trace: ${e is Error ? e.stackTrace : "Non disponibile"}',
      );
    }
  }

  final _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _notificationService.initialize();
    _checkFirstLoginAndProfile();
    _loadData();
    _loadFriendlyMatches();
    _subscribeRealtime();
    saveFcmToken(); // Salva il token FCM all'avvio
  }

  @override
  void dispose() {
    playerSub?.unsubscribe();
    leaderboardSub?.unsubscribe();
    playersSub?.unsubscribe();
    tournamentsSub?.unsubscribe();
    friendlyMatchesSub?.unsubscribe();
    super.dispose();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isFirstLoginDone');
    await prefs.remove('isProfileSetupDone');
    // Qui aggiungi anche la tua logica di logout supabase
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() => loading = true);

    try {
      final user = supabase.auth.currentUser;
      debugPrint('Current user: ${user?.email}');

      if (user == null) {
        debugPrint('Nessun utente autenticato');
        setState(() => loading = false);
        // Redirect to login or handle unauthenticated state
        return;
      }

      debugPrint('User ID: ${user.id}');

      try {
        debugPrint('Iniziando la query del profilo...');

        // Query player
        final playerResponse = await supabase
            .from('players')
            .select('*')
            .eq('id', user.id)
            .single();

        debugPrint('Dati giocatore caricati: $playerResponse');

        // Otteniamo i punti dal record players (campo 'points') se presente
        int resolvedPoints = 0;
        final rawPoints = playerResponse['points'];
        if (rawPoints is int) {
          resolvedPoints = rawPoints;
        } else if (rawPoints is Map) {
          resolvedPoints = rawPoints['points'] ?? 0;
        } else if (rawPoints is List && rawPoints.isNotEmpty) {
          resolvedPoints = rawPoints[0]?['points'] ?? 0;
        }

        playerResponse['points'] = resolvedPoints;
        debugPrint(
          'Punti estratti: ${playerResponse['points']} (resolved from players table)',
        );

        // Carichiamo i dati della classifica: prendiamo i punti dalla tabella `players`
        final playersLeaderboard = await supabase
            .from('players')
            .select('id, name, avatar_url, level, city, points')
            .order('points', ascending: false);

        // Trasformiamo i record dei giocatori nella forma attesa dal UI:
        // { points: <int>, player: { ...playerFields }, player_id: <id> }
        final leaderboardData =
            (playersLeaderboard as List<dynamic>?)
                ?.map<Map<String, dynamic>>(
                  (pl) => {
                    'points': pl['points'] ?? 0,
                    'player': pl,
                    'player_id': pl['id'],
                  },
                )
                .toList() ??
            <Map<String, dynamic>>[]; // Otteniamo i tornei dell'utente
        final registrations = await supabase
            .from('tournaments_user')
            .select('tournament_id, active')
            .eq('user_id', user.id)
            .eq('active', true);

        // Otteniamo i dettagli di tutti i tornei in una singola query
        final tournamentsMap = new Map<String, dynamic>();
        if (registrations.isNotEmpty) {
          final tournamentIds = registrations
              .map((r) => r['tournament_id'])
              .toList();
          final tournamentsData = await supabase
              .from('tournaments')
              .select()
              .inFilter('id', tournamentIds);

          for (final t in tournamentsData) {
            tournamentsMap[t['id'].toString()] = t;
          }
        }

        // Combiniamo i dati
        final combinedTournaments = registrations.map((registration) {
          final tournamentData =
              tournamentsMap[registration['tournament_id'].toString()];
          return {...registration, 'tournaments': tournamentData};
        }).toList();

        if (!mounted) return;

        setState(() {
          player = playerResponse;
          debugPrint('Player impostato nello stato: $player');
          leaderboard = List<Map<String, dynamic>>.from(leaderboardData);
          tournaments = List<Map<String, dynamic>>.from(combinedTournaments);
          loading = false;
        });
      } catch (e) {
        debugPrint('Errore nel recupero del profilo: $e');
        if ((e.toString().contains('Row not found') ||
                e.toString().contains('no rows')) &&
            mounted) {
          // Se il profilo non esiste, reindirizza alla pagina di setup
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const ProfileSetupPage()),
          );
          return;
        }
        // Per altri errori, mostra un messaggio all'utente
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Errore nel caricamento del profilo: ${e.toString()}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => loading = false);
      }
    } catch (e) {
      debugPrint("Errore caricamento dati: $e");
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel caricamento dei dati: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _subscribeRealtime() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // 🤝 Ascolta aggiornamenti sulle partite amichevoli
    friendlyMatchesSub = supabase
        .channel('friendly-matches')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendly_matches',
          callback: (payload) async {
            debugPrint('Cambiamento richiesta partita: ${payload.eventType}');
            if (payload.eventType == PostgresChangeEvent.delete) {
              // Se è una cancellazione, ricarica subito
              _loadFriendlyMatches();
            } else if (payload.newRecord['to_player_id'] == user.id ||
                payload.newRecord['from_player_id'] == user.id) {
              _loadFriendlyMatches();

              // Carica i dettagli del giocatore che ha inviato la richiesta
              final fromPlayer = await supabase
                  .from('players')
                  .select()
                  .eq('id', payload.newRecord['from_player_id'])
                  .single();

              if (payload.newRecord['to_player_id'] == user.id &&
                  payload.newRecord['status'] == 'pending') {
                // Nuova richiesta ricevuta
                await _notificationService.showMatchInviteNotification(
                  title: 'Nuovo invito a giocare! 🎾',
                  body:
                      '${fromPlayer['name']} ti ha invitato a giocare una partita',
                  payload: payload.newRecord['id'],
                );
              } else if (payload.newRecord['from_player_id'] == user.id &&
                  payload.newRecord['status'] == 'confirmed') {
                // Richiesta accettata
                await _notificationService.showMatchConfirmationNotification(
                  title: 'Partita confermata! 🎉',
                  body: 'La tua richiesta è stata accettata',
                  payload: payload.newRecord['id'],
                );
              }
            }
            ;
          },
        )
        .subscribe();

    // 👤 Ascolta aggiornamenti sul giocatore attuale
    playerSub = supabase
        .channel('player-updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'players',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: user.id,
          ),
          callback: (payload) {
            debugPrint('Profilo aggiornato in realtime ✅');
            if (mounted) {
              setState(() {
                player = payload.newRecord;
              });
            }
          },
        )
        .subscribe();

    // 🏅 Ascolta aggiornamenti classifica
    leaderboardSub = supabase
        .channel('leaderboard-updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'leaderboard',
          callback: (payload) async {
            debugPrint('Leaderboard aggiornata 🔁');
            debugPrint('Payload: $payload');

            // Ricarica sia i punti del giocatore che la classifica completa
            try {
              final user = supabase.auth.currentUser;
              if (user != null) {
                debugPrint(
                  'Caricamento punti (da players) per user ID: ${user.id}',
                );
                final playerRecord = await supabase
                    .from('players')
                    .select('points')
                    .eq('id', user.id)
                    .maybeSingle();

                debugPrint(
                  'Punti aggiornati del giocatore (players): $playerRecord',
                );
                debugPrint(
                  'Struttura player prima dell\'aggiornamento: $player',
                );
                debugPrint(
                  'Dettagli punti ricevuti: ${playerRecord?['points']}',
                );
                // Quando la leaderboard cambia, ricarichiamo dai players
                final playersLeaderboardUpdate = await supabase
                    .from('players')
                    .select('id, name, avatar_url, level, city, points')
                    .order('points', ascending: false);

                final newLeaderboard =
                    (playersLeaderboardUpdate as List<dynamic>?)
                        ?.map<Map<String, dynamic>>(
                          (pl) => {
                            'points': pl['points'] ?? 0,
                            'player': pl,
                            'player_id': pl['id'],
                          },
                        )
                        .toList() ??
                    <Map<String, dynamic>>[];

                if (mounted) {
                  setState(() {
                    // Aggiorna i punti direttamente nel profilo del giocatore
                    if (playerRecord != null) {
                      // normalize different shapes
                      final rp = playerRecord['points'];
                      if (rp is int) {
                        player!['points'] = rp;
                      } else if (rp is Map) {
                        player!['points'] = rp['points'] ?? 0;
                      } else if (rp is List && rp.isNotEmpty) {
                        player!['points'] = rp[0]?['points'] ?? 0;
                      } else {
                        player!['points'] = 0;
                      }
                    }
                    // Aggiorna la classifica
                    leaderboard = List<Map<String, dynamic>>.from(
                      newLeaderboard,
                    );
                  });
                }
              }
            } catch (e) {
              debugPrint('Errore aggiornamento classifica: $e');
            }
          },
        )
        .subscribe();

    // 👥 Ascolta aggiornamenti sui players per aggiornare la leaderboard
    playersSub = supabase
        .channel('players-leaderboard-updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'players',
          callback: (payload) async {
            debugPrint('Players table changed - ricarico leaderboard');
            try {
              final playersLeaderboardUpdate = await supabase
                  .from('players')
                  .select('id, name, avatar_url, level, city, points')
                  .order('points', ascending: false);

              final newLeaderboard =
                  (playersLeaderboardUpdate as List<dynamic>?)
                      ?.map<Map<String, dynamic>>(
                        (pl) => {
                          'points': pl['points'] ?? 0,
                          'player': pl,
                          'player_id': pl['id'],
                        },
                      )
                      .toList() ??
                  <Map<String, dynamic>>[];

              if (mounted) {
                setState(() {
                  leaderboard = List<Map<String, dynamic>>.from(newLeaderboard);
                });
              }
            } catch (e) {
              debugPrint('Errore ricaricamento leaderboard da players: $e');
            }
          },
        )
        .subscribe();

    // 🎾 Ascolta nuovi tornei o modifiche
    tournamentsSub = supabase
        .channel('tournaments-updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tournaments',
          callback: (payload) async {
            debugPrint('Tornei aggiornati 🏆');
            final newTournaments = await supabase
                .from('tournaments')
                .select()
                .eq('active', true);
            setState(() {
              tournaments = newTournaments;
            });
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00E676)),
        ),
      );
    }

    debugPrint('Player state: $player');

    // Verifichiamo se player è null o vuoto
    if (player == null) {
      debugPrint('Player è null');
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: Text(
            'Errore nel caricamento del profilo',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final playerData = player;

    // I punti ora sono direttamente un numero
    debugPrint('Player data structure: $playerData');
    debugPrint('Points raw data: ${playerData?['points']}');

    int points = playerData?['points'] ?? 0;
    debugPrint('Points estratti: $points');

    final name = playerData?['name']?.toString() ?? 'Giocatore';
    final avatar =
        playerData?['avatar_url']?.toString() ??
        "https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=0D47A1&color=fff";

    debugPrint(
      'Extracted values - points: $points, name: $name, avatar: $avatar',
    );

    return Scaffold(
      backgroundColor: const Color(0xFF121212),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(name, avatar),
              const SizedBox(height: 24),
              _buildDynamicLevelCard(points: points),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildLeaderboard(),
                      const SizedBox(height: 24),
                      _buildTournaments(),
                      const SizedBox(height: 24),
                      _buildFriendlyMatches(),
                      const SizedBox(height: 24),
                      _buildFriendlyMatchSearch(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSearchingMatch = false;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  Widget _buildFriendlyMatches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Partite amichevoli",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (openRequests.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00E676).withOpacity(0.2),
                  const Color(0xFF00BFA5).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00E676), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.public,
                      color: Color(0xFF00E676),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Richieste aperte disponibili",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Altri giocatori cercano un avversario",
                  style: GoogleFonts.poppins(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                ...openRequests.map((request) {
                  final fromPlayer = request['from_player'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage:
                              fromPlayer['avatar_url'] != null &&
                                  fromPlayer['avatar_url'].toString().isNotEmpty
                              ? NetworkImage(fromPlayer['avatar_url'])
                              : null,
                          backgroundColor: const Color(0xFF16213E),
                          child:
                              fromPlayer['avatar_url'] == null ||
                                  fromPlayer['avatar_url'].toString().isEmpty
                              ? Text(
                                  (fromPlayer['name'] ?? 'U')[0].toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fromPlayer['name'] ?? 'Giocatore',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.stars,
                                    color: const Color(0xFFFFD700),
                                    size: 12,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Lv. ${fromPlayer['level'] ?? 1}',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFFFD700),
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (fromPlayer['city'] != null) ...[
                                    Icon(
                                      Icons.location_on,
                                      color: Colors.white60,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: Text(
                                        fromPlayer['city'],
                                        style: GoogleFonts.poppins(
                                          color: Colors.white60,
                                          fontSize: 10,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    color: const Color(0xFF00E676),
                                    size: 12,
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      '${DateFormat('d MMM', 'it_IT').format(DateTime.parse(request['match_date']))} ${request['match_time']}',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E676),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () => _acceptOpenRequest(request),
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(
                            'Accetta',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
        if (friendlyRequests.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00E676), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Richieste ricevute",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...friendlyRequests.map((request) {
                  final fromPlayer = request['from_player'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: fromPlayer['avatar_url'] != null
                              ? NetworkImage(fromPlayer['avatar_url'])
                              : null,
                          child: fromPlayer['avatar_url'] == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fromPlayer['name'] ?? 'Giocatore',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${DateFormat('d MMMM', 'it_IT').format(DateTime.parse(request['match_date']))} alle ${request['match_time']}',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close),
                              color: Colors.red,
                              onPressed: () =>
                                  _handleMatchRequest(request, accepted: false),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check),
                              color: const Color(0xFF00E676),
                              onPressed: () =>
                                  _handleMatchRequest(request, accepted: true),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
        if (friendlyMatches.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...friendlyMatches.map((match) {
            final isFromPlayer =
                match['from_player_id'] == supabase.auth.currentUser?.id;
            final opponent = isFromPlayer
                ? match['to_player']
                : match['from_player'];
            final matchDate = DateTime.parse(match['match_date']);
            final bool isPast = matchDate.isBefore(DateTime.now());
            final bool isPending = match['status'] == 'pending';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: match['status'] == 'confirmed'
                    ? Border.all(
                        color: const Color(0xFF00E676).withOpacity(0.3),
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Player 1 (From Player)
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(
                              player?['avatar_url'] ??
                                  "https://ui-avatars.com/api/?name=${Uri.encodeComponent(player?['name'] ?? 'P1')}&background=0D47A1&color=fff",
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            player?['name'] ?? 'Giocatore 1',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      // VS
                      Text(
                        'VS',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF00E676),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Player 2 (Opponent)
                      Row(
                        children: [
                          Text(
                            opponent?['name'] ?? 'Giocatore 2',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: opponent?['avatar_url'] != null
                                ? NetworkImage(opponent['avatar_url'])
                                : null,
                            child: opponent?['avatar_url'] == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Data e ora
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Color(0xFF00E676),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${DateFormat('d MMMM', 'it_IT').format(matchDate)} alle ${match['match_time']}',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  if (match['location'] != null) ...[
                    const SizedBox(height: 8),
                    // Location
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFF00E676),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          match['location'],
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (match['status'] == 'completed' &&
                      match['player1_score'] != null &&
                      match['player2_score'] != null) ...[
                    const SizedBox(height: 12),
                    // Punteggio
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF00E676).withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              // Nomi dei giocatori con corona per il vincitore
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2C2C2C),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Player 1
                                    Row(
                                      children: [
                                        Text(
                                          player?['name'] ?? 'Giocatore 1',
                                          style: GoogleFonts.poppins(
                                            color: _isPlayer1Winner(match)
                                                ? const Color(0xFF00E676)
                                                : Colors.white,
                                            fontSize: 14,
                                            fontWeight: _isPlayer1Winner(match)
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                          ),
                                        ),
                                        if (_isPlayer1Winner(match))
                                          const Text(
                                            ' 👑',
                                            style: TextStyle(fontSize: 20),
                                          ),
                                      ],
                                    ),
                                    const Text(
                                      'VS',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 14,
                                      ),
                                    ),
                                    // Player 2
                                    Row(
                                      children: [
                                        Text(
                                          opponent?['name'] ?? 'Giocatore 2',
                                          style: GoogleFonts.poppins(
                                            color: !_isPlayer1Winner(match)
                                                ? const Color(0xFF00E676)
                                                : Colors.white,
                                            fontSize: 14,
                                            fontWeight: !_isPlayer1Winner(match)
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                          ),
                                        ),
                                        if (!_isPlayer1Winner(match))
                                          const Text(
                                            ' 👑',
                                            style: TextStyle(fontSize: 20),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Punteggio
                              Text(
                                'Risultato: ${match['player1_score']} - ${match['player2_score']}',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(match['status']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(match['status']),
                      style: GoogleFonts.poppins(
                        color: _getStatusColor(match['status']),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (!isPast) ...[
                    const SizedBox(height: 16),
                    // Pulsanti per contattare l'avversario
                    if (match['status'] == 'confirmed') ...[
                      Text(
                        'Contatta l\'avversario',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00E676),
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
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
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
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
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        if (match['status'] == 'confirmed') ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.sports_score),
                              label: Text(
                                'Inserisci punteggio',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => MatchScoreDialog(
                                    match: match,
                                    onScoreUpdated: _loadFriendlyMatches,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (match['status'] == 'confirmed' ||
                            (isPending && isFromPlayer))
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => isPending && isFromPlayer
                                  ? _cancelRequest(match)
                                  : _cancelMatch(match),
                              child: Text(
                                isPending && isFromPlayer
                                    ? 'Cancella richiesta'
                                    : 'Annulla partita',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
        if (friendlyMatches.isEmpty && friendlyRequests.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Nessuna partita amichevole programmata',
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
            ),
          ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return const Color(0xFF00E676);
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'In attesa';
      case 'confirmed':
        return 'Confermata';
      case 'cancelled':
        return 'Annullata';
      case 'completed':
        return 'Completata';
      default:
        return 'Sconosciuto';
    }
  }

  Future<void> _handleMatchRequest(
    Map<String, dynamic> request, {
    required bool accepted,
  }) async {
    try {
      if (accepted) {
        // Aggiorna lo stato della richiesta
        await supabase
            .from('friendly_matches')
            .update({'status': 'confirmed'})
            .eq('id', request['id']);

        // Invia notifica al creatore della richiesta
        final user = supabase.auth.currentUser;
        final accepterName =
            user?.userMetadata?['name'] ?? user?.email ?? 'Un giocatore';
        final fromPlayerId = request['from_player_id'];
        final matchDate = request['match_date'];
        final matchTime = request['match_time'];

        await supabase.functions.invoke(
          'send-push-notification',
          body: {
            'title': 'Partita confermata! 🎾',
            'body':
                '$accepterName ha accettato la tua richiesta per il $matchDate alle $matchTime',
            'data': {
              'type': 'match_accepted',
              'match_date': matchDate,
              'match_time': matchTime,
              'accepter_name': accepterName,
              'accepter_id': user?.id,
            },
            'target_user_id': fromPlayerId, // Invia solo al creatore
          },
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Partita confermata! 🎾'),
            backgroundColor: Color(0xFF00E676),
          ),
        );
      } else {
        // Aggiorna lo stato della richiesta
        await supabase
            .from('friendly_matches')
            .update({'status': 'cancelled'})
            .eq('id', request['id']);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Richiesta rifiutata'),
            backgroundColor: Colors.grey,
          ),
        );
      }

      // Ricarica i dati
      await _loadFriendlyMatches();
    } catch (e) {
      debugPrint('Errore: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _acceptOpenRequest(Map<String, dynamic> request) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Utente non autenticato');
      }

      debugPrint('=== Accettazione richiesta aperta ===');
      debugPrint('ID richiesta: ${request['id']}');
      debugPrint('User ID accettante: ${user.id}');
      debugPrint('Creatore richiesta: ${request['from_player_id']}');

      // Elimina la vecchia richiesta aperta
      await supabase.from('friendly_matches').delete().eq('id', request['id']);

      debugPrint('Richiesta aperta eliminata');

      // Crea una nuova partita confermata tra i due giocatori
      await supabase.from('friendly_matches').insert({
        'from_player_id': request['from_player_id'],
        'to_player_id': user.id,
        'match_date': request['match_date'],
        'match_time': request['match_time'],
        'location': request['location'],
        'status': 'confirmed',
        'is_open_request': false,
      });

      debugPrint('Nuova partita confermata creata');

      // Invia notifica al creatore della richiesta
      final accepterName =
          user.userMetadata?['name'] ?? user.email ?? 'Un giocatore';
      final fromPlayerId = request['from_player_id'];
      final matchDate = request['match_date'];
      final matchTime = request['match_time'];

      await supabase.functions.invoke(
        'send-push-notification',
        body: {
          'title': 'Partita confermata! 🎾',
          'body':
              '$accepterName ha accettato la tua richiesta per il $matchDate alle $matchTime',
          'data': {
            'type': 'match_accepted',
            'match_date': matchDate,
            'match_time': matchTime,
            'accepter_name': accepterName,
            'accepter_id': user.id,
          },
          'target_user_id': fromPlayerId, // Invia solo al creatore
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Partita confermata con ${request['from_player']['name']}! 🎾',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: const Color(0xFF00E676),
        ),
      );

      // Ricarica i dati
      await _loadFriendlyMatches();
    } catch (e) {
      debugPrint('Errore accettazione richiesta: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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

  Future<void> _cancelRequest(Map<String, dynamic> request) async {
    // Mostra dialog di conferma
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Conferma cancellazione',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Sei sicuro di voler cancellare questa richiesta di partita?',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'No',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Sì, cancella',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Aggiorniamo lo stato della richiesta a 'cancelled'
      await supabase
          .from('friendly_matches')
          .update({'status': 'cancelled'})
          .eq('id', request['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Richiesta cancellata'),
          backgroundColor: Colors.grey,
        ),
      );

      // Ricarica i dati
      await _loadFriendlyMatches();
    } catch (e) {
      debugPrint('Errore: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _cancelMatch(Map<String, dynamic> match) async {
    // Mostra dialog di conferma
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Conferma cancellazione',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Sei sicuro di voler cancellare questa partita?',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'No',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Sì, cancella',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Aggiorna lo stato della richiesta
      await supabase
          .from('friendly_matches')
          .update({'status': 'cancelled'})
          .eq('id', match['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Partita cancellata'),
          backgroundColor: Colors.grey,
        ),
      );

      // Ricarica i dati
      await _loadFriendlyMatches();
    } catch (e) {
      debugPrint('Errore: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildFriendlyMatchSearch() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00E676).withOpacity(0.1),
            const Color(0xFF1E1E1E),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00E676).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sports_tennis,
                color: const Color(0xFF00E676),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                "Cerca partita amichevole",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_isSearchingMatch) ...[
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Color(0xFF00E676),
                                onPrimary: Colors.black,
                                surface: Color(0xFF1E1E1E),
                                onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        setState(() => _selectedDate = date);
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _selectedDate != null
                          ? DateFormat(
                              'd MMMM y',
                              'it_IT',
                            ).format(_selectedDate!)
                          : 'Seleziona data',
                      style: GoogleFonts.poppins(),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF2C2C2C),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Color(0xFF00E676),
                                onPrimary: Colors.black,
                                surface: Color(0xFF1E1E1E),
                                onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (time != null) {
                        setState(() => _selectedTime = time);
                      }
                    },
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      _selectedTime != null
                          ? _selectedTime!.format(context)
                          : 'Seleziona ora',
                      style: GoogleFonts.poppins(),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF2C2C2C),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  // Debugging info
                  Text(
                    'Data: ${_selectedDate?.toString() ?? "non selezionata"}',
                    style: GoogleFonts.poppins(color: Colors.white70),
                  ),
                  Text(
                    'Ora: ${_selectedTime?.format(context) ?? "non selezionata"}',
                    style: GoogleFonts.poppins(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: (_selectedDate != null && _selectedTime != null)
                        ? () {
                            debugPrint('Bottone premuto - Avvio ricerca');
                            debugPrint('Data selezionata: $_selectedDate');
                            debugPrint('Ora selezionata: $_selectedTime');
                            setState(() => _isSearchingMatch = true);
                            _startSearching();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: Text(
                      'Cerca giocatori disponibili',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          color: const Color(0xFF00E676),
                          strokeWidth: 8,
                          backgroundColor: Colors.grey.withOpacity(0.2),
                        ),
                      ),
                      Icon(
                        Icons.sports_tennis,
                        color: const Color(0xFF00E676),
                        size: 40,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Ricerca in corso...',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cerco giocatori disponibili nelle vicinanze',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _isSearchingMatch = false);
                    },
                    icon: const Icon(Icons.cancel),
                    label: const Text('Annulla ricerca'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
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

  Future<void> _startSearching() async {
    debugPrint('=== Creazione richiesta aperta ===');

    final user = supabase.auth.currentUser;
    if (user == null) {
      debugPrint('Errore: Nessun utente autenticato');
      setState(() => _isSearchingMatch = false);
      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      debugPrint('Errore: Data o ora non selezionate');
      setState(() => _isSearchingMatch = false);
      return;
    }

    try {
      // Formattiamo la data nel formato corretto per il database (YYYY-MM-DD)
      final date = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final time = _selectedTime!.format(context);

      debugPrint('Data: $date, Ora: $time');

      // Verifica se l'utente ha già una richiesta attiva per quella data
      final existingRequests = await supabase
          .from('friendly_matches')
          .select()
          .eq('match_date', date)
          .eq('from_player_id', user.id)
          .or('status.eq.pending,status.eq.confirmed');

      if (existingRequests.isNotEmpty) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: Text(
              'Hai già una partita programmata',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Hai già una richiesta di partita attiva per questa data.',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _isSearchingMatch = false);
                },
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
        return;
      }

      // Crea una richiesta aperta (visibile a tutti)
      debugPrint('Creazione richiesta aperta...');

      await supabase.from('friendly_matches').insert({
        'from_player_id': user.id,
        'to_player_id': null, // Nessun destinatario specifico
        'match_date': date,
        'match_time': time,
        'status': 'pending',
        'is_open_request': true, // Richiesta aperta a tutti
        'created_at': DateTime.now().toIso8601String(),
      });

      // Invia la notifica push a tutti tramite Edge Function
      final playerName =
          user.userMetadata?['name'] ?? user.email ?? 'Un giocatore';
      await supabase.functions.invoke(
        'send-push-notification',
        body: {
          'title': 'Nuova richiesta partita!',
          'body': '$playerName vuole giocare il $date alle $time',
          'data': {
            'type': 'match_request',
            'match_date': date,
            'match_time': time,
            'player_name': playerName,
            'player_id': user.id,
          },
        },
      );

      debugPrint('✅ Richiesta aperta creata!');

      if (!mounted) return;

      // Mostra messaggio di successo
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF00E676),
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Richiesta pubblicata!',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'La tua richiesta è stata pubblicata e tutti i giocatori possono vederla. Riceverai una notifica quando qualcuno accetta!',
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                Navigator.pop(context);
                setState(() => _isSearchingMatch = false);
                _loadFriendlyMatches(); // Ricarica per mostrare la nuova richiesta
              },
              child: Text(
                'OK',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('❌ Errore: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isSearchingMatch = false);
    }
  }

  Widget _buildHeader(String name, String avatarUrl) {
    debugPrint('_buildHeader called with name: $name, avatarUrl: $avatarUrl');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Tennix 🎾",
              style: GoogleFonts.poppins(
                color: const Color(0xFF00E676),
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Ciao, $name",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        CircleAvatar(radius: 22, backgroundImage: NetworkImage(avatarUrl)),
      ],
    );
  }

  Widget _buildDynamicLevelCard({required int points}) {
    final levelData = _getLevelData(points);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(levelData['icon'], color: levelData['color'], size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  levelData['name'],
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Punti: $points / ${levelData['nextThreshold']} · ${levelData['nameNext']}",
                  style: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor:
                            (points - levelData['min']) /
                            (levelData['nextThreshold'] - levelData['min']),
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: levelData['color'],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Classifiche",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...leaderboard.map((p) {
          final player = p['player'];
          if (player == null) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: NetworkImage(player['avatar_url'] ?? ""),
                      radius: 18,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      player['name'] ?? "",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  "${p["points"]} pt",
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF00E676),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<void> _unregisterFromTournament(
    Map<String, dynamic> tournament,
  ) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Mostra dialog di conferma
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: Text(
          'Conferma cancellazione',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Sei sicuro di voler cancellare la tua iscrizione a questo torneo?',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Annulla',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Conferma',
              style: GoogleFonts.poppins(color: const Color(0xFF00E676)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      debugPrint('Cancellazione torneo: ${tournament['tournaments']['id']}');
      // Aggiorna il record impostando active = false
      await supabase
          .from('tournaments_user')
          .update({'active': false})
          .eq('tournament_id', tournament['tournaments']['id'])
          .eq('user_id', user.id);

      // Aggiorna la lista locale
      setState(() {
        tournaments.removeWhere(
          (t) => t['tournaments']['id'] == tournament['tournaments']['id'],
        );
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancellazione completata con successo!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore durante la cancellazione')),
      );
    }
  }

  Widget _buildTournaments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "I tuoi tornei",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TournamentsPage(),
                ),
              ),
              child: Text(
                "Vedi tutti",
                style: GoogleFonts.poppins(
                  color: const Color(0xFF00E676),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (tournaments.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                "Non sei iscritto a nessun torneo",
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
              ),
            ),
          )
        else
          ...tournaments.map(
            (t) => GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TournamentDetailPage(
                    tournament: t['tournaments'],
                    initialRegistrationState: true,
                    onRegistrationChanged: (isRegistered) {
                      setState(() {
                        if (!isRegistered) {
                          tournaments.removeWhere(
                            (tournament) => tournament['id'] == t['id'],
                          );
                        }
                      });
                    },
                  ),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2C2C2C), Color(0xFF1A1A1A)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E676).withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Immagine del torneo
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child:
                          t["tournaments"]["image_url"] != null &&
                              t["tournaments"]["image_url"].isNotEmpty
                          ? Image.network(
                              t["tournaments"]["image_url"],
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 120,
                                color: Colors.black,
                                child: Icon(
                                  Icons.sports_tennis,
                                  size: 40,
                                  color: const Color(
                                    0xFF00E676,
                                  ).withOpacity(0.5),
                                ),
                              ),
                            )
                          : Container(
                              height: 120,
                              color: Colors.black,
                              child: Icon(
                                Icons.sports_tennis,
                                size: 40,
                                color: const Color(0xFF00E676).withOpacity(0.5),
                              ),
                            ),
                    ),
                    // Informazioni torneo
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t["tournaments"]["name"] ?? "Torneo",
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                          color: Color(0xFF00E676),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          t["tournaments"]["date"] ??
                                              "Data da definire",
                                          style: GoogleFonts.poppins(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _unregisterFromTournament(t),
                                icon: const Icon(Icons.cancel_outlined),
                                color: Colors.red,
                                tooltip: 'Cancella iscrizione',
                              ),
                            ],
                          ),
                          if (t["tournaments"]["location"] != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Color(0xFF00E676),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  t["tournaments"]["location"],
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool _isPlayer1Winner(Map<String, dynamic> match) {
    debugPrint('Checking winner for match: ${match['id']}');
    debugPrint('player1_score: ${match['player1_score']}');
    debugPrint('player2_score: ${match['player2_score']}');

    if (match['player1_score'] == null || match['player2_score'] == null) {
      debugPrint('Scores are null, returning false');
      return false;
    }

    // Separiamo i punteggi per ciascun giocatore
    final player1Scores = match['player1_score'].toString().split(', ');
    final player2Scores = match['player2_score'].toString().split(', ');
    debugPrint('Player1 scores: $player1Scores');
    debugPrint('Player2 scores: $player2Scores');

    // Verifichiamo che abbiamo lo stesso numero di set per entrambi i giocatori
    if (player1Scores.length != player2Scores.length) {
      debugPrint('Numero di set diverso tra i giocatori');
      return false;
    }

    // Confrontiamo i punteggi set per set
    int totalPlayer1Score = 0;
    int totalPlayer2Score = 0;

    for (int i = 0; i < player1Scores.length; i++) {
      final p1Score = int.tryParse(player1Scores[i]) ?? 0;
      final p2Score = int.tryParse(player2Scores[i]) ?? 0;
      debugPrint('Set ${i + 1} - Player1: $p1Score, Player2: $p2Score');

      totalPlayer1Score += p1Score;
      totalPlayer2Score += p2Score;
    }

    debugPrint(
      'Punteggio totale - Player1: $totalPlayer1Score, Player2: $totalPlayer2Score',
    );
    return totalPlayer1Score > totalPlayer2Score;
  }

  Map<String, dynamic> _getLevelData(int points) {
    if (points < 500) {
      return {
        "name": "Bronze",
        "nameNext": "Silver",
        "min": 0,
        "nextThreshold": 500,
        "color": const Color(0xFF795548),
        "icon": Icons.sports_tennis,
      };
    } else if (points < 1000) {
      return {
        "name": "Silver",
        "nameNext": "Gold",
        "min": 500,
        "nextThreshold": 1000,
        "color": const Color(0xFF9E9E9E),
        "icon": Icons.military_tech,
      };
    } else if (points < 2000) {
      return {
        "name": "Gold",
        "nameNext": "Platinum",
        "min": 1000,
        "nextThreshold": 2000,
        "color": const Color(0xFFFFD700),
        "icon": Icons.emoji_events,
      };
    } else if (points < 4000) {
      return {
        "name": "Platinum",
        "nameNext": "Pro",
        "min": 2000,
        "nextThreshold": 4000,
        "color": const Color(0xFFB3E5FC),
        "icon": Icons.diamond,
      };
    } else {
      return {
        "name": "Pro",
        "nameNext": "Top",
        "min": 4000,
        "nextThreshold": 5000,
        "color": const Color(0xFF00E676),
        "icon": Icons.star,
      };
    }
  }
}
