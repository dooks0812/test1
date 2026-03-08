import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/shared/app_ui.dart';
import 'screens/login_screen.dart';
import 'screens/user_dashboard.dart';
import 'screens/admin_dashboard.dart';

import 'package:car_wash_app/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase
  await Firebase.initializeApp();
  await LocalNotifs.init();


  // ✅ setPersistence is WEB-ONLY. Android/iOS persist automatically.
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  runApp(const MyApp());
}

/// Root app
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AuthGate(),
    );
  }
}

/// ✅ AuthGate decides what to show based on login session
/// - Not logged in -> LoginScreen
/// - Logged in -> AdminDashboard (if admin@gmail.com) else UserDashboard
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  /// ✅ Admin rule (simple and reliable for now)
  bool _isAdmin(User user) {
    return (user.email ?? "").toLowerCase() == "admin@gmail.com";
  }

  /// Ensure Firestore user profile exists (prevents role lookup / null doc problems)
  Future<void> _ensureUserProfile(User user) async {
    final userDoc = FirebaseFirestore.instance.collection("users").doc(user.uid);

    final snap = await userDoc.get();
    if (snap.exists) return;

    // ✅ Create a minimal profile document
    await userDoc.set({
      "name": user.displayName ?? "",
      "email": user.email ?? "",
      "role": _isAdmin(user) ? "admin" : "user",
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get role from Firestore (fallback to admin email or "user")
  Future<String> _getRole(User user) async {
    // ✅ Email-based admin always wins
    if (_isAdmin(user)) return "admin";

    final doc =
        await FirebaseFirestore.instance.collection("users").doc(user.uid).get();

    if (!doc.exists) return "user";

    final data = doc.data();
    return (data?["role"] as String?)?.toLowerCase() ?? "user";
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // ✅ Firebase keeps session automatically on Android/iOS
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        // Loading state
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data;

        // Not logged in -> login screen
        if (user == null) {
          return const LoginScreen();
        }

        // Logged in -> ensure profile doc exists -> then route
        return FutureBuilder<void>(
          future: _ensureUserProfile(user),
          builder: (context, ensureSnap) {
            if (ensureSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (ensureSnap.hasError) {
              return Scaffold(
                body: Center(
                  child: Text(
                    "Profile setup error:\n${ensureSnap.error}",
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            // Now fetch role and route
            return FutureBuilder<String>(
              future: _getRole(user),
              builder: (context, roleSnap) {
                if (roleSnap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (roleSnap.hasError) {
                  return Scaffold(
                    body: Center(
                      child: Text(
                        "Role check error:\n${roleSnap.error}",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final role = (roleSnap.data ?? "user").toLowerCase();

                if (role == "admin") {
                  return const AdminDashboard();
                }

                return const UserDashboard();
              },
            );
          },
        );
      },
    );
  }
}
