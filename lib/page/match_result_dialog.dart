import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MatchResultDialog extends StatefulWidget {
  final String player1Name;
  final String player2Name;

  const MatchResultDialog({
    super.key,
    required this.player1Name,
    required this.player2Name,
  });

  @override
  State<MatchResultDialog> createState() => _MatchResultDialogState();
}

class _MatchResultDialogState extends State<MatchResultDialog> {
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
