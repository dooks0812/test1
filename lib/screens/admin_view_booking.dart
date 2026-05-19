import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'shared/app_ui.dart';

//EmailJS service
import 'package:car_wash_app/services/emailjs_service.dart';

class AdminViewBookingScreen extends StatelessWidget {
  const AdminViewBookingScreen({super.key});//constructor

  // Keep these aligned with admin_booking_trends.dart / payment logic
  static const String _promo6FlagId = "promo6";
  static const String _promo6Title = "Special Offer on 6th Wash 🎁";
  static const String _promo6Type = "promo6";
  static const double _promo6DiscountPercent = 10;

  /// Update booking status + update matching payment status + send EmailJS email
  Future<void> _updateBookingAndPaymentStatus({
    required BuildContext context,
    required String bookingId,
    required String bookingStatus, // "approved" / "cancelled"
    required String userId,
    required String userEmail,
    required String dateText,
    required String timeSlot,
  }) async {
    final db = FirebaseFirestore.instance;

    try {
      // 1) Update booking document
      await db.collection("bookings").doc(bookingId).update({
        "status": bookingStatus,
        "updatedAt": FieldValue.serverTimestamp(),
      });

      // 2) Update payment(s) linked to this booking (if exists)
      final paySnap = await db
          .collection("payments")
          .where("bookingId", isEqualTo: bookingId)
          .limit(5)
          .get();

      if (paySnap.docs.isNotEmpty) {
        final paymentStatus =
            (bookingStatus == "approved") ? "approved" : "declined";

        final batch = db.batch();
        for (final p in paySnap.docs) {
          batch.update(p.reference, {
            "status": paymentStatus,
            "updatedAt": FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }

      // 3) Auto-send one-time 6th wash promo once user becomes eligible
      bool promoSentNow = false;
      if (bookingStatus == "approved" && userId.trim().isNotEmpty) {
        promoSentNow = await _autoSendSixthWashPromoIfEligible(
          db: db,
          userId: userId,
          userEmail: userEmail,
        );
      }

      // 3)Send EmailJS email
      final toName = userEmail.contains("@")
          ? userEmail.split("@").first
          : "Customer";

      final subject = (bookingStatus == "approved")
          ? "Your booking is approved ✅"
          : "Your booking is cancelled ❌";

      final message = (bookingStatus == "approved")
          ? "Hello $toName,\n\nYour booking has been APPROVED.\n\nDate: $dateText\nTime: $timeSlot\nBooking ID: $bookingId\n\nThank you for choosing Smart Car Wash!"
          : "Hello $toName,\n\nYour booking has been CANCELLED.\n\nDate: $dateText\nTime: $timeSlot\nBooking ID: $bookingId\n\nIf this is a mistake, please book again from the app.";

      //calls emailjs
      final (bool emailOk, String emailMsg) =
          await EmailJsService.sendStatusEmail(
        toEmail: userEmail,
        toName: toName,
        subject: subject,
        message: message,
        bookingId: bookingId,
        bookingDate: dateText,
        bookingTime: timeSlot,
        status: bookingStatus,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Booking updated. "
              "${emailOk ? "Email sent ✅" : "Email failed ❌"}"
              "${promoSentNow ? "\n6th-wash promo sent automatically ✅" : ""}"
              "${emailOk ? "" : "\nReason: $emailMsg"}",
            ),
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Firebase error: ${e.message}")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  Future<bool> _autoSendSixthWashPromoIfEligible({
    required FirebaseFirestore db,
    required String userId,
    required String userEmail,
  }) async {
    final flagRef = db
        .collection("users")
        .doc(userId)
        .collection("promo_flags")
        .doc(_promo6FlagId);

    final alreadySent = await flagRef.get();
    if (alreadySent.exists) return false;

    // Avoid extra index requirements by filtering status client-side.
    final userPayments =
        await db.collection("payments").where("userId", isEqualTo: userId).get();

    final approvedCount = userPayments.docs.where((d) {
      final data = d.data();
      return (data["status"] ?? "").toString().toLowerCase() == "approved";
    }).length;

    // Eligible exactly before 6th rewarded wash (same logic as payment_screen).
    if (approvedCount != 5) return false;

    final notifRef =
        db.collection("users").doc(userId).collection("notifications").doc();

    bool created = false;

    await db.runTransaction((tx) async {
      final flagSnap = await tx.get(flagRef);
      if (flagSnap.exists) return;

      created = true;

      tx.set(flagRef, {
        "sentAt": FieldValue.serverTimestamp(),
        "sentBy": "admin_auto",
        "discountPercent": _promo6DiscountPercent,
        "offerKind": "sixth_wash",
      });

      tx.set(notifRef, {
        "type": _promo6Type,
        "title": _promo6Title,
        "message":
            "Great news! You unlocked $_promo6DiscountPercent% off on your 6th wash. Tap to view packages.",
        "ctaRoute": "packages",
        "isRead": false,
        "createdAt": FieldValue.serverTimestamp(),
        "sentBy": "admin_auto",
        "discountPercent": _promo6DiscountPercent,
        "offerScope": "single_use",
        "offerKind": "sixth_wash",
        "userEmail": userEmail,
      });
    });

    return created;
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return "${d.day}/${d.month}/${d.year}";
    }
    return "";
  }

  Color _statusColor(String status) {
    switch (status) {
      case "approved":
        return Colors.green;
      case "cancelled":
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Widget _statusChip(String status) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String _money(dynamic v) {
    final n = (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? "");
    if (n == null) return "";
    return n.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Bookings"),
        backgroundColor: AppColors.brandA,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("bookings")
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

          // Empty
          if (docs.isEmpty) {
            return const Center(child: Text("No bookings found."));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final bookingId = doc.id;

              final userId = (data["userId"] ?? "").toString().trim();
              final userEmail = (data["userEmail"] ?? "").toString().trim();
              final timeSlot = (data["timeSlot"] ?? "").toString();
              final status = (data["status"] ?? "pending").toString();
              final dateText = _formatDate(data["date"]);

              final pkg = data["package"] as Map<String, dynamic>?;
              final pkgName = pkg?["name"]?.toString();
              final pkgPrice = pkg?["price"];

              // IMPORTANT: Use discounted amount if present
              // booking.paymentSummary.amount is the FINAL payable amount (after discount / offer)
              final pay = data["paymentSummary"] as Map<String, dynamic>?;
              final payableAmount = pay?["amount"];
              final originalAmount = pay?["originalAmount"];
              final discountApplied = (pay?["discountApplied"] == true);
              final discountPercent = pay?["discountPercent"];
              final discountAmount = pay?["discountAmount"];
              final discountReason = (pay?["discountReason"] ?? "").toString();

              final isFinal = status == "approved" || status == "cancelled";

              return Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              "Booking ID: $bookingId",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          _statusChip(status),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Text("User: $userEmail"),
                      Text("Date: $dateText"),
                      Text("Time: $timeSlot"),
                      if (pkgName != null) Text("Package: $pkgName"),

                      const SizedBox(height: 8),

                      //Price display (prefers FINAL amount)
                      if (payableAmount != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Payable: Rs ${_money(payableAmount)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                            if (discountApplied) ...[
                              const SizedBox(height: 4),
                              if (originalAmount != null)
                                Text(
                                  "Original: Rs ${_money(originalAmount)}",
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              if (discountPercent != null || discountAmount != null)
                                Text(
                                  "Discount: ${_money(discountPercent)}%  (-Rs ${_money(discountAmount)})",
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              if (discountReason.trim().isNotEmpty)
                                Text(
                                  "Reason: $discountReason",
                                  style: const TextStyle(color: Colors.black54),
                                ),
                            ],
                          ],
                        )
                      else if (pkgPrice != null)
                        Text(
                          "Price: Rs ${_money(pkgPrice)}",
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        )
                      else
                        const Text(
                          "Price: (not available)",
                          style: TextStyle(color: Colors.black54),
                        ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: (isFinal || userEmail.isEmpty)
                                  ? null
                                  : () => _updateBookingAndPaymentStatus(
                                        context: context,
                                        bookingId: bookingId,
                                        bookingStatus: "approved",
                                        userId: userId,
                                        userEmail: userEmail,
                                        dateText: dateText,
                                        timeSlot: timeSlot,
                                      ),
                              child: const Text("Approve"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: (isFinal || userEmail.isEmpty)
                                  ? null
                                  : () => _updateBookingAndPaymentStatus(
                                        context: context,
                                        bookingId: bookingId,
                                        bookingStatus: "cancelled",
                                        userId: userId,
                                        userEmail: userEmail,
                                        dateText: dateText,
                                        timeSlot: timeSlot,
                                      ),
                              child: const Text("Cancel"),
                            ),
                          ),
                        ],
                      ),

                      if (userEmail.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            "⚠️ No userEmail found for this booking, email cannot be sent.",
                            style: TextStyle(color: Colors.red),
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
