import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Shared UI (top.jpg header + bg.jpg background)
import 'shared/app_ui.dart';

// ADD THIS IMPORT
import 'user_dashboard.dart';

class PaymentScreen extends StatefulWidget {
  final String bookingId;
  final String date;
  final String time;
  final double price;

  const PaymentScreen({
    super.key,
    required this.bookingId,
    required this.date,
    required this.time,
    required this.price,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String? selectedPaymentMethod;
  bool _saving = false;

  /// Rule: ONLY the 6th wash gets 10% off (based on APPROVED payments count before this one)
  static const int _sixthWashApprovedBefore = 5; // 5 approved before => this is 6th
  static const double _sixthWashDiscountRate = 0.10; // 10%

  double _round2(double v) => double.parse(v.toStringAsFixed(2));

  /// Count user's APPROVED payments
  Future<int> _countApprovedPayments(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection("payments")
        .where("userId", isEqualTo: uid)
        .where("status", isEqualTo: "approved")
        .get();

    return snap.size;
  }

  /// Prevent giving the "6th wash" reward more than once (even with race conditions)
  Future<bool> _hasUsedSixthWashReward(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection("payments")
        .where("userId", isEqualTo: uid)
        .where("sixthWashRewardApplied", isEqualTo: true)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Discount lookup (best-effort, won't break if fields/collection don't exist)
  ///
  /// Supported schemas (any one works):
  /// 1) users/{uid} fields:
  ///    - specialOfferActive: true/false
  ///    - specialOfferRate: 0.10   OR specialOfferPercent: 10
  /// 2) users/{uid}/specialOffers/{doc}:
  ///    - active: true
  ///    - rate: 0.10  OR percent: 10
  Future<_OfferResult> _fetchSpecialOffer(String uid) async {
    DocumentReference<Map<String, dynamic>>? offerRef;
    double rate = 0.0;

    // A) Try users/{uid}
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection("users").doc(uid).get();
      final data = userDoc.data();
      if (data != null) {
        final bool docActive = (data["specialOfferActive"] == true) ||
            (data["hasSpecialOffer"] == true);

        if (docActive) {
          final dynamic r = data["specialOfferRate"];
          final dynamic p = data["specialOfferPercent"];

          if (r is num) {
            rate = r.toDouble();
          } else if (p is num) {
            rate = (p.toDouble() / 100.0);
          } else {
            rate = _sixthWashDiscountRate; // default 10% if not specified
          }

          // clamp
          if (rate < 0) rate = 0;
          if (rate > 0.9) rate = 0.9;

          // mark source (we'll deactivate this field after use)
          return _OfferResult(active: true, rate: rate, userFieldOffer: true);
        }
      }
    } catch (_) {
      // ignore
    }

    // B) Try users/{uid}/specialOffers where active==true
    try {
      final q = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .collection("specialOffers")
          .where("active", isEqualTo: true)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        final doc = q.docs.first;
        final data = doc.data();

        offerRef = doc.reference;

        final dynamic r = data["rate"];
        final dynamic p = data["percent"];

        if (r is num) {
          rate = r.toDouble();
        } else if (p is num) {
          rate = (p.toDouble() / 100.0);
        } else {
          rate = _sixthWashDiscountRate;
        }

        if (rate < 0) rate = 0;
        if (rate > 0.9) rate = 0.9;

        return _OfferResult(
          active: true,
          rate: rate,
          offerDocRef: offerRef,
          userFieldOffer: false,
        );
      }
    } catch (_) {
      // ignore
    }

    return const _OfferResult(active: false, rate: 0.0);
  }

  Future<_DiscountInfo> _computeDiscount(String uid) async {
    final approvedCount = await _countApprovedPayments(uid);

    // Discount wins over 6th wash reward
    final offer = await _fetchSpecialOffer(uid);

    // Sixth wash reward (ONLY when approvedCount == 5, and only once)
    bool sixthEligible = false;
    if (!offer.active && approvedCount == _sixthWashApprovedBefore) {
      final used = await _hasUsedSixthWashReward(uid);
      sixthEligible = !used;
    }

    if (offer.active) {
      return _DiscountInfo(
        approvedCount: approvedCount,
        rate: offer.rate,
        reason: "special_offer",
        sixthApplied: false,
        offer: offer,
      );
    }

    if (sixthEligible) {
      return _DiscountInfo(
        approvedCount: approvedCount,
        rate: _sixthWashDiscountRate,
        reason: "sixth_wash",
        sixthApplied: true,
        offer: offer,
      );
    }

    return _DiscountInfo(
      approvedCount: approvedCount,
      rate: 0.0,
      reason: "none",
      sixthApplied: false,
      offer: offer,
    );
  }

  Future<void> _consumeSpecialOfferIfAny(String uid, _OfferResult offer) async {
    if (!offer.active) return;

    // A) user doc flag
    if (offer.userFieldOffer == true) {
      try {
        await FirebaseFirestore.instance.collection("users").doc(uid).update({
          "specialOfferActive": false,
          "specialOfferUsedAt": FieldValue.serverTimestamp(),
        });
      } catch (_) {}
      return;
    }

    // B) offer doc in subcollection
    if (offer.offerDocRef != null) {
      try {
        await offer.offerDocRef!.update({
          "active": false,
          "usedAt": FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  Future<void> _confirmPayment() async {
    if (selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a payment method")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in.")),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // 1) Read booking to include package/plate details in payment doc
      final bookingSnap = await FirebaseFirestore.instance
          .collection("bookings")
          .doc(widget.bookingId)
          .get();

      final booking = bookingSnap.data() ?? {};

      final car = booking["car"] as Map<String, dynamic>?;
      // robust: supports plateNumber OR plateRaw
      final plateNumber = (car?["plateNumber"] ?? car?["plateRaw"] ?? "")
          .toString()
          .trim();

      final pkg = booking["package"] as Map<String, dynamic>?;
      final pkgName = (pkg?["name"] ?? "").toString();

      // 2) Compute discount (ONLY 6th OR discount)
      final info = await _computeDiscount(user.uid);

      final double originalAmount = widget.price;
      final double discountPercent = info.rate * 100.0;
      final double discountAmount =
          info.rate > 0 ? _round2(originalAmount * info.rate) : 0.0;
      final double finalAmount = _round2(originalAmount - discountAmount);

      // 3) Save payment
      await FirebaseFirestore.instance.collection("payments").add({
        "bookingId": widget.bookingId,
        "userId": user.uid,
        "userEmail": user.email ?? "",

        "originalAmount": _round2(originalAmount),
        "discountPercent": _round2(discountPercent),
        "discountAmount": _round2(discountAmount),
        "amount": finalAmount,

        "method": selectedPaymentMethod == "Card" ? "card" : "cash",
        "status": "pending",
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),

        "packageName": pkgName,
        "plateNumber": plateNumber,
        "dateText": widget.date,
        "timeText": widget.time,

        // analytics / audit
        "approvedPaymentsBeforeThis": info.approvedCount,
        "discountApplied": info.rate > 0,
        "discountReason": info.reason, // "sixth_wash" | "special_offer" | "none"

        // important: ensures 6th wash reward is not reused
        "sixthWashRewardApplied": info.sixthApplied,
      });

      // 4)consume discount if it was used
      if (info.reason == "special_offer") {
        await _consumeSpecialOfferIfAny(user.uid, info.offer);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            info.rate > 0
                ? "Discount applied! Final: Rs ${finalAmount.toStringAsFixed(0)}. Sent to admin for approval."
                : "Payment submitted to admin for approval.",
          ),
        ),
      );

      // CHANGE: go to UserDashboard and remove previous screens
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const UserDashboard()),
        (route) => false,
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
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Stack(
        children: [
          /// Background image (bg.jpg)
          Positioned.fill(
            child: Image.asset(
              "assets/images/bg.jpg",
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

          /// Overlay (clearer bg)
          Positioned.fill(
            child: Container(color: Colors.white.withValues(alpha: 0.45)),
          ),

          /// Scrollable screen (top included)
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: AppGradientHeader(
                  title: "Payment",
                  subtitle: "Complete your booking",
                  description: "Select a payment method and confirm.",
                  backgroundImageAsset: "assets/images/top.jpg",
                  trailing: IconButton(
                    tooltip: "Back",
                    icon:
                        const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: AppPage(
                  maxWidth: 650,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      /// Summary card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Booking Details",
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _InfoRow(
                                label: "Booking ID",
                                value: widget.bookingId,
                              ),
                              _InfoRow(label: "Date", value: widget.date),
                              _InfoRow(label: "Time", value: widget.time),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.payments_rounded,
                                    size: 18,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Base Amount: Rs ${widget.price.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),

                              /// Discount preview (6th wash OR discount)
                              if (user != null)
                                FutureBuilder<_DiscountInfo>(
                                  future: _computeDiscount(user.uid),
                                  builder: (context, snap) {
                                    if (!snap.hasData) {
                                      return Row(
                                        children: const [
                                          SizedBox(
                                            height: 14,
                                            width: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            "Checking discounts...",
                                            style: TextStyle(
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      );
                                    }

                                    final info = snap.data!;
                                    if (info.rate <= 0) {
                                      // show progress to 6th wash
                                      final remaining =
                                          (_sixthWashApprovedBefore + 1) -
                                              (info.approvedCount + 1);

                                      final text = (remaining > 0)
                                          ? "No discount now. $remaining wash(es) left to reach your 6th-wash 10% reward."
                                          : "No discount now.";

                                      return _Badge(
                                        icon: Icons.local_offer_outlined,
                                        text: text,
                                      );
                                    }

                                    final previewFinal = _round2(
                                      widget.price - (widget.price * info.rate),
                                    );

                                    final label = info.reason == "sixth_wash"
                                        ? "6th wash reward: 10% OFF"
                                        : "Discount: ${(info.rate * 100).toStringAsFixed(0)}% OFF";

                                    return _Badge(
                                      icon: Icons.local_offer_rounded,
                                      text:
                                          "$label • Estimated final: Rs ${previewFinal.toStringAsFixed(0)}",
                                      strong: true,
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      /// Payment method card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Select Payment Method",
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              RadioGroup<String>(
                                groupValue: selectedPaymentMethod,
                                onChanged: (value) {
                                  if (_saving) return;
                                  setState(() => selectedPaymentMethod = value);
                                },
                                child: Column(
                                  children: [
                                    RadioListTile<String>(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text(
                                        "Card",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800),
                                      ),
                                      subtitle: const Text(
                                        "Pay by card (online / terminal)",
                                        style:
                                            TextStyle(color: AppColors.textMuted),
                                      ),
                                      value: "Card",
                                    ),
                                    const Divider(height: 1),
                                    RadioListTile<String>(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text(
                                        "Cash on Site",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800),
                                      ),
                                      subtitle: const Text(
                                        "Pay when you arrive at the car wash",
                                        style:
                                            TextStyle(color: AppColors.textMuted),
                                      ),
                                      value: "Cash",
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      /// Confirm button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _confirmPayment,
                          child: _saving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text("Confirm Payment"),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              "$label:",
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool strong;

  const _Badge({
    required this.icon,
    required this.text,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: strong
            ? AppColors.brandA.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: strong ? AppColors.brandA : AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: strong ? AppColors.textStrong : AppColors.textMuted,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferResult {
  final bool active;
  final double rate;

  /// if true => came from users/{uid} field flags
  final bool? userFieldOffer;

  /// if not null => came from users/{uid}/specialOffers/{doc}
  final DocumentReference<Map<String, dynamic>>? offerDocRef;

  const _OfferResult({
    required this.active,
    required this.rate,
    this.userFieldOffer,
    this.offerDocRef,
  });
}

class _DiscountInfo {
  final int approvedCount;
  final double rate;
  final String reason; // "sixth_wash" | "special_offer" | "none"
  final bool sixthApplied;
  final _OfferResult offer;

  const _DiscountInfo({
    required this.approvedCount,
    required this.rate,
    required this.reason,
    required this.sixthApplied,
    required this.offer,
  });
}
