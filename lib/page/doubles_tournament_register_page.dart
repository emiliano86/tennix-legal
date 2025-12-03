import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DoublesTournamentRegisterPage extends StatefulWidget {
  final Map<String, dynamic> tournament;

  const DoublesTournamentRegisterPage({Key? key, required this.tournament})
    : super(key: key);

  @override
  State<DoublesTournamentRegisterPage> createState() =>
      _DoublesTournamentRegisterPageState();
}

class _DoublesTournamentRegisterPageState
    extends State<DoublesTournamentRegisterPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _selectedPartnerId;
  List<Map<String, dynamic>> _availablePlayers = [];
  final TextEditingController _pairNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAvailablePlayers();
  }

  @override
  void dispose() {
    _pairNameController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailablePlayers() async {
    setState(() => _isLoading = true);

    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Carica tutti i giocatori tranne l'utente corrente
      final playersResponse = await supabase
          .from('players')
          .select('id, name, avatar_url, level, city')
          .neq('id', currentUserId)
          .order('name');

      // Carica le coppie già registrate per questo torneo
      final pairsResponse = await supabase
          .from('tournament_pairs')
          .select('player1_id, player2_id')
          .eq('tournament_id', widget.tournament['id']);

      // Crea un set di giocatori già registrati
      final Set<String> registeredPlayerIds = {};
      for (var pair in pairsResponse) {
        registeredPlayerIds.add(pair['player1_id']);
        registeredPlayerIds.add(pair['player2_id']);
      }

      // Filtra i giocatori disponibili (non ancora registrati)
      final availablePlayers = (playersResponse as List)
          .where((player) => !registeredPlayerIds.contains(player['id']))
          .cast<Map<String, dynamic>>()
          .toList();

      setState(() {
        _availablePlayers = availablePlayers;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Errore caricamento giocatori: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _registerPair() async {
    if (_selectedPartnerId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seleziona un partner')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Utente non autenticato');

      // Verifica che l'utente corrente non sia già registrato
      final existingPairs = await supabase
          .from('tournament_pairs')
          .select()
          .eq('tournament_id', widget.tournament['id'])
          .or('player1_id.eq.$currentUserId,player2_id.eq.$currentUserId');

      if (existingPairs.isNotEmpty) {
        throw Exception('Sei già registrato a questo torneo');
      }

      // Registra la coppia
      await supabase.from('tournament_pairs').insert({
        'tournament_id': widget.tournament['id'],
        'player1_id': currentUserId,
        'player2_id': _selectedPartnerId,
        'pair_name': _pairNameController.text.trim().isEmpty
            ? null
            : _pairNameController.text.trim(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coppia registrata con successo! 🎾'),
          backgroundColor: Color(0xFF00E676),
        ),
      );

      Navigator.pop(context, true); // Ritorna true per ricaricare la pagina
    } catch (e) {
      debugPrint('Errore registrazione: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Registra Coppia',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info torneo
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Color(0xFF00E676),
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.tournament['name'] ?? 'Torneo',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Torneo di Doppio • 16 coppie',
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
                  const SizedBox(height: 24),

                  // Nome coppia (opzionale)
                  Text(
                    'Nome Coppia (opzionale)',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pairNameController,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Es: I Campioni',
                      hintStyle: GoogleFonts.poppins(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Seleziona partner
                  Text(
                    'Seleziona il tuo Partner',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_availablePlayers.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Nessun giocatore disponibile',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._availablePlayers.map((player) {
                      final isSelected = _selectedPartnerId == player['id'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPartnerId = player['id'];
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF00E676).withOpacity(0.2)
                                : const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF00E676)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFF0D47A1),
                                backgroundImage: player['avatar_url'] != null
                                    ? NetworkImage(player['avatar_url'])
                                    : null,
                                child: player['avatar_url'] == null
                                    ? Text(
                                        player['name']
                                            .toString()
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      player['name'] ?? 'Giocatore',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (player['level'] != null) ...[
                                          Text(
                                            player['level'],
                                            style: GoogleFonts.poppins(
                                              color: const Color(0xFF00E676),
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        if (player['city'] != null)
                                          Text(
                                            player['city'],
                                            style: GoogleFonts.poppins(
                                              color: Colors.white70,
                                              fontSize: 13,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Checkmark
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF00E676),
                                  size: 28,
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _registerPair,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : Text(
                    'Registra Coppia',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
