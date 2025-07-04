import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class DossierVeterinaireScreen extends StatelessWidget {
  final String animalId;
  final String ownerId;
  const DossierVeterinaireScreen({required this.animalId, required this.ownerId, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dossier vétérinaire'),
          backgroundColor: const Color(0xFFA37551),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Color(0xFFFEF9EA),
            unselectedLabelColor: Color(0xFFFEF9EA),
            indicatorColor: Color(0xFFFEF9EA),
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.alarm), text: 'Rappels'),
              Tab(icon: Icon(Icons.vaccines), text: 'Vaccinations'),
              Tab(icon: Icon(Icons.medication), text: 'Traitements'),
              Tab(icon: Icon(Icons.warning), text: 'Allergies'),
              Tab(icon: Icon(Icons.history), text: 'Antécédents'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RappelsSection(animalId: animalId, ownerId: ownerId),
            VaccinationsTab(animalId: animalId, ownerId: ownerId),
            TraitementsTab(animalId: animalId, ownerId: ownerId),
            AllergiesTab(animalId: animalId, ownerId: ownerId),
            AntecedentsTab(animalId: animalId, ownerId: ownerId),
          ],
        ),
      ),
    );
  }
}

class RappelsSection extends StatelessWidget {
  final String animalId;
  final String ownerId;
  const RappelsSection({required this.animalId, required this.ownerId, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final vaccRef = FirebaseFirestore.instance
        .collection('users')
        .doc(ownerId)
        .collection('animals')
        .doc(animalId)
        .collection('vaccinations');
    final traitRef = FirebaseFirestore.instance
        .collection('users')
        .doc(ownerId)
        .collection('animals')
        .doc(animalId)
        .collection('traitements');
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchRappels(vaccRef, traitRef),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final rappels = snapshot.data ?? [];
        if (rappels.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Aucun rappel à venir.'),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rappels à venir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFA37551))),
              const SizedBox(height: 8),
              ...rappels.map((r) => Card(
                color: Colors.orange[50],
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Icon(r['type'] == 'vaccination' ? Icons.vaccines : Icons.medication, color: Colors.orange),
                  title: Text(r['label'] ?? ''),
                  subtitle: Text('Date de rappel : ${_formatDate(r['dateRappel'])}'),
                  trailing: r['dateRappel'] != null ? IconButton(
                    icon: const Icon(Icons.calendar_today, color: Color(0xFFA37551)),
                    tooltip: 'Ajouter au calendrier Google',
                    onPressed: () => _addToGoogleCalendar(context, r),
                  ) : null,
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRappels(CollectionReference vaccRef, CollectionReference traitRef) async {
    final now = DateTime.now();
    final vaccs = await vaccRef.get();
    final traits = await traitRef.get();
    final rappels = <Map<String, dynamic>>[];
    for (final v in vaccs.docs) {
      final data = v.data() as Map<String, dynamic>;
      // Date de vaccination
      if (data['dateVaccination'] != null) {
        DateTime? date;
        if (data['dateVaccination'] is Timestamp) {
          date = (data['dateVaccination'] as Timestamp).toDate();
        } else if (data['dateVaccination'] is DateTime) {
          date = data['dateVaccination'];
        } else if (data['dateVaccination'] is String) {
          try {
            date = DateTime.parse(data['dateVaccination']);
          } catch (e) {
            print('Date de vaccination ignorée (format invalide): ${data['dateVaccination']}');
          }
        }
        if (date != null && date.isAfter(now)) {
          rappels.add({
            'type': 'vaccination',
            'label': data['typeVaccin'] ?? 'Vaccin',
            'dateRappel': data['dateVaccination'],
            'description': 'Date de vaccination' + (data['nomCommercial'] != null ? ' (${data['nomCommercial']})' : ''),
          });
        }
      }
      // Date de rappel
      if (data['dateRappel'] != null) {
        DateTime? date;
        if (data['dateRappel'] is Timestamp) {
          date = (data['dateRappel'] as Timestamp).toDate();
        } else if (data['dateRappel'] is DateTime) {
          date = data['dateRappel'];
        } else if (data['dateRappel'] is String) {
          try {
            date = DateTime.parse(data['dateRappel']);
          } catch (e) {
            print('Date de rappel ignorée (format invalide): ${data['dateRappel']}');
          }
        }
        if (date != null && date.isAfter(now)) {
          rappels.add({
            'type': 'vaccination',
            'label': data['typeVaccin'] ?? 'Vaccin',
            'dateRappel': data['dateRappel'],
            'description': 'Date de rappel' + (data['nomCommercial'] != null ? ' (${data['nomCommercial']})' : ''),
          });
        }
      }
    }
    for (final t in traits.docs) {
      final data = t.data() as Map<String, dynamic>;
      // Date de début traitement
      if (data['dateDebut'] != null) {
        DateTime? date;
        if (data['dateDebut'] is Timestamp) {
          date = (data['dateDebut'] as Timestamp).toDate();
        } else if (data['dateDebut'] is DateTime) {
          date = data['dateDebut'];
        } else if (data['dateDebut'] is String) {
          try {
            date = DateTime.parse(data['dateDebut']);
          } catch (e) {
            print('Date de début ignorée (format invalide): ${data['dateDebut']}');
          }
        }
        if (date != null && date.isAfter(now)) {
          rappels.add({
            'type': 'traitement',
            'label': data['nomMedicament'] ?? 'Traitement',
            'dateRappel': data['dateDebut'],
            'description': 'Début du traitement' + (data['motif'] != null ? ' (${data['motif']})' : ''),
          });
        }
      }
      // Date de fin traitement
      if (data['dateFin'] != null) {
        DateTime? date;
        if (data['dateFin'] is Timestamp) {
          date = (data['dateFin'] as Timestamp).toDate();
        } else if (data['dateFin'] is DateTime) {
          date = data['dateFin'];
        } else if (data['dateFin'] is String) {
          try {
            date = DateTime.parse(data['dateFin']);
          } catch (e) {
            print('Date de fin ignorée (format invalide): ${data['dateFin']}');
          }
        }
        if (date != null && date.isAfter(now)) {
          rappels.add({
            'type': 'traitement',
            'label': data['nomMedicament'] ?? 'Traitement',
            'dateRappel': data['dateFin'],
            'description': 'Fin du traitement' + (data['motif'] != null ? ' (${data['motif']})' : ''),
          });
        }
      }
    }
    rappels.sort((a, b) => (a['dateRappel'] as Timestamp).compareTo(b['dateRappel'] as Timestamp));
    return rappels;
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    if (date is Timestamp) date = date.toDate();
    if (date is DateTime) return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return date.toString();
  }

  void _addToGoogleCalendar(BuildContext context, Map<String, dynamic> rappel) async {
    try {
      final googleSignIn = GoogleSignIn(
        scopes: [
          'https://www.googleapis.com/auth/calendar',
        ],
      );
      GoogleSignInAccount? account = googleSignIn.currentUser;
      account ??= await googleSignIn.signIn();
      if (account == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connexion Google annulée.')),
        );
        return;
      }
      final authHeaders = await account.authHeaders;
      final client = GoogleAuthClient(authHeaders);
      final calendarApi = gcal.CalendarApi(client);

      final date = (rappel['dateRappel'] is Timestamp)
          ? (rappel['dateRappel'] as Timestamp).toDate()
          : rappel['dateRappel'] as DateTime;
      final event = gcal.Event()
        ..summary = '${rappel['type'] == 'vaccination' ? 'Vaccin' : 'Traitement'} - ${rappel['label']}'
        ..description = rappel['description'] ?? ''
        ..start = gcal.EventDateTime(dateTime: date, timeZone: 'Europe/Paris')
        ..end = gcal.EventDateTime(dateTime: date.add(const Duration(hours: 1)), timeZone: 'Europe/Paris')
        ..reminders = gcal.EventReminders(
          useDefault: false,
          overrides: [gcal.EventReminder(method: 'popup', minutes: 60 * 24)], // rappel 1 jour avant
        );
      await calendarApi.events.insert(event, 'primary');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rappel ajouté à Google Calendar !')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'ajout au calendrier : $e')),
      );
    }
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  GoogleAuthClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class VaccinationsTab extends StatelessWidget {
  final String animalId;
  final String ownerId;
  const VaccinationsTab({required this.animalId, required this.ownerId, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final vaccRef = FirebaseFirestore.instance
        .collection('users')
        .doc(ownerId)
        .collection('animals')
        .doc(animalId)
        .collection('vaccinations');
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: vaccRef.orderBy('dateVaccination', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('Aucune vaccination enregistrée.'));
            }
            final vaccs = snapshot.data!.docs;
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: vaccs.length,
              itemBuilder: (context, i) {
                final v = vaccs[i].data() as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    leading: const Icon(Icons.vaccines, color: Color(0xFFA37551)),
                    title: Text(v['typeVaccin'] ?? 'Type inconnu'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (v['nomCommercial'] != null) Text('Nom commercial : ${v['nomCommercial']}'),
                        if (v['dateVaccination'] != null) Text('Date : ${_formatDate(v['dateVaccination'])}'),
                        if (v['dureeValidite'] != null) Text('Validité : ${v['dureeValidite']}'),
                        if (v['dateRappel'] != null) Text('Rappel : ${_formatDate(v['dateRappel'])}'),
                        if (v['veterinaire'] != null) Text('Vétérinaire : ${v['veterinaire']}'),
                        if (v['lieu'] != null) Text('Lieu : ${v['lieu']}'),
                        if (v['observations'] != null) Text('Obs. : ${v['observations']}'),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (val) {
                        if (val == 'edit') {
                          _showVaccinationDialog(context, vaccRef, docId: vaccs[i].id, data: v);
                        } else if (val == 'delete') {
                          vaccRef.doc(vaccs[i].id).delete();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton(
            backgroundColor: const Color(0xFFA37551),
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
            onPressed: () => _showVaccinationDialog(context, vaccRef),
            tooltip: 'Ajouter',
          ),
        ),
      ],
    );
  }

  void _showVaccinationDialog(BuildContext context, CollectionReference vaccRef, {String? docId, Map<String, dynamic>? data}) {
    final _formKey = GlobalKey<FormState>();
    final typeVaccinCtrl = TextEditingController(text: data?['typeVaccin'] ?? '');
    final nomCommercialCtrl = TextEditingController(text: data?['nomCommercial'] ?? '');
    DateTime? dateVaccination = data?['dateVaccination'] != null ? (data!['dateVaccination'] as Timestamp).toDate() : null;
    final dureeValiditeCtrl = TextEditingController(text: data?['dureeValidite'] ?? '');
    DateTime? dateRappel = data?['dateRappel'] != null ? (data!['dateRappel'] as Timestamp).toDate() : null;
    final veterinaireCtrl = TextEditingController(text: data?['veterinaire'] ?? '');
    final lieuCtrl = TextEditingController(text: data?['lieu'] ?? '');
    final observationsCtrl = TextEditingController(text: data?['observations'] ?? '');

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFFEF9EA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      docId == null ? 'Ajouter une vaccination' : 'Modifier la vaccination',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFFA37551)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: typeVaccinCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Type de vaccin',
                      prefixIcon: Icon(Icons.vaccines, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nomCommercialCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom commercial',
                      prefixIcon: Icon(Icons.label, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date de vaccination',
                            prefixIcon: Icon(Icons.event, color: Color(0xFFA37551)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dateVaccination ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                dateVaccination = picked;
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                dateVaccination != null ? _formatDate(dateVaccination) : 'Sélectionner',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: dureeValiditeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Durée de validité',
                      prefixIcon: Icon(Icons.timelapse, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date de rappel',
                            prefixIcon: Icon(Icons.alarm, color: Color(0xFFA37551)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dateRappel ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                dateRappel = picked;
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                dateRappel != null ? _formatDate(dateRappel) : 'Sélectionner',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: veterinaireCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom du vétérinaire',
                      prefixIcon: Icon(Icons.person, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: lieuCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Lieu d\'administration',
                      prefixIcon: Icon(Icons.place, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: observationsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Observations',
                      prefixIcon: Icon(Icons.notes, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFA37551),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        child: const Text('Annuler'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA37551),
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        ),
                        onPressed: () async {
                          if (_formKey.currentState?.validate() != true) return;
                          final dataToSave = {
                            'typeVaccin': typeVaccinCtrl.text.trim(),
                            'nomCommercial': nomCommercialCtrl.text.trim(),
                            'dateVaccination': dateVaccination != null ? Timestamp.fromDate(dateVaccination!) : null,
                            'dureeValidite': dureeValiditeCtrl.text.trim(),
                            'dateRappel': dateRappel != null ? Timestamp.fromDate(dateRappel!) : null,
                            'veterinaire': veterinaireCtrl.text.trim(),
                            'lieu': lieuCtrl.text.trim(),
                            'observations': observationsCtrl.text.trim(),
                            'createdAt': FieldValue.serverTimestamp(),
                          };
                          if (docId == null) {
                            await vaccRef.add(dataToSave);
                          } else {
                            await vaccRef.doc(docId).update(dataToSave);
                          }
                          Navigator.pop(context);
                          // Ajout automatique à Google Calendar
                          if (dateVaccination != null && dateVaccination?.isAfter(DateTime.now()) == true) {
                            await addToGoogleCalendarDirect(context, {
                              'type': 'vaccination',
                              'label': typeVaccinCtrl.text.trim(),
                              'dateRappel': dateVaccination,
                              'description': 'Date de vaccination' + (nomCommercialCtrl.text.isNotEmpty ? ' (${nomCommercialCtrl.text})' : ''),
                            });
                          }
                          if (dateRappel != null && dateRappel?.isAfter(DateTime.now()) == true) {
                            await addToGoogleCalendarDirect(context, {
                              'type': 'vaccination',
                              'label': typeVaccinCtrl.text.trim(),
                              'dateRappel': dateRappel,
                              'description': 'Date de rappel' + (nomCommercialCtrl.text.isNotEmpty ? ' (${nomCommercialCtrl.text})' : ''),
                            });
                          }
                        },
                        child: Text(docId == null ? 'Ajouter' : 'Enregistrer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    if (date is Timestamp) date = date.toDate();
    if (date is DateTime) return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return date.toString();
  }
}

class TraitementsTab extends StatelessWidget {
  final String animalId;
  final String ownerId;
  const TraitementsTab({required this.animalId, required this.ownerId, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final traitRef = FirebaseFirestore.instance
        .collection('users')
        .doc(ownerId)
        .collection('animals')
        .doc(animalId)
        .collection('traitements');
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: traitRef.orderBy('dateDebut', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('Aucun traitement enregistré.'));
            }
            final traits = snapshot.data!.docs;
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: traits.length,
              itemBuilder: (context, i) {
                final t = traits[i].data() as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    leading: const Icon(Icons.medication, color: Color(0xFFA37551)),
                    title: Text(t['nomMedicament'] ?? 'Médicament inconnu'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (t['posologie'] != null) Text('Posologie : ${t['posologie']}'),
                        if (t['voie'] != null) Text('Voie : ${t['voie']}'),
                        if (t['dateDebut'] != null) Text('Début : ${_formatDate(t['dateDebut'])}'),
                        if (t['dateFin'] != null) Text('Fin : ${_formatDate(t['dateFin'])}'),
                        if (t['motif'] != null) Text('Motif : ${t['motif']}'),
                        if (t['veterinaire'] != null) Text('Vétérinaire : ${t['veterinaire']}'),
                        if (t['effetsSecondaires'] != null) Text('Effets secondaires : ${t['effetsSecondaires']}'),
                        if (t['reponse'] != null) Text('Réponse : ${t['reponse']}'),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (val) {
                        if (val == 'edit') {
                          _showTraitementDialog(context, traitRef, docId: traits[i].id, data: t);
                        } else if (val == 'delete') {
                          traitRef.doc(traits[i].id).delete();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton(
            backgroundColor: const Color(0xFFA37551),
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
            onPressed: () => _showTraitementDialog(context, traitRef),
            tooltip: 'Ajouter',
          ),
        ),
      ],
    );
  }

  void _showTraitementDialog(BuildContext context, CollectionReference traitRef, {String? docId, Map<String, dynamic>? data}) {
    final _formKey = GlobalKey<FormState>();
    final nomMedicamentCtrl = TextEditingController(text: data?['nomMedicament'] ?? '');
    final posologieCtrl = TextEditingController(text: data?['posologie'] ?? '');
    final voieCtrl = TextEditingController(text: data?['voie'] ?? '');
    DateTime? dateDebut = data?['dateDebut'] != null ? (data!['dateDebut'] as Timestamp).toDate() : null;
    DateTime? dateFin = data?['dateFin'] != null ? (data!['dateFin'] as Timestamp).toDate() : null;
    final motifCtrl = TextEditingController(text: data?['motif'] ?? '');
    final veterinaireCtrl = TextEditingController(text: data?['veterinaire'] ?? '');
    final effetsSecondairesCtrl = TextEditingController(text: data?['effetsSecondaires'] ?? '');
    final reponseCtrl = TextEditingController(text: data?['reponse'] ?? '');

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFFEF9EA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      docId == null ? 'Ajouter un traitement' : 'Modifier le traitement',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFFA37551)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: nomMedicamentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom du médicament',
                      prefixIcon: Icon(Icons.medication, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: posologieCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Posologie',
                      prefixIcon: Icon(Icons.format_list_numbered, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: voieCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Voie d\'administration',
                      prefixIcon: Icon(Icons.south, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date de début',
                            prefixIcon: Icon(Icons.event, color: Color(0xFFA37551)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dateDebut ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                dateDebut = picked;
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                dateDebut != null ? _formatDate(dateDebut) : 'Sélectionner',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date de fin',
                            prefixIcon: Icon(Icons.event_available, color: Color(0xFFA37551)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dateFin ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                dateFin = picked;
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                dateFin != null ? _formatDate(dateFin) : 'Sélectionner',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: motifCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Motif du traitement',
                      prefixIcon: Icon(Icons.info, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: veterinaireCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Vétérinaire prescripteur',
                      prefixIcon: Icon(Icons.person, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: effetsSecondairesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Effets secondaires observés',
                      prefixIcon: Icon(Icons.warning, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: reponseCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Réponse au traitement',
                      prefixIcon: Icon(Icons.check_circle, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFA37551),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        child: const Text('Annuler'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA37551),
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        ),
                        onPressed: () async {
                          if (_formKey.currentState?.validate() != true) return;
                          final dataToSave = {
                            'nomMedicament': nomMedicamentCtrl.text.trim(),
                            'posologie': posologieCtrl.text.trim(),
                            'voie': voieCtrl.text.trim(),
                            'dateDebut': dateDebut != null ? Timestamp.fromDate(dateDebut!) : null,
                            'dateFin': dateFin != null ? Timestamp.fromDate(dateFin!) : null,
                            'motif': motifCtrl.text.trim(),
                            'veterinaire': veterinaireCtrl.text.trim(),
                            'effetsSecondaires': effetsSecondairesCtrl.text.trim(),
                            'reponse': reponseCtrl.text.trim(),
                            'createdAt': FieldValue.serverTimestamp(),
                          };
                          if (docId == null) {
                            await traitRef.add(dataToSave);
                          } else {
                            await traitRef.doc(docId).update(dataToSave);
                          }
                          Navigator.pop(context);
                          // Ajout automatique à Google Calendar
                          if (dateDebut != null && dateDebut?.isAfter(DateTime.now()) == true) {
                            await addToGoogleCalendarDirect(context, {
                              'type': 'traitement',
                              'label': nomMedicamentCtrl.text.trim(),
                              'dateRappel': dateDebut,
                              'description': 'Début du traitement' + (motifCtrl.text.isNotEmpty ? ' (${motifCtrl.text})' : ''),
                            });
                          }
                          if (dateFin != null && dateFin?.isAfter(DateTime.now()) == true) {
                            await addToGoogleCalendarDirect(context, {
                              'type': 'traitement',
                              'label': nomMedicamentCtrl.text.trim(),
                              'dateRappel': dateFin,
                              'description': 'Fin du traitement' + (motifCtrl.text.isNotEmpty ? ' (${motifCtrl.text})' : ''),
                            });
                          }
                        },
                        child: Text(docId == null ? 'Ajouter' : 'Enregistrer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    if (date is Timestamp) date = date.toDate();
    if (date is DateTime) return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return date.toString();
  }
}

class AllergiesTab extends StatelessWidget {
  final String animalId;
  final String ownerId;
  const AllergiesTab({required this.animalId, required this.ownerId, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final allergieRef = FirebaseFirestore.instance
        .collection('users')
        .doc(ownerId)
        .collection('animals')
        .doc(animalId)
        .collection('allergies');
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: allergieRef.orderBy('dateDiagnostic', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('Aucune allergie/intolérance enregistrée.'));
            }
            final allergies = snapshot.data!.docs;
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: allergies.length,
              itemBuilder: (context, i) {
                final a = allergies[i].data() as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    leading: const Icon(Icons.warning, color: Color(0xFFFF9800)),
                    title: Text(a['type'] ?? 'Type inconnu'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (a['allergene'] != null) Text('Allergène : ${a['allergene']}'),
                        if (a['dateDiagnostic'] != null) Text('Diagnostic : ${_formatDate(a['dateDiagnostic'])}'),
                        if (a['symptomes'] != null) Text('Symptômes : ${a['symptomes']}'),
                        if (a['traitement'] != null) Text('Traitement : ${a['traitement']}'),
                        if (a['commentaires'] != null) Text('Commentaires : ${a['commentaires']}'),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (val) {
                        if (val == 'edit') {
                          _showAllergieDialog(context, allergieRef, docId: allergies[i].id, data: a);
                        } else if (val == 'delete') {
                          allergieRef.doc(allergies[i].id).delete();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton(
            backgroundColor: const Color(0xFFFF9800),
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
            onPressed: () => _showAllergieDialog(context, allergieRef),
            tooltip: 'Ajouter',
          ),
        ),
      ],
    );
  }

  void _showAllergieDialog(BuildContext context, CollectionReference allergieRef, {String? docId, Map<String, dynamic>? data}) {
    final _formKey = GlobalKey<FormState>();
    final typeCtrl = TextEditingController(text: data?['type'] ?? '');
    final allergeneCtrl = TextEditingController(text: data?['allergene'] ?? '');
    DateTime? dateDiagnostic = data?['dateDiagnostic'] != null ? (data!['dateDiagnostic'] as Timestamp).toDate() : null;
    final symptomesCtrl = TextEditingController(text: data?['symptomes'] ?? '');
    final traitementCtrl = TextEditingController(text: data?['traitement'] ?? '');
    final commentairesCtrl = TextEditingController(text: data?['commentaires'] ?? '');

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFFEF9EA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      docId == null ? 'Ajouter une allergie/intolérance' : 'Modifier l\'allergie/intolérance',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFFA37551)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: typeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Type (alimentaire, médicamenteuse, etc.)',
                      prefixIcon: Icon(Icons.category, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: allergeneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Allergène identifié',
                      prefixIcon: Icon(Icons.science, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date de diagnostic',
                            prefixIcon: Icon(Icons.event, color: Color(0xFFA37551)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dateDiagnostic ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                dateDiagnostic = picked;
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                dateDiagnostic != null ? _formatDate(dateDiagnostic) : 'Sélectionner',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: symptomesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Symptômes observés',
                      prefixIcon: Icon(Icons.sick, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: traitementCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Traitement recommandé / de secours',
                      prefixIcon: Icon(Icons.medical_services, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: commentairesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Commentaires ou précautions',
                      prefixIcon: Icon(Icons.notes, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFA37551),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        child: const Text('Annuler'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA37551),
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        ),
                        onPressed: () async {
                          if (_formKey.currentState?.validate() != true) return;
                          final dataToSave = {
                            'type': typeCtrl.text.trim(),
                            'allergene': allergeneCtrl.text.trim(),
                            'dateDiagnostic': dateDiagnostic != null ? Timestamp.fromDate(dateDiagnostic!) : null,
                            'symptomes': symptomesCtrl.text.trim(),
                            'traitement': traitementCtrl.text.trim(),
                            'commentaires': commentairesCtrl.text.trim(),
                            'createdAt': FieldValue.serverTimestamp(),
                          };
                          if (docId == null) {
                            await allergieRef.add(dataToSave);
                          } else {
                            await allergieRef.doc(docId).update(dataToSave);
                          }
                          Navigator.pop(context);
                        },
                        child: Text(docId == null ? 'Ajouter' : 'Enregistrer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    if (date is Timestamp) date = date.toDate();
    if (date is DateTime) return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return date.toString();
  }
}

class AntecedentsTab extends StatelessWidget {
  final String animalId;
  final String ownerId;
  const AntecedentsTab({required this.animalId, required this.ownerId, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final antecedentRef = FirebaseFirestore.instance
        .collection('users')
        .doc(ownerId)
        .collection('animals')
        .doc(animalId)
        .collection('antecedents');
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: antecedentRef.orderBy('dateEvenement', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('Aucun antécédent médical enregistré.'));
            }
            final antecedents = snapshot.data!.docs;
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: antecedents.length,
              itemBuilder: (context, i) {
                final a = antecedents[i].data() as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    leading: const Icon(Icons.history, color: Color(0xFF9C27B0)),
                    title: Text(a['type'] ?? 'Type inconnu'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (a['description'] != null) Text('Description : ${a['description']}'),
                        if (a['dateEvenement'] != null) Text('Date : ${_formatDate(a['dateEvenement'])}'),
                        if (a['etatActuel'] != null) Text('État actuel : ${a['etatActuel']}'),
                        if (a['documents'] != null) Text('Documents : ${a['documents']}'),
                        if (a['commentaires'] != null) Text('Commentaires : ${a['commentaires']}'),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (val) {
                        if (val == 'edit') {
                          _showAntecedentDialog(context, antecedentRef, docId: antecedents[i].id, data: a);
                        } else if (val == 'delete') {
                          antecedentRef.doc(antecedents[i].id).delete();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton(
            backgroundColor: const Color(0xFF9C27B0),
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
            onPressed: () => _showAntecedentDialog(context, antecedentRef),
            tooltip: 'Ajouter',
          ),
        ),
      ],
    );
  }

  void _showAntecedentDialog(BuildContext context, CollectionReference antecedentRef, {String? docId, Map<String, dynamic>? data}) {
    final _formKey = GlobalKey<FormState>();
    final typeCtrl = TextEditingController(text: data?['type'] ?? '');
    final descriptionCtrl = TextEditingController(text: data?['description'] ?? '');
    DateTime? dateEvenement = data?['dateEvenement'] != null ? (data!['dateEvenement'] as Timestamp).toDate() : null;
    final etatActuelCtrl = TextEditingController(text: data?['etatActuel'] ?? '');
    final documentsCtrl = TextEditingController(text: data?['documents'] ?? '');
    final commentairesCtrl = TextEditingController(text: data?['commentaires'] ?? '');

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFFEF9EA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      docId == null ? 'Ajouter un antécédent médical' : 'Modifier l\'antécédent médical',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFFA37551)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: typeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Type (maladie, chirurgie, blessure, etc.)',
                      prefixIcon: Icon(Icons.category, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date de l\'événement',
                            prefixIcon: Icon(Icons.event, color: Color(0xFFA37551)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dateEvenement ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                dateEvenement = picked;
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                dateEvenement != null ? _formatDate(dateEvenement) : 'Sélectionner',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: etatActuelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'État actuel / suivi en cours',
                      prefixIcon: Icon(Icons.healing, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: documentsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Documents liés (liens, noms, etc.)',
                      prefixIcon: Icon(Icons.attach_file, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: commentairesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Commentaires',
                      prefixIcon: Icon(Icons.notes, color: Color(0xFFA37551)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFA37551),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        child: const Text('Annuler'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA37551),
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        ),
                        onPressed: () async {
                          if (_formKey.currentState?.validate() != true) return;
                          final dataToSave = {
                            'type': typeCtrl.text.trim(),
                            'description': descriptionCtrl.text.trim(),
                            'dateEvenement': dateEvenement != null ? Timestamp.fromDate(dateEvenement!) : null,
                            'etatActuel': etatActuelCtrl.text.trim(),
                            'documents': documentsCtrl.text.trim(),
                            'commentaires': commentairesCtrl.text.trim(),
                            'createdAt': FieldValue.serverTimestamp(),
                          };
                          if (docId == null) {
                            await antecedentRef.add(dataToSave);
                          } else {
                            await antecedentRef.doc(docId).update(dataToSave);
                          }
                          Navigator.pop(context);
                        },
                        child: Text(docId == null ? 'Ajouter' : 'Enregistrer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    if (date is Timestamp) date = date.toDate();
    if (date is DateTime) return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return date.toString();
  }
}

Future<void> addToGoogleCalendarDirect(BuildContext context, Map<String, dynamic> rappel) async {
  try {
    final googleSignIn = GoogleSignIn(
      scopes: [
        'https://www.googleapis.com/auth/calendar',
      ],
    );
    GoogleSignInAccount? account = googleSignIn.currentUser;
    account ??= await googleSignIn.signIn();
    if (account == null) return;
    final authHeaders = await account.authHeaders;
    final client = GoogleAuthClient(authHeaders);
    final calendarApi = gcal.CalendarApi(client);
    final date = rappel['dateRappel'] is Timestamp
        ? (rappel['dateRappel'] as Timestamp).toDate()
        : rappel['dateRappel'] as DateTime;
    final event = gcal.Event()
      ..summary = '${rappel['type'] == 'vaccination' ? 'Vaccin' : 'Traitement'} - ${rappel['label']}'
      ..description = rappel['description'] ?? ''
      ..start = gcal.EventDateTime(dateTime: date, timeZone: 'Europe/Paris')
      ..end = gcal.EventDateTime(dateTime: date.add(const Duration(hours: 1)), timeZone: 'Europe/Paris')
      ..reminders = gcal.EventReminders(
        useDefault: false,
        overrides: [gcal.EventReminder(method: 'popup', minutes: 60 * 24)],
      );
    await calendarApi.events.insert(event, 'primary');
  } catch (e) {
    print('Erreur ajout Google Calendar: $e');
  }
} 