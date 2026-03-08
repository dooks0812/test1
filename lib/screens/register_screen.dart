import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ shared theme/widgets
import 'shared/app_ui.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _showPassword = false;

  final List<TextEditingController> _nickCtrls = [];
  final List<TextEditingController> _plateCtrls = [];

  @override
  void initState() {
    super.initState();
    _addCarRow(); // start with 1 car
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    for (final c in _nickCtrls) c.dispose();
    for (final c in _plateCtrls) c.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _addCarRow() {
    _nickCtrls.add(TextEditingController());
    _plateCtrls.add(TextEditingController());
    setState(() {});
  }

  void _removeCarRow(int index) {
    _nickCtrls[index].dispose();
    _plateCtrls[index].dispose();
    _nickCtrls.removeAt(index);
    _plateCtrls.removeAt(index);
    setState(() {});
  }

  // Normalize: "7890 MR 22" -> "7890MR22"
  String _plateKey(String raw) {
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty) {
      _toast("Please fill all contact details.");
      return;
    }

    if (_nickCtrls.isEmpty) {
      _toast("Please add at least one car.");
      return;
    }

    for (int i = 0; i < _nickCtrls.length; i++) {
      final nick = _nickCtrls[i].text.trim();
      final plate = _plateCtrls[i].text.trim();

      if (nick.isEmpty || plate.isEmpty) {
        _toast("Please fill nickname and plate for car ${i + 1}.");
        return;
      }
      if (_plateKey(plate).isEmpty) {
        _toast("Car ${i + 1}: invalid plate format.");
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      // 1) Create account in Firebase Auth
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;

      // 2) Create user profile in Firestore (NO FACE DATA)
      final userDoc = FirebaseFirestore.instance.collection("users").doc(uid);
      await userDoc.set({
        "name": name,
        "email": email,
        "phone": phone,
        "role": "user",
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3) Save cars in subcollection
      final carsCol = userDoc.collection("cars");
      for (int i = 0; i < _nickCtrls.length; i++) {
        final nickname = _nickCtrls[i].text.trim();
        final plateRaw = _plateCtrls[i].text.trim();
        final plateKey = _plateKey(plateRaw);

        await carsCol.add({
          "nickname": nickname,
          "plateRaw": plateRaw,
          "plateKey": plateKey,
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      _toast("Account created successfully!");
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg = "Registration failed";
      if (e.code == "email-already-in-use") msg = "Email already in use";
      if (e.code == "invalid-email") msg = "Invalid email";
      if (e.code == "weak-password") msg = "Password too weak";
      _toast(msg);
    } catch (e) {
      _toast("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _carRow(int index) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  "Car ${index + 1}",
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                if (_nickCtrls.length > 1)
                  IconButton(
                    tooltip: "Remove car",
                    onPressed: _isLoading ? null : () => _removeCarRow(index),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _nickCtrls[index],
              decoration: const InputDecoration(
                labelText: "Car nickname / name (e.g. Corolla, BMW)",
                prefixIcon: Icon(Icons.directions_car_filled_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _plateCtrls[index],
              decoration: const InputDecoration(
                labelText: "Plate number (e.g. 7890 MR 22)",
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppGradientHeader(
            title: "Register",
            subtitle: "Create your account",
            description: "Add contact details and your car plate(s) for IoT tracking.",
            backgroundImageAsset: "assets/images/top.jpg",
            trailing: IconButton(
              tooltip: "Back",
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: AppPage(
              maxWidth: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "Contact Details",
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: "Full name",
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: "Phone number",
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: "Email",
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextField(
                              controller: _passwordCtrl,
                              obscureText: !_showPassword,
                              decoration: InputDecoration(
                                labelText: "Password",
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  tooltip: _showPassword ? "Hide password" : "Show password",
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                  ),
                                  onPressed: () => setState(() => _showPassword = !_showPassword),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    Row(
                      children: [
                        Text(
                          "Cars",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _isLoading ? null : _addCarRow,
                          icon: const Icon(Icons.add),
                          label: const Text("Add car"),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    for (int i = 0; i < _nickCtrls.length; i++) ...[
                      _carRow(i),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    const SizedBox(height: AppSpacing.lg),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        child: _isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text("Create account"),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.sensors, size: 18, color: AppColors.textMuted),
                        SizedBox(width: 8),
                        Text(
                          "Plate-based IoT monitoring enabled",
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}