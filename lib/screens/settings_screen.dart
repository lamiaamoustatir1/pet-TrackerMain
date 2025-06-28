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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    const Text('PET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        Icon(Icons.settings, color: Colors.brown),
                        SizedBox(width: 8),
                        Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: 'Username...'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'email...'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(labelText: 'full name...'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cinController,
                      decoration: const InputDecoration(labelText: 'National id...'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: '+212...'),
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                    ],
                    ElevatedButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _logout,
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 