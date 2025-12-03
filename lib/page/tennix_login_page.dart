import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tennix/page/profil_setup_page.dart';
import 'package:tennix/services/notification_service.dart';
import 'package:tennix/widget/google_logo_widget.dart';

class TennixLoginPage extends StatefulWidget {
  const TennixLoginPage({super.key});

  @override
  State<TennixLoginPage> createState() => _TennixLoginPageState();
}

class _TennixLoginPageState extends State<TennixLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  final supabase = Supabase.instance.client;

  Future<void> _signInWithEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Salva il token FCM dopo login
      await saveFcmToken();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Accesso effettuato!')));
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileSetupPage()),
        );
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('Iniziando accesso con Google...');

      // Web Client ID corretto dal file google-services.json
      const webClientId =
          '388887208445-gaq49mlr51ses6agg0ao7ef6a08qfkpj.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
        scopes: ['email', 'profile'],
      );

      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('Selezione account Google annullata dall\'utente');
        setState(() {
          _isLoading = false;
          _errorMessage = 'Accesso con Google annullato';
        });
        return;
      }

      debugPrint('Account Google selezionato: ${googleUser.email}');
      final googleAuth = await googleUser.authentication;
      debugPrint('Token Google ottenuti');

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        debugPrint(
          'Errore: Token mancanti - Access Token: ${googleAuth.accessToken != null}, ID Token: ${googleAuth.idToken != null}',
        );
        setState(
          () =>
              _errorMessage = 'Errore: Impossibile ottenere i token di accesso',
        );
        return;
      }

      // Autenticazione con Supabase usando i token di Google
      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken!,
      );
      // Salva il token FCM dopo login Google
      await saveFcmToken();

      debugPrint('Autenticazione Supabase completata: ${response.user?.email}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accesso con Google riuscito!')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProfileSetupPage()),
        );
      }
    } on AuthException catch (e) {
      debugPrint('Errore AuthException: ${e.message}');
      setState(() => _errorMessage = 'Errore di autenticazione: ${e.message}');
    } catch (e) {
      debugPrint('Errore generico: $e');
      setState(() => _errorMessage = 'Errore di accesso con Google: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registrazione completata! Verifica la tua email.'),
          ),
        );
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'TENNIX 🎾',
                style: TextStyle(
                  fontSize: 40,
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'Email',
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
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Password',
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
              const SizedBox(height: 20),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator(color: Colors.greenAccent)
                  : Column(
                      children: [
                        ElevatedButton(
                          onPressed: _signInWithEmail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Accedi'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _signUp,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.greenAccent),
                            foregroundColor: Colors.greenAccent,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Registrati'),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'oppure',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _signInWithGoogle,
                          icon: GoogleLogoWidget(
                            size: 24,
                            background: Colors.white,
                          ),
                          label: const Text('Accedi con Google'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
}
