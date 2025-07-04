import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _cinController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = "Utilisateur non connecté.";
      });
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data != null) {
        _usernameController.text = data['prenom'] ?? '';
        _emailController.text = data['email'] ?? user.email ?? '';
        _fullNameController.text = data['nom'] ?? '';
        _cinController.text = data['cin'] ?? '';
        _phoneController.text = data['telephone'] ?? '';
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur de chargement: $e';
      });
    }
    setState(() {
      _loading = false;
    });
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() { _error = null; _loading = true; });
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'prenom': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'nom': _fullNameController.text.trim(),
        'cin': _cinController.text.trim(),
        'telephone': _phoneController.text.trim(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modifications enregistrées.')));
    } catch (e) {
      setState(() { _error = 'Erreur de sauvegarde: $e'; });
    }
    setState(() { _loading = false; });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _fullNameController.dispose();
    _cinController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color brown = const Color(0xFFA37551);
    final Color background = const Color(0xFFFEF9EA);
    final Color fieldColor = const Color(0xFFEAD7C0);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleSpacing: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 8),
            Text('Paramètres', style: TextStyle(color: brown, fontWeight: FontWeight.bold, fontSize: 24)),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: brown),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                child: Container(
                  width: 400,
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Nom de famille', style: TextStyle(color: brown, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _fullNameController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: fieldColor,
                          hintText: 'Entrez votre nom de famille...',
                          hintStyle: TextStyle(color: brown.withOpacity(0.7)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Prénom', style: TextStyle(color: brown, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: fieldColor,
                          hintText: 'Entrez votre prénom...',
                          hintStyle: TextStyle(color: brown.withOpacity(0.7)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Email', style: TextStyle(color: brown, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: fieldColor,
                          hintText: 'Entrez votre email...',
                          hintStyle: TextStyle(color: brown.withOpacity(0.7)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Numéro de téléphone', style: TextStyle(color: brown, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: fieldColor,
                          hintText: '+212...',
                          hintStyle: TextStyle(color: brown.withOpacity(0.7)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('CIN', style: TextStyle(color: brown, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _cinController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: fieldColor,
                          hintText: 'Entrez votre CIN...',
                          hintStyle: TextStyle(color: brown.withOpacity(0.7)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (_error != null) ...[
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: fieldColor,
                            foregroundColor: brown,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: brown.withOpacity(0.18)),
                            ),
                            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Enregistrer'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _logout,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: brown,
                            side: BorderSide(color: brown.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Déconnexion'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
} 