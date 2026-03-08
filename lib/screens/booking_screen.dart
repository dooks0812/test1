import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ Shared UI (header + spacing + theme)
import 'shared/app_ui.dart';

import 'car_details_screen.dart';

class BookingScreen extends StatefulWidget {
  final String packageName;
  final double packagePrice;
  final String imageUrl;

  const BookingScreen({
    super.key,
    required this.packageName,
    required this.packagePrice,
    required this.imageUrl,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  // ✅ Capacity rules
  static const int MAX_PER_DATE = 18; // ✅ changed from 9 → 18
  static const int MAX_PER_SLOT = 2; // ✅ stays 2

  DateTime? selectedDate;
  String? selectedTime;

  bool _isSaving = false;

  final Set<String> _fullyBookedDateKeys = {};
  Map<String, int> _slotCountsForSelectedDate = {};
  int _totalBookingsForSelectedDate = 0;

  final List<String> timeSlots = const [
    "08:00 AM",
    "09:00 AM",
    "10:00 AM",
    "11:00 AM",
    "12:00 PM",
    "01:00 PM",
    "02:00 PM",
    "03:00 PM",
    "04:00 PM",
  ];

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _dateKey(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-"
      "${d.month.toString().padLeft(2, '0')}-"
      "${d.day.toString().padLeft(2, '0')}";

  @override
  void initState() {
    super.initState();
    _preloadFullyBookedDates();
  }

  /// ✅ Preload full dates for next 30 days (now full means >= 18 bookings)
  Future<void> _preloadFullyBookedDates() async {
    final now = _dateOnly(DateTime.now());
    final keys = List.generate(30, (i) => _dateKey(now.add(Duration(days: i))));

    try {
      final snap = await FirebaseFirestore.instance
          .collection("bookings")
          .where("dateKey", whereIn: keys)
          .get();

      final Map<String, int> countsByDate = {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final k = (data["dateKey"] ?? "").toString();
        if (k.isEmpty) continue;
        countsByDate[k] = (countsByDate[k] ?? 0) + 1;
      }

      final full = <String>{};
      countsByDate.forEach((k, c) {
        if (c >= MAX_PER_DATE) full.add(k);
      });

      if (!mounted) return;
      setState(() {
        _fullyBookedDateKeys
          ..clear()
          ..addAll(full);
      });
    } catch (_) {
      // ignore (date picker still works, just without grey dates)
    }
  }

  /// ✅ Load total + per-slot counts for selected date
  Future<void> _loadCountsForDate(DateTime date) async {
    final key = _dateKey(date);

    final snap = await FirebaseFirestore.instance
        .collection("bookings")
        .where("dateKey", isEqualTo: key)
        .get();

    final total = snap.size;

    final Map<String, int> slotCounts = {};
    for (final doc in snap.docs) {
      final data = doc.data();
      final slot = (data["timeSlot"] ?? "").toString();
      if (slot.isEmpty) continue;
      slotCounts[slot] = (slotCounts[slot] ?? 0) + 1;
    }

    if (!mounted) return;
    setState(() {
      _totalBookingsForSelectedDate = total;
      _slotCountsForSelectedDate = slotCounts;

      // If the chosen time became full, clear it
      if (selectedTime != null &&
          (_slotCountsForSelectedDate[selectedTime!] ?? 0) >= MAX_PER_SLOT) {
        selectedTime = null;
      }

      // If the date became full, mark it
      if (_totalBookingsForSelectedDate >= MAX_PER_DATE) {
        _fullyBookedDateKeys.add(key);
      }
    });
  }

  Future<void> _pickDate() async {
    final now = _dateOnly(DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      selectableDayPredicate: (day) {
        final key = _dateKey(_dateOnly(day));
        return !_fullyBookedDateKeys.contains(key);
      },
    );

    if (picked != null) {
      final dateOnly = _dateOnly(picked);
      setState(() {
        selectedDate = dateOnly;
        selectedTime = null;
      });

      await _loadCountsForDate(dateOnly);
    }
  }

  Future<void> _confirmBooking() async {
    if (selectedDate == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select date and time")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final bookingDate = selectedDate!;
      final key = _dateKey(bookingDate);
      final slot = selectedTime!;

      // ✅ Re-check counts (avoid race condition)
      final snap = await FirebaseFirestore.instance
          .collection("bookings")
          .where("dateKey", isEqualTo: key)
          .get();

      final total = snap.size;

      int slotCount = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        if ((data["timeSlot"] ?? "").toString() == slot) slotCount++;
      }

      if (total >= MAX_PER_DATE) {
        setState(() => _fullyBookedDateKeys.add(key));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Please select another date — maximum $MAX_PER_DATE bookings reached.",
            ),
          ),
        );
        return;
      }

      if (slotCount >= MAX_PER_SLOT) {
        await _loadCountsForDate(bookingDate);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "This time slot ($slot) is fully booked. Please select another time.",
            ),
          ),
        );
        return;
      }

      // ✅ Save booking
      final bookingRef =
          await FirebaseFirestore.instance.collection("bookings").add({
        "userId": user.uid,
        "userEmail": user.email ?? "",
        "date": Timestamp.fromDate(bookingDate),
        "dateKey": key,
        "timeSlot": slot,
        "status": "pending",
        "createdAt": FieldValue.serverTimestamp(),
        "package": {
          "name": widget.packageName,
          "price": widget.packagePrice,
          "imageUrl": widget.imageUrl,
        },
      });

      if (!mounted) return;

      _preloadFullyBookedDates();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CarDetailsScreen(
            bookingId: bookingRef.id,
            bookingDate: bookingDate,
            timeSlot: slot,
            packageName: widget.packageName,
            packagePrice: widget.packagePrice,
            imageUrl: widget.imageUrl,
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
    final dateText = selectedDate == null
        ? "No date chosen"
        : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}";

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

          /// ✅ Overlay
          Positioned.fill(
            child: Container(color: Colors.white.withOpacity(0.72)),
          ),

          Column(
            children: [
              /// ✅ Header image (top.jpg) + back
              AppGradientHeader(
                title: "Book Car Wash",
                description: "Choose your date and time",
                backgroundImageAsset: "assets/images/top.jpg",
                trailing: IconButton(
                  tooltip: "Back",
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              Expanded(
                child: AppPage(
                  maxWidth: 640,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        /// ✅ BIGGER package tile + larger image (user-friendly)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Selected Package",
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppSpacing.md),

                                /// Large image preview
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.lg),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Image.network(
                                      widget.imageUrl,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.packageName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(fontSize: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF16A34A)
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: const Color(0xFF16A34A)
                                              .withOpacity(0.35),
                                        ),
                                      ),
                                      child: Text(
                                        "Rs ${widget.packagePrice.toStringAsFixed(0)}",
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
                                  "Select a date and time slot for your booking.",
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        /// ✅ Date card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Select Date",
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _isSaving ? null : _pickDate,
                                      icon: const Icon(
                                          Icons.calendar_month_rounded),
                                      label: const Text("Choose Date"),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Text(
                                        dateText,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textStrong,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                if (selectedDate != null)
                                  Text(
                                    "Bookings for this date: $_totalBookingsForSelectedDate / $MAX_PER_DATE",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color:
                                          _totalBookingsForSelectedDate >= MAX_PER_DATE
                                              ? AppColors.danger
                                              : AppColors.textStrong,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        /// ✅ Time card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Select Time",
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                DropdownButtonFormField<String>(
                                  value: selectedTime,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: "Time slot",
                                    prefixIcon:
                                        Icon(Icons.access_time_rounded),
                                  ),
                                  hint: const Text("Select a time slot"),
                                  items: timeSlots.map((slot) {
                                    final count =
                                        _slotCountsForSelectedDate[slot] ?? 0;
                                    final isFull = count >= MAX_PER_SLOT;

                                    String label = slot;
                                    if (isFull) {
                                      label = "$slot (Full)";
                                    } else if (count == 1) {
                                      label = "$slot (1 booked)";
                                    }

                                    return DropdownMenuItem<String>(
                                      value: slot,
                                      enabled: !isFull,
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          color:
                                              isFull ? Colors.grey : Colors.black,
                                          fontWeight: isFull
                                              ? FontWeight.w700
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: _isSaving
                                      ? null
                                      : (v) => setState(() => selectedTime = v),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        /// ✅ Confirm button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _confirmBooking,
                            child: _isSaving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text("Confirm Booking"),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
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
