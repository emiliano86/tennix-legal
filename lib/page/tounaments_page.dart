import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:tennix/page/tournament_detail_page_new.dart';
import 'package:tennix/page/doubles_tournament_page.dart';
import 'package:tennix/page/doubles_tournament_register_page.dart';

class TournamentsPage extends StatefulWidget {
  const TournamentsPage({Key? key}) : super(key: key);

  @override
  State<TournamentsPage> createState() => _TournamentsPageState();
}

class _TournamentsPageState extends State<TournamentsPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  bool loading = true;
  List<dynamic> tournaments = [];
  Set<dynamic> registeredTournaments =
      {}; // Set di ID dei tornei a cui sono iscritto
  late TabController _tabController;
  String activeTab = 'singles'; // 'singles', 'doubles', or 'history'

  // Optional realtime channel for tournaments updates
  RealtimeChannel? _tournamentsChannel;

  // Storico tornei
  List<dynamic> completedTournaments = [];
  List<dynamic> archivedTournaments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 0) {
        setState(() => activeTab = 'singles');
      } else if (_tabController.index == 1) {
        setState(() => activeTab = 'doubles');
      } else {
        setState(() => activeTab = 'history');
        if (completedTournaments.isEmpty && archivedTournaments.isEmpty) {
          _loadHistoricalTournaments();
        }
      }
    });
    _loadTournaments();
    _loadRegisteredTournaments();
    _subscribeRealtime();
  }

  Future<void> _unregisterFromTournament(dynamic tournamentId) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Devi effettuare il login per cancellarti.'),
        ),
      );
      return;
    }

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
      // Aggiorna il record impostando active = false
      debugPrint('Cancellazione iscrizione per torneo UUID: $tournamentId');

      await supabase
          .from('tournaments_user')
          .update({'active': false})
          .eq('tournament_id', tournamentId)
          .eq('user_id', user.id);

      // Rimuovi il torneo dalla lista dei registrati
      setState(() {
        registeredTournaments.remove(tournamentId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancellazione completata con successo!')),
      );
    } catch (e) {
      debugPrint('Errore cancellazione: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore durante la cancellazione.')),
      );
    }
  }

  Future<void> _registerForTournament(dynamic tournamentId) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Devi effettuare il login per iscriverti.'),
        ),
      );
      return;
    }

    try {
      debugPrint(
        'Iniziando processo di iscrizione per torneo UUID: $tournamentId',
      );

      // Usa l'ID come stringa (UUID)
      final tournamentUUID = tournamentId.toString();

      // 1️⃣ Verifica il numero di partecipanti attuali e il limite
      final tournament = await supabase
          .from('tournaments')
          .select('max_participants, status')
          .eq('id', tournamentUUID)
          .single();

      final maxParticipants = tournament['max_participants'] as int?;
      final tournamentStatus = tournament['status'] as String?;

      // Verifica se il torneo è ancora aperto
      if (tournamentStatus != 'open') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Questo torneo non è più aperto alle iscrizioni.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Conta i partecipanti attuali
      final currentParticipants = await supabase
          .from('tournaments_user')
          .select('user_id')
          .eq('tournament_id', tournamentUUID)
          .eq('active', true);

      final participantCount = currentParticipants.length;

      // Verifica se ha raggiunto il limite
      if (maxParticipants != null && participantCount >= maxParticipants) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Torneo completo! Limite di $maxParticipants giocatori raggiunto.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 2️⃣ Ottieni il profilo dell'utente
      final profileResponse = await supabase
          .from('profiles')
          .select('name')
          .eq('id', user.id)
          .single();

      final String playerName =
          profileResponse['name'] ?? profileResponse['username'] ?? 'Giocatore';

      // 3️⃣ Verifica se già iscritto attivamente
      debugPrint('Verifica iscrizione per torneo ID: $tournamentId');
      debugPrint('Usando ID torneo come UUID: $tournamentUUID');

      final existing = await supabase
          .from('tournaments_user')
          .select()
          .eq('tournament_id', tournamentUUID)
          .eq(
            'user_id',
            user.id,
          ); // Se esiste un'iscrizione attiva, non permettere la registrazione
      if (existing.any((reg) => reg['active'] == true)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sei già iscritto a questo torneo.')),
        );
        return;
      }

      // Se esiste un'iscrizione non attiva, aggiornala
      if (existing.isNotEmpty) {
        await supabase
            .from('tournaments_user')
            .update({'active': true, 'date': DateTime.now().toIso8601String()})
            .eq('tournament_id', tournamentUUID)
            .eq('user_id', user.id);

        // Aggiorna lo stato locale anche per la riattivazione
        setState(() {
          registeredTournaments.add(tournamentId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Iscrizione riattivata! (${participantCount + 1}/$maxParticipants)',
            ),
            backgroundColor: const Color(0xFF00E676),
          ),
        );
      } else {
        // 4️⃣ Inserisci nuova iscrizione
        debugPrint(
          'Inserimento nuova iscrizione per torneo UUID: $tournamentId',
        );

        await supabase.from('tournaments_user').insert({
          'tournament_id': tournamentId,
          'user_id': user.id,
          'date': DateTime.now().toIso8601String(),
          'name': playerName,
          'active': true,
        });

        setState(() {
          registeredTournaments.add(tournamentId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Iscrizione completata! (${participantCount + 1}/$maxParticipants)',
            ),
            backgroundColor: const Color(0xFF00E676),
          ),
        );
      }

      // Verifica se il torneo ha raggiunto il numero massimo di partecipanti
      await _checkAndStartTournament(tournamentId);
    } catch (e) {
      debugPrint('Errore iscrizione: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Errore durante l'iscrizione")),
      );
    }
  }

  Future<void> _checkAndStartTournament(dynamic tournamentId) async {
    try {
      debugPrint('=== CONTROLLO AVVIO TORNEO ===');
      debugPrint('Tournament ID: $tournamentId');

      // 1. Ottieni i dettagli del torneo
      final tournament = await supabase
          .from('tournaments')
          .select('max_participants, status')
          .eq('id', tournamentId)
          .single();

      final maxParticipants = tournament['max_participants'];
      final currentStatus = tournament['status'];

      debugPrint('Max partecipanti: $maxParticipants');
      debugPrint('Status torneo: $currentStatus');

      // Se non c'è un limite o il torneo è già iniziato, esci
      if (maxParticipants == null) {
        debugPrint('STOP: max_participants è null');
        return;
      }

      if (currentStatus != 'open') {
        debugPrint('STOP: status non è open, ma $currentStatus');
        return;
      }

      // 2. Conta i partecipanti attuali
      final participants = await supabase
          .from('tournaments_user')
          .select('user_id')
          .eq('tournament_id', tournamentId)
          .eq('active', true);

      debugPrint(
        'Torneo $tournamentId: ${participants.length}/$maxParticipants partecipanti',
      );

      // 3. Se ha raggiunto il massimo, avvia il torneo
      if (participants.length >= maxParticipants) {
        debugPrint('✅ NUMERO MASSIMO RAGGIUNTO! AVVIO TORNEO...');
        await _startTournamentWithGroups(tournamentId, participants);
      } else {
        debugPrint(
          '⏳ Ancora ${maxParticipants - participants.length} giocatori mancanti',
        );
      }
    } catch (e) {
      debugPrint('❌ ERRORE verifica avvio torneo: $e');
    }
  }

  Future<void> _startTournamentWithGroups(
    dynamic tournamentId,
    List<dynamic> participants,
  ) async {
    try {
      // SISTEMA TORNEO: 16 giocatori totali
      // - Fase 1: 4 gironi da 4 giocatori (round robin)
      // - Fase 2: Tabellone a eliminazione diretta da 8 (primi 2 di ogni girone)

      debugPrint('=== AVVIO TORNEO CON GIRONI ===');
      debugPrint('Numero giocatori: ${participants.length}');

      // Verifica che ci siano esattamente 16 giocatori
      if (participants.length != 16) {
        debugPrint(
          '⚠️ ATTENZIONE: Il torneo dovrebbe avere esattamente 16 giocatori, '
          'ma ne ha ${participants.length}',
        );
        // Non avviare il torneo se non ci sono esattamente 16 giocatori
        return;
      }

      // Verifica se i gironi sono già stati creati
      final existingGroups = await supabase
          .from('tournament_groups')
          .select('id')
          .eq('tournament_id', tournamentId);

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

      // 1. Aggiorna lo stato del torneo a "in_progress"
      debugPrint('📝 Aggiornamento stato torneo a in_progress...');
      await supabase
          .from('tournaments')
          .update({
            'status': 'in_progress',
            'actual_start_date': DateTime.now().toIso8601String(),
          })
          .eq('id', tournamentId);
      debugPrint('✅ Stato torneo aggiornato');

      // 2. Mescola i partecipanti per distribuirli casualmente
      final shuffledParticipants = List.from(participants)..shuffle();
      debugPrint('🔀 Partecipanti mescolati');

      // 3. Crea esattamente 4 gironi da 4 giocatori
      final groupSize = 4;
      final numberOfGroups = 4; // Fisso a 4 gironi per 16 giocatori
      debugPrint(
        '📊 Creazione di $numberOfGroups gironi da $groupSize giocatori...',
      );

      for (int i = 0; i < numberOfGroups; i++) {
        debugPrint('\n--- Creazione Girone ${String.fromCharCode(65 + i)} ---');
        final groupStartIndex = i * groupSize;
        final groupEndIndex =
            (groupStartIndex + groupSize) > shuffledParticipants.length
            ? shuffledParticipants.length
            : groupStartIndex + groupSize;

        final groupMembers = shuffledParticipants.sublist(
          groupStartIndex,
          groupEndIndex,
        );

        // Crea il girone
        debugPrint('📝 Inserimento girone nel database...');
        final groupResponse = await supabase
            .from('tournament_groups')
            .insert({
              'tournament_id': tournamentId,
              'group_name':
                  'Girone ${String.fromCharCode(65 + i)}', // A, B, C, etc.
            })
            .select()
            .single();

        final groupId = groupResponse['id'];
        debugPrint('✅ Girone creato con ID: $groupId');
        debugPrint('   Membri del girone: ${groupMembers.length}');

        // Aggiungi i membri al girone
        for (var member in groupMembers) {
          debugPrint('   → Aggiunta giocatore: ${member['user_id']}');
          await supabase.from('tournament_group_members').insert({
            'group_id': groupId,
            'player_id': member['user_id'],
            'points': 0,
            'matches_played': 0,
            'matches_won': 0,
            'matches_lost': 0,
          });
        }
        debugPrint('✅ Membri del girone aggiunti');

        // Crea i match del girone (round robin - tutti contro tutti)
        int matchCount = 0;
        for (int j = 0; j < groupMembers.length; j++) {
          for (int k = j + 1; k < groupMembers.length; k++) {
            matchCount++;
            await supabase.from('tournament_matches').insert({
              'tournament_id': tournamentId,
              'group_id': groupId,
              'player1_id': groupMembers[j]['user_id'],
              'player2_id': groupMembers[k]['user_id'],
              'status': 'scheduled',
              'phase': 'group',
            });
          }
        }
        debugPrint('✅ $matchCount match creati per questo girone');
      }

      debugPrint(
        'Torneo avviato con successo! Creati $numberOfGroups gironi da 4 giocatori.\n'
        'I primi 2 classificati di ogni girone (8 giocatori totali) '
        'passeranno al tabellone a eliminazione diretta.',
      );

      // Mostra notifica all'utente
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Il torneo è iniziato! $numberOfGroups gironi da 4 giocatori.\n'
              'I primi 2 di ogni girone passano al tabellone da 8.',
            ),
            backgroundColor: const Color(0xFF00E676),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Ricarica i tornei per mostrare lo stato aggiornato
      _loadTournaments();
    } catch (e) {
      debugPrint('Errore avvio torneo con gironi: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tournamentsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadRegisteredTournaments() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final registrations = await supabase
          .from('tournaments_user')
          .select('tournament_id')
          .eq('user_id', user.id)
          .eq('active', true);

      setState(() {
        // Manteniamo gli ID come stringhe (UUID)
        registeredTournaments = registrations
            .map((reg) => reg['tournament_id'].toString())
            .toSet();
      });
    }
  }

  Future<void> _loadTournaments() async {
    setState(() => loading = true);
    try {
      debugPrint('Fetching tournaments...');
      final response = await supabase
          .from('tournaments')
          .select(
            'id, name, type, status, start_date, registration_end, location, regulation, image_url, groups_created',
          )
          .neq('status', 'archived'); // Esclude i tornei archiviati

      debugPrint('Raw response from tournaments table: $response');

      if (response.isEmpty) {
        debugPrint('Warning: No tournaments found in database');
        setState(() {
          tournaments = [];
          loading = false;
        });
        return;
      }

      debugPrint('Found ${response.length} tournaments in database');

      // Debug della struttura dei dati
      for (var tournament in response) {
        debugPrint('Tournament raw data:');
        debugPrint('  ID: ${tournament['id']}');
        debugPrint('  Name: ${tournament['name']}');
        debugPrint('  Raw type value: ${tournament['type']}');
      } // Le iscrizioni vengono gestite separatamente in _loadRegisteredTournaments
      // Convertiamo la response in una lista
      List<dynamic> list = response;

      // Stampa dettagliata degli elementi per capire i campi
      for (var i = 0; i < list.length; i++) {
        debugPrint('Tournament[$i]: ${list[i].toString()}');
      }

      // 4) Normalizzazione: estrai il campo "type" con sicurezza,
      //    fallback a "" se mancante. Converti tutto in lowercase per confronto.
      final normalized = list.map((t) {
        debugPrint('\nNormalizing tournament data:');
        final Map<String, dynamic> item = Map<String, dynamic>.from(t as Map);

        debugPrint('Looking for type in fields:');
        debugPrint('  type: ${item['type']}');
        debugPrint('  format: ${item['format']}');
        debugPrint('  match_type: ${item['match_type']}');
        debugPrint('  tipo: ${item['tipo']}');

        String? rawType =
            item['type']?.toString().toLowerCase().trim() ??
            item['format']?.toString().toLowerCase().trim() ??
            item['match_type']?.toString().toLowerCase().trim() ??
            item['tipo']?.toString().toLowerCase().trim();

        if (rawType == null || rawType.isEmpty) {
          debugPrint('No type found, defaulting to "singles"');
          rawType = 'singles';
        }

        debugPrint('Final normalized type: $rawType');
        item['__normalized_type'] = rawType;
        return item;
      }).toList();

      // 5) Costruisci le liste per singles e doubles basandoti sul normalized type
      final singlesList = normalized
          .where(
            (t) =>
                t['__normalized_type'] == 'singles' ||
                t['__normalized_type'] == 'singolo' ||
                t['__normalized_type'] == 'singolare' ||
                t['__normalized_type'] == 'single' ||
                t['__normalized_type'] == 's',
          )
          .toList();

      final doublesList = normalized
          .where(
            (t) =>
                t['__normalized_type'] == 'doubles' ||
                t['__normalized_type'] == 'doppio' ||
                t['__normalized_type'] == 'double' ||
                t['__normalized_type'] == 'd',
          )
          .toList();

      debugPrint('Normalized total: ${normalized.length}');
      debugPrint('Singles found: ${singlesList.length}');
      debugPrint('Doubles found: ${doublesList.length}');

      setState(() {
        tournaments = normalized;
        // se vuoi salvare separatamente:
        //_singles = singlesList;
        //_doubles = doublesList;
        loading = false;
      });
    } catch (e, st) {
      debugPrint('Errore _loadTournamentsDebug: $e');
      debugPrint(st.toString());
      setState(() {
        tournaments = [];
        //_singles = [];
        //_doubles = [];
        loading = false;
      });
    }
  }

  Future<void> _loadHistoricalTournaments() async {
    try {
      debugPrint('Loading historical tournaments...');

      // Carica tornei completati (recenti)
      final completedResponse = await supabase
          .from('tournaments')
          .select()
          .eq('status', 'completed')
          .order('created_at', ascending: false);

      // Carica tornei archiviati (vecchi)
      final archivedResponse = await supabase
          .from('tournaments')
          .select()
          .eq('status', 'archived')
          .order('created_at', ascending: false);

      setState(() {
        completedTournaments = completedResponse as List<dynamic>;
        archivedTournaments = archivedResponse as List<dynamic>;
      });

      debugPrint(
        'Loaded ${completedTournaments.length} completed and ${archivedTournaments.length} archived tournaments',
      );
    } catch (e) {
      debugPrint('Error loading historical tournaments: $e');
      setState(() {
        completedTournaments = [];
        archivedTournaments = [];
      });
    }
  }

  void _subscribeRealtime() {
    // ascolta cambiamenti sulle tabelle tournaments e tournaments_user
    _tournamentsChannel = supabase
        .channel('public:tournaments')
        .onPostgresChanges(
          schema: 'public',
          table: 'tournaments',
          event: PostgresChangeEvent.all,
          callback: (payload) {
            _loadTournaments();
          },
        )
        .onPostgresChanges(
          schema: 'public',
          table: 'tournaments_user',
          event: PostgresChangeEvent.all,
          callback: (payload) {
            _loadRegisteredTournaments();
          },
        )
        .subscribe();
  }

  Widget _buildTournamentButton(Map<String, dynamic> tournament) {
    final isRegistered = registeredTournaments.contains(tournament['id']);
    final groupsCreated = tournament['groups_created'] ?? false;
    final status = tournament['status'] ?? 'open';

    String buttonText;
    Color backgroundColor;
    Color foregroundColor;
    BorderSide borderSide;
    double elevation;
    VoidCallback? onPressed;

    if (status == 'completed') {
      // Torneo completato - disabilitato
      buttonText = 'Torneo Completato';
      backgroundColor = Colors.grey.shade700;
      foregroundColor = Colors.white60;
      borderSide = BorderSide.none;
      elevation = 0;
      onPressed = null;
    } else if (groupsCreated || status == 'in_progress') {
      // Torneo in corso - disabilitato
      buttonText = 'Torneo in Corso';
      backgroundColor = Colors.grey;
      foregroundColor = Colors.white70;
      borderSide = BorderSide.none;
      elevation = 0;
      onPressed = null;
    } else if (isRegistered) {
      // Iscritto ma non iniziato - può cancellarsi
      buttonText = 'Cancella iscrizione';
      backgroundColor = Colors.black;
      foregroundColor = Colors.white;
      borderSide = const BorderSide(color: Color(0xFF00E676), width: 3);
      elevation = 8;
      onPressed = () => _unregisterFromTournament(tournament['id']);
    } else {
      // Non iscritto - può iscriversi
      buttonText = 'Iscriviti ora';
      backgroundColor = const Color(0xFF00E676);
      foregroundColor = Colors.black;
      borderSide = BorderSide.none;
      elevation = 0;

      // Per tornei di doppio, apri la pagina di registrazione coppia
      if (tournament['type'] == 'doubles') {
        onPressed = () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  DoublesTournamentRegisterPage(tournament: tournament),
            ),
          ).then((_) => _loadTournaments()); // Ricarica dopo registrazione
        };
      } else {
        // Per tornei singoli, usa la registrazione normale
        onPressed = () => _registerForTournament(tournament['id']);
      }
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: borderSide,
        ),
        elevation: elevation,
        disabledBackgroundColor: Colors.grey,
        disabledForegroundColor: Colors.white70,
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            buttonText,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('d MMM, yyyy').format(dt);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('\nFiltering tournaments...');
    debugPrint('Total tournaments before filtering: ${tournaments.length}');

    final singles = tournaments.where((t) {
      final type = (t['__normalized_type'] ?? 'singles')
          .toString()
          .toLowerCase();
      final id = t['id'];
      debugPrint('\nChecking tournament $id for singles:');
      debugPrint('  Normalized type: $type');

      final bool isSingles =
          type.contains('single') ||
          type.contains('singolo') ||
          type.contains('singolare') ||
          type == 's';

      debugPrint('  Is singles? $isSingles');
      return isSingles;
    }).toList();
    debugPrint('\nSingles tournaments found: ${singles.length}');

    final doubles = tournaments.where((t) {
      final type = (t['__normalized_type'] ?? '').toString().toLowerCase();
      final id = t['id'];
      debugPrint('\nChecking tournament $id for doubles:');
      debugPrint('  Normalized type: $type');

      final bool isDoubles =
          type.contains('double') || type.contains('doppio') || type == 'd';

      debugPrint('  Is doubles? $isDoubles');
      return isDoubles;
    }).toList();
    debugPrint('\nDoubles tournaments found: ${doubles.length}');

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Tornei',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00E676),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Singolare'),
            Tab(text: 'Doppio'),
            Tab(text: 'Storico'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Colors.white70,
            onPressed: _loadTournaments,
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildListView(context, singles),
                _buildListView(context, doubles),
                _buildHistoryView(),
              ],
            ),
    );
  }

  Widget _buildListView(BuildContext context, List<dynamic> list) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          'Nessun torneo disponibile',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      separatorBuilder: (_, __) => const SizedBox(height: 24),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final t = list[index] as Map<String, dynamic>;
        return Hero(tag: 'tournament-${t['id']}', child: _tournamentCard(t));
      },
    );
  }

  Widget _tournamentCard(Map<String, dynamic> t) {
    final imageUrl = t['image_url'] as String?;
    final name = t['name'] as String? ?? 'Torneo';
    final regulation =
        t['regulation'] as String? ?? 'Regolamento non disponibile';
    final startDate = _formatDate(t['start_date'] as String?);
    final regEnd = _formatDate(t['registration_end'] as String?);
    final location = t['location'] as String? ?? '';
    final type = t['type'] as String? ?? 'singles';

    return GestureDetector(
      onTap: () => _openTournamentDetails(t),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2C2C2C), Color(0xFF1A1A1A)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E676).withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Stack(
              children: [
                // Immagine di copertina
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imageFallback(),
                        )
                      : _imageFallback(),
                ),
                // Overlay gradiente
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),
                // Badge tipo torneo
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      type == 'singles' ? 'Singolare' : 'Doppio',
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Titolo sovrapposto all'immagine
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Text(
                    name,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        const Shadow(
                          offset: Offset(0, 2),
                          blurRadius: 4,
                          color: Colors.black45,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info principali
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 20,
                        color: Color(0xFF00E676),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          location,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Date e dettagli
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: Color(0xFF00E676),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Data inizio',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    startDate,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white24,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.how_to_reg,
                                          size: 16,
                                          color: Color(0xFF00E676),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Chiusura iscrizioni',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      regEnd,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Descrizione
                  Text(
                    regulation.length > 100
                        ? '${regulation.substring(0, 100)}...'
                        : regulation,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Pulsante iscrizione
                  Row(children: [Expanded(child: _buildTournamentButton(t))]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      height: 150,
      color: Colors.black,
      alignment: Alignment.center,
      child: Icon(
        Icons.sports_tennis,
        size: 60,
        color: const Color(0xFF00E676).withOpacity(0.9),
      ),
    );
  }

  void _openTournamentDetails(Map<String, dynamic> tournament) {
    final type = tournament['type'] as String? ?? 'singles';

    // Se è un torneo di doppio, apri la pagina specifica per i doppi
    if (type == 'doubles' ||
        type == 'doppio' ||
        type == 'double' ||
        type == 'd') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              DoublesTournamentPage(tournamentId: tournament['id']),
        ),
      );
    } else {
      // Altrimenti apri la pagina standard per i singoli
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TournamentDetailPage(
            tournament: tournament,
            initialRegistrationState: registeredTournaments.contains(
              tournament['id'],
            ),
            onRegistrationChanged: (isRegistered) {
              setState(() {
                if (isRegistered) {
                  registeredTournaments.add(tournament['id']);
                } else {
                  registeredTournaments.remove(tournament['id']);
                }
              });
            },
          ),
        ),
      );
    }
  }

  Widget _buildHistoryView() {
    if (completedTournaments.isEmpty && archivedTournaments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              'Nessun torneo completato',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sezione completati di recente
        if (completedTournaments.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.amber, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Completati di Recente',
                  style: GoogleFonts.poppins(
                    color: Colors.amber,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...completedTournaments.map((t) => _buildHistoryCard(t, true)),
          const SizedBox(height: 32),
        ],

        // Sezione archivio
        if (archivedTournaments.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory_2, color: Colors.grey, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Archivio',
                  style: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...archivedTournaments.map((t) => _buildHistoryCard(t, false)),
        ],
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> tournament, bool isRecent) {
    final name = tournament['name'] as String? ?? 'Torneo';
    final type = tournament['type'] as String? ?? 'singles';
    final createdAt = tournament['created_at'] as String?;
    final status = tournament['status'] as String? ?? 'completed';

    final statusColor = isRecent ? Colors.amber : Colors.grey;
    final statusText = status == 'completed' ? 'COMPLETATO' : 'ARCHIVIATO';

    return GestureDetector(
      onTap: () => _openTournamentDetails(tournament),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF2C2C2C), const Color(0xFF1A1A1A)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icona trofeo
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.emoji_events, color: statusColor, size: 32),
              ),
              const SizedBox(width: 16),

              // Informazioni torneo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(createdAt),
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: statusColor.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            statusText,
                            style: GoogleFonts.poppins(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            type == 'singles' ? 'Singolare' : 'Doppio',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF00E676),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Freccia
              Icon(Icons.chevron_right, color: Colors.white38, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
