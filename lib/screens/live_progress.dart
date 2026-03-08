import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:car_wash_app/services/notification_service.dart';

class LiveProgressScreen extends StatefulWidget {
  const LiveProgressScreen({super.key});

  @override
  State<LiveProgressScreen> createState() => _LiveProgressScreenState();
}

class _LiveProgressScreenState extends State<LiveProgressScreen> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventSub;
  String? _lastEventId;

  @override
  void initState() {
    super.initState();
    _startEventListener();
  }

  void _startEventListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final q = FirebaseFirestore.instance
        .collection('events')
        .where('uid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(1);

    _eventSub = q.snapshots().listen((snap) async {
      if (snap.docs.isEmpty) return;

      final doc = snap.docs.first;
      final eventId = doc.id;

      // Prevent showing same notification repeatedly
      if (_lastEventId == eventId) return;
      _lastEventId = eventId;

      final data = doc.data();
      final type = (data['type'] ?? 'UPDATE').toString();
      final plateKey = (data['plateKey'] ?? '').toString();

      final titleMap = {
        'CAR_ARRIVED': 'Car arrived ✅',
        'WASH_START': 'Wash started 🚿',
        'WASH_END': 'Wash finished ✅',
        'POLISH_START': 'Polish started ✨',
        'POLISH_END': 'Polish finished ✅',
        'VACUUM_START': 'Vacuum started 💨',
        'VACUUM_END': 'Vacuum finished ✅',
        'DONE': 'Car wash complete 🎉',
      };

      final title = titleMap[type] ?? 'Car Wash Update';
      final body = plateKey.isNotEmpty ? 'Plate: $plateKey' : 'Stage updated';

      // ✅ 1) Your Local Notification (kept)
      await LocalNotifs.show(title: title, body: body);

      // ✅ 2) Sweet in-app alert (added)
      if (!mounted) return;
      _showSweetAlert(title: title, body: body, type: type);
    });
  }

  void _showSweetAlert({
    required String title,
    required String body,
    required String type,
  }) {
    final icon = _eventIcon(type);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _SweetAlertDialog(
        title: title,
        message: body,
        icon: icon,
      ),
    );

    // Auto close after short time (feels smooth, not annoying)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'CAR_ARRIVED':
        return Icons.directions_car_rounded;
      case 'VACUUM_START':
      case 'VACUUM_END':
        return Icons.air_rounded;
      case 'WASH_START':
      case 'WASH_END':
        return Icons.local_car_wash_rounded;
      case 'POLISH_START':
      case 'POLISH_END':
        return Icons.auto_fix_high_rounded;
      case 'DONE':
        return Icons.celebration_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please login first.")),
      );
    }

    // ✅ Keeping your session doc usage
    final sessionRef =
        FirebaseFirestore.instance.collection("wash_sessions").doc("1");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Progress"),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: sessionRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _LoadingView();
          }

          final data = snap.data?.data();

          // ✅ Always show timeline even if nothing found
          if (data == null) {
            return _WaitingTimeline(
              title: "Waiting for your car…",
              subtitle:
                  "Once your car arrives and the wash begins, you’ll see live progress here.",
            );
          }

          final sessionActive = (data["sessionActive"] ?? false) as bool;
          final sessionUid = (data["userid"] ?? data["userId"] ?? "").toString();

          final stage = (data["stage"] ?? "WAITING").toString();
          final message = (data["message"] ?? "").toString();
          final rawProgress = data["progress"] ?? 0;
          final progress = rawProgress is int
              ? rawProgress
              : int.tryParse(rawProgress.toString()) ?? 0;

          final p = progress.clamp(0, 100).toDouble();

          // ✅ Requirement: show timeline always when not started / not active / not your account
          if (!sessionActive || sessionUid != user.uid) {
            return _WaitingTimeline(
              title: "No wash started yet",
              subtitle:
                  "Your timeline is ready. When your car arrives, we’ll update you instantly.",
            );
          }

          // ✅ DONE state
          final isDone = stage.toUpperCase() == "DONE" || p >= 100;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _HeaderCard(stage: stage, message: message),
                const SizedBox(height: 12),

                // ✅ Timeline (always shown for active session too)
                _ProgressTimeline(stage: stage, progress: p),

                const SizedBox(height: 12),

                if (isDone)
                  const _DoneCard()
                else
                  _ProgressCard(
                    progress: p,
                    stage: stage,
                    message: message,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// ✅ Nice top info card
class _HeaderCard extends StatelessWidget {
  final String stage;
  final String message;

  const _HeaderCard({
    required this.stage,
    required this.message,
  });

  IconData _stageIcon(String stage) {
    final s = stage.toUpperCase();
    if (s.contains("VACUUM")) return Icons.air_rounded;
    if (s.contains("WASH")) return Icons.local_car_wash_rounded;
    if (s.contains("POLISH")) return Icons.auto_fix_high_rounded;
    if (s.contains("ARRIVED")) return Icons.directions_car_rounded;
    if (s.contains("DONE")) return Icons.celebration_rounded;
    return Icons.timelapse_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: cs.primary.withOpacity(0.12),
              child: Icon(_stageIcon(stage), color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Current Stage",
                    style: TextStyle(
                      color: cs.onSurface.withOpacity(0.65),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stage,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (message.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      message,
                      style: TextStyle(color: cs.onSurface.withOpacity(0.8)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ✅ Shows waiting timeline when no wash started (your requirement)
class _WaitingTimeline extends StatelessWidget {
  final String title;
  final String subtitle;

  const _WaitingTimeline({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.schedule_rounded, size: 40),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _ProgressTimeline(stage: "WAITING", progress: 0),
      ],
    );
  }
}

/// ✅ Timeline widget (clean and always visible)
class _ProgressTimeline extends StatelessWidget {
  final String stage;
  final double progress;

  const _ProgressTimeline({
    required this.stage,
    required this.progress,
  });

  int _currentIndex(String stage, double p) {
    final s = stage.toUpperCase();

    if (s.contains("DONE") || p >= 100) return 4;
    if (s.contains("POLISH")) return 3;
    if (s.contains("WASH")) return 2;
    if (s.contains("VACUUM")) return 1;
    if (s.contains("ARRIVED")) return 0;

    // WAITING or UNKNOWN
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final idx = _currentIndex(stage, progress);

    final steps = <_TimelineStepData>[
      const _TimelineStepData(
        title: "Car Arrived",
        subtitle: "We detected your car at the entrance",
        icon: Icons.directions_car_rounded,
      ),
      const _TimelineStepData(
        title: "Vacuum",
        subtitle: "Interior cleaning in progress",
        icon: Icons.air_rounded,
      ),
      const _TimelineStepData(
        title: "Wash",
        subtitle: "Exterior wash in progress",
        icon: Icons.local_car_wash_rounded,
      ),
      const _TimelineStepData(
        title: "Polish",
        subtitle: "Finishing touches & shine",
        icon: Icons.auto_fix_high_rounded,
      ),
      const _TimelineStepData(
        title: "Done",
        subtitle: "Your car is ready 🎉",
        icon: Icons.celebration_rounded,
      ),
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Timeline",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            ...List.generate(steps.length, (i) {
              final isCompleted = idx >= i && idx != -1;
              final isActive = idx == i;

              return _TimelineRow(
                data: steps[i],
                isCompleted: isCompleted,
                isActive: isActive,
                isLast: i == steps.length - 1,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TimelineStepData {
  final String title;
  final String subtitle;
  final IconData icon;

  const _TimelineStepData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _TimelineRow extends StatelessWidget {
  final _TimelineStepData data;
  final bool isCompleted;
  final bool isActive;
  final bool isLast;

  const _TimelineRow({
    required this.data,
    required this.isCompleted,
    required this.isActive,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Color dotBg = isCompleted
        ? cs.primary
        : cs.onSurface.withOpacity(0.12);

    final Color iconColor = isCompleted ? cs.onPrimary : cs.onSurface;

    final TextStyle titleStyle = TextStyle(
      fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
      fontSize: 14,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: dotBg,
                shape: BoxShape.circle,
              ),
              child: Icon(data.icon, size: 18, color: iconColor),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 34,
                color: cs.onSurface.withOpacity(0.12),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title, style: titleStyle),
                const SizedBox(height: 2),
                Text(
                  data.subtitle,
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// ✅ Progress card (pretty)
class _ProgressCard extends StatelessWidget {
  final double progress;
  final String stage;
  final String message;

  const _ProgressCard({
    required this.progress,
    required this.stage,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Live Progress",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  "${progress.toStringAsFixed(0)}%",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  stage,
                  style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
                ),
              ],
            ),
            if (message.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(color: cs.onSurface.withOpacity(0.8)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ✅ Done screen card
class _DoneCard extends StatelessWidget {
  const _DoneCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(Icons.celebration_rounded, size: 52, color: cs.primary),
            const SizedBox(height: 10),
            const Text(
              "DONE 🎉",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Your car wash is complete. Thank you for choosing us!",
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }
}

/// ✅ Sweet alert dialog UI
class _SweetAlertDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _SweetAlertDialog({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: cs.primary.withOpacity(0.12),
              child: Icon(icon, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(color: cs.onSurface.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
