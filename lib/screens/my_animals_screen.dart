import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'animal_detail_screen.dart';

class MyAnimalsScreen extends StatefulWidget {
  const MyAnimalsScreen({super.key});

  @override
  State<MyAnimalsScreen> createState() => _MyAnimalsScreenState();
}

class _MyAnimalsScreenState extends State<MyAnimalsScreen> {
  String? selectedCategoryId;
  bool shouldStayOnCategory = false;

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
    _checkFirebaseConfig();
  }

  Future<void> _checkFirebaseConfig() async {
    try {
      debugPrint('Vérification de la configuration Firebase...');
      // Essayer d'accéder à une référence de test
      final ref = FirebaseStorage.instance.ref('test-config');
      await ref.getDownloadURL().catchError((error) {
        debugPrint('Erreur de configuration Firebase: $error');
        // C'est normal que cela échoue, on veut juste vérifier la connexion
      });
      debugPrint('Configuration Firebase OK');
    } catch (e) {
      debugPrint('Erreur lors de la vérification de Firebase: $e');
    }
  }

  Future<void> _checkNfcAvailability() async {
    try {
      _isNfcAvailable = await NfcManager.instance.isAvailable();
      setState(() {});
    } catch (e) {
      _isNfcAvailable = false;
      setState(() {});
    }
  }

  final _user = FirebaseAuth.instance.currentUser;
  final _priceController = TextEditingController();
  final _buyerEmailController = TextEditingController();
  bool _isLoading = false;
  bool _isNfcAvailable = false;
  bool _isNfcScanning = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Utilisateur non connecté.')),
      );
    }
    final categoriesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('categories');
    final animalsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('animals');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEF9EA),
        elevation: 0,
        centerTitle: true,
        titleSpacing: 0,
        title: Text(
          'Mes animaux',
          style: TextStyle(
            color: const Color(0xFFA37551),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: const Color(0xFFA37551)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: categoriesRef.snapshots(),
        builder: (context, catSnapshot) {
          if (catSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final categories = catSnapshot.data?.docs ?? [];
          if (categories.isEmpty) {
            // Aucune catégorie, afficher juste le bouton +
            return Center(
              child: IconButton(
                icon: Icon(Icons.add_circle, color: const Color(0xFFA37551), size: 60),
                onPressed: () => _showAddCategoryDialog(context, categoriesRef),
                tooltip: 'Ajouter une catégorie',
              ),
            );
          }
          if (selectedCategoryId == null) {
            // Afficher la grille de catégories
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                children: [
                  ...categories.map((cat) {
                    final data = cat.data() as Map<String, dynamic>;
                    final color = _parseColor(data['color'] ?? '#D6F5D6');
                    return InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => setState(() => selectedCategoryId = cat.id),
                      onLongPress: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Supprimer cette catégorie ?'),
                            content: const Text('Tous les animaux associés à cette catégorie seront également supprimés.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Annuler'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Supprimer'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await categoriesRef.doc(cat.id).delete();
                          // Supprimer tous les animaux associés à cette catégorie
                          final animalsToDelete = await animalsRef.where('categoryId', isEqualTo: cat.id).get();
                          for (var doc in animalsToDelete.docs) {
                            await doc.reference.delete();
                          }
                          setState(() => selectedCategoryId = null);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.07),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            data['name'] ?? '',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black),
                          ),
                        ),
                      ),
                    );
                  }),
                  // Bouton +
                  InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => _showAddCategoryDialog(context, categoriesRef),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFD6F6FA),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.07),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.add, size: 40, color: Color(0xFFA37551)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else {
            // Afficher la liste des animaux de la catégorie sélectionnée
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Color(0xFFA37551)),
                        onPressed: () => setState(() => selectedCategoryId = null),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        categories.firstWhere((c) => c.id == selectedCategoryId)?.get('name') ?? '',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFA37551)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: animalsRef.where('categoryId', isEqualTo: selectedCategoryId).snapshots(),
                    builder: (context, animalSnapshot) {
                      if (animalSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
          }
                      final animals = animalSnapshot.data?.docs ?? [];
                      if (animals.isEmpty) {
                        return const Center(child: Text('Aucun animal dans cette catégorie.'));
                      }
          return ListView.builder(
            itemCount: animals.length,
            itemBuilder: (context, index) {
              final animal = animals[index];
              final animalData = animal.data() as Map<String, dynamic>?;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                            child: ListTile(
                              leading: animal['photoUrl'] != null && animal['photoUrl'] != ''
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  animal['photoUrl'],
                                        width: 60,
                                        height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                          width: 60,
                                          height: 60,
                                    color: Colors.grey[200],
                                          child: const Icon(Icons.pets, size: 32, color: Colors.grey),
                                  ),
                                ),
                              )
                            : Container(
                                      width: 60,
                                      height: 60,
                                color: Colors.grey[200],
                                      child: const Icon(Icons.pets, size: 32, color: Colors.grey),
                              ),
                              title: Text(animal['nom'] ?? 'Sans nom', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Âge: ${animal['age'] ?? 'Non spécifié'}'),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AnimalDetailScreen(animal: animal),
                                  ),
                                );
                              },
                                      ),
                          );
                        },
                      );
                    },
                                  ),
                ),
              ],
            );
                                }
                              },
                            ),
      floatingActionButton: selectedCategoryId != null
          ? FloatingActionButton(
              backgroundColor: const Color(0xFFA37551),
              child: const Icon(Icons.add, color: Colors.white),
              onPressed: () => _showAddAnimalDialog(context, animalsRef, selectedCategoryId!),
            )
          : null,
    );
  }

  void _showAddCategoryDialog(BuildContext context, CollectionReference categoriesRef) {
    final nameController = TextEditingController();
    Color selectedColor = const Color(0xFFD6F5D6);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Nouvelle catégorie'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nom de la catégorie'),
                  ),
                  const SizedBox(height: 12),
                              Row(
                                children: [
                      const Text('Couleur :'),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          final color = await showDialog<Color>(
                            context: context,
                            builder: (context) => SimpleDialog(
                              title: const Text('Choisir une couleur'),
                              children: [
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    ...[
                                      0xFFFFD6F5, 0xFFD6F5D6, 0xFFD6F6FA, 0xFFFFF9C4, 0xFFFFE0E0,
                                      0xFFE3E6FA, 0xFFF5E6D6, 0xFFF5D6E6, 0xFFD6E6F5, 0xFFF5F5D6,
                                    ].map((c) => GestureDetector(
                                          onTap: () => Navigator.pop(context, Color(c)),
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            margin: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Color(c),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(width: 2, color: Colors.grey.shade300),
                                            ),
                                          ),
                                        )),
                                  ],
                                ),
                              ],
                            ),
                          );
                          if (color != null) {
                            setState(() => selectedColor = color);
                          }
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: selectedColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(width: 2, color: Colors.grey.shade300),
                          ),
                        ),
                              ),
                          ],
                        ),
                      ],
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Utilisateur non connecté'), backgroundColor: Colors.red),
                        );
                      }
                      return;
                    }
                    if (name.isNotEmpty) {
                      try {
                        print('Ajout catégorie: $name, couleur: $selectedColor');
                        await categoriesRef.add({
                          'name': name,
                          'color': selectedColor is Color
                              ? '#${selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2)}'
                              : '#D6F5D6',
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        Navigator.pop(context);
                      } catch (e) {
                        print('Erreur Firestore: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Ajouter'),
                ),
              ],
              );
            },
          );
        },
    );
  }

  void _showAddAnimalDialog(BuildContext context, CollectionReference animalsRef, String categoryId) {
    File? _pickedImage;
    final picker = ImagePicker();
    bool _isLoading = false;
    final _raceController = TextEditingController();
    final _especeController = TextEditingController();
    final _poidsController = TextEditingController();
    final _couleurController = TextEditingController();
    final _descriptionController = TextEditingController();
    final _nfcCodeController = TextEditingController();
    final _nomController = TextEditingController();
    DateTime? _dateNaissance;
    DateTime? _dateArrivee;
    String? _selectedSex;
    String? _error;

    void disposeAll() {
      _raceController.dispose();
      _especeController.dispose();
      _poidsController.dispose();
      _couleurController.dispose();
      _descriptionController.dispose();
      _nfcCodeController.dispose();
      _nomController.dispose();
    }

    showDialog(
      context: context,
      builder: (context) {
        int? _calculatedAge;
        if (_dateNaissance != null) {
          final now = DateTime.now();
          _calculatedAge = now.year - _dateNaissance!.year - ((now.month < _dateNaissance!.month || (now.month == _dateNaissance!.month && now.day < _dateNaissance!.day)) ? 1 : 0);
        }
        final Color accent = const Color(0xFFA37551);
        final Color bg = const Color(0xFFFEF9EA);
            return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: bg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          title: Center(
            child: Text(
              'Ajouter un animal',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: accent,
              ),
            ),
          ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picked = await picker.pickImage(source: ImageSource.gallery);
                    if (!context.mounted) return;
                        if (picked != null) {
                          setState(() {
                            _pickedImage = File(picked.path);
                          });
                        }
                      },
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                      child: _pickedImage != null
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.file(_pickedImage!, width: 90, height: 90, fit: BoxFit.cover),
                            )
                        : const Icon(Icons.pets, size: 44, color: Color(0xFFA37551)),
                            ),
                    ),
                const SizedBox(height: 18),
                    TextField(
                      controller: _nomController,
                  decoration: InputDecoration(
                    labelText: 'Nom',
                    prefixIcon: Icon(Icons.pets, color: accent),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: accent, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().subtract(const Duration(days: 365)),
                            firstDate: DateTime(1990),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _dateNaissance = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date de naissance',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(_dateNaissance != null ? "${_dateNaissance!.day.toString().padLeft(2, '0')}/${_dateNaissance!.month.toString().padLeft(2, '0')}/${_dateNaissance!.year}" : 'Sélectionner'),
                        ),
                      ),
                    ),
                    if (_calculatedAge != null) ...[
                      const SizedBox(width: 10),
                      Text('$_calculatedAge ans', style: TextStyle(fontWeight: FontWeight.w600, color: accent)),
                    ]
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _selectedSex,
                  items: const [
                    DropdownMenuItem(value: 'Mâle', child: Text('Mâle')),
                    DropdownMenuItem(value: 'Femelle', child: Text('Femelle')),
                    DropdownMenuItem(value: 'Mâle castré', child: Text('Mâle castré')),
                    DropdownMenuItem(value: 'Femelle stérilisée', child: Text('Femelle stérilisée')),
                  ],
                  onChanged: (val) => setState(() => _selectedSex = val),
                  decoration: InputDecoration(
                    labelText: 'Sexe',
                    prefixIcon: Icon(Icons.transgender, color: accent),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                ),
                const SizedBox(height: 14),
                    TextField(
                      controller: _raceController,
                  decoration: InputDecoration(
                    labelText: 'Race',
                    prefixIcon: Icon(Icons.flag, color: accent),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                    ),
                const SizedBox(height: 14),
                    TextField(
                      controller: _especeController,
                  decoration: InputDecoration(
                    labelText: 'Espèce',
                    prefixIcon: Icon(Icons.category, color: accent),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                    ),
                const SizedBox(height: 14),
                    TextField(
                      controller: _poidsController,
                  decoration: InputDecoration(
                    labelText: 'Poids (kg)',
                    prefixIcon: Icon(Icons.monitor_weight, color: accent),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                      keyboardType: TextInputType.number,
                    ),
                const SizedBox(height: 14),
                    TextField(
                  controller: _couleurController,
                                    decoration: InputDecoration(
                    labelText: 'Couleur / robe',
                    prefixIcon: Icon(Icons.palette, color: accent),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(1990),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _dateArrivee = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: "Date d'arrivée/adoption",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(_dateArrivee != null ? "${_dateArrivee!.day.toString().padLeft(2, '0')}/${_dateArrivee!.month.toString().padLeft(2, '0')}/${_dateArrivee!.year}" : 'Sélectionner'),
                                ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description / remarques',
                    prefixIcon: Icon(Icons.description, color: accent),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  maxLines: 3,
                        ),
                const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nfcCodeController,
                            decoration: InputDecoration(
                              labelText: 'Code NFC (carte animal)',
                          prefixIcon: Icon(Icons.nfc, color: accent),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: () {
                                  setState(() {
                                    _nfcCodeController.text = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
                                  });
                                },
                                tooltip: 'Générer un nouveau code',
                              ),
                            ),
                            readOnly: true,
                          ),
                        ),
                       IconButton(
                      icon: Icon(Icons.nfc, size: 30, color: _isNfcAvailable ? accent : Colors.grey),
                          onPressed: _isNfcAvailable ? () async {
                            final nfcCode = _nfcCodeController.text.trim();
                            if (nfcCode.isEmpty) {
                          if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Veuillez d\'abord générer un code NFC'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              return;
                            }
                            try {
                              if (!await NfcManager.instance.isAvailable()) {
                                throw 'NFC non disponible sur cet appareil';
                              }
                          setState(() => _isNfcScanning = true);
                          if (!context.mounted) return;
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Prêt à écrire'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 16),
                                        Text('Approchez la puce NFC de l\'appareil...'),
                                      ],
                                    ),
                                  );
                                },
                              );
                              bool isWritten = false;
                              await NfcManager.instance.startSession(
                                onDiscovered: (NfcTag tag) async {
                                  try {
                                    final ndef = Ndef.from(tag);
                                    if (ndef == null || !ndef.isWritable) {
                                      throw 'Tag non compatible ou non inscriptible';
                                    }
                                    final message = NdefMessage([
                                      NdefRecord.createText(nfcCode),
                                    ]);
                                    await ndef.write(message);
                                    isWritten = true;
                                    NfcManager.instance.stopSession();
                                    isWritten = true;
                                if (!context.mounted) return;
                                FocusScope.of(context).unfocus();
                                await Future.delayed(const Duration(milliseconds: 100));
                                if (Navigator.of(context, rootNavigator: true).canPop()) {
                                  Navigator.of(context, rootNavigator: true).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Écriture sur la puce NFC réussie !'),
                                          backgroundColor: Color(0xFFA37551),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    NfcManager.instance.stopSession(errorMessage: e.toString());
                                if (!context.mounted) return;
                                if (Navigator.of(context, rootNavigator: true).canPop()) {
                                  Navigator.of(context, rootNavigator: true).pop();
                                    }
                                    return;
                                  }
                                },
                                onError: (error) async {
                              if (!context.mounted) return;
                              if (Navigator.of(context, rootNavigator: true).canPop()) {
                                Navigator.of(context, rootNavigator: true).pop();
                                  }
                                  return;
                                },
                              );
                            } catch (e) {
                          if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Erreur: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                            }
                          } : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('NFC non disponible sur cet appareil'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                          tooltip: _isNfcAvailable ? 'Écrire sur une carte NFC' : 'NFC non disponible',
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
              actions: [
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                if (!_isLoading)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        disposeAll();
                        if (!context.mounted) return;
                        if (Navigator.of(context, rootNavigator: true).canPop()) {
                          Navigator.of(context, rootNavigator: true).pop();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(color: accent),
                      ),
                      child: Text('Annuler', style: TextStyle(color: accent)),
                  ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            setState(() => _isLoading = true);
                            try {
                              print('Début upload image');
                              String? photoUrl;
                              if (_pickedImage != null) {
                                  final user = FirebaseAuth.instance.currentUser;
                                if (user == null) throw Exception('Utilisateur non connecté');
                                final storagePath = 'animals/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
                                  final storageRef = FirebaseStorage.instance.ref(storagePath);
                                final uploadTask = storageRef.putFile(_pickedImage!);
                                    final snapshot = await uploadTask;
                                print('Upload terminé, état: \\${snapshot.state}');
                                    if (snapshot.state == TaskState.success) {
                                        photoUrl = await storageRef.getDownloadURL();
                                  print('URL image: \\${photoUrl}');
                                    } else {
                                  print('Échec upload');
                                  throw Exception('Échec du téléchargement de l\'image');
                                }
                              }
                              print('Ajout Firestore');
                              double? latitude;
                              double? longitude;
                              try {
                                final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                                latitude = position.latitude;
                                longitude = position.longitude;
                              } catch (e) {}
                              if (!context.mounted) return;
                              await animalsRef.add({
                                'nom': _nomController.text.trim(),
                                'dateNaissance': _dateNaissance != null ? Timestamp.fromDate(_dateNaissance!) : null,
                                'age': _dateNaissance != null ? (DateTime.now().year - _dateNaissance!.year - ((DateTime.now().month < _dateNaissance!.month || (DateTime.now().month == _dateNaissance!.month && DateTime.now().day < _dateNaissance!.day)) ? 1 : 0)) : null,
                                'sex': _selectedSex,
                                'race': _raceController.text.trim(),
                                'espece': _especeController.text.trim(),
                                'poids': _poidsController.text.trim(),
                                'couleur': _couleurController.text.trim(),
                                'dateArrivee': _dateArrivee != null ? Timestamp.fromDate(_dateArrivee!) : null,
                                'description': _descriptionController.text.trim(),
                                'nfcCode': _nfcCodeController.text.trim(),
                                'latitude': latitude,
                                'longitude': longitude,
                                'photoUrl': photoUrl ?? '',
                                'imageUrl': photoUrl,
                                'isForSale': false,
                                'price': null,
                                'createdAt': FieldValue.serverTimestamp(),
                                'categoryId': categoryId,
                              });
                              print('Ajout Firestore terminé');
                              shouldStayOnCategory = true;
                              Navigator.pop(context);
                            } catch (e) {
                              print('Erreur upload image ou ajout Firestore: \\${e}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erreur upload image ou ajout: \\${e}'), backgroundColor: Colors.red),
        );
      }
                              setState(() => _isLoading = false);
      return;
                            }
                          },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      child: const Text('Ajouter', style: TextStyle(color: Colors.white)),
                    ),
              ),
            ],
          ),
          ],
        );
      },
                );
              }

  Color _parseColor(String hexColor) {
      try {
      return Color(int.parse(hexColor.replaceAll('#', '0xff')));
    } catch (e) {
      return const Color(0xFFD6F5D6);
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _buyerEmailController.dispose();
    super.dispose();
  }
}
