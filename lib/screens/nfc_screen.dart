import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'animal_detail_screen.dart';


class NfcScreen extends StatefulWidget {
  const NfcScreen({super.key});

  @override
  State<NfcScreen> createState() => _NfcScreenState();
}

class _NfcScreenState extends State<NfcScreen> {
  bool _isScanning = false;
  String? _error;
  String? _lastNfcCode;

  Future<void> _startNfcScan() async {
    setState(() {
      _isScanning = true;
      _error = null;
    });

    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      setState(() {
        _isScanning = false;
        _error = "NFC non disponible sur cet appareil.";
      });
      return;
    }

    try {
      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          NfcManager.instance.stopSession();
          String? nfcText;
          try {
            final ndef = Ndef.from(tag);
            if (ndef != null && ndef.cachedMessage != null) {
              final payload = ndef.cachedMessage!.records.first.payload;
              print('Payload hex: ${payload.map((e) => e.toRadixString(16)).toList()}');
              final langCodeLen = payload.first & 0x3F;
              nfcText = String.fromCharCodes(payload.skip(1 + langCodeLen)).trim();
              print('Code NFC nettoyé : "$nfcText"');
              setState(() {
                _lastNfcCode = nfcText;
              });
              // Navigation automatique vers DetailsScreen
              if (mounted && nfcText.isNotEmpty) {
                // Récupérer la position GPS
                Position? position;
                try {
                  position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                } catch (e) {
                  print('Erreur Geolocator: $e');
                  position = null;
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Localisation indisponible : activez le GPS et autorisez l\'application.')),
                    );
                  }
                }

                if (position == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Impossible de récupérer la position GPS.')),
                    );
                  }
                }

                // Chercher l'animal pour retrouver le propriétaire
                final animalSnap = await FirebaseFirestore.instance
                  .collectionGroup('animals')
                  .where('nfcCode', isEqualTo: nfcText.trim().toLowerCase())
                  .limit(1)
                  .get();
                String? ownerId;
                if (animalSnap.docs.isNotEmpty) {
                  final animalDoc = animalSnap.docs.first;
                  // parent.parent = document user
                  ownerId = animalDoc.reference.parent.parent?.id;

                  // Navigation selon le propriétaire
                  final currentUser = FirebaseAuth.instance.currentUser;
                  final animalData = animalDoc.data() as Map<String, dynamic>;

                  if (ownerId != null) {
                    await FirebaseFirestore.instance
                      .collection('users')
                      .doc(ownerId)
                      .collection('alerts')
                      .add({
                        'nfcCode': nfcText.trim().toLowerCase(),
                        'timestamp': FieldValue.serverTimestamp(),
                        'latitude': position?.latitude,
                        'longitude': position?.longitude,
                        'animalId': animalDoc.id,
                      });
                  }

                  if (currentUser != null && ownerId == currentUser.uid) {
                    // Propriétaire : page détails propriétaire
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AnimalDetailScreen(animal: animalDoc),
                        ),
                      );
                    }
                  } else {
                    // Non-propriétaire : page détails publique
                    if (mounted) {
                      Navigator.pushReplacementNamed(
                        context,
                        '/details',
                        arguments: {
                          'nfcText': nfcText,
                        },
                      );
                    }
                  }
                }
              }
            }
          } catch (e) {
            setState(() {
              _error = "Erreur de décodage du tag.";
            });
          }
        },
        onError: (e) async {
          setState(() {
            _isScanning = false;
            _error = "Erreur lors de la lecture NFC.";
          });
          NfcManager.instance.stopSession(errorMessage: 'Erreur NFC');
        },
      );
    } catch (e) {
      setState(() {
        _isScanning = false;
        _error = "Erreur lors de l'initialisation de la session NFC.";
      });
    }
  }

  @override
  void dispose() {
    NfcManager.instance.stopSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color brown = const Color(0xFFA37551);
    final Color background = const Color(0xFF7B6A5E);
    final Color cardColor = Colors.white;
    final Color lightBeige = const Color(0xFFEAD7C0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isScanning) _startNfcScan();
    });
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleSpacing: 0,
        title: Text(
          'Lecture NFC',
          style: TextStyle(
            color: lightBeige,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: lightBeige),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Container(
          width: 350,
          constraints: const BoxConstraints(maxWidth: 350),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Prêt à scanner',
                style: TextStyle(
                  color: brown,
                  fontWeight: FontWeight.w600,
                  fontSize: 26,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Icon(Icons.nfc, color: Colors.blue, size: 110),
              const SizedBox(height: 36),
              Text(
                'Approchez votre appareil du tag NFC',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: lightBeige,
                    foregroundColor: brown,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  child: const Text('annuler'),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 18.0),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
