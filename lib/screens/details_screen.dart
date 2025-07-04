import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/animal.dart';
import 'sell_animal_screen.dart';

class DetailsScreen extends StatefulWidget {
  final bool isGuest;
  const DetailsScreen({super.key, required this.isGuest});

  static bool getIsGuest(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    return args != null && args['isGuest'] == false ? false : true;
  }

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  // Fonction utilitaire pour calculer l'âge à partir de la date de naissance
  String _calculateAge(dynamic dateNaissance) {
    if (dateNaissance == null) return '';
    DateTime? birthDate;
    if (dateNaissance is String && dateNaissance.isNotEmpty) {
      birthDate = DateTime.tryParse(dateNaissance);
    } else if (dateNaissance is Timestamp) {
      birthDate = dateNaissance.toDate();
    }
    if (birthDate == null) return '';
    final now = DateTime.now();
    int years = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
      years--;
    }
    return '$years ans';
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final nfcText = args != null && args['nfcText'] != null ? args['nfcText'] as String : '';
    
    debugPrint('Arguments de navigation: $args');
    debugPrint('Code NFC: $nfcText');
    debugPrint('Utilisateur actuel: ${FirebaseAuth.instance.currentUser?.uid}');
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEF9EA),
        elevation: 0,
        centerTitle: true,
        titleSpacing: 0,
        title: Text(
          "Détails de l'animal",
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
      body: nfcText.isEmpty
          ? const Center(child: Text('Aucun code NFC lu.'))
          : FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collectionGroup('animals')
                  .where('nfcCode', isEqualTo: nfcText)
                  .limit(1)
                  .get()
                  .catchError((e) {
                    print('Erreur Firestore : $e');
                  }),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Aucun animal trouvé pour ce code NFC.'));
                }
                final animal = snapshot.data!.docs.first;
                final animalData = animal.data() as Map<String, dynamic>;
                final userRef = animal.reference.parent.parent;
                final String? ownerId = userRef?.id;
                final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
                final bool isGuest = args != null && args['isGuest'] == true;
                final bool isOwner = currentUserId != null && ownerId != null && currentUserId == ownerId;
                if (isGuest || !isOwner) {
                  // Maquette simplifiée améliorée pour guest ou non-propriétaire
                  return FutureBuilder<DocumentSnapshot>(
                    future: userRef?.get(),
                    builder: (context, userSnap) {
                      if (userSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!userSnap.hasData || !userSnap.data!.exists) {
                        return const Center(child: Text('Propriétaire inconnu.'));
                      }
                      final userData = userSnap.data!.data() as Map<String, dynamic>;
                      final Color brown = const Color(0xFFA37551);
                      final Color cardColor = const Color(0xFFFDFCFB);
                      final Color background = const Color(0xFFFEF9EA);
                      final Color infoCard = const Color(0xFFEAD7C0);
                      return Container(
                        color: background,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.07),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.person, color: brown),
                                        const SizedBox(width: 8),
                                        Text("Informations du propriétaire", style: TextStyle(fontWeight: FontWeight.bold, color: brown, fontSize: 17)),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        const Icon(Icons.badge, size: 20),
                                        const SizedBox(width: 6),
                                        Text('Nom : ', style: TextStyle(fontWeight: FontWeight.bold, color: brown)),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 32.0, bottom: 8),
                                      child: Text('${userData['nom'] ?? ''} ${userData['prenom'] ?? ''}', style: const TextStyle(fontSize: 16)),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.email, size: 20),
                                        const SizedBox(width: 6),
                                        Text('Contact : ', style: TextStyle(fontWeight: FontWeight.bold, color: brown)),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 32.0, bottom: 8),
                                      child: Text(userData['email'] ?? '', style: const TextStyle(fontSize: 16)),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone, size: 20),
                                        const SizedBox(width: 6),
                                        Text('Téléphone : ', style: TextStyle(fontWeight: FontWeight.bold, color: brown)),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 32.0, bottom: 8),
                                      child: Text(userData['telephone'] ?? '', style: const TextStyle(fontSize: 16)),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.home, size: 20),
                                        const SizedBox(width: 6),
                                        Text('Adresse : ', style: TextStyle(fontWeight: FontWeight.bold, color: brown)),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 32.0, bottom: 8),
                                      child: Text(userData['adresse'] ?? '', style: const TextStyle(fontSize: 16)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                                decoration: BoxDecoration(
                                  color: infoCard,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.pets, color: brown),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Informations générales sur l\'animal',
                                              style: TextStyle(fontWeight: FontWeight.bold, color: brown, fontSize: 17),
                                              softWrap: true,
                                              overflow: TextOverflow.visible,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        const Icon(Icons.pets, size: 20),
                                        const SizedBox(width: 6),
                                        Text('Nom de l\'animal : ', style: TextStyle(fontWeight: FontWeight.bold, color: brown)),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 32.0, bottom: 8),
                                      child: Text(animalData['nom'] ?? '', style: const TextStyle(fontSize: 16)),
                                    ),
                                    Row(
                                      children: [
                                        Icon(Icons.category, size: 20, color: brown),
                                        const SizedBox(width: 6),
                                        Text('Espèce : ', style: TextStyle(fontWeight: FontWeight.bold, color: brown)),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 32.0, bottom: 8),
                                      child: Text(animalData['espece'] ?? '', style: const TextStyle(fontSize: 16)),
                                    ),
                                    Row(
                                      children: [
                                        Icon(Icons.flag, size: 20, color: brown),
                                        const SizedBox(width: 6),
                                        Text('Race : ', style: TextStyle(fontWeight: FontWeight.bold, color: brown)),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 32.0, bottom: 8),
                                      child: Text(animalData['race'] ?? '', style: const TextStyle(fontSize: 16)),
                                    ),
                                    Row(
                                      children: [
                                        Icon(Icons.transgender, size: 20, color: brown),
                                        const SizedBox(width: 6),
                                        Text('Sexe : ', style: TextStyle(fontWeight: FontWeight.bold, color: brown)),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 32.0, bottom: 8),
                                      child: Text(animalData['sex'] ?? '', style: const TextStyle(fontSize: 16)),
                                    ),
                                    Row(
                                      children: [
                                        Icon(Icons.cake, size: 20, color: brown),
                                        const SizedBox(width: 6),
                                        Text('Âge : ', style: TextStyle(fontWeight: FontWeight.bold, color: brown)),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 32.0, bottom: 8),
                                      child: Text(
                                        (animalData['dateNaissance'] != null)
                                          ? _calculateAge(animalData['dateNaissance'])
                                          : '',
                                        style: const TextStyle(fontSize: 16)),
                                    ),
                                    Row(
                                      children: [
                                        Icon(Icons.description, size: 20, color: brown),
                                        const SizedBox(width: 6),
                                        Text('Description : ', style: TextStyle(fontWeight: FontWeight.bold, color: brown)),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 32.0, bottom: 8),
                                      child: Text(animalData['description'] ?? '', style: const TextStyle(fontSize: 16)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
                return FutureBuilder<DocumentSnapshot>(
                  future: userRef?.get(),
                  builder: (context, userSnap) {
                    if (userSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!userSnap.hasData || !userSnap.data!.exists) {
                      return const Center(child: Text('Propriétaire inconnu.'));
                    }

                    final userData = userSnap.data!.data() as Map<String, dynamic>;

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Nom de l\'animal : ${animalData['nom'] ?? '-'}',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              Text('Âge : ${animalData['age'] ?? '-'}'),
                              const Divider(height: 30),
                              Text('Propriétaire : ${userData['nom'] ?? '-'} ${userData['prenom'] ?? ''}'),
                              Text('Contact : ${userData['email'] ?? '-'}'),
                              // Section pour les propriétaires
                              Builder(
                                builder: (context) {
                                  debugPrint('UID Utilisateur actuel: ${FirebaseAuth.instance.currentUser?.uid}');
                                  debugPrint('UID Propriétaire animal: ${animal.reference.parent.parent?.id}');
                                  debugPrint('isForSale: ${animalData['isForSale']}');
                                  debugPrint('Prix: ${animalData['price']}');
                                  return const SizedBox.shrink();
                                },
                              ),
                              if (FirebaseAuth.instance.currentUser?.uid == animal.reference.parent.parent?.id) ...[
                                const SizedBox(height: 20),
                                OutlinedButton.icon(
                                  onPressed: () => _navigateToSellScreen(context, animal.reference, animalData),
                                  icon: const Icon(Icons.sell, size: 18),
                                  label: Text(animalData['isForSale'] == true 
                                      ? 'Modifier la vente' 
                                      : 'Mettre en vente'),
                                ),
                                if (animalData['isForSale'] == true) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    'Prix : ${animalData['price']} €',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFA37551),
                                    ),
                                  ),
                                ],
                              ] else if (animalData['isForSale'] == true) ...[
                                // Section pour les acheteurs potentiels
                                const SizedBox(height: 20),
                                Text(
                                  'À vendre : ${animalData['price']} €',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFA37551),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () => _buyAnimal(context, animal.reference, animalData, userData),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFA37551),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Acheter cet animal'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Future<void> _buyAnimal(
    BuildContext context,
    DocumentReference animalRef,
    Map<String, dynamic> animalData,
    Map<String, dynamic> ownerData,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez être connecté pour acheter un animal')),
      );
      return;
    }

    // Vérifier que l'utilisateur n'achète pas son propre animal
    if (currentUser.uid == animalRef.parent.parent?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous êtes déjà le propriétaire de cet animal')),
      );
      return;
    }

    try {
      // Afficher une boîte de dialogue de confirmation
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmer l\'achat'),
          content: Text('Voulez-vous vraiment acheter ${animalData['nom']} pour ${animalData['price']} € ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA37551)),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Récupérer les informations de l'acheteur
      final buyerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (!buyerDoc.exists) {
        throw Exception('Utilisateur non trouvé');
      }

      final buyerData = buyerDoc.data()!;

      // Mettre à jour le document de l'animal avec le nouveau propriétaire
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Vérifier que l'animal est toujours à vendre
        final animalDoc = await transaction.get(animalRef);
        if (!animalDoc.exists || animalDoc['isForSale'] != true) {
          throw Exception('Cet animal n\'est plus disponible à la vente');
        }

        // Mettre à jour l'animal avec les nouvelles informations
        transaction.update(animalRef, {
          'ownerId': currentUser.uid,
          'ownerName': '${buyerData['nom']} ${buyerData['prenom']}'.trim(),
          'ownerContact': buyerData['email'],
          'isForSale': false,
          'price': FieldValue.delete(),
        });

        // Créer une notification pour l'ancien propriétaire
        final notificationRef = FirebaseFirestore.instance
            .collection('users')
            .doc(animalRef.parent.parent?.id)
            .collection('notifications')
            .doc();
            
        transaction.set(notificationRef, {
          'type': 'animal_sold',
          'title': 'Animal vendu',
          'message': '${animalData['nom']} a été acheté par ${buyerData['nom']} ${buyerData['prenom']}',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'animalId': animalRef.id,
        });

        // Créer une notification pour le nouvel acheteur
        final buyerNotificationRef = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('notifications')
            .doc();
            
        transaction.set(buyerNotificationRef, {
          'type': 'animal_purchased',
          'title': 'Achat effectué',
          'message': 'Vous avez acheté ${animalData['nom']} pour ${animalData['price']} €',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'animalId': animalRef.id,
        });
      });

      // Afficher un message de succès
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Félicitations ! Vous êtes maintenant le propriétaire de ${animalData['nom']}')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'achat : $e')),
        );
      }
    }
  }

  Future<void> _navigateToSellScreen(
    BuildContext context,
    DocumentReference animalRef,
    Map<String, dynamic> animalData,
  ) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SellAnimalScreen(
          animalId: animalRef.id,
          animalName: animalData['nom'] ?? 'cet animal',
          isForSale: animalData['isForSale'] == true,
          currentPrice: animalData['price']?.toDouble(),
        ),
      ),
    );

    if (result == true && mounted) {
      // Rafraîchir les données si nécessaire
      setState(() {});
    }
  }
}
