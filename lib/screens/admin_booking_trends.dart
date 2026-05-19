import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'shared/app_ui.dart';

class AdminBookingTrendsScreen extends StatefulWidget {
  const AdminBookingTrendsScreen({super.key});

  @override
  State<AdminBookingTrendsScreen> createState() =>
      _AdminBookingTrendsScreenState();
}

class _AdminBookingTrendsScreenState extends State<AdminBookingTrendsScreen> {
  int _days = 30;
  //Firestore will fetch bookings from the last 30 days
  DateTime get _fromDate => DateTime.now().subtract(Duration(days: _days));

  // One-time 6th-wash promo identifiers
  static const String _promo6FlagId = "promo6";
  static const String _promo6Title = "Special Offer on 6th Wash 🎁";
  static const String _promo6Type = "promo6";
  static const double _promo6DiscountPercent = 10;


  //This stores whether a promo has already been sent to a user.
  final Map<String, bool> _promo6SentCache = {};
  //This stores the user ID currently receiving a promo.
  String? _sendingUid;
  //becomes true when the admin is sending a global discount to all users
  bool _sendingAll = false;

  // Global discount (admin -> all users)
  final TextEditingController _globalDiscountMessageCtrl =
      TextEditingController();
  final TextEditingController _globalDiscountPercentCtrl =
      TextEditingController(text: "10");

  @override
  void dispose() {
    _globalDiscountMessageCtrl.dispose();
    _globalDiscountPercentCtrl.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> _promo6FlagRef(String uid) {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("promo_flags")
        .doc(_promo6FlagId);
  }

  //Check if 6th-wash promo was already sent to this user (FOREVER)
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

  /// Send 6th-wash promo to a single user (ONLY ONCE, marked forever)
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

  /// Global discount -> sends to EVERY user
  double? _parseDiscountPercent(String raw) {
    final cleaned = raw.trim().replaceAll("%", "");
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
//converts discount to clean text
  String _formatPercent(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.000001) return rounded.toInt().toString();
    // Keep it short for UI (e.g., 12.5)
    return value.toStringAsFixed(1).replaceFirst(RegExp(r"\.0$"), "");
  }

//sends a discount notification to every use
  Future<void> _sendGlobalDiscountToAllUsers() async {
    final message = _globalDiscountMessageCtrl.text.trim();
    final percent = _parseDiscountPercent(_globalDiscountPercentCtrl.text);

//If no message is written, show error
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a discount message.")),
      );
      return;
    }

    if (percent == null || percent <= 0 || percent > 90) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid discount percent (1 - 90)."),
        ),
      );
      return;
    }

    final percentText = _formatPercent(percent);

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Send Discount To All Users"),
            content: Text(
              "This will send a discount popup to ALL users and apply $percentText% off on their next payment.\n\n"
              "Message:\n$message\n\nProceed?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Send"),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    setState(() => _sendingAll = true);

    try {
      final db = FirebaseFirestore.instance;

      //Requires admin read permission on /users/{uid}
      final usersSnap = await db.collection("users").get();

      WriteBatch batch = db.batch();
      int ops = 0;

      for (final u in usersSnap.docs) {
        final uid = u.id;

        final userRef = db.collection("users").doc(uid);
        final notifDoc = userRef.collection("notifications").doc();

        // Store discount on the user doc so PaymentScreen applies it automatically.
        batch.set(
          userRef,
          {
            "specialOfferActive": true,
            "specialOfferPercent": percent,
            "specialOfferMessage": message,
            "specialOfferKind": "admin_global_discount",
            "specialOfferSentAt": FieldValue.serverTimestamp(),
            "specialOfferSentBy": "admin",
          },
          SetOptions(merge: true),
        );
        ops++;

        // User popup (dashboard reads /notifications where isRead == false)
        batch.set(notifDoc, {
          "type": "global_discount",
          "title": "New Discount",
          "message":
              "$message\n\n$percentText% off will be applied automatically at checkout.",
          "ctaRoute": "packages",
          "isRead": false,
          "createdAt": FieldValue.serverTimestamp(),
          "sentBy": "admin",

          "discountPercent": percent,
          "offerScope": "single_use",
          "offerKind": "global_discount",
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
        SnackBar(content: Text("Discount sent to ${usersSnap.size} users ✅")),
      );

      // keep % for convenience; clear message for next campaign
      _globalDiscountMessageCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send discount: $e")),
      );
    } finally {
      if (mounted) setState(() => _sendingAll = false);
    }
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _dateKey(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-"
      "${d.month.toString().padLeft(2, '0')}-"
      "${d.day.toString().padLeft(2, '0')}";

  List<_DayPoint> _buildDailySeries(List<QueryDocumentSnapshot> docs) {
    final today = _dateOnly(DateTime.now());
    final counts = <String, int>{};

    for (final d in docs) {
      final data = d.data() as Map<String, dynamic>;

      DateTime? when;
      final createdAt = data["createdAt"];
      final bookingDate = data["date"];

      if (createdAt is Timestamp) {
        when = createdAt.toDate();
      } else if (createdAt is DateTime) {
        when = createdAt;
      } else if (bookingDate is Timestamp) {
        when = bookingDate.toDate();
      } else if (bookingDate is DateTime) {
        when = bookingDate;
      }

      if (when == null) continue;

      final key = _dateKey(_dateOnly(when));
      counts[key] = (counts[key] ?? 0) + 1;
    }
//build chart
    final points = <_DayPoint>[];

    // Build exactly N days ending today (7/30/90)
    for (int i = _days - 1; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final key = _dateKey(day);
      final label = "${day.day}/${day.month}";
      points.add(_DayPoint(label: label, count: counts[key] ?? 0));
    }

    return points;
  }

  @override
  Widget build(BuildContext context) {
    final fromTs = Timestamp.fromDate(_fromDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking Trends & Promotions"),
        backgroundColor: AppColors.brandA,
        foregroundColor: Colors.white,
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
                final dailySeries = _buildDailySeries(docs);

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    // Global discount to all
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Discount (All Users)",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _globalDiscountMessageCtrl,
                              minLines: 2,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: "Message",
                                hintText:
                                    "E.g. Limited-time offer for everyone!",
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _globalDiscountPercentCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: "Discount %",
                                      hintText: "10",
                                      suffixText: "%",
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: _sendingAll
                                      ? null
                                      : _sendGlobalDiscountToAllUsers,
                                  child: _sendingAll
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text("Send"),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "Applies automatically to each user's next payment.",
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
                            Text(
                              "Bookings Trend ($_days days)",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            _DailyBookingsChart(points: dailySeries),
                          ],
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

                    // 6th wash promo (one-time forever)
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

class _DayPoint {
  final String label;
  final int count;

  const _DayPoint({
    required this.label,
    required this.count,
  });
}

class _DailyBookingsChart extends StatelessWidget {
  final List<_DayPoint> points;

  const _DailyBookingsChart({
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Text("No data available for this range.");
    }

    final maxCount = points
        .map((p) => p.count)
        .fold<int>(0, (m, v) => v > m ? v : m);
    final safeMaxCount = maxCount == 0 ? 1 : maxCount;

    final labelStep = points.length <= 10
        ? 1
        : (points.length <= 30 ? 3 : 7); // 7d=all labels, 30d=every 3rd, 90d=weekly

    final pointSpacing =
        points.length <= 10 ? 52.0 : (points.length <= 30 ? 34.0 : 24.0);
    final chartWidth = ((points.length - 1) * pointSpacing) + 96.0;
    const chartHeight = 220.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: chartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(
                width: 26,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Center(
                    child: Text(
                      "Number of Cars Booked",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartWidth,
                    height: chartHeight,
                    child: CustomPaint(
                      painter: _LineChartPainter(
                        points: points,
                        maxCount: safeMaxCount,
                        labelStep: labelStep,
                        lineColor: AppColors.brandA,
                        gridColor: AppColors.borderSoft,
                        textColor: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text(
            "Date",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<_DayPoint> points;
  final int maxCount;
  final int labelStep;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;

  const _LineChartPainter({
    required this.points,
    required this.maxCount,
    required this.labelStep,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const leftPad = 34.0;
    const rightPad = 10.0;
    const topPad = 10.0;
    const bottomPad = 34.0;

    final chartLeft = leftPad;
    final chartRight = size.width - rightPad;
    final chartTop = topPad;
    final chartBottom = size.height - bottomPad;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;

    final axisPaint = Paint()
      ..color = textColor.withValues(alpha: 0.8)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.65)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    // Horizontal grid lines + Y tick labels.
    const gridSteps = 4;
    for (int i = 0; i <= gridSteps; i++) {
      final t = i / gridSteps;
      final y = chartBottom - (chartHeight * t);
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);

      final val = ((maxCount * t)).round();
      final tp = TextPainter(
        text: TextSpan(
          text: val.toString(),
          style: TextStyle(
            fontSize: 10,
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(chartLeft - tp.width - 6, y - (tp.height / 2)));
    }

    // Axes.
    canvas.drawLine(
      Offset(chartLeft, chartTop),
      Offset(chartLeft, chartBottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(chartLeft, chartBottom),
      Offset(chartRight, chartBottom),
      axisPaint,
    );

    final path = Path();
    final fillPath = Path();
    Offset? firstPoint;

    final count = points.length;
    final stepX = count <= 1 ? 0.0 : chartWidth / (count - 1);

    for (int i = 0; i < count; i++) {
      final p = points[i];
      final x = chartLeft + (stepX * i);
      final y = chartBottom - ((p.count / maxCount) * chartHeight);
      final pt = Offset(x, y);

      if (i == 0) {
        firstPoint = pt;
        path.moveTo(pt.dx, pt.dy);
        fillPath.moveTo(pt.dx, chartBottom);
        fillPath.lineTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
        fillPath.lineTo(pt.dx, pt.dy);
      }
    }

    if (firstPoint != null) {
      fillPath.lineTo(chartLeft + (stepX * (count - 1)), chartBottom);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, linePaint);
    }

    // Markers + date labels.
    for (int i = 0; i < count; i++) {
      final p = points[i];
      final x = chartLeft + (stepX * i);
      final y = chartBottom - ((p.count / maxCount) * chartHeight);

      canvas.drawCircle(
        Offset(x, y),
        3.8,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(x, y),
        3.8,
        Paint()
          ..color = lineColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );

      final showLabel = i % labelStep == 0 || i == count - 1;
      if (!showLabel) continue;

      final tp = TextPainter(
        text: TextSpan(
          text: p.label,
          style: TextStyle(
            fontSize: 10,
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(x - (tp.width / 2), chartBottom + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.maxCount != maxCount ||
        oldDelegate.labelStep != labelStep ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.textColor != textColor;
  }
}
