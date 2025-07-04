import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  final bool isGuest;
  const HomeScreen({super.key, required this.isGuest});

  static bool getIsGuest(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    return args != null && args['isGuest'] == false ? false : true;
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool get isGuest => widget.isGuest;

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isGuest');
      // Naviguer vers l'écran de connexion
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Erreur lors de la déconnexion: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool effectiveIsGuest = HomeScreen.getIsGuest(context);
    final Color brown = const Color(0xFFA37551);
    final Color background = const Color(0xFFFEF9EA);
    final Color buttonText = Colors.white;
    final double buttonHeight = 54;
    final double buttonSpacing = 22;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        titleSpacing: 0,
        title: Text(
          'Accueil',
          style: TextStyle(
            color: brown,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          if (!effectiveIsGuest) ...[
            IconButton(
              icon: Icon(Icons.notifications, color: brown),
                  onPressed: () {
                    Navigator.pushNamed(context, '/notifications');
                  },
              tooltip: 'Notifications',
            ),
            IconButton(
              icon: Icon(Icons.settings, color: brown),
              onPressed: () {
                Navigator.pushNamed(context, '/settings');
              },
              tooltip: 'Paramètres',
            ),
          ]
          else
            IconButton(
              icon: Icon(Icons.logout, color: brown),
              onPressed: _signOut,
              tooltip: 'Déconnexion',
            ),
        ],
      ),
      body: Center(
        child: effectiveIsGuest
            ? Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: Image.asset(
                      'assets/animal.png',
                      height: 500,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Builder(
                    builder: (context) => SizedBox(
                      width: MediaQuery.of(context).size.width * 0.9,
                      height: 54,
                      child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/nfc', arguments: {'isGuest': true});
                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEAD7C0),
                          foregroundColor: brown,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: brown.withOpacity(0.18)),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 20,
                          ),
                        ),
                        child: const Text("Scanner une puce NFC d'animal"),
                      ),
                    ),
                  ),
                ],
              )
            : FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseAuth.instance.currentUser != null
                    ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .get()
                    : Future.value(null),
                builder: (context, snapshot) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                        Expanded(
                          child: GridView(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 28,
                              mainAxisSpacing: 28,
                              childAspectRatio: 1.05,
                            ),
                            children: [
                              _HomeCard(
                                color: const Color(0xFFD6F5D6),
                        icon: Icons.pets,
                        label: 'Mes animaux',
                                onTap: () => Navigator.pushNamed(context, '/my_animals'),
                      ),
                              _HomeCard(
                                color: const Color(0xFFFFE0E0),
                        icon: Icons.qr_code_scanner,
                        label: 'Scanner un animal',
                                onTap: () => Navigator.pushNamed(context, '/nfc', arguments: {'isGuest': false}),
                              ),
                              _HomeCard(
                                color: const Color(0xFFE3E6FA),
                                icon: Icons.shopping_cart,
                                label: 'Marché des animaux',
                                onTap: () => Navigator.pushNamed(context, '/market'),
                      ),
                              _HomeCard(
                                color: const Color(0xFFD6F6FA),
                        icon: Icons.history,
                        label: 'Historique',
                                onTap: () => Navigator.pushNamed(context, '/history'),
                      ),
                            ],
                          ),
                      ),
                    ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HomeCard({required this.color, required this.icon, required this.label, required this.onTap, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final Color brown = const Color(0xFFA37551);
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: brown, size: 40),
            const SizedBox(height: 18),
            Text(
          label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
            fontSize: 18,
                letterSpacing: 0.2,
              ),
          ),
          ],
        ),
      ),
    );
  }
}
