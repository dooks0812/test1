import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'shared/app_ui.dart';

class AdminCrudScreen extends StatefulWidget {
  const AdminCrudScreen({super.key});

  @override
  State<AdminCrudScreen> createState() => _AdminCrudScreenState();
}

class _AdminCrudScreenState extends State<AdminCrudScreen> {
  final CollectionReference _packagesCol =
      FirebaseFirestore.instance.collection("packages");

// Simple URL validation (http/https)
  bool _isValidHttpUrl(String url) {
    final u = Uri.tryParse(url.trim());
    if (u == null) return false;
    if (!(u.scheme == "http" || u.scheme == "https")) return false;
    if (u.host.isEmpty) return false;
    return true;
  }

  /// Create or Update dialog
  Future<void> _openPackageDialog({
    String? docId,
    Map<String, dynamic>? existing,
  }) async {
    final bool isEdit = (docId ?? "").trim().isNotEmpty;

    final nameCtrl = TextEditingController(
      text: (existing?["name"] ?? existing?["packageName"] ?? "").toString(),
    );
    final priceCtrl = TextEditingController(
      text: existing?["price"] == null ? "" : existing!["price"].toString(),
    );
    final descCtrl =
        TextEditingController(text: existing?["description"]?.toString() ?? "");
    final imgCtrl = TextEditingController(
      text: (existing?["imageUrl"] ?? existing?["image"] ?? "").toString(),
    );

    String? inlineError;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final imageUrl = imgCtrl.text.trim();
            final showPreview =
                imageUrl.isNotEmpty && _isValidHttpUrl(imageUrl);

            return AlertDialog(
              title: Text(isEdit ? "Update Package" : "Create Package"),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    if (inlineError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          inlineError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    // ----------------------------
                    // Package name
                    // ----------------------------
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: "Package Name",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ----------------------------
                    // Price
                    // ----------------------------
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Price (Rs)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ----------------------------
                    // Description
                    // ----------------------------
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Description",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ----------------------------
                    // Image URL (FREE alternative to Firebase Storage)
                    // ----------------------------
                    TextField(
                      controller: imgCtrl,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: "Image URL (ImgBB / Postimages direct link)",
                        hintText: "https://i.ibb.co/xxxxx/image.jpg",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ----------------------------
                    // Live Preview
                    // ----------------------------
                    if (imgCtrl.text.trim().isNotEmpty && !showPreview)
                      Container(
                        height: 120,
                        width: double.infinity,
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Text(
                          "Invalid URL.\nUse a direct http/https image link.",
                          textAlign: TextAlign.center,
                        ),
                      ),

                    if (showPreview)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          imageUrl,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 120,
                            width: double.infinity,
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Text(
                              "Image failed to load.\nUse a direct image link.",
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => inlineError = null);
                          final name = nameCtrl.text.trim();
                          final priceStr = priceCtrl.text.trim();
                          final desc = descCtrl.text.trim();
                          final img = imgCtrl.text.trim();

                          // Validate fields
                          if (name.isEmpty || priceStr.isEmpty || img.isEmpty) {
                            setDialogState(() {
                              inlineError =
                                  "Please fill package name, price, and image URL.";
                            });
                            return;
                          }

                          // Validate price
                          final price = double.tryParse(priceStr);
                          if (price == null) {
                            setDialogState(() {
                              inlineError = "Price must be a number.";
                            });
                            return;
                          }

                          // Validate URL
                          if (!_isValidHttpUrl(img)) {
                            setDialogState(() {
                              inlineError =
                                  "Invalid image URL. Use a direct http/https link.";
                            });
                            return;
                          }

                          final payload = <String, dynamic>{
                            "name": name,
                            "packageName": name,
                            "price": price,
                            "description": desc,
                            "imageUrl": img,
                            "updatedAt": FieldValue.serverTimestamp(),
                          };

                          setDialogState(() => isSaving = true);

                          try {
                            if (isEdit) {
                              await _packagesCol.doc(docId!).set(
                                    payload,
                                    SetOptions(merge: true),
                                  );
                            } else {
                              await _packagesCol.add({
                                ...payload,
                                "createdAt": FieldValue.serverTimestamp(),
                              });
                            }

                            if (!mounted || !ctx.mounted) return;
                            Navigator.pop(ctx);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEdit
                                      ? "Package updated ✅"
                                      : "Package created ✅",
                                ),
                              ),
                            );
                          } on FirebaseException catch (e) {
                            if (!mounted || !ctx.mounted) return;
                            setDialogState(() {
                              isSaving = false;
                              inlineError =
                                  e.message ?? "Firebase error: ${e.code}";
                            });
                          } catch (e) {
                            if (!mounted || !ctx.mounted) return;
                            setDialogState(() {
                              isSaving = false;
                              inlineError = "Error: $e";
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEdit ? "Update" : "Create"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Delete package
  Future<void> _deletePackage(String docId, String pkgName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete package?"),
        content: Text("Delete \"$pkgName\" permanently?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _packagesCol.doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Package deleted ✅")),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Firebase error: ${e.message}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin - Manage Packages"),
        backgroundColor: AppColors.brandA,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: "Add Package",
            onPressed: () => _openPackageDialog(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _packagesCol.orderBy("createdAt", descending: true).snapshots(),
        builder: (context, snapshot) {
          // Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
//Gets all package documents.
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text("No packages yet. Tap + to add."),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final id = doc.id;

              final name =
                  (data["name"] ?? data["packageName"] ?? "").toString();
              final desc = (data["description"] ?? "").toString();
              final img = (data["imageUrl"] ?? data["image"] ?? "").toString();
              final rawPrice = data["price"];
              final price = rawPrice is num
                  ? rawPrice.toDouble()
                  : double.tryParse(rawPrice?.toString() ?? "") ?? 0.0;

              return Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          img,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 90,
                            height: 90,
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(Icons.image_not_supported),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text("Rs ${price.toStringAsFixed(0)}"),
                            const SizedBox(height: 6),
                            Text(
                              desc,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _openPackageDialog(
                                    docId: id,
                                    existing: data,
                                  ),
                                  icon: const Icon(Icons.edit),
                                  label: const Text("Edit"),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton.icon(
                                  onPressed: () => _deletePackage(id, name),
                                  icon: const Icon(Icons.delete),
                                  label: const Text("Delete"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
