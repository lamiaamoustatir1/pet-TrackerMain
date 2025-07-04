import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _obscurePassword = true;

  Future<void> _signIn(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: {'isGuest': false},
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInAnonymously(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isGuest', true);
      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: {'isGuest': true},
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur connexion guest: $e')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color background = const Color(0xFFFEF9EA);
    final Color cardColor = const Color(0xFFF5E6D6);
    final Color fieldColor = const Color(0xFFEADBC8);
    final Color brown = const Color(0xFFA37551);
    final Color greyText = Colors.grey.shade600;

    return Scaffold(
      backgroundColor: background,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LOGO
              Padding(
                padding: const EdgeInsets.only(top: 32, bottom: 16),
                child: Icon(
                  Icons.pets,
                  size: 100,
                  color: Color(0xFFA37551),
                ),
              ),
              // CARTE DE CONNEXION
              Container(
                width: 370,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: brown.withOpacity(0.18)),
                  boxShadow: [
                    BoxShadow(
                      color: brown.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Connexion',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w600,
                        color: brown,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // EMAIL FIELD
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: brown),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: fieldColor,
                        prefixIcon: Icon(Icons.email, color: brown),
                        hintText: 'Entrez votre email...',
                        hintStyle: TextStyle(color: brown.withOpacity(0.7)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // PASSWORD FIELD
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(color: brown),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: fieldColor,
                        prefixIcon: Icon(Icons.lock, color: brown),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: brown.withOpacity(0.5),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        hintText: 'Entrez votre mot de passe...',
                        hintStyle: TextStyle(color: brown.withOpacity(0.7)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Mot de passe oublié centré
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: () async {
                          final emailController = TextEditingController();
                          await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Réinitialiser le mot de passe'),
                              content: TextField(
                                controller: emailController,
                                decoration: const InputDecoration(labelText: 'Email'),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Annuler'),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    try {
                                      await FirebaseAuth.instance.sendPasswordResetEmail(
                                          email: emailController.text.trim());
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('Email de réinitialisation envoyé.')),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Erreur: $e')),
                                      );
                                    }
                                  },
                                  child: const Text('Envoyer'),
                                ),
                              ],
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: brown,
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                        ),
                        child: const Text('Mot de passe oublié ?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // BOUTON SE CONNECTER
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      ElevatedButton(
                        onPressed: () => _signIn(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: fieldColor,
                          foregroundColor: brown,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: const Text('Se connecter'),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 18),
                    // LIEN INSCRIPTION
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Pas encore inscrit ?', style: TextStyle(color: brown.withOpacity(0.7))),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/register');
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: brown.withOpacity(0.7),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          child: const Text('Créer un compte'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // BOUTON CONTINUER EN INVITÉ
              TextButton(
                onPressed: () => _signInAnonymously(context),
                style: TextButton.styleFrom(
                  foregroundColor: greyText,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                child: const Text('Continuer sans compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
