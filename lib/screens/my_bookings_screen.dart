import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'shared/app_ui.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  DateTime _createdAtForSort(Map<String, dynamic> data) {
    final value = data["createdAt"];
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.toLocal();
    if (value is num) {
      final raw = value.toInt();
      if (raw > 0) {
        final ms = raw >= 1000000000000 ? raw : raw * 1000;
        return DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
      }
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toLocal();
      final numeric = int.tryParse(value.trim());
      if (numeric != null && numeric > 0) {
        final ms = numeric >= 1000000000000 ? numeric : numeric * 1000;
        return DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
      }
    }
    return DateTime(1970);
  }

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate().toLocal();
      return "${d.day}/${d.month}/${d.year}";
    }
    if (value is DateTime) {
      final d = value.toLocal();
      return "${d.day}/${d.month}/${d.year}";
    }
    final text = value?.toString().trim() ?? "";
    return text.isEmpty ? "-" : text;
  }

  String _money(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse("$value");
    if (n == null) return "-";
    return "Rs ${n.toStringAsFixed(0)}";
  }

  String _packageName(Map<String, dynamic> data) {
    final pkg = data["package"];
    if (pkg is Map<String, dynamic>) {
      final name = (pkg["name"] ?? "").toString().trim();
      if (name.isNotEmpty) return name;
    }

    final direct = (data["packageName"] ?? "").toString().trim();
    return direct.isEmpty ? "-" : direct;
  }

  String _packagePrice(Map<String, dynamic> data) {
    final paymentSummary = data["paymentSummary"];
    if (paymentSummary is Map<String, dynamic> &&
        paymentSummary["amount"] != null) {
      return _money(paymentSummary["amount"]);
    }

    final pkg = data["package"];
    if (pkg is Map<String, dynamic> && pkg["price"] != null) {
      return _money(pkg["price"]);
    }

    return "-";
  }

  String _plate(Map<String, dynamic> data) {
    final car = data["car"];
    if (car is Map<String, dynamic>) {
      final plate =
          (car["plateRaw"] ?? car["plateNumber"] ?? car["plateKey"] ?? "")
              .toString()
              .trim();
      if (plate.isNotEmpty) return plate.toUpperCase();
    }

    final direct = (data["plateNumber"] ?? data["plateRaw"] ?? "")
        .toString()
        .trim();
    return direct.isEmpty ? "-" : direct.toUpperCase();
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return Colors.green;
      case "cancelled":
      case "declined":
        return AppColors.danger;
      default:
        return Colors.orange;
    }
  }

  Widget _statusChip(String status) {
    final cleanStatus = status.trim().isEmpty ? "pending" : status;
    final color = _statusColor(cleanStatus);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        cleanStatus.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/images/bg.jpg",
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.white.withValues(alpha: 0.72)),
          ),
          Column(
            children: [
              AppGradientHeader(
                title: "My Bookings",
                subtitle: "Booking history",
                description: "View the bookings you have made.",
                backgroundImageAsset: "assets/images/top.jpg",
                trailing: IconButton(
                  tooltip: "Back",
                  icon:
                      const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: uid == null
                    ? const Center(child: Text("Please login again."))
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection("bookings")
                            .where("userId", isEqualTo: uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text("Error: ${snapshot.error}"),
                            );
                          }

                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = [...snapshot.data!.docs]..sort(
                              (a, b) => _createdAtForSort(b.data()).compareTo(
                                _createdAtForSort(a.data()),
                              ),
                            );

                          if (docs.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  "You have not made any bookings yet.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          }

                          return AppPage(
                            child: ListView.separated(
                              itemCount: docs.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final data = doc.data();
                                final status =
                                    (data["status"] ?? "pending").toString();
                                final date = _formatDate(data["date"]);
                                final time =
                                    (data["timeSlot"] ?? data["time"] ?? "-")
                                        .toString();
                                final packageName = _packageName(data);
                                final price = _packagePrice(data);
                                final plate = _plate(data);

                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const CircleAvatar(
                                              backgroundColor:
                                                  AppColors.brandA,
                                              foregroundColor: Colors.white,
                                              child: Icon(Icons
                                                  .local_car_wash_rounded),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    packageName,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    "Booking ID: ${doc.id}",
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color:
                                                          AppColors.textMuted,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            _statusChip(status),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        _BookingInfoRow(
                                          icon: Icons.event_available_rounded,
                                          label: "Date",
                                          value: date,
                                        ),
                                        _BookingInfoRow(
                                          icon: Icons.access_time_rounded,
                                          label: "Time",
                                          value: time,
                                        ),
                                        _BookingInfoRow(
                                          icon: Icons.directions_car_rounded,
                                          label: "Plate",
                                          value: plate,
                                        ),
                                        _BookingInfoRow(
                                          icon: Icons.payments_rounded,
                                          label: "Amount",
                                          value: price,
                                        ),
                                      ],
                                    ),
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

class _BookingInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _BookingInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
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
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
