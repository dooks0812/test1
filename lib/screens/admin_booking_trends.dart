import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminBookingTrendsScreen extends StatefulWidget {
  const AdminBookingTrendsScreen({super.key});

  @override
  State<AdminBookingTrendsScreen> createState() =>
      _AdminBookingTrendsScreenState();
}

class _AdminBookingTrendsScreenState extends State<AdminBookingTrendsScreen> {
  int _days = 30;
  DateTime get _fromDate => DateTime.now().subtract(Duration(days: _days));

  // ✅ One-time 6th-wash promo identifiers
  static const String _promo6FlagId = "promo6";
  static const String _promo6Title = "Special Offer on 6th Wash 🎁";
  static const String _promo6Type = "promo6";
  static const double _promo6DiscountPercent = 10;

  // UI state
  final Map<String, bool> _promo6SentCache = {};
  String? _sendingUid;
  bool _sendingAll = false;

  DocumentReference<Map<String, dynamic>> _promo6FlagRef(String uid) {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("promo_flags")
        .doc(_promo6FlagId);
  }

  /// ✅ Check if 6th-wash promo was already sent to this user (FOREVER)
  Future<bool> _isPromo6AlreadySent(String uid) async {
    final cached = _promo6SentCache[uid];
    if (cached != null) return cached;

    // 1) New reliable source: promo flag doc
    final flagSnap = await _promo6FlagRef(uid).get();
    if (flagSnap.exists) {
      _promo6SentCache[uid] = true;
      return true;
    }

    // 2) Backward-compatible fallback: old notification lookup
    //    (If found, we auto-migrate by creating the flag doc)
    final notifSnap = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("notifications")
        .where("title", isEqualTo: _promo6Title)
        .limit(10)
        .get();

    bool sent = false;
    for (final d in notifSnap.docs) {
      final data = d.data();
      final sentBy = (data["sentBy"] ?? "").toString();
      final type = (data["type"] ?? "").toString();
      if (sentBy == "admin" && (type == "promo" || type == _promo6Type)) {
        sent = true;
        break;
      }
    }

    if (sent) {
      // migrate -> create permanent flag
      await _promo6FlagRef(uid).set({
        "sentAt": FieldValue.serverTimestamp(),
        "sentBy": "admin",
        "discountPercent": _promo6DiscountPercent,
        "offerKind": "sixth_wash",
      }, SetOptions(merge: true));
    }

    _promo6SentCache[uid] = sent;
    return sent;
  }

  /// ✅ Send 6th-wash promo to a single user (ONLY ONCE, marked forever)
  Future<void> _sendPromoToUser({
    required String uid,
    required String email,
    required int count,
  }) async {
    setState(() => _sendingUid = uid);

    try {
      final db = FirebaseFirestore.instance;
      final flagRef = _promo6FlagRef(uid);
      final notifRef = db
          .collection("users")
          .doc(uid)
          .collection("notifications")
          .doc();

      await db.runTransaction((tx) async {
        final flagSnap = await tx.get(flagRef);

        // Already sent -> stop (forever)
        if (flagSnap.exists) return;

        // 1) Create permanent flag first
        tx.set(flagRef, {
          "sentAt": FieldValue.serverTimestamp(),
          "sentBy": "admin",
          "discountPercent": _promo6DiscountPercent,
          "offerKind": "sixth_wash",
        });

        // 2) Create the notification for the user UI
        tx.set(notifRef, {
          "type": _promo6Type,
          "title": _promo6Title,
          "message":
              "Thanks for booking $count times! Your next eligible wash gets $_promo6DiscountPercent% off.",
          "ctaRoute": "packages",
          "isRead": false,
          "createdAt": FieldValue.serverTimestamp(),
          "sentBy": "admin",

          // optional fields
          "discountPercent": _promo6DiscountPercent,
          "offerScope": "single_use",
          "offerKind": "sixth_wash",
        });
      });

      // Re-check state (transaction may have no-op if already exists)
      final nowSent = await _isPromo6AlreadySent(uid);
      _promo6SentCache[uid] = nowSent;

      if (!mounted) return;

      if (nowSent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("6th-wash promo sent/marked for $email ✅")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("6th-wash promo already sent to $email ✅")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send promo: $e")),
      );
    } finally {
      if (mounted) setState(() => _sendingUid = null);
    }
  }

  /// ✅ Special promotion -> sends to EVERY user (can be repeated)
  Future<void> _sendSpecialPromoToAllUsers() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Send Special Promotion"),
            content: const Text(
              "This will send a promotion notification to ALL users.\n\nProceed?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Send to all"),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    setState(() => _sendingAll = true);

    try {
      final db = FirebaseFirestore.instance;

      // ✅ Requires admin read permission on /users/{uid}
      final usersSnap = await db.collection("users").get();

      WriteBatch batch = db.batch();
      int ops = 0;

      for (final u in usersSnap.docs) {
        final uid = u.id;

        final notifDoc = db
            .collection("users")
            .doc(uid)
            .collection("notifications")
            .doc();

        batch.set(notifDoc, {
          "type": "special_promo",
          "title": "Special Promotion 🎉",
          "message":
              "Limited-time offer: 10% off your next wash! Tap to view packages.",
          "ctaRoute": "packages",
          "isRead": false,
          "createdAt": FieldValue.serverTimestamp(),
          "sentBy": "admin",

          "discountPercent": 10,
          "offerScope": "single_use",
          "offerKind": "special",
        });

        ops++;

        // keep safe under batch limits
        if (ops >= 450) {
          await batch.commit();
          batch = db.batch();
          ops = 0;
        }
      }

      if (ops > 0) await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Special promo sent to ${usersSnap.size} users ✅")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send special promo: $e")),
      );
    } finally {
      if (mounted) setState(() => _sendingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromTs = Timestamp.fromDate(_fromDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking Trends & Promotions"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text("Time range: "),
                const SizedBox(width: 10),
                DropdownButton<int>(
                  value: _days,
                  items: const [
                    DropdownMenuItem(value: 7, child: Text("7 days")),
                    DropdownMenuItem(value: 30, child: Text("30 days")),
                    DropdownMenuItem(value: 90, child: Text("90 days")),
                  ],
                  onChanged: (v) => setState(() => _days = v ?? 30),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("bookings")
                  .where("createdAt", isGreaterThanOrEqualTo: fromTs)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text("Error: ${snap.error}"));
                }

                final docs = snap.data?.docs ?? [];

                // ---- Aggregate ----
                final Map<String, int> byTimeSlot = {};
                final Map<String, int> byUser = {};
                final Map<String, String> userIdToEmail = {};

                for (final d in docs) {
                  final data = d.data() as Map<String, dynamic>;
                  final uid = (data["userId"] ?? "").toString();
                  final email = (data["userEmail"] ?? "").toString();
                  final slot = (data["timeSlot"] ?? "").toString();

                  if (uid.isNotEmpty) {
                    byUser[uid] = (byUser[uid] ?? 0) + 1;
                    if (email.isNotEmpty) userIdToEmail[uid] = email;
                  }
                  if (slot.isNotEmpty) {
                    byTimeSlot[slot] = (byTimeSlot[slot] ?? 0) + 1;
                  }
                }

                // Users eligible for 6th wash promo (>=5 bookings in the selected range)
                final loyal = byUser.entries
                    .where((e) => e.value >= 5)
                    .toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                final slotList = byTimeSlot.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    // ✅ Special promo to all
                    Card(
                      child: ListTile(
                        title: const Text(
                          "Special Promotion (All Users)",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          "Send a promotional offer notification to every user.",
                        ),
                        trailing: ElevatedButton(
                          onPressed: _sendingAll ? null : _sendSpecialPromoToAllUsers,
                          child: _sendingAll
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text("Send"),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          "Bookings in last $_days days: ${docs.length}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Most popular time slots",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            if (slotList.isEmpty)
                              const Text("No bookings/time slots in this range."),
                            ...slotList.map(
                              (e) => Text("${e.key}: ${e.value} bookings"),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ✅ 6th wash promo (one-time forever)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Loyal users (>= 5 bookings) — 6th wash promo (one-time)",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),

                            if (loyal.isEmpty)
                              const Text("No loyal users in this range."),

                            ...loyal.map((e) {
                              final uid = e.key;
                              final count = e.value;
                              final email = userIdToEmail[uid] ?? uid;

                              return FutureBuilder<bool>(
                                future: _isPromo6AlreadySent(uid),
                                builder: (context, s) {
                                  final sent = s.data == true;
                                  final loading =
                                      s.connectionState == ConnectionState.waiting;
                                  final isBusyThisUser = _sendingUid == uid;

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(email),
                                    subtitle: Text("Bookings: $count"),
                                    trailing: SizedBox(
                                      width: 190,
                                      child: ElevatedButton(
                                        onPressed: (sent || loading || isBusyThisUser)
                                            ? null
                                            : () => _sendPromoToUser(
                                                  uid: uid,
                                                  email: email,
                                                  count: count,
                                                ),
                                        child: isBusyThisUser
                                            ? const SizedBox(
                                                height: 16,
                                                width: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : Text(
                                                sent ? "Sent ✅" : "Send 6th wash promo",
                                                textAlign: TextAlign.center,
                                              ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
