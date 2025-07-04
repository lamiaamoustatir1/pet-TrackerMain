import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:flutter/services.dart';
import 'sell_animal_screen.dart';
import 'sell_animal_confirmation_screen.dart';
import 'sell_to_user_screen.dart';
import 'dossier_veterinaire_screen.dart';

class AnimalDetailScreen extends StatefulWidget {
  final QueryDocumentSnapshot animal;
  const AnimalDetailScreen({required this.animal, Key? key}) : super(key: key);

  @override
  State<AnimalDetailScreen> createState() => _AnimalDetailScreenState();
}

class _AnimalDetailScreenState extends State<AnimalDetailScreen> {
  late TextEditingController _nomController;
  late TextEditingController _ageController;
  late TextEditingController _nfcCodeController;
  late TextEditingController _raceController;
  late TextEditingController _especeController;
  late TextEditingController _poidsController;
  late TextEditingController _descriptionController;
  late TextEditingController _couleurController;
  bool _isLoading = false;
  bool _isNfcAvailable = false;
  bool _isNfcScanning = false;
  String? _error;
  File? _image;
  final ImagePicker _picker = ImagePicker();
  String? _imageUrl;
  String? _userId;
  bool _isEditing = false;
  List<QueryDocumentSnapshot>? _categories;
  String? _selectedCategoryId;
  String? nom, espece, race, age, poids, description, sex, dateNaissance, dateArrivee, couleur, nfcCode, categoryId;
  double? latitude, longitude;
  bool? isForSale;
  dynamic price;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.animal['nom'] ?? '');
    _ageController = TextEditingController(text: widget.animal['age']?.toString() ?? '');
    _nfcCodeController = TextEditingController(text: widget.animal['nfcCode'] ?? '');
    _raceController = TextEditingController(text: widget.animal['race'] ?? '');
    _especeController = TextEditingController(text: widget.animal['espece'] ?? '');
    _poidsController = TextEditingController(text: widget.animal['poids']?.toString() ?? '');
    _descriptionController = TextEditingController(text: widget.animal['description'] ?? '');
    _imageUrl = widget.animal['imageUrl'] ?? widget.animal['photoUrl'] ?? '';
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _selectedCategoryId = widget.animal['categoryId'];
    nom = widget.animal['nom'];
    espece = widget.animal['espece'];
    race = widget.animal['race'];
    age = widget.animal['age']?.toString();
    poids = widget.animal['poids']?.toString();
    description = widget.animal['description'];
    sex = widget.animal['sex'];
    dateNaissance = widget.animal['dateNaissance'] != null
      ? (widget.animal['dateNaissance'] is Timestamp
          ? (widget.animal['dateNaissance'] as Timestamp).toDate().toString().split(' ')[0]
          : widget.animal['dateNaissance'].toString().split(' ')[0])
      : null;
    dateArrivee = widget.animal['dateArrivee'] != null
      ? (widget.animal['dateArrivee'] is Timestamp
          ? (widget.animal['dateArrivee'] as Timestamp).toDate().toString().split(' ')[0]
          : widget.animal['dateArrivee'].toString().split(' ')[0])
      : null;
    couleur = widget.animal['couleur'];
    nfcCode = widget.animal['nfcCode'];
    categoryId = widget.animal['categoryId'];
    latitude = widget.animal['latitude'];
    longitude = widget.animal['longitude'];
    final animalData = widget.animal.data() as Map<String, dynamic>?;
    isForSale = animalData != null && animalData['isForSale'] == true;
    price = (animalData != null && animalData.containsKey('price')) ? animalData['price'] : null;
    _couleurController = TextEditingController(text: couleur ?? '');
    _fetchCategories();
    _checkNfcAvailability();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _ageController.dispose();
    _nfcCodeController.dispose();
    _raceController.dispose();
    _especeController.dispose();
    _poidsController.dispose();
    _descriptionController.dispose();
    _couleurController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la sélection de l\'image'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_image == null) return _imageUrl;
    
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('animals')
          .child('${_userId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      await storageRef.putFile(_image!);
      return await storageRef.getDownloadURL();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du téléchargement de l\'image'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _fetchCategories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('categories')
        .get();
                    setState(() {
      _categories = snapshot.docs;
                    });
  }

  String? _getCategoryName(String? id) {
    if (_categories == null || id == null) return null;
    try {
      final cat = _categories!.firstWhere((c) => c.id == id);
      return cat['name'];
    } catch (e) {
      return null;
    }
  }

  Future<void> _checkNfcAvailability() async {
    try {
      final available = await NfcManager.instance.isAvailable();
      setState(() => _isNfcAvailable = available);
    } catch (e) {
      setState(() => _isNfcAvailable = false);
    }
  }

  Future<void> _refreshAnimal() async {
    final doc = await widget.animal.reference.get();
    if (doc.exists) {
      setState(() {
        _nomController.text = doc['nom'] ?? '';
        _especeController.text = doc['espece'] ?? '';
        _raceController.text = doc['race'] ?? '';
        _ageController.text = doc['age']?.toString() ?? '';
        _poidsController.text = doc['poids']?.toString() ?? '';
        _descriptionController.text = doc['description'] ?? '';
        _selectedCategoryId = doc['categoryId'];
        _nfcCodeController.text = doc['nfcCode'] ?? '';
        nom = doc['nom'];
        espece = doc['espece'];
        race = doc['race'];
        age = doc['age']?.toString();
        poids = doc['poids']?.toString();
        description = doc['description'];
        sex = doc['sex'];
        dateNaissance = doc['dateNaissance'] != null
          ? (doc['dateNaissance'] is Timestamp
              ? (doc['dateNaissance'] as Timestamp).toDate().toString().split(' ')[0]
              : doc['dateNaissance'].toString().split(' ')[0])
          : null;
        dateArrivee = doc['dateArrivee'] != null
          ? (doc['dateArrivee'] is Timestamp
              ? (doc['dateArrivee'] as Timestamp).toDate().toString().split(' ')[0]
              : doc['dateArrivee'].toString().split(' ')[0])
          : null;
        couleur = doc['couleur'];
        nfcCode = doc['nfcCode'];
        categoryId = doc['categoryId'];
        latitude = doc['latitude'];
        longitude = doc['longitude'];
        final docData = doc.data() as Map<String, dynamic>?;
        isForSale = docData != null && docData['isForSale'] == true;
        price = (docData != null && docData.containsKey('price')) ? docData['price'] : null;
        _couleurController.text = doc['couleur'] ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color brown = const Color(0xFFA37551);
    final Color cardColor = const Color(0xFFFDFCFB);
    final Color background = const Color(0xFFFEF9EA);
    String? imageUrl = _imageUrl;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleSpacing: 0,
        title: Text(
          "Détails de l'animal",
          style: TextStyle(
            color: brown,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: brown),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          !_isEditing
            ? IconButton(
                icon: const Icon(Icons.edit, color: Colors.green),
                tooltip: 'Modifier l\'animal',
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                onPressed: () {
                  setState(() => _isEditing = true);
                },
              )
            : IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                tooltip: 'Confirmer la mise à jour',
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                onPressed: () async {
                  setState(() => _isLoading = true);
                  try {
                    await widget.animal.reference.update({
                      'nom': _nomController.text.trim(),
                      'espece': _especeController.text.trim(),
                      'race': _raceController.text.trim(),
                      'age': int.tryParse(_ageController.text.trim()),
                      'poids': _poidsController.text.trim(),
                      'description': _descriptionController.text.trim(),
                      'categoryId': _selectedCategoryId,
                      'nfcCode': _nfcCodeController.text.trim(),
                      'sex': sex,
                      'dateNaissance': (dateNaissance != null && dateNaissance!.isNotEmpty) ? DateTime.parse(dateNaissance!) : null,
                      'dateArrivee': (dateArrivee != null && dateArrivee!.isNotEmpty) ? DateTime.parse(dateArrivee!) : null,
                      'couleur': couleur,
                    });
                    await _refreshAnimal();
                    setState(() {
                      _isEditing = false;
                      _isLoading = false;
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Animal mis à jour avec succès'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    setState(() => _isLoading = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erreur lors de la mise à jour : $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              ),
            IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Supprimer l\'animal',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
            onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Supprimer cet animal'),
                          content: const Text('Êtes-vous sûr de vouloir supprimer définitivement cet animal ?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Annuler'),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _deleteAnimal();
                              },
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Supprimer'),
                            ),
                          ],
                        ),
                      );
                    },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: _isEditing
                    ? GestureDetector(
                        onTap: _pickImage,
                        child: _image != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(_image!, width: 180, height: 180, fit: BoxFit.cover),
                              )
                            : imageUrl != null && imageUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(imageUrl, width: 180, height: 180, fit: BoxFit.cover),
                                  )
                                : Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.pets, size: 60, color: Colors.grey),
                                  ),
                      )
                    : imageUrl != null && imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(imageUrl, width: 180, height: 180, fit: BoxFit.cover),
                          )
                        : Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.pets, size: 60, color: Colors.grey),
                          ),
                ),
                const SizedBox(height: 18),
                _isEditing
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nom', style: TextStyle(fontSize: 15, color: Colors.brown, fontWeight: FontWeight.w500)),
                        SizedBox(height: 4),
                        TextFormField(
                          controller: _nomController,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.pets),
                            contentPadding: EdgeInsets.symmetric(vertical: 22, horizontal: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.brown),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListTile(
                      leading: const Icon(Icons.pets, color: Color(0xFFA37551)),
                      title: const Text('Nom'),
                      subtitle: Text(nom ?? ''),
                    ),
                _isEditing
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Espèce', style: TextStyle(fontSize: 15, color: Colors.brown, fontWeight: FontWeight.w500)),
                        SizedBox(height: 4),
                        TextFormField(
                          controller: _especeController,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.category),
                            contentPadding: EdgeInsets.symmetric(vertical: 22, horizontal: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.brown),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListTile(
                      leading: const Icon(Icons.category, color: Color(0xFFA37551)),
                      title: const Text('Espèce'),
                      subtitle: Text(espece ?? ''),
                    ),
                _isEditing
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Race', style: TextStyle(fontSize: 15, color: Colors.brown, fontWeight: FontWeight.w500)),
                        SizedBox(height: 4),
                        TextFormField(
                          controller: _raceController,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.flag),
                            contentPadding: EdgeInsets.symmetric(vertical: 22, horizontal: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.brown),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListTile(
                      leading: const Icon(Icons.flag, color: Color(0xFFA37551)),
                      title: const Text('Race'),
                      subtitle: Text(race ?? ''),
                    ),
                if (!_isEditing)
                  ListTile(
                    leading: const Icon(Icons.cake, color: Color(0xFFA37551)),
                    title: const Text('Âge'),
                    subtitle: Text(_calculateAge(dateNaissance)),
                  ),
                _isEditing
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Poids', style: TextStyle(fontSize: 15, color: Colors.brown, fontWeight: FontWeight.w500)),
                        SizedBox(height: 4),
                        TextFormField(
                          controller: _poidsController,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.monitor_weight),
                            suffixText: 'kg',
                            contentPadding: EdgeInsets.symmetric(vertical: 22, horizontal: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.brown),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    )
                  : ListTile(
                      leading: const Icon(Icons.monitor_weight, color: Color(0xFFA37551)),
                      title: const Text('Poids'),
                      subtitle: Text(poids != null ? '$poids kg' : ''),
                    ),
                _isEditing
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Description', style: TextStyle(fontSize: 15, color: Colors.brown, fontWeight: FontWeight.w500)),
                        SizedBox(height: 4),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.description),
                            contentPadding: EdgeInsets.symmetric(vertical: 22, horizontal: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.brown),
                            ),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    )
                  : ListTile(
                      leading: const Icon(Icons.description, color: Color(0xFFA37551)),
                      title: const Text('Description'),
                      subtitle: Text(description ?? ''),
                    ),
                // Champ Sexe (Dropdown)
                _isEditing
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sexe', style: TextStyle(fontSize: 15, color: Colors.brown, fontWeight: FontWeight.w500)),
                        SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: sex,
                          items: [
                            'Mâle',
                            'Femelle',
                            'Femelle stérilisée',
                            'Mâle castré',
                          ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (val) => setState(() => sex = val),
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.transgender),
                            contentPadding: EdgeInsets.symmetric(vertical: 22, horizontal: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.brown),
                            ),
              ),
            ),
          ],
                    )
                  : ListTile(
                      leading: const Icon(Icons.transgender, color: Color(0xFFA37551)),
                      title: const Text('Sexe'),
                      subtitle: Text(sex ?? ''),
                    ),
                // Champ Date de naissance (DatePicker)
                _isEditing
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date de naissance', style: TextStyle(fontSize: 15, color: Colors.brown, fontWeight: FontWeight.w500)),
                        SizedBox(height: 4),
                        GestureDetector(
                          onTap: () async {
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: dateNaissance != null ? DateTime.parse(dateNaissance!) : DateTime.now(),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() {
                                dateNaissance = picked.toIso8601String().split('T')[0];
                              });
                            }
                          },
                          child: AbsorbPointer(
                            child: TextFormField(
                              controller: TextEditingController(text: dateNaissance ?? ''),
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.calendar_today),
                                contentPadding: EdgeInsets.symmetric(vertical: 22, horizontal: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: Colors.brown),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListTile(
                      leading: const Icon(Icons.calendar_today, color: Color(0xFFA37551)),
                      title: const Text('Date de naissance'),
                      subtitle: Text(dateNaissance ?? ''),
                    ),
                // Champ Date d'arrivée (DatePicker)
                _isEditing
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Date d'arrivée", style: TextStyle(fontSize: 15, color: Colors.brown, fontWeight: FontWeight.w500)),
                        SizedBox(height: 4),
                        GestureDetector(
                          onTap: () async {
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: dateArrivee != null ? DateTime.parse(dateArrivee!) : DateTime.now(),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now().add(Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() {
                                dateArrivee = picked.toIso8601String().split('T')[0];
                              });
                            }
                          },
                          child: AbsorbPointer(
                            child: TextFormField(
                              controller: TextEditingController(text: dateArrivee ?? ''),
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.event),
                                contentPadding: EdgeInsets.symmetric(vertical: 22, horizontal: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: Colors.brown),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListTile(
                      leading: const Icon(Icons.event, color: Color(0xFFA37551)),
                      title: const Text("Date d'arrivée"),
                      subtitle: Text(dateArrivee ?? ''),
                    ),
                // Champ Couleur/robe
                _isEditing
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Couleur / robe', style: TextStyle(fontSize: 15, color: Colors.brown, fontWeight: FontWeight.w500)),
                        SizedBox(height: 4),
                        TextFormField(
                          controller: _couleurController,
                          onChanged: (val) => setState(() => couleur = val),
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.palette),
                            contentPadding: EdgeInsets.symmetric(vertical: 22, horizontal: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.brown),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListTile(
                      leading: const Icon(Icons.palette, color: Color(0xFFA37551)),
                      title: const Text('Couleur / robe'),
                      subtitle: Text(couleur ?? ''),
                    ),
                // Champ Catégorie (Dropdown harmonisé)
                _isEditing && _categories != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Catégorie', style: TextStyle(fontSize: 15, color: Colors.brown, fontWeight: FontWeight.w500)),
                        SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: _selectedCategoryId,
                          items: _categories!.map((cat) => DropdownMenuItem(
                            value: cat.id,
                            child: Text(cat['name']),
                          )).toList(),
                          onChanged: (val) => setState(() => _selectedCategoryId = val),
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.folder),
                            contentPadding: EdgeInsets.symmetric(vertical: 22, horizontal: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.brown),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListTile(
                      leading: const Icon(Icons.folder, color: Color(0xFFA37551)),
                      title: const Text('Catégorie'),
                      subtitle: Text(_getCategoryName(categoryId) ?? ''),
                    ),
                // Champ Code NFC (harmonisé, lecture seule)
                _isEditing
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Code NFC (carte animal)', style: TextStyle(fontSize: 15, color: Colors.brown, fontWeight: FontWeight.w500)),
                        SizedBox(height: 4),
                        TextFormField(
                          controller: _nfcCodeController,
                          readOnly: true,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.nfc, color: Theme.of(context).primaryColor),
                            contentPadding: EdgeInsets.symmetric(vertical: 22, horizontal: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.brown),
                            ),
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
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: Icon(Icons.nfc),
                          label: Text('Écrire sur la carte NFC'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
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
                            } finally {
                              setState(() => _isNfcScanning = false);
                            }
                          } : null,
                        ),
                      ],
                    )
                  : ListTile(
                      leading: Icon(Icons.nfc, color: Theme.of(context).primaryColor),
                      title: const Text('Code NFC (carte animal)'),
                      subtitle: Text(nfcCode ?? ''),
                    ),
                if (!_isEditing)
                  ListTile(
                    leading: const Icon(Icons.location_on, color: Color(0xFFA37551)),
                    title: const Text('Localisation'),
                    subtitle: Text(latitude != null && longitude != null ? 'Lat: $latitude, Lng: $longitude' : ''),
                  ),
                if (!_isEditing && isForSale == true)
                  Card(
                    color: Colors.green[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.green),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.sell, color: Colors.green),
                              const SizedBox(width: 8),
                              Text('À vendre : ', style: TextStyle(color: Colors.green[900], fontWeight: FontWeight.bold)),
                              Text((price != null && price.toString().isNotEmpty) ? '$price €' : '', style: TextStyle(color: Colors.green[900], fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.sell, color: Colors.green),
                                label: const Text('Vendre', style: TextStyle(color: Colors.green)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.green),
                                  foregroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                ),
                                onPressed: () async {
                                  final animalData = Map<String, dynamic>.from(widget.animal.data() as Map<String, dynamic>);
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SellToUserScreen(
                                        animalData: animalData,
                                        animalId: widget.animal.id,
                                      ),
                                    ),
                                  );
                                  if (result == true) {
                                    await _refreshAnimal();
                                  }
                                },
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.cancel, color: Colors.grey),
                                label: const Text('Annuler', style: TextStyle(color: Colors.grey)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.grey),
                                  foregroundColor: Colors.grey,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                ),
                                onPressed: () async {
                                  // Retirer l'animal de la vente
                                  final user = FirebaseAuth.instance.currentUser;
                                  if (user == null) return;
                                  await widget.animal.reference.update({
                                    'isForSale': false,
                                    'price': FieldValue.delete(),
                                    'userId': FieldValue.delete(),
                                    'ownerEmail': FieldValue.delete(),
                                    'ownerName': FieldValue.delete(),
                                  });
                                  await _refreshAnimal();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Animal retiré de la vente'), backgroundColor: Colors.orange),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.settings, color: Colors.green),
                              label: const Text('Gérer la vente', style: TextStyle(color: Colors.green)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.green),
                                foregroundColor: Colors.green,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              ),
                              onPressed: _showEditPriceDialog,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!_isEditing && isForSale != true)
                  Center(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.sell, color: Colors.orange),
                      label: const Text('Mettre en vente', style: TextStyle(color: Colors.orange)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange),
                        foregroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SellAnimalScreen(
                              animalId: widget.animal.id,
                              animalName: nom ?? '',
                              isForSale: false,
                              currentPrice: null,
                            ),
                          ),
                        );
                        if (result == true) {
                          await _refreshAnimal();
                        }
                      },
                    ),
                  ),
                // Ajout du bouton Dossier vétérinaire
                if (!_isEditing) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.medical_services, color: Colors.white),
                      label: Text('Dossier vétérinaire'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFA37551),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DossierVeterinaireScreen(
                              animalId: widget.animal.id,
                              ownerId: widget.animal.reference.parent.parent?.id ?? '',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAnimal() async {
    setState(() => _isLoading = true);

    try {
      await widget.animal.reference.delete();
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _calculateAge(String? dateNaissance) {
    if (dateNaissance == null || dateNaissance.isEmpty) return '';
    final birthDate = DateTime.tryParse(dateNaissance);
    if (birthDate == null) return '';
    final now = DateTime.now();
    int years = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
      years--;
    }
    return '$years ans';
  }

  Future<void> _showEditPriceDialog() async {
    final priceController = TextEditingController(text: price != null ? price.toString() : '');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le prix'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Nouveau prix (€)'),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Veuillez entrer un prix';
              final p = double.tryParse(value);
              if (p == null || p <= 0) return 'Prix invalide';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(context, double.parse(priceController.text));
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (result != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await widget.animal.reference.update({'price': result});
      await _refreshAnimal();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prix modifié avec succès'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _showSellToUserDialog() async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vendre à un utilisateur'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: "Email de l'acheteur"),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Veuillez entrer un email';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}').hasMatch(value)) return 'Email invalide';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(context, emailController.text.trim());
              }
            },
            child: const Text('Vendre'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final buyerQuery = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: result).limit(1).get();
      if (buyerQuery.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucun utilisateur trouvé avec cet email'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      final buyerId = buyerQuery.docs.first.id;
      final animalData = Map<String, dynamic>.from(widget.animal.data() as Map<String, dynamic>);
      animalData['isForSale'] = false;
      animalData['previousOwnerId'] = FirebaseAuth.instance.currentUser?.uid;
      animalData['saleDate'] = FieldValue.serverTimestamp();
      // Supprimer l'animal chez le vendeur
      await widget.animal.reference.delete();
      // Ajouter l'animal chez l'acheteur
      await FirebaseFirestore.instance.collection('users').doc(buyerId).collection('animals').add(animalData);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Animal vendu avec succès !'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    }
  }
}
