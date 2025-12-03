import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> userProfile;

  const EditProfilePage({super.key, required this.userProfile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  File? _avatarImage;
  String? _avatarUrl;

  late TextEditingController _usernameController;
  late TextEditingController _cityController;
  late TextEditingController _bioController;
  late String _selectedLevel;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.userProfile['username'],
    );
    _cityController = TextEditingController(
      text: widget.userProfile['city'] ?? '',
    );
    _bioController = TextEditingController(
      text: widget.userProfile['bio'] ?? '',
    );
    _selectedLevel = widget.userProfile['level'] ?? 'Principiante';
    _avatarUrl = widget.userProfile['avatar_url'];
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _avatarImage = File(pickedFile.path);
      });

      // Mostra un messaggio che l'immagine verrà caricata al salvataggio
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Immagine selezionata. Salva le modifiche per caricarla.',
            ),
            backgroundColor: Color(0xFF00E676),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<String?> _uploadAvatar() async {
    if (_avatarImage == null) return _avatarUrl;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Utente non autenticato');
      }

      debugPrint('📤 Inizio upload avatar...');

      final bytes = await _avatarImage!.readAsBytes();
      final fileExt = _avatarImage!.path.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '${user.id}/$fileName';

      debugPrint('📁 Upload su: $filePath (${bytes.length} bytes)');

      // Carica il file su Supabase Storage
      await supabase.storage
          .from('avatars')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
              upsert: true,
            ),
          );

      // Ottieni l'URL pubblico
      final publicUrl = supabase.storage.from('avatars').getPublicUrl(filePath);

      debugPrint('✅ Upload completato: $publicUrl');

      return publicUrl;
    } catch (e, stackTrace) {
      debugPrint('❌ Errore upload avatar: $e');
      debugPrint('Stack: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore caricamento immagine: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Rilancia l'errore per bloccare il salvataggio
      rethrow;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not found');

      // Carica l'avatar se è stato selezionato
      String? newAvatarUrl = await _uploadAvatar();

      // Se non c'è un avatar caricato, usa l'URL di default
      if (newAvatarUrl == null || newAvatarUrl.isEmpty) {
        final name = _usernameController.text.trim();
        newAvatarUrl =
            'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=0D47A1&color=fff';
      }

      // Prepara i dati da salvare
      final timestamp = DateTime.now().toIso8601String();
      final name = _usernameController.text.trim();
      final city = _cityController.text.trim();
      final bio = _bioController.text.trim();

      // Dati per la tabella profiles
      final profileData = {
        'id': user.id,
        'name': name, // Aggiungiamo anche il campo name
        'city': city,
        'bio': bio,
        'level': _selectedLevel,
        'avatar_url': newAvatarUrl,
        'updated_at': timestamp,
      };

      // Dati per la tabella players
      final playerData = {
        'id': user.id,
        'name': name,
        'city': city,
        'level': _selectedLevel,
        'avatar_url': newAvatarUrl,
        'points': 0, // Aggiungiamo i punti iniziali
        'updated_at': timestamp,
      };

      debugPrint('Salvataggio profilo con dati: $profileData');
      debugPrint('Salvataggio player con dati: $playerData');

      // Salva in entrambe le tabelle usando upsert
      await Future.wait([
        supabase.from('profiles').upsert(profileData),

        supabase.from('players').upsert(playerData),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profilo aggiornato con successo!'),
            backgroundColor: Color(0xFF00E676),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          'Modifica Profilo',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar selector
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: const Color(0xFF1E1E1E),
                              backgroundImage: _avatarImage != null
                                  ? FileImage(_avatarImage!) as ImageProvider
                                  : _avatarUrl != null
                                  ? NetworkImage(_avatarUrl!)
                                  : null,
                              child: _avatarImage == null && _avatarUrl == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.white54,
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E676),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF121212),
                                    width: 3,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 20,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Tocca per modificare l\'avatar',
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Informazioni Base'),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _usernameController,
                      label: 'Username',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Inserisci uno username';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _cityController,
                      label: 'Città',
                      icon: Icons.location_city,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Livello di Gioco'),
                    const SizedBox(height: 16),
                    _buildLevelSelector(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Bio'),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _bioController,
                      label: 'Racconta qualcosa di te',
                      icon: Icons.edit,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _saveProfile,
                        child: Text(
                          'Salva Modifiche',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      style: GoogleFonts.poppins(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.white70),
        prefixIcon: Icon(icon, color: const Color(0xFF00E676)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00E676)),
        ),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
      ),
    );
  }

  Widget _buildLevelSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedLevel,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E1E1E),
          style: GoogleFonts.poppins(color: Colors.white),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00E676)),
          items: ['Principiante', 'Intermedio', 'Avanzato', 'Pro'].map((
            String level,
          ) {
            return DropdownMenuItem<String>(value: level, child: Text(level));
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => _selectedLevel = newValue);
            }
          },
        ),
      ),
    );
  }
}
