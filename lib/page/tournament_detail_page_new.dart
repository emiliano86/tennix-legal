import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'tournament_groups_page.dart';

class TournamentDetailPage extends StatefulWidget {
  final Map<String, dynamic> tournament;
  final Function(bool isRegistered) onRegistrationChanged;
  final bool initialRegistrationState;
  final bool isOrganizer;

  const TournamentDetailPage({
    super.key,
    required this.tournament,
    required this.onRegistrationChanged,
    required this.initialRegistrationState,
    this.isOrganizer = false,
  });

  @override
  State<TournamentDetailPage> createState() => _TournamentDetailPageState();
}

class _TournamentDetailPageState extends State<TournamentDetailPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<Map<String, dynamic>> participants = [];
  bool isRegistered = false;
  bool groupsCreated = false;

  @override
  void initState() {
    super.initState();
    isRegistered = widget.initialRegistrationState;
    _loadTournamentDetails();
  }

  Future<void> _checkAndGenerateGroups() async {
    if (!widget.isOrganizer) return;

    try {
      // Verifica se i gironi sono già stati creati
      final tournamentResponse = await supabase
          .from('tournaments')
          .select('groups_created, max_players, registration_end')
          .eq('id', widget.tournament['id'])
          .single();

      final groupsCreated = tournamentResponse['groups_created'] ?? false;

      if (!groupsCreated) {
        final maxPlayers = tournamentResponse['max_players'] as int?;
        final registrationEnd = tournamentResponse['registration_end'] != null
            ? DateTime.parse(tournamentResponse['registration_end'])
            : null;
        final now = DateTime.now();

        // Genera i gironi se:
        // 1. Si è raggiunto il numero massimo di partecipanti, o
        // 2. È scaduta la data di iscrizione
        if ((maxPlayers != null && participants.length >= maxPlayers) ||
            (registrationEnd != null && now.isAfter(registrationEnd))) {
          final groupsPage = TournamentGroupsPage(
            tournament: widget.tournament,
            isOrganizer: true,
          );
          final state = groupsPage.createState() as TournamentGroupsPageState;
          await state.generateGroups();

          // Aggiorna la UI
          if (mounted) {
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gironi generati automaticamente!'),
                backgroundColor: Color(0xFF00E676),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Errore nel controllo/generazione gironi: $e');
    }
  }

  Future<void> _loadTournamentDetails() async {
    setState(() => isLoading = true);

    try {
      // Carica lo stato aggiornato del torneo
      final tournamentData = await supabase
          .from('tournaments')
          .select('groups_created')
          .eq('id', widget.tournament['id'])
          .single();

      // Carica i partecipanti
      final response = await supabase
          .from('tournaments_user')
          .select('user_id')
          .eq('tournament_id', widget.tournament['id'])
          .eq('active', true);

      // Carica i dati dei giocatori per ogni partecipante
      final List<Map<String, dynamic>> participantsWithData = [];
      for (final registration in response) {
        final playerId = registration['user_id'];
        try {
          final playerData = await supabase
              .from('players')
              .select('*')
              .eq('id', playerId)
              .single();

          participantsWithData.add({
            'user_id': playerId,
            'players': playerData,
          });
        } catch (e) {
          debugPrint('Errore caricamento giocatore $playerId: $e');
        }
      }

      final user = supabase.auth.currentUser;
      final isUserRegistered = participantsWithData.any(
        (p) => p['user_id'] == user?.id,
      );

      if (mounted) {
        setState(() {
          participants = participantsWithData;
          isRegistered = isUserRegistered;
          groupsCreated = tournamentData['groups_created'] ?? false;
          isLoading = false;
        });

        // Controlla se generare i gironi dopo aver caricato i partecipanti
        await _checkAndGenerateGroups();
      }
    } catch (e) {
      debugPrint('Errore caricamento dettagli: $e');
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _toggleRegistration() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Devi effettuare il login per iscriverti'),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      if (isRegistered) {
        // Cancella iscrizione
        await supabase
            .from('tournaments_user')
            .delete()
            .eq('tournament_id', widget.tournament['id'])
            .eq('user_id', user.id);

        widget.onRegistrationChanged(false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Iscrizione cancellata')));
      } else {
        // Aggiungi iscrizione
        await supabase.from('tournaments_user').insert({
          'tournament_id': widget.tournament['id'],
          'user_id': user.id,
          'active': true,
          'created_at': DateTime.now().toIso8601String(),
        });

        widget.onRegistrationChanged(true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Iscrizione completata!')));
      }

      await _loadTournamentDetails();
    } catch (e) {
      debugPrint('Errore: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      setState(() => isLoading = false);
    }
  }

  Widget _buildDetailsTab() {
    final tournament = widget.tournament;
    final imageUrl = tournament['image_url'] as String?;
    final name = tournament['name'] as String? ?? 'Torneo';
    final location = tournament['location'] as String? ?? '';
    final regulation = tournament['regulation'] as String? ?? '';
    final startDate = _formatDate(tournament['start_date'] as String?);
    final endDate = _formatDate(tournament['end_date'] as String?);
    final maxPlayers = tournament['max_players'] as int? ?? 0;
    final prizePool = tournament['prize_pool'] as String? ?? '';
    final surface = tournament['surface'] as String? ?? '';

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: imageUrl != null
                    ? Image.network(imageUrl, fit: BoxFit.cover)
                    : Container(
                        color: Colors.black,
                        child: Icon(
                          Icons.sports_tennis,
                          size: 80,
                          color: const Color(0xFF00E676).withOpacity(0.5),
                        ),
                      ),
                title: Text(
                  name,
                  style: GoogleFonts.poppins(
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
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informazioni torneo
                    _buildInfoSection('Informazioni Torneo', [
                      _buildInfoRow(Icons.event, 'Data Inizio', startDate),
                      _buildInfoRow(Icons.event_busy, 'Data Fine', endDate),
                      _buildInfoRow(Icons.location_on, 'Location', location),
                      _buildInfoRow(
                        Icons.sports_tennis,
                        'Superficie',
                        surface.isNotEmpty ? surface : 'Non specificata',
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // Montepremi
                    _buildInfoSection('Montepremi', [
                      _buildInfoRow(
                        Icons.emoji_events,
                        'Premio',
                        prizePool.isNotEmpty ? prizePool : 'Non specificato',
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // Regolamento
                    _buildInfoSection('Regolamento', [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          regulation,
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // Partecipanti
                    _buildInfoSection(
                      'Partecipanti (${participants.length}${maxPlayers > 0 ? '/$maxPlayers' : ''})',
                      [
                        for (var participant in participants)
                          _buildParticipantCard(participant),
                      ],
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Bottone iscrizione
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _buildRegistrationButton(),
        ),
      ],
    );
  }

  Widget _buildRegistrationButton() {
    // Verifica se il torneo è iniziato (gironi creati)
    String buttonText;
    Color backgroundColor;
    Color foregroundColor;
    VoidCallback? onPressed;

    if (groupsCreated) {
      // Torneo in corso - bottone disabilitato
      buttonText = 'Torneo in Corso';
      backgroundColor = Colors.grey;
      foregroundColor = Colors.white70;
      onPressed = null;
    } else if (isRegistered) {
      // Iscritto ma torneo non iniziato - può cancellarsi
      buttonText = 'Cancella Iscrizione';
      backgroundColor = Colors.red;
      foregroundColor = Colors.white;
      onPressed = _toggleRegistration;
    } else {
      // Non iscritto - può iscriversi
      buttonText = 'Iscriviti al Torneo';
      backgroundColor = const Color(0xFF00E676);
      foregroundColor = Colors.black;
      onPressed = _toggleRegistration;
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        disabledBackgroundColor: Colors.grey,
        disabledForegroundColor: Colors.white70,
      ),
      onPressed: onPressed,
      child: Text(
        buttonText,
        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00E676)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantCard(Map<String, dynamic> participant) {
    final player = participant['players'];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: player['avatar_url'] != null
                ? NetworkImage(player['avatar_url'])
                : null,
            child: player['avatar_url'] == null
                ? const Icon(Icons.person, size: 20)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player['name'] ?? 'Giocatore',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (player['city'] != null)
                  Text(
                    player['city'],
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              player['level'] ?? 'N/A',
              style: GoogleFonts.poppins(
                color: const Color(0xFF00E676),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null) return 'Data non disponibile';
    try {
      final dt = DateTime.parse(date);
      return DateFormat('d MMMM y', 'it_IT').format(dt);
    } catch (_) {
      return date;
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
            widget.tournament['name'] ?? 'Torneo',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          bottom: TabBar(
            indicatorColor: const Color(0xFF00E676),
            labelColor: const Color(0xFF00E676),
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'Dettagli'),
              Tab(text: 'Gironi'),
            ],
          ),
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E676)),
              )
            : TabBarView(
                children: [
                  _buildDetailsTab(),
                  TournamentGroupsPage(
                    tournament: widget.tournament,
                    isOrganizer: widget.isOrganizer,
                  ),
                ],
              ),
      ),
    );
  }
}
