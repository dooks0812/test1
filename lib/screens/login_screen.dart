import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ Shared theme/widgets
import 'shared/app_ui.dart';

import 'user_dashboard.dart';
import 'admin_dashboard.dart';
import 'register_screen.dart';

// ✅ Built-in phone biometrics (Face/Fingerprint)
import 'package:local_auth/local_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  // ✅ Show/hide password
  bool _obscurePassword = true;

  // ✅ Forgot password loading
  bool _isResetting = false;

  // ✅ Phone biometric state (KEEP)
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _phoneBioAvailable = false;
  bool _phoneBioUnlocking = false;

  @override
  void initState() {
    super.initState();
    _initPhoneBiometricState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------------------------------------------------------------------
  // ✅ PHONE BUILT-IN BIOMETRICS (FACE/FINGERPRINT)  (KEEP)
  // ---------------------------------------------------------------------------

  Future<void> _initPhoneBiometricState() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!mounted) return;
      setState(() => _phoneBioAvailable = supported && canCheck);
    } catch (_) {
      if (!mounted) return;
      setState(() => _phoneBioAvailable = false);
    }
  }

  Future<void> _unlockWithPhoneBiometrics() async {
    if (_phoneBioUnlocking) return;

    if (!_phoneBioAvailable) {
      _toast("Phone biometrics not available. Enable Face/Fingerprint in Settings.");
      return;
    }

    setState(() => _phoneBioUnlocking = true);

    bool ok = false;
    try {
      ok = await _localAuth.authenticate(
        localizedReason: "Unlock Teknik Wash",
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      _toast("Biometric error: $e");
    }

    if (!mounted) return;
    setState(() => _phoneBioUnlocking = false);

    if (!ok) return;

    // IMPORTANT: built-in biometrics does NOT sign in to Firebase.
    // It only unlocks access to an already stored Firebase session.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast("Please login once with email & password first.");
      return;
    }

    final email = user.email ?? "";
    final role = await _ensureProfileAndGetRole(uid: user.uid, email: email);

    if (!mounted) return;
    _routeByRole(role);
  }

  // ---------------------------------------------------------------------------
  // ✅ EMAIL/PASSWORD LOGIN (FIRST TIME)
  // ---------------------------------------------------------------------------

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _toast("Please enter email and password");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(code: "no-user", message: "No user returned.");
      }

      final role = await _ensureProfileAndGetRole(uid: user.uid, email: email);

      if (!mounted) return;
      _routeByRole(role);
    } on FirebaseAuthException catch (e) {
      String msg = "Login failed";
      if (e.code == "user-not-found") msg = "No account found for this email";
      if (e.code == "wrong-password") msg = "Incorrect password";
      if (e.code == "invalid-email") msg = "Invalid email";
      if (e.code == "user-disabled") msg = "This account has been disabled";
      if (e.code == "too-many-requests") msg = "Too many attempts, try later";
      _toast(msg);
    } catch (e) {
      _toast("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ ROLE / ROUTING
  // ---------------------------------------------------------------------------

  Future<String> _ensureProfileAndGetRole({
    required String uid,
    required String email,
  }) async {
    final users = FirebaseFirestore.instance.collection("users");
    final doc = await users.doc(uid).get();

    String role = "user";

    if (doc.exists) {
      final data = doc.data();
      role = (data?["role"] as String?)?.toLowerCase() ?? "user";
    } else {
      await users.doc(uid).set({
        "name": "",
        "email": email,
        "role": "user",
        "createdAt": FieldValue.serverTimestamp(),
      });
      role = "user";
    }

    return role;
  }

  void _routeByRole(String role) {
    if (role == "admin") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UserDashboard()),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ FORGOT PASSWORD
  // ---------------------------------------------------------------------------

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _toast("Enter your email first.");
      return;
    }

    setState(() => _isResetting = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _toast("Password reset link sent to $email. Check inbox/spam.");
    } on FirebaseAuthException catch (e) {
      String msg = "Failed to send reset email";
      if (e.code == "invalid-email") msg = "Invalid email";
      if (e.code == "user-not-found") msg = "No account found for this email";
      _toast(msg);
    } catch (e) {
      _toast("Error: $e");
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final userHasSession = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      body: Column(
        children: [
          const AppGradientHeader(
            title: "Teknik Wash",
            description: "Secure login to manage bookings and wash progress.",
            backgroundImageAsset: "assets/images/top.jpg",
          ),
          Expanded(
            child: AppPage(
              maxWidth: 440,
              child: SingleChildScrollView(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 6),

                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [AppColors.brandA, AppColors.brandB],
                                ),
                                boxShadow: AppShadows.soft(),
                              ),
                              child: CircleAvatar(
                                radius: 44,
                                backgroundColor: Colors.white,
                                child: ClipOval(
                                  child: Image.asset(
                                    "assets/images/logo.png",
                                    width: 62,
                                    height: 62,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.local_car_wash_rounded,
                                        size: 44,
                                        color: AppColors.brandA,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          Text(
                            "Welcome Back",
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            userHasSession
                                ? "Use Face ID to continue"
                                : "Login once with email & password, then Face ID will work",
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email,
                            ],
                            decoration: const InputDecoration(
                              labelText: "Email",
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.md),

                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: "Password",
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword ? "Show password" : "Hide password",
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                ),
                                onPressed: () =>
                                    setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            onEditingComplete: () => FocusScope.of(context).unfocus(),
                          ),

                          const SizedBox(height: AppSpacing.sm),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isResetting ? null : _forgotPassword,
                              child: _isResetting
                                  ? const Text("Sending...")
                                  : const Text("Forgot password?"),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.md),

                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _login,
                                    child: const Text("Login (First time)"),
                                  ),
                                ),

                          const SizedBox(height: AppSpacing.md),

                          // ✅ KEEP: Phone built-in Face/Fingerprint prompt
                          OutlinedButton.icon(
                            onPressed: _phoneBioUnlocking ? null : _unlockWithPhoneBiometrics,
                            icon: const Icon(Icons.fingerprint),
                            label: Text(
                              _phoneBioUnlocking
                                  ? "Unlocking..."
                                  : (_phoneBioAvailable
                                      ? "Unlock with Phone Face ID"
                                      : "Phone Face ID not available"),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.md),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.sensors, size: 18, color: AppColors.textMuted),
                              SizedBox(width: 8),
                              Text(
                                "Real-time monitoring enabled",
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ],
                          ),

                          const SizedBox(height: AppSpacing.md),

                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RegisterScreen()),
                              );
                            },
                            child: const Text("Not registered? Sign Up"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}