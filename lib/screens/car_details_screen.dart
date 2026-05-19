import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'shared/app_ui.dart';
import 'payment_screen.dart';

class CarDetailsScreen extends StatefulWidget {
  //from BookingScreen
  final String bookingId;
  final DateTime bookingDate;
  final String timeSlot;

  //optional package data
  final String? packageName;
  final double? packagePrice;
  final String? imageUrl;

  const CarDetailsScreen({
    super.key,
    required this.bookingId,
    required this.bookingDate,
    required this.timeSlot,
    this.packageName,
    this.packagePrice,
    this.imageUrl,
  });

  @override
  State<CarDetailsScreen> createState() => _CarDetailsScreenState();
}

class _CarDetailsScreenState extends State<CarDetailsScreen> {
  bool _isSaving = false;

  //Selected car (document id)
  String? _selectedCarId;

  String _formatDate(DateTime d) => "${d.day}/${d.month}/${d.year}";

  ///Save selected car into booking and go to payment
  Future<void> _saveSelectedCarAndGoPayment({
    required Map<String, dynamic> carData,
    required String carId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;//chk if logged in
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in.")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final nickname = (carData["nickname"] ?? "My Car").toString().trim();
      final plateRaw =
          (carData["plateRaw"] ?? "").toString().trim().toUpperCase();
      final plateKey =
          (carData["plateKey"] ?? "").toString().trim().toUpperCase();

      if (plateRaw.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Selected car has no plate number.")),
        );
        return;
      }

      //Attach car selection to booking document
      await FirebaseFirestore.instance //updates the existing booking document
          .collection("bookings")
          .doc(widget.bookingId)
          .update({
        "car": {
          "carId": carId,
          "nickname": nickname,
          "plateRaw": plateRaw, // display value
          "plateKey": plateKey, // matching value for OCR
        },
        "carSelectedAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen( //opens the payment screen and these value are passed on 
            bookingId: widget.bookingId,
            date: _formatDate(widget.bookingDate),
            time: widget.timeSlot,
            price: widget.packagePrice ?? 0.0,
          ),
        ),
      );
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Firebase error: ${e.message}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPackage = widget.packageName != null && //checks whether all package values are available
        widget.packagePrice != null &&
        widget.imageUrl != null;

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Stack(
        children: [
          ///Background image (bg.jpg)
          Positioned.fill(
            child: Image.asset(
              "assets/images/bg.jpg",
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

          ///Soft overlay for readability
          Positioned.fill(
            child: Container(color: Colors.white.withValues(alpha: 0.72)),
          ),

          ///Whole screen scrollable INCLUDING the header
          (user == null)
              ? const Center(child: Text("You must be logged in."))
              : StreamBuilder<QuerySnapshot>( //istens to the logged-in user’s saved cars in real time
                  stream: FirebaseFirestore.instance
                      .collection("users")
                      .doc(user.uid)
                      .collection("cars")
                      .orderBy("createdAt", descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    // Loading
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Error
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }

                    final docs = snapshot.data?.docs ?? [];

                    // Empty cars
                    if (docs.isEmpty) {
                      return CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: AppGradientHeader(
                              title: "Select Vehicle",
                              subtitle: "Almost done",
                              description:
                                  "Choose your car plate for IoT tracking and continue to payment.",
                              backgroundImageAsset: "assets/images/top.jpg",
                              trailing: IconButton(
                                tooltip: "Back",
                                icon: const Icon(Icons.arrow_back_rounded,
                                    color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: AppPage(
                              maxWidth: 640,
                              child: Center(
                                child: Text(
                                  "No cars found in your profile.\n"
                                  "Please add a car during registration or in Profile.",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: AppColors.textMuted),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    //dropdown items
                    final items = docs.map((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final nickname =
                          (data["nickname"] ?? "My Car").toString();
                      final plateRaw = (data["plateRaw"] ?? "").toString();

                      final label = plateRaw.trim().isEmpty
                          ? nickname
                          : "$nickname • $plateRaw";

                      return DropdownMenuItem<String>(
                        value: d.id,
                        child: Text(label, overflow: TextOverflow.ellipsis),
                      );
                    }).toList();

                    //Ensure selected value stays valid
                    if (_selectedCarId == null ||
                        !docs.any((d) => d.id == _selectedCarId)) {
                      _selectedCarId = docs.first.id;
                    }

                    return CustomScrollView(
                      slivers: [
                        ///Header is now scrollable (part of the scroll view)
                        SliverToBoxAdapter(
                          child: AppGradientHeader(
                            title: "Select Vehicle",
                            subtitle: "Almost done",
                            description:
                                "Choose your car plate for IoT tracking and continue to payment.",
                            backgroundImageAsset: "assets/images/top.jpg",
                            trailing: IconButton(
                              tooltip: "Back",
                              icon: const Icon(Icons.arrow_back_rounded,
                                  color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),

                        SliverToBoxAdapter(
                          child: AppPage(
                            maxWidth: 640,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ///Booking Summary card
                                Card(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.all(AppSpacing.lg),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Booking Summary",
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: AppSpacing.md),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.event_available_rounded,
                                              size: 18,
                                              color: AppColors.textMuted,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              "Date: ${_formatDate(widget.bookingDate)}",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.access_time_rounded,
                                              size: 18,
                                              color: AppColors.textMuted,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              "Time: ${widget.timeSlot}",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: AppSpacing.lg),

                                ///Bigger package tile + reasonable image size
                                if (hasPackage) ...[
                                  Card(
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.all(AppSpacing.lg),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Selected Package",
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          const SizedBox(height: AppSpacing.md),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    AppRadii.lg),
                                            child: AspectRatio(
                                              aspectRatio: 16 / 9,
                                              child: Image.network(
                                                widget.imageUrl!,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (_, __, ___) => Container(
                                                  color: Colors.grey.shade200,
                                                  alignment: Alignment.center,
                                                  child: const Icon(
                                                    Icons.image_not_supported,
                                                    size: 34,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: AppSpacing.md),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  widget.packageName!,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleLarge
                                                      ?.copyWith(fontSize: 20),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF16A34A)
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                  border: Border.all(
                                                    color: const Color(
                                                            0xFF16A34A)
                                                        .withValues(alpha: 0.35),
                                                  ),
                                                ),
                                                child: Text(
                                                  "Rs ${widget.packagePrice!.toStringAsFixed(2)}",
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF16A34A),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          const Text(
                                            "Now select the car you will bring to the wash.",
                                            style: TextStyle(
                                                color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                ],

                                ///Select car card
                                Card(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.all(AppSpacing.lg),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Select Your Car",
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: AppSpacing.md),
                                        DropdownButtonFormField<String>(
                                          initialValue: _selectedCarId,
                                          items: items,
                                          decoration: const InputDecoration(
                                            labelText: "Choose a car",
                                            prefixIcon: Icon(Icons
                                                .directions_car_filled_outlined),
                                          ),
                                          onChanged: _isSaving
                                              ? null
                                              : (value) {
                                                  setState(() =>
                                                      _selectedCarId = value);
                                                },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: AppSpacing.lg),

                                ///Proceed button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isSaving
                                        ? null
                                        : () {
                                            final selectedId = _selectedCarId;
                                            if (selectedId == null) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      "Please select a car."),
                                                ),
                                              );
                                              return;
                                            }

                                            final selectedDoc = docs.firstWhere(
                                                (d) => d.id == selectedId);
                                            final carData = selectedDoc.data()
                                                as Map<String, dynamic>;

                                            _saveSelectedCarAndGoPayment(
                                              carData: carData,
                                              carId: selectedId,
                                            );
                                          },
                                    child: _isSaving
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Text("Proceed to Payment"),
                                  ),
                                ),

                                const SizedBox(height: AppSpacing.xl),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ],
      ),
    );
  }
}
