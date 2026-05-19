import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'booking_screen.dart';
import 'user_dashboard.dart'; // ✅ ADD: redirect target
import 'shared/app_ui.dart'; // ✅ use your shared header/theme

class PackagesScreen extends StatelessWidget {
  const PackagesScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    final packagesStream = FirebaseFirestore.instance
        .collection("packages")
        .orderBy("createdAt", descending: true)
        .snapshots();

    return Scaffold(
      body: Stack(
        children: [
          /// ✅ Background image (bg.jpg)
          Positioned.fill(
            child: Image.asset(
              "assets/images/bg.jpg",
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        
          /// ✅ Soft overlay for readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.50),
                    Colors.white.withValues(alpha: 0.50),
                  ],
                ),
              ),
            ),
          ),

          /// ✅ Content
          Column(
            children: [
              /// ✅ Top image header (top.jpg) + back button
              AppGradientHeader(
                title: "Car Wash Packages",
                subtitle: "Choose a package",
                description: "Select a service package to continue booking.",
                backgroundImageAsset: "assets/images/top.jpg",
                trailing: IconButton(
                  tooltip: "Back",
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),

                  /// ✅ FIXED: always go back to UserDashboard
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UserDashboard(),
                      ),
                      (route) => false,
                    );
                  },
                ),
              ),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: packagesStream,
                  builder: (context, snapshot) {
                    // Loading
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Error
                    if (snapshot.hasError) {
                      return Center(
                        child: Text("Error loading packages: ${snapshot.error}"),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    // Empty state
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text("No packages available yet."),
                      );
                    }

                    return AppPage(
                      maxWidth: 980,
                      child: GridView.builder(
                        padding: EdgeInsets.zero,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: context.gridCount(xs: 2, md: 3, lg: 4),
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;

                          // ✅ Safe parsing
                          final String name = (data["name"] ?? "").toString();
                          final double price =
                              (data["price"] as num?)?.toDouble() ?? 0.0;
                          final String imageUrl =
                              (data["imageUrl"] ?? "").toString();
                          final String description =
                              (data["description"] ?? "").toString();

                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Image
                                Expanded(
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey.shade200,
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.image_not_supported),
                                    ),
                                  ),
                                ),

                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.md,
                                    AppSpacing.md,
                                    AppSpacing.md,
                                    AppSpacing.sm,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          color: AppColors.textStrong,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Rs ${price.toStringAsFixed(0)}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textMuted,
                                          height: 1.25,
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => BookingScreen(
                                                  packageName: name,
                                                  packagePrice: price,
                                                  imageUrl: imageUrl,
                                                ),
                                              ),
                                            );
                                          },
                                          child: const Text("Select"),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
