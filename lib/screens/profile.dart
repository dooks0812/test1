import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'shared/app_ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? get _user => FirebaseAuth.instance.currentUser;

  String _plateKey(String raw) =>
      raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

  Future<void> _openCarDialog({
    String? carId,
    Map<String, dynamic>? existing,
  }) async {
    final isEdit = carId != null;
    final nickCtrl =
        TextEditingController(text: existing?["nickname"]?.toString() ?? "");
    final plateCtrl =
        TextEditingController(text: existing?["plateRaw"]?.toString() ?? "");

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEdit ? "Edit Car" : "Add Car"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nickCtrl,
              decoration: InputDecoration(
                labelText: "Nickname / name",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: plateCtrl,
              decoration: InputDecoration(
                labelText: "Plate number",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final nick = nickCtrl.text.trim();
              final plateRaw = plateCtrl.text.trim();
              final key = _plateKey(plateRaw);

              if (nick.isEmpty || plateRaw.isEmpty || key.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Please fill nickname and plate correctly.")),
                );
                return;
              }

              final uid = _user?.uid;
              if (uid == null) return;

              final carsCol = FirebaseFirestore.instance
                  .collection("users")
                  .doc(uid)
                  .collection("cars");

              final payload = {
                "nickname": nick,
                "plateRaw": plateRaw,
                "plateKey": key,
                "updatedAt": FieldValue.serverTimestamp(),
              };

              try {
                if (isEdit) {
                  await carsCol.doc(carId).update(payload);
                } else {
                  await carsCol.add({
                    ...payload,
                    "createdAt": FieldValue.serverTimestamp(),
                  });
                }
                if (!mounted || !ctx.mounted) return;
                Navigator.pop(ctx);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e")),
                );
              }
            },
            child: Text(isEdit ? "Update" : "Add"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCar(String carId, String nickname) async {
    final uid = _user?.uid;
    if (uid == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete car?"),
        content: Text("Delete \"$nickname\" permanently?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("cars")
        .doc(carId)
        .delete();
  }

  Future<void> _updateContactDialog(Map<String, dynamic> existing) async {
    final nameCtrl =
        TextEditingController(text: existing["name"]?.toString() ?? "");
    final phoneCtrl =
        TextEditingController(text: existing["phone"]?.toString() ?? "");

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Edit Contact Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: "Name",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "Phone",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final uid = _user?.uid;
              if (uid == null) return;

              await FirebaseFirestore.instance.collection("users").doc(uid).update({
                "name": nameCtrl.text.trim(),
                "phone": phoneCtrl.text.trim(),
                "updatedAt": FieldValue.serverTimestamp(),
              });

              if (!mounted || !ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _user?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text("Please login first.")),
      );
    }

    final userDoc = FirebaseFirestore.instance.collection("users").doc(uid);
    final carsCol =
        userDoc.collection("cars").orderBy("createdAt", descending: true);

    return Scaffold(
      extendBodyBehindAppBar: false,

      // TOP IMAGE in AppBar area (behind title)
      appBar: AppBar(
        title: const Text(
          "Profile",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        toolbarHeight: 70,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: "Add car",
            onPressed: () => _openCarDialog(),
            icon: const Icon(Icons.add),
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/images/top.jpg"),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            // dark overlay so title/icons stay readable
            color: Colors.black.withValues(alpha: 0.25),
          ),
        ),
        backgroundColor: Colors.transparent,
      ),

      // Background image
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/images/bg.jpg",
              fit: BoxFit.cover,
            ),
          ),

          // light overlay so cards are readable
          Positioned.fill(
            child: Container(
              color: const Color(0xFFEAF1FF).withValues(alpha: 0.45),
            ),
          ),

          // Original layout kept (Column with StreamBuilders)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Contact details
                StreamBuilder<DocumentSnapshot>(
                  stream: userDoc.snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const LinearProgressIndicator();
                    final data =
                        (snap.data!.data() as Map<String, dynamic>?) ?? {};

                    final name = (data["name"] ?? "").toString();
                    final email = (data["email"] ?? "").toString();
                    final phone = (data["phone"] ?? "").toString();

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        title: Text(
                          name.isEmpty ? "Your Name" : name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            phone.trim().isEmpty ? email : "$email\n$phone",
                          ),
                        ),
                        isThreeLine: phone.trim().isNotEmpty,
                        trailing: Container(
                          decoration: BoxDecoration(
                            color: AppColors.brandA.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            tooltip: "Edit contact",
                            icon: const Icon(Icons.edit),
                            onPressed: () => _updateContactDialog(data),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 10),

                // Cars list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: carsCol.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text("Error: ${snapshot.error}"));
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(
                          child: Text("No cars yet. Tap + to add a car."),
                        );
                      }

                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final doc = docs[i];
                          final data = doc.data() as Map<String, dynamic>;
                          final id = doc.id;

                          final nick = (data["nickname"] ?? "").toString();
                          final plate = (data["plateRaw"] ?? "").toString();

                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              leading: Container(
                                height: 42,
                                width: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.brandA.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.directions_car,
                                    color: AppColors.brandA),
                              ),
                              title: Text(
                                nick,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(plate),
                              trailing: Wrap(
                                spacing: 6,
                                children: [
                                  IconButton(
                                    tooltip: "Edit",
                                    icon: const Icon(Icons.edit),
                                    onPressed: () =>
                                        _openCarDialog(carId: id, existing: data),
                                  ),
                                  IconButton(
                                    tooltip: "Delete",
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _deleteCar(id, nick),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
