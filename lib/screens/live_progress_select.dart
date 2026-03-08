import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'live_progress.dart';

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
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: activeSessionQueryUserid.snapshots(),
        builder: (context, snap1) {
          if (snap1.hasError) {
            return Center(child: Text("Error: ${snap1.error}"));
          }

          if (snap1.hasData && snap1.data!.docs.isNotEmpty) {
            final doc = snap1.data!.docs.first;
            return _ActiveSessionCard(data: doc.data());
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: activeSessionQueryUserId.snapshots(),
            builder: (context, snap2) {
              if (snap2.hasError) {
                return Center(child: Text("Error: ${snap2.error}"));
              }

              if (snap2.hasData && snap2.data!.docs.isNotEmpty) {
                final doc = snap2.data!.docs.first;
                return _ActiveSessionCard(data: doc.data());
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

                          // ✅ Let user open LiveProgressScreen anyway (timeline will show)
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

                      final plate = (data['plateNumber'] ?? '-').toString();
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

  const _ActiveSessionCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final stage = (data['stage'] ?? 'WAITING').toString();
    final msg = (data['message'] ?? '').toString();

    final rawProgress = data['progress'] ?? 0;
    final progress = rawProgress is num ? rawProgress.toDouble() : 0.0;

    final p = progress.clamp(0, 100);

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
              if (msg.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(msg),
              ],
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: p / 100,
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 8),
              Text("${p.toStringAsFixed(0)}%"),
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
}
