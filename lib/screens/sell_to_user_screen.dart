import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SellToUserScreen extends StatefulWidget {
  final Map<String, dynamic> animalData;
  final String animalId;
  const SellToUserScreen({Key? key, required this.animalData, required this.animalId}) : super(key: key);

  @override
  State<SellToUserScreen> createState() => _SellToUserScreenState();
}

class _SellToUserScreenState extends State<SellToUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sellToUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      debugPrint('Recherche de l\'acheteur avec email: $email');
      final buyerQuery = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: email).limit(1).get();
      if (buyerQuery.docs.isEmpty) {
        debugPrint('Aucun utilisateur trouvé avec cet email');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucun utilisateur trouvé avec cet email'), backgroundColor: Colors.red),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
      final buyerId = buyerQuery.docs.first.id;
      final buyerData = buyerQuery.docs.first.data();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw 'Utilisateur non connecté';
      final animalData = Map<String, dynamic>.from(widget.animalData);
      animalData['isForSale'] = false;
      animalData['previousOwnerId'] = currentUser.uid;
      animalData['saleDate'] = FieldValue.serverTimestamp();
      // Mettre à jour les infos de l'acheteur
      animalData['userId'] = buyerId;
      animalData['ownerName'] = '${buyerData['prenom'] ?? ''} ${buyerData['nom'] ?? ''}'.trim();
      animalData['ownerEmail'] = buyerData['email'] ?? '';
      animalData['ownerPhone'] = buyerData['telephone'] ?? '';

      // Gestion de la catégorie :
      String? oldCategoryId = animalData['categoryId'];
      String? newCategoryId;
      if (oldCategoryId != null && oldCategoryId.isNotEmpty) {
        // Chercher la catégorie chez le vendeur
        final sellerCatSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('categories')
            .doc(oldCategoryId)
            .get();
        Map<String, dynamic>? catData = sellerCatSnap.data();
        // Chercher si une catégorie équivalente existe déjà chez l'acheteur (même nom)
        if (catData != null) {
          final buyerCatQuery = await FirebaseFirestore.instance
              .collection('users')
              .doc(buyerId)
              .collection('categories')
              .where('name', isEqualTo: catData['name'])
              .limit(1)
              .get();
          if (buyerCatQuery.docs.isNotEmpty) {
            // Catégorie existe déjà chez l'acheteur
            newCategoryId = buyerCatQuery.docs.first.id;
          } else {
            // Créer la catégorie chez l'acheteur
            final newCatRef = await FirebaseFirestore.instance
                .collection('users')
                .doc(buyerId)
                .collection('categories')
                .add(catData);
            newCategoryId = newCatRef.id;
          }
        }
      }
      if (newCategoryId != null) {
        animalData['categoryId'] = newCategoryId;
      }

      debugPrint('Suppression de l\'animal chez le vendeur (${currentUser.uid})');
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).collection('animals').doc(widget.animalId).delete();
      debugPrint('Ajout de l\'animal chez l\'acheteur ($buyerId)');
      await FirebaseFirestore.instance.collection('users').doc(buyerId).collection('animals').doc(widget.animalId).set(animalData);
      debugPrint('Ajout de la notification pour l\'acheteur');
      await FirebaseFirestore.instance.collection('users').doc(buyerId).collection('notifications').add({
        'type': 'animal_received',
        'animalId': widget.animalId,
        'animalName': animalData['nom'] ?? '',
        'sellerEmail': currentUser.email,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'message': "Félicitations ! Vous êtes maintenant propriétaire de l'animal ${animalData['nom'] ?? ''} (espèce : ${animalData['espece'] ?? ''}, race : ${animalData['race'] ?? ''}). Vendu par ${currentUser.email ?? ''}.",
      });
      debugPrint('Ajout de la notification pour le vendeur');
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).collection('notifications').add({
        'type': 'animal_sold',
        'animalId': widget.animalId,
        'animalName': animalData['nom'] ?? '',
        'buyerEmail': email,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'message': "Vous avez vendu l'animal ${animalData['nom'] ?? ''} à ${email} le ${DateTime.now().toLocal().toString().split(' ')[0]}.",
      });
      debugPrint('Ajout à l\'historique de vente du vendeur');
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).collection('sales').add({
        'animalId': widget.animalId,
        'animalName': animalData['nom'] ?? '',
        'buyerId': buyerId,
        'buyerEmail': email,
        'saleDate': FieldValue.serverTimestamp(),
        'price': animalData['price'],
      });
      if (mounted) {
        debugPrint('Vente réussie, retour à la fiche animal');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Animal vendu avec succès !'), backgroundColor: Colors.green),
        );
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Vente réussie'),
            content: const Text('L\'animal a bien été transféré au nouveau propriétaire.'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Erreur lors de la vente : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final animal = widget.animalData;
    return Scaffold(
      appBar: AppBar(title: const Text('Vendre à un utilisateur')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (animal['imageUrl'] != null && animal['imageUrl'].toString().isNotEmpty)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(animal['imageUrl'], width: 120, height: 120, fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 12),
            Text('Nom : ${animal['nom'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (animal['price'] != null) Text('Prix : ${animal['price']} €'),
            if (animal['race'] != null) Text('Race : ${animal['race']}'),
            if (animal['espece'] != null) Text('Espèce : ${animal['espece']}'),
            const Divider(height: 32),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: "Email de l'acheteur"),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Veuillez entrer un email';
                  if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.[a-zA-Z]{2,4}$').hasMatch(value)) return 'Email invalide';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.sell),
              label: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Vendre'),
              onPressed: _isLoading ? null : _sellToUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 