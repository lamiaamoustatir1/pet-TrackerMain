import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignInScreen extends StatefulWidget {
  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _error = '';

  void signIn() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() {
        _error = 'Erreur de connexion';
      });
    }
  }

  void signInAsGuest() async {
    try {
      await _auth.signInAnonymously();
      Navigator.pushReplacementNamed(context, '/homeGuest');
    } catch (e) {
      print('Erreur Guest : $e');
      setState(() {
        _error = 'Erreur mode invité';
      });
    }
  }

  void signUp() {
    Navigator.pushNamed(context, '/signUp');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Se connecter')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Mot de passe'),
              obscureText: true,
            ),
            if (_error.isNotEmpty) ...[
              SizedBox(height: 10),
              Text(_error, style: TextStyle(color: Colors.red)),
            ],
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: signIn,
              child: Text('Se connecter'),
            ),
            ElevatedButton(
              onPressed: signInAsGuest,
              child: Text('Continuer en tant que Guest'),
            ),
            TextButton(
              onPressed: signUp,
              child: Text('Créer un compte'),
            ),
          ],
        ),
      ),
    );
  }
} 