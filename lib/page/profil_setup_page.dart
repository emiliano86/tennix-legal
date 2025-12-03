import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tennix/services/notification_service.dart';
import 'package:tennix/page/main_page.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedLevel = 'Principiante';
  File? _avatarImage;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _avatarImage = File(pickedFile.path));
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Inserisci il tuo nome')));
      return;
    }

    if (_cityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Inserisci la tua città')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Utente non autenticato');
      }

      String imageUrl;
      if (_avatarImage != null) {
        // Upload con lo stesso formato di edit_profile_page
        final bytes = await _avatarImage!.readAsBytes();
        final fileExt = _avatarImage!.path.split('.').last.toLowerCase();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = '${user.id}/$fileName';

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

        imageUrl = supabase.storage.from('avatars').getPublicUrl(filePath);
      } else {
        // Usa un URL predefinito per l'avatar di default
        imageUrl =
            'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_nameController.text.trim())}&background=0D47A1&color=fff';
      }

      try {
        final timestamp = DateTime.now().toIso8601String();
        final name = _nameController.text.trim();
        final city = _cityController.text.trim();
        final phone = _phoneController.text.trim();

        // Salviamo i dati in tutte e tre le tabelle
        await Future.wait([
          // Profilo utente
          supabase.from('profiles').upsert({
            'id': user.id,
            'email': user.email,
            'name': name,
            'city': city,
            'phone': phone,
            'level': _selectedLevel,
            'avatar_url': imageUrl,
            'updated_at': timestamp,
          }),

          // Tabella players
          supabase.from('players').upsert({
            'id': user.id,
            'name': name,
            'city': city,
            'phone': phone,
            'level': _selectedLevel,
            'avatar_url': imageUrl,
            'updated_at': timestamp,
            'created_at': timestamp,
          }),

          // Leaderboard
          supabase.from('leaderboard').upsert({
            'player_id': user.id,
            'points': 0, // Punti iniziali per nuovo giocatore
            'rank': 0,
          }),
        ]);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profilo salvato con successo!')),
          );
          // Salva il token FCM dopo il setup profilo
          await saveFcmToken();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isProfileSetupDone', true);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainPage()),
            (route) => false,
          );
        }
      } on PostgrestException catch (error) {
        if (mounted) {
          String errorMessage = 'Errore durante il salvataggio del profilo: ';
          if (error.message.contains('violates foreign key constraint')) {
            errorMessage += 'Errore di riferimento nel database';
          } else if (error.message.contains('duplicate key value')) {
            errorMessage += 'Profilo già esistente';
          } else {
            errorMessage += error.message;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore inaspettato: ${e.toString()}'),
            duration: const Duration(seconds: 5),
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Crea il tuo profilo'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white10,
                backgroundImage: _avatarImage != null
                    ? FileImage(_avatarImage!)
                    : null,
                child: _avatarImage == null
                    ? const Icon(
                        Icons.camera_alt,
                        color: Colors.white70,
                        size: 32,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Nome completo',
                filled: true,
                fillColor: Colors.white10,
                hintStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(
                hintText: 'Città',
                filled: true,
                fillColor: Colors.white10,
                hintStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: 'Telefono',
                filled: true,
                fillColor: Colors.white10,
                hintStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedLevel,
              dropdownColor: Colors.black,
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Principiante',
                  child: Text('Principiante'),
                ),
                DropdownMenuItem(
                  value: 'Intermedio',
                  child: Text('Intermedio'),
                ),
                DropdownMenuItem(value: 'Avanzato', child: Text('Avanzato')),
                DropdownMenuItem(value: 'Pro', child: Text('Pro')),
              ],
              style: const TextStyle(color: Colors.white),
              onChanged: (value) => setState(() => _selectedLevel = value!),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator(color: Colors.greenAccent)
                : ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Salva profilo'),
                  ),
          ],
        ),
      ),
    );
  }
}
