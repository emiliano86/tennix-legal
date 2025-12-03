import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DoublesMatchResultPage extends StatefulWidget {
  final Map<String, dynamic> match;
  final VoidCallback onResultSubmitted;

  const DoublesMatchResultPage({
    Key? key,
    required this.match,
    required this.onResultSubmitted,
  }) : super(key: key);

  @override
  State<DoublesMatchResultPage> createState() => _DoublesMatchResultPageState();
}

class _DoublesMatchResultPageState extends State<DoublesMatchResultPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  // Controllers per i punteggi
  final _pair1Set1Controller = TextEditingController();
  final _pair2Set1Controller = TextEditingController();
  final _pair1Set2Controller = TextEditingController();
  final _pair2Set2Controller = TextEditingController();
  final _pair1Set3Controller = TextEditingController();
  final _pair2Set3Controller = TextEditingController();

  @override
  void dispose() {
    _pair1Set1Controller.dispose();
    _pair2Set1Controller.dispose();
    _pair1Set2Controller.dispose();
    _pair2Set2Controller.dispose();
    _pair1Set3Controller.dispose();
    _pair2Set3Controller.dispose();
    super.dispose();
  }

  String _getPairDisplayName(Map<String, dynamic> pair) {
    if (pair['pair_name'] != null && pair['pair_name'].toString().isNotEmpty) {
      return pair['pair_name'];
    }
    final player1Name = pair['player1']?['name'] ?? 'Giocatore 1';
    final player2Name = pair['player2']?['name'] ?? 'Giocatore 2';
    return '$player1Name / $player2Name';
  }

  bool _validateScores() {
    // Validazione Set 1 e 2 (obbligatori)
    final p1s1 = int.tryParse(_pair1Set1Controller.text);
    final p2s1 = int.tryParse(_pair2Set1Controller.text);
    final p1s2 = int.tryParse(_pair1Set2Controller.text);
    final p2s2 = int.tryParse(_pair2Set2Controller.text);

    if (p1s1 == null || p2s1 == null || p1s2 == null || p2s2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci i punteggi dei primi 2 set'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    // Verifica che i set siano validi (uno deve essere a 6)
    if (!_isValidSet(p1s1, p2s1) || !_isValidSet(p1s2, p2s2)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Punteggio non valido. Un giocatore deve vincere 6 game',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    // Controlla se serve il terzo set
    final pair1Sets = (p1s1 > p2s1 ? 1 : 0) + (p1s2 > p2s2 ? 1 : 0);
    final pair2Sets = (p2s1 > p1s1 ? 1 : 0) + (p2s2 > p1s2 ? 1 : 0);

    if (pair1Sets == pair2Sets) {
      // Serve il terzo set
      final p1s3 = int.tryParse(_pair1Set3Controller.text);
      final p2s3 = int.tryParse(_pair2Set3Controller.text);

      if (p1s3 == null || p2s3 == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inserisci il punteggio del tie-break (terzo set)'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      // Validazione tie-break (uno deve arrivare a 10)
      if (!_isValidTieBreak(p1s3, p2s3)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tie-break non valido. Il vincitore deve arrivare a 10 punti',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    } else {
      // Non serve il terzo set, verifica che non sia inserito
      if (_pair1Set3Controller.text.isNotEmpty ||
          _pair2Set3Controller.text.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Il terzo set non è necessario (2-0)'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    }

    return true;
  }

  bool _isValidSet(int score1, int score2) {
    // Un set normale: uno deve vincere 6 game
    // con almeno 2 di differenza o 7-5 o 7-6 (tie-break)
    if (score1 == 6 && score2 <= 4) return true;
    if (score2 == 6 && score1 <= 4) return true;
    if (score1 == 7 && (score2 == 5 || score2 == 6)) return true;
    if (score2 == 7 && (score1 == 5 || score1 == 6)) return true;
    return false;
  }

  bool _isValidTieBreak(int score1, int score2) {
    // Tie-break a 10 punti: uno deve arrivare a 10
    // con almeno 2 punti di differenza
    if (score1 >= 10 && score1 - score2 >= 2) return true;
    if (score2 >= 10 && score2 - score1 >= 2) return true;
    return false;
  }

  Future<void> _submitResult() async {
    if (!_validateScores()) return;

    setState(() => _isLoading = true);

    try {
      final p1s1 = int.parse(_pair1Set1Controller.text);
      final p2s1 = int.parse(_pair2Set1Controller.text);
      final p1s2 = int.parse(_pair1Set2Controller.text);
      final p2s2 = int.parse(_pair2Set2Controller.text);
      final p1s3 = _pair1Set3Controller.text.isEmpty
          ? null
          : int.parse(_pair1Set3Controller.text);
      final p2s3 = _pair2Set3Controller.text.isEmpty
          ? null
          : int.parse(_pair2Set3Controller.text);

      await supabase
          .from('tournament_doubles_matches')
          .update({
            'pair1_set1': p1s1,
            'pair2_set1': p2s1,
            'pair1_set2': p1s2,
            'pair2_set2': p2s2,
            'pair1_set3': p1s3,
            'pair2_set3': p2s3,
            'match_date': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.match['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Risultato registrato! 🎾'),
          backgroundColor: Color(0xFF00E676),
        ),
      );

      widget.onResultSubmitted();
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Errore inserimento risultato: $e');
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
    final pair1 = widget.match['pair1'];
    final pair2 = widget.match['pair2'];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Inserisci Risultato',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info match
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    _getPairDisplayName(pair1),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'VS',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF00E676),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    _getPairDisplayName(pair2),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Info formato
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF00E676).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF00E676),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Formato: 2 set a 6 game. Se 1-1, tie-break a 10 punti',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF00E676),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Set 1
            _buildSetInput(
              'Primo Set',
              _pair1Set1Controller,
              _pair2Set1Controller,
              _getPairDisplayName(pair1),
              _getPairDisplayName(pair2),
            ),
            const SizedBox(height: 20),

            // Set 2
            _buildSetInput(
              'Secondo Set',
              _pair1Set2Controller,
              _pair2Set2Controller,
              _getPairDisplayName(pair1),
              _getPairDisplayName(pair2),
            ),
            const SizedBox(height: 20),

            // Set 3 (Tie-break)
            Text(
              'Terzo Set (Tie-break a 10 punti)',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Solo se il risultato è 1-1',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _buildSetInput(
              null,
              _pair1Set3Controller,
              _pair2Set3Controller,
              _getPairDisplayName(pair1),
              _getPairDisplayName(pair2),
              isTieBreak: true,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitResult,
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
                    'Conferma Risultato',
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

  Widget _buildSetInput(
    String? title,
    TextEditingController controller1,
    TextEditingController controller2,
    String pair1Name,
    String pair2Name, {
    bool isTieBreak = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pair1Name,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: controller1,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: GoogleFonts.poppins(color: Colors.white24),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  Text(
                    '-',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pair2Name,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: controller2,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: GoogleFonts.poppins(color: Colors.white24),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
