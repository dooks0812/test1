import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// ✅ Register User (Email & Password)
  Future<String?> registerUser({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      // Create user in Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save user details in Firestore
      await _db.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'user', // default role
        'createdAt': Timestamp.now(),
      });

      return "Registration Successful";
    } catch (e) {
      return e.toString();
    }
  }

  /// ✅ Login User
  Future<String?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return "Login Successful";
    } catch (e) {
      return e.toString();
    }
  }

  /// ✅ Logout User
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// ✅ Get Current Logged-In User
  User? get currentUser => _auth.currentUser;

  /// ✅ Check if User is Admin or Normal User
  Future<String?> getUserRole() async {
    try {
      String uid = _auth.currentUser!.uid;
      DocumentSnapshot userDoc = await _db.collection('users').doc(uid).get();
      return userDoc['role']; // 'admin' or 'user'
    } catch (e) {
      return null;
    }
  }

  /// ✅ Reset Password (Email Reset Link)
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return "Password reset email sent!";
    } catch (e) {
      return e.toString();
    }
  }
}
