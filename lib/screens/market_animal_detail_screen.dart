import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MarketAnimalDetailScreen extends StatefulWidget {
  final Map<String, dynamic> animalData;
  const MarketAnimalDetailScreen({Key? key, required this.animalData}) : super(key: key);

  @override
  State<MarketAnimalDetailScreen> createState() => _MarketAnimalDetailScreenState();
}

class _MarketAnimalDetailScreenState extends State<MarketAnimalDetailScreen> {
  String? _ownerPhone;
  bool _isLoadingPhone = false;

  Future<void> _launchUrl(Uri uri) async {
    if (!await launchUrl(uri)) {
      throw Exception('Impossible d\'ouvrir $uri');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchOwnerPhoneIfNeeded();
  }

  Future<void> _fetchOwnerPhoneIfNeeded() async {
    final animalData = widget.animalData;
    // Si déjà présent dans animalData, inutile de charger
    if ((animalData['telephone'] != null && animalData['telephone'].toString().isNotEmpty) ||
        (animalData['ownerPhone'] != null && animalData['ownerPhone'].toString().isNotEmpty)) {
      setState(() {
        _ownerPhone = animalData['telephone']?.toString() ?? animalData['ownerPhone']?.toString();
      });
      return;
    }
    // Chercher l'ID du propriétaire
    final ownerId = animalData['userId'] ?? animalData['ownerId'];
    if (ownerId == null) return;
    setState(() { _isLoadingPhone = true; });
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(ownerId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final phone = userDoc.data()!['telephone']?.toString();
        if (phone != null && phone.isNotEmpty) {
          setState(() { _ownerPhone = phone; });
        }
      }
    } catch (_) {}
    setState(() { _isLoadingPhone = false; });
  }

  @override
  Widget build(BuildContext context) {
    final animalData = widget.animalData;
    final labelStyle = TextStyle(fontWeight: FontWeight.w600, color: Colors.brown[700]);
    final valueStyle = const TextStyle(fontWeight: FontWeight.normal, color: Colors.black87);
    return Scaffold(
      appBar: AppBar(title: const Text('Détails de l\'animal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: (animalData['imageUrl'] != null && animalData['imageUrl'].toString().isNotEmpty)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(animalData['imageUrl'], width: 160, height: 160, fit: BoxFit.cover),
                            )
                          : Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.pets, size: 60, color: Colors.grey),
                            ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(animalData['nom'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (animalData['espece'] != null)
                          Expanded(child: Text('Espèce : ${animalData['espece']}', style: valueStyle)),
                        if (animalData['race'] != null)
                          Expanded(child: Text('Race : ${animalData['race']}', style: valueStyle)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (animalData['sex'] != null)
                          Expanded(child: Text('Sexe : ${animalData['sex']}', style: valueStyle)),
                        if (animalData['age'] != null)
                          Expanded(child: Text('Âge : ${animalData['age']}', style: valueStyle)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (animalData['poids'] != null)
                          Expanded(child: Text('Poids : ${animalData['poids']} kg', style: valueStyle)),
                        if (animalData['couleur'] != null)
                          Expanded(child: Text('Couleur : ${animalData['couleur']}', style: valueStyle)),
                      ],
                    ),
                    if (animalData['description'] != null && animalData['description'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text('Description : ${animalData['description']}', style: valueStyle),
                      ),
                    if (animalData['price'] != null) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: Text('Prix : ${animalData['price']} €', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green)),
                      ),
                    ],
                    const Divider(height: 32),
                    Text('Propriétaire', style: labelStyle.copyWith(fontSize: 17)),
                    const SizedBox(height: 6),
                    if (animalData['ownerName'] != null && animalData['ownerName'].toString().isNotEmpty)
                      Row(children: [const Icon(Icons.person, size: 18, color: Colors.brown), SizedBox(width: 6), Text(animalData['ownerName'], style: valueStyle)]),
                    if (animalData['ownerEmail'] != null && animalData['ownerEmail'].toString().isNotEmpty)
                      Row(children: [const Icon(Icons.email, size: 18, color: Colors.brown), SizedBox(width: 6), Text(animalData['ownerEmail'], style: valueStyle)]),
                    if (_isLoadingPhone)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_ownerPhone != null && _ownerPhone!.isNotEmpty)
                      Row(children: [const Icon(Icons.phone_android, size: 18, color: Colors.brown), SizedBox(width: 6), Text(_ownerPhone!, style: valueStyle)]),
                    if (animalData['adresse'] != null && animalData['adresse'].toString().isNotEmpty)
                      Row(children: [const Icon(Icons.home, size: 18, color: Colors.brown), SizedBox(width: 6), Expanded(child: Text(animalData['adresse'], style: valueStyle))]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (animalData['ownerEmail'] != null && animalData['ownerEmail'].toString().isNotEmpty)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.email),
                    label: const Text('Envoyer un email'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    onPressed: () async {
                      final email = animalData['ownerEmail'];
                      final uri = Uri(scheme: 'mailto', path: email);
                      await _launchUrl(uri);
                    },
                  ),
                if (((animalData['telephone'] != null && animalData['telephone'].toString().isNotEmpty) ||
                     (animalData['ownerPhone'] != null && animalData['ownerPhone'].toString().isNotEmpty) ||
                     (_ownerPhone != null && _ownerPhone!.isNotEmpty))) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.sms),
                    label: const Text('Envoyer un SMS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    onPressed: () async {
                      final phone = animalData['telephone'] ?? animalData['ownerPhone'] ?? _ownerPhone;
                      final uri = Uri(scheme: 'sms', path: phone);
                      await _launchUrl(uri);
                    },
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    onPressed: () async {
                      final phone = (animalData['telephone'] ?? animalData['ownerPhone'] ?? _ownerPhone).toString();
                      final formatted = phone.replaceAll(RegExp(r'[^0-9]'), '');
                      final url = Uri.parse('https://wa.me/$formatted');
                      await _launchUrl(url);
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
} 