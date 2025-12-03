import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:tennix/page/tournament_detail_page_new.dart';

class TournamentHistoryPage extends StatefulWidget {
  const TournamentHistoryPage({Key? key}) : super(key: key);

  @override
  State<TournamentHistoryPage> createState() => _TournamentHistoryPageState();
}

class _TournamentHistoryPageState extends State<TournamentHistoryPage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  List<dynamic> archivedTournaments = [];
  List<dynamic> completedTournaments = [];

  @override
  void initState() {
    super.initState();
    _loadHistoricalTournaments();
  }

  Future<void> _loadHistoricalTournaments() async {
    setState(() => loading = true);
    try {
      // Carica tornei completati (recenti, ultimi 7 giorni)
      final completed = await supabase
          .from('tournaments')
          .select('id, name, type, status, start_date, created_at, image_url')
          .eq('status', 'completed')
          .order('created_at', ascending: false);

      // Carica tornei archiviati (più vecchi di 7 giorni)
      final archived = await supabase
          .from('tournaments')
          .select('id, name, type, status, start_date, created_at, image_url')
          .eq('status', 'archived')
          .order('created_at', ascending: false);

      setState(() {
        completedTournaments = completed;
        archivedTournaments = archived;
        loading = false;
      });
    } catch (e) {
      debugPrint('Errore caricamento storico: $e');
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Storico Tornei',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Colors.white70,
            onPressed: _loadHistoricalTournaments,
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tornei completati recenti
                  if (completedTournaments.isNotEmpty) ...[
                    Text(
                      'Completati di Recente',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFFD700),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...completedTournaments.map(
                      (tournament) =>
                          _buildTournamentCard(tournament, isRecent: true),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Tornei archiviati
                  if (archivedTournaments.isNotEmpty) ...[
                    Text(
                      'Archivio',
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...archivedTournaments.map(
                      (tournament) =>
                          _buildTournamentCard(tournament, isRecent: false),
                    ),
                  ],

                  // Nessun torneo
                  if (completedTournaments.isEmpty &&
                      archivedTournaments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          'Nessun torneo completato',
                          style: GoogleFonts.poppins(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildTournamentCard(
    Map<String, dynamic> tournament, {
    required bool isRecent,
  }) {
    final dateFormat = DateFormat('dd MMM yyyy', 'it_IT');
    final startDate = tournament['start_date'] != null
        ? dateFormat.format(DateTime.parse(tournament['start_date']))
        : 'Data non disponibile';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TournamentDetailPage(
              tournament: tournament,
              onRegistrationChanged: (bool registered) {},
              initialRegistrationState: false,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isRecent
                ? [const Color(0xFF1E293B), const Color(0xFF334155)]
                : [
                    const Color(0xFF1E293B).withOpacity(0.5),
                    const Color(0xFF334155).withOpacity(0.5),
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRecent
                ? const Color(0xFFFFD700).withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icona torneo
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isRecent
                    ? const Color(0xFFFFD700).withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.emoji_events,
                color: isRecent ? const Color(0xFFFFD700) : Colors.grey,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),

            // Info torneo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tournament['name'] ?? 'Torneo',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.grey, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        startDate,
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isRecent
                          ? const Color(0xFFFFD700).withOpacity(0.2)
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isRecent ? 'COMPLETATO' : 'ARCHIVIATO',
                      style: GoogleFonts.poppins(
                        color: isRecent ? const Color(0xFFFFD700) : Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Freccia
            Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
