import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'shared/app_ui.dart';
import 'live_progress.dart';

String _extractPlateFromSession(Map<String, dynamic> data) {
  final direct = (data["plateNumber"] ??
          data["plateRaw"] ??
          data["plate"] ??
          data["plateNo"] ??
          data["plateKey"] ??
          "")
      .toString()
      .trim();
  if (direct.isNotEmpty) return direct.toUpperCase();

  final car = data["car"]; //If the plate was not found directly, the code checks if there is a nested car object
  if (car is Map<String, dynamic>) {
    final nested =
        (car["plateNumber"] ?? car["plateRaw"] ?? car["plateKey"] ?? "")
            .toString()
            .trim();
    if (nested.isNotEmpty) return nested.toUpperCase();
  }

  return "";
}

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

//tries to find the latest plate number from the user’s event documents
String _latestPlateFromEvents(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
  if (docs.isEmpty) return "";

  final sorted = [...docs]..sort(
      (a, b) =>
          _createdAtForSort(b.data()).compareTo(_createdAtForSort(a.data())),
    );

  for (final doc in sorted) {
    final plate = _extractPlateFromSession(doc.data());//Tries to extract a plate from each event
    if (plate.isNotEmpty) return plate;
  }
  return "";
}

class LiveProgressSelectScreen extends StatelessWidget {
  const LiveProgressSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text("Please login again.")),
      );
    }

    final activeSessionQueryUserid = FirebaseFirestore.instance
        .collection('wash_sessions')
        .where('sessionActive', isEqualTo: true)
        .where('userid', isEqualTo: uid)
        .limit(1);

    final activeSessionQueryUserId = FirebaseFirestore.instance
        .collection('wash_sessions')
        .where('sessionActive', isEqualTo: true)
        .where('userId', isEqualTo: uid)
        .limit(1);

    final bookingsQuery = FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Progress"),
        centerTitle: true,
        backgroundColor: AppColors.brandA,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: activeSessionQueryUserid.snapshots(),
        builder: (context, snap1) {
          if (snap1.hasError) {
            return Center(child: Text("Error: ${snap1.error}"));
          }

          if (snap1.hasData && snap1.data!.docs.isNotEmpty) {
            final doc = snap1.data!.docs.first;
            return _ActiveSessionCard(
              data: doc.data(),
              uid: uid,
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: activeSessionQueryUserId.snapshots(),
            builder: (context, snap2) {
              if (snap2.hasError) {
                return Center(child: Text("Error: ${snap2.error}"));
              }

              if (snap2.hasData && snap2.data!.docs.isNotEmpty) {
                final doc = snap2.data!.docs.first;
                return _ActiveSessionCard(
                  data: doc.data(),
                  uid: uid,
                );
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: bookingsQuery.snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text("Error: ${snap.error}"));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data!.docs;

                  if (docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 44),
                          const SizedBox(height: 10),
                          const Text(
                            "Nothing to show yet",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "No active wash session and no bookings found.",
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),

                          // Let user open LiveProgressScreen anyway (timeline will show)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              icon: const Icon(Icons.timeline_rounded),
                              label: const Text("Open Timeline"),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LiveProgressScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      final data = d.data();

                      final extractedPlate = _extractPlateFromSession(data);
                      final plate =
                          extractedPlate.isNotEmpty ? extractedPlate : "-";
                      final pkg = (data['packageName'] ?? '-').toString();
                      final date = (data['date'] ?? '-').toString();
                      final time = (data['time'] ?? '-').toString();

                      return Card(
                        elevation: 2,
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.local_car_wash_rounded),
                          ),
                          title: Text("Plate: $plate"),
                          subtitle: Text("Package: $pkg\n$date • $time"),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LiveProgressScreen(),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String uid;

  const _ActiveSessionCard({
    required this.data,
    required this.uid,
  });

  Widget _buildCardBody({
    required BuildContext context,
    required String stage,
    required String msg,
    required double progress,
    required String plate,
  }) {
    final shownPlate = plate.trim().isNotEmpty ? plate : "-";

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Active Wash Session Found",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text("Stage: $stage"),
              const SizedBox(height: 4),
              Text("Plate: $shownPlate"),
              if (msg.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(msg),
              ],
              const SizedBox(height: 12),
              ClipRRect( //Displays the progress bar.
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 8),
              Text("${progress.toStringAsFixed(0)}%"),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  label: const Text("Continue Live Progress"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LiveProgressScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stage = (data['stage'] ?? 'WAITING').toString();
    final msg = (data['message'] ?? '').toString();
    final extractedPlate = _extractPlateFromSession(data);

    final rawProgress = data['progress'] ?? 0; //Gets progress from Firestore
    final progress = rawProgress is num ? rawProgress.toDouble() : 0.0;

    final p = progress.clamp(0, 100).toDouble();

    if (extractedPlate.isNotEmpty) {
      return _buildCardBody(
        context: context,
        stage: stage,
        msg: msg,
        progress: p,
        plate: extractedPlate,
      );
    }

    final eventsQuery = FirebaseFirestore.instance
        .collection("events")
        .where("uid", isEqualTo: uid)
        .limit(20);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: eventsQuery.snapshots(), //listens to those events in real time
      builder: (context, snap) {
        final eventPlate =
            snap.hasData ? _latestPlateFromEvents(snap.data!.docs) : "";
        final plate = eventPlate.isNotEmpty ? eventPlate : "-";

        return _buildCardBody(
          context: context,
          stage: stage,
          msg: msg,
          progress: p,
          plate: plate,
        );
      },
    );
  }
}
