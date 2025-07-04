import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cinController = TextEditingController();
  final TextEditingController _adresseController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  XFile? _idImage;
  bool _isScanning = false;
  String _error = '';
  bool _obscurePassword = true;

  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _idImage = image;
        _isScanning = true;
      });
      await scanTextFromImage(image);
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> scanTextFromImage(XFile image) async {
    final inputImage = InputImage.fromFilePath(image.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    String? extractedNom;
    String? extractedPrenom;
    String? extractedCIN;
    String? extractedAdresse;

    String? mrzLine1;
    String? mrzLine2;

    // Pass 1: Find MRZ and Address lines
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        String lineText = line.text.replaceAll(' ', '').toUpperCase();
        // Heuristic for MRZ Line 1 (contains the ID)
        if (lineText.startsWith('I') && lineText.contains('<') && lineText.contains(RegExp(r'\d'))) {
          mrzLine1 = lineText;
        } else if (lineText.contains('<<') && !lineText.contains(RegExp(r'[0-9]'))) {
          mrzLine2 = lineText;
        }
        // Also look for address line
        if (line.text.trim().toUpperCase().startsWith('ADRESSE')) {
          extractedAdresse = line.text.trim().substring(7).trim();
        }
      }
    }

    // Pass 2: Process MRZ lines
    if (mrzLine2 != null) {
      List<String> parts = mrzLine2.split('<<');
      if (parts.length >= 2) {
        extractedNom = parts[0].replaceAll('<', ' ').trim();
        extractedPrenom = parts[1].replaceAll(RegExp(r'<.*'), '').trim();
      }
    }
    if (mrzLine1 != null) {
      final regex = RegExp(r'<(\d)([A-Z]{1,2}\d{5,7})');
      final match = regex.firstMatch(mrzLine1);
      if (match != null && match.groupCount >= 2) {
        extractedCIN = match.group(2);
      }
    }

    // Pass 3: Fallback search for CIN if MRZ parsing fails
    if (extractedCIN == null) {
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          String lineText = line.text.trim().toUpperCase();
          if (lineText.startsWith('N°')) {
            String potentialId = lineText.substring(2).trim().replaceAll(' ', '');
            RegExp cinRegex = RegExp(r'^[A-Z]{1,2}\d{6,7} 0$');
            if (cinRegex.hasMatch(potentialId)) {
              extractedCIN = potentialId;
              break;
            }
          }
        }
        if (extractedCIN != null) break;
      }
    }

    setState(() {
      if (extractedNom != null && extractedNom.isNotEmpty) _nomController.text = extractedNom;
      if (extractedPrenom != null && extractedPrenom.isNotEmpty) _prenomController.text = extractedPrenom;
      if (extractedCIN != null && extractedCIN.isNotEmpty) _cinController.text = extractedCIN;
      if (extractedAdresse != null && extractedAdresse.isNotEmpty) _adresseController.text = extractedAdresse;
    });
  }

  Future<void> _register(BuildContext context) async {
    setState(() {
      _error = '';
    });
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final uid = cred.user?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'nom': _nomController.text.trim(),
          'prenom': _prenomController.text.trim(),
          'cin': _cinController.text.trim(),
          'adresse': _adresseController.text.trim(),
          'telephone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: {'isGuest': false},
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message ?? 'Erreur d\'inscription';
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur d\'inscription: $e';
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nomController.dispose();
    _prenomController.dispose();
    _cinController.dispose();
    _adresseController.dispose();
    _phoneController.dispose();
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
              Padding(
                padding: const EdgeInsets.only(top: 32, bottom: 16),
                child: Icon(
                  Icons.pets,
                  size: 100,
                  color: brown,
                ),
              ),
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
                      'Créer un compte',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: brown,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      icon: Icon(Icons.camera_alt, color: brown),
                      label: Text('Scanner ma carte', style: TextStyle(color: brown)),
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
                      onPressed: pickImage,
                    ),
                    if (_idImage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Image.file(
                          File(_idImage!.path),
                          height: 100,
                        ),
                      ),
                    if (_isScanning)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    const SizedBox(height: 16),
                    // CHAMPS
                    _buildField(_nomController, 'Nom', Icons.person, brown, fieldColor),
                    const SizedBox(height: 12),
                    _buildField(_prenomController, 'Prénom', Icons.person_outline, brown, fieldColor),
                    const SizedBox(height: 12),
                    _buildField(_cinController, 'CIN', Icons.badge, brown, fieldColor),
                    const SizedBox(height: 12),
                    _buildField(_adresseController, 'Adresse', Icons.home, brown, fieldColor),
                    const SizedBox(height: 12),
                    _buildField(_phoneController, 'Téléphone', Icons.phone, brown, fieldColor, keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    _buildField(_emailController, 'Email', Icons.email, brown, fieldColor, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    // Mot de passe avec oeil
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
                        hintText: 'Mot de passe',
                        hintStyle: TextStyle(color: brown.withOpacity(0.7)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_error.isNotEmpty)
                      Text(_error, style: const TextStyle(color: Colors.red)),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _register(context),
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
                        child: const Text('Créer mon compte'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Déjà inscrit ?', style: TextStyle(color: brown.withOpacity(0.7))),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: brown.withOpacity(0.7),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          child: const Text('Se connecter'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String hint, IconData icon, Color brown, Color fieldColor, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: brown),
      decoration: InputDecoration(
        filled: true,
        fillColor: fieldColor,
        prefixIcon: Icon(icon, color: brown),
        hintText: hint,
        hintStyle: TextStyle(color: brown.withOpacity(0.7)),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
