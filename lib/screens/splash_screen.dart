import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF9EA),
      body: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, prefsSnapshot) {
          if (!prefsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final prefs = prefsSnapshot.data!;
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              Future.delayed(const Duration(seconds: 1), () {
                if (!context.mounted) return;
                if (prefs.getBool('isGuest') == true) {
                  Navigator.pushReplacementNamed(context, '/home', arguments: {'isGuest': true});
                } else if (snapshot.data != null) {
                  Navigator.pushReplacementNamed(context, '/home', arguments: {'isGuest': false});
                } else {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              });
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/splash.png',
                      width: 250,
                      height: 400,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.pets, size: 100, color: Color(0xFFA37551)),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'PetTrack',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFA37551),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
} 