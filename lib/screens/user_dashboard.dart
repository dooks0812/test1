import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'packages_screen.dart';
import 'about_us_screen.dart';
import 'login_screen.dart';
import 'profile.dart';
import 'shared/app_ui.dart';
import 'live_progress_select.dart';
import 'my_bookings_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

///This is now your MAIN APP SHELL for users (bottom nav on all pages)
class _UserDashboardState extends State<UserDashboard> {
  int _selectedIndex = 0;

  void _setTab(int index) {
    if (!mounted) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Keep tab states alive
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _DashboardHomeTab(onTabRequested: _setTab), // 0
          const PackagesScreen(), // 1
          const _MapsTab(), // 2
          const AboutUsScreen(), // 3
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(//bottom menu
        currentIndex: _selectedIndex,
        onTap: _setTab,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.brandA,
        unselectedItemColor: AppColors.textMuted,
        backgroundColor: AppColors.surface,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_car_wash_rounded),
            label: "Packages",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_rounded),
            label: "Maps",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline_rounded),
            label: "About",
          ),
        ],
      ),
    );
  }
}

///Your original dashboard UI, but now as a TAB (no Scaffold)
class _DashboardHomeTab extends StatefulWidget {
  final void Function(int index) onTabRequested;

  const _DashboardHomeTab({required this.onTabRequested});

  @override
  State<_DashboardHomeTab> createState() => _DashboardHomeTabState();
}

class _DashboardHomeTabState extends State<_DashboardHomeTab> {
  bool _dialogShowing = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notifSub;
  bool _notifErrorShown = false;

  @override
  void initState() {
    super.initState();
    _listenForNotifications();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  void _listenForNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final stream = FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("notifications")
        .where("isRead", isEqualTo: false)
        .limit(20)
        .snapshots();

    _notifSub = stream.listen(
      (snap) async {
        if (!mounted) return;
        if (snap.docs.isEmpty) return;
        if (_dialogShowing) return;

        final docs = [...snap.docs]..sort(
            (a, b) => _createdAtForSort(b.data()).compareTo(
              _createdAtForSort(a.data()),
            ),
          );

        final doc = docs.first;
        final data = doc.data();//read notif data

        final title = (data["title"] ?? "Notification").toString();
        final message = (data["message"] ?? "").toString();
        final ctaRoute = (data["ctaRoute"] ?? "packages").toString();

        _dialogShowing = true;

        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) {
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () async {
                    try {
                      await doc.reference.update({"isRead": true});
                    } catch (_) {}
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text("Dismiss"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await doc.reference.update({"isRead": true});
                    } catch (_) {}
                    if (mounted) Navigator.pop(context);

                    //Redirect using tabs (NO pushing new pages)
                    if (ctaRoute == "packages") {
                      widget.onTabRequested(1); // Packages tab
                    }
                  },
                  child: const Text("View Packages"),
                ),
              ],
            );
          },
        ).then((_) {
          _dialogShowing = false;
        });
      },
      onError: (err) {
        if (!mounted) return;

        if (!_notifErrorShown) {
          _notifErrorShown = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Notifications error: $err")),
          );
        }
      },
    );
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

  void _logout() {
    context.pushReplaceAll(const LoginScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ///Background image
        Positioned.fill(
          child: Image.asset(
            "assets/images/bg.jpg",
            fit: BoxFit.cover,
          ),
        ),

        ///Soft overlay (readable)
        Positioned.fill(
          child: Container(
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),

        ///Content
        Column(
          children: [
            AppGradientHeader(
              title: "User Dashboard",
              subtitle: "Welcome back",
              backgroundImageAsset: "assets/images/top.jpg",
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.person_outline, color: Colors.white),
                    tooltip: "Profile",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProfileScreen()),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    tooltip: "Logout",
                    onPressed: _logout,
                  ),
                ],
              ),
            ),
            Expanded(
              child: AppPage(
                child: GridView(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: context.gridCount(xs: 2, md: 3, lg: 4),
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: context.tileAspectRatio,
                  ),
                  children: [
                    AppActionTile(
                      icon: Icons.local_car_wash_rounded,
                      title: "Packages",
                      subtitle: "Prices & services",
                      onTap: () => widget.onTabRequested(1),
                    ),
                    AppActionTile(
                      icon: Icons.navigation_rounded,
                      title: "Direction",
                      subtitle: "Navigate to car wash",
                      onTap: () => widget.onTabRequested(2),
                    ),
                    AppActionTile(
                      icon: Icons.timeline_rounded,
                      title: "Live Progress",
                      subtitle: "Real-time wash updates",
                      onTap: () =>
                          context.push(const LiveProgressSelectScreen()),
                    ),
                    AppActionTile(
                      icon: Icons.receipt_long_rounded,
                      title: "My Bookings",
                      subtitle: "View your booking history",
                      onTap: () => context.push(const MyBookingsScreen()),
                    ),
                    AppActionTile(
                      icon: Icons.info_outline_rounded,
                      title: "About Us",
                      subtitle: "Who we are & how it works",
                      onTap: () => widget.onTabRequested(3),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// ✅ Maps tab inside this file (so NO circular imports)
class _MapsTab extends StatefulWidget {
  const _MapsTab();

  @override
  State<_MapsTab> createState() => _MapsTabState();
}

class _MapsTabState extends State<_MapsTab> {
  static const String _address = "Etwar Road, Ecroignard, Flacq, Mauritius";
  static const String _label = "Teknik Wash";

  static const LatLng _washLatLng = LatLng(-20.230395, 57.745369);

  static final Uri _pinnedGoogleLink =
      Uri.parse("https://maps.app.goo.gl/Bef1G15qk5ppxEAF9");

  late final Set<Marker> _markers = {
    const Marker(
      markerId: MarkerId("teknik_wash"),
      position: _washLatLng,
      infoWindow: InfoWindow(title: _label, snippet: _address),
    ),
  };

  Future<void> _openExternalNavigation() async {
    final ok = await launchUrl(
      _pinnedGoogleLink,
      mode: LaunchMode.externalApplication,
    );

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open Maps.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _washLatLng,
                zoom: 15,
              ),
              markers: _markers,
              zoomControlsEnabled: true,
              myLocationEnabled: !kIsWeb,
              myLocationButtonEnabled: !kIsWeb,
              compassEnabled: true,
              mapToolbarEnabled: true,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Card(
                elevation: 2,
                child: ListTile(
                  leading:
                      const Icon(Icons.place_rounded, color: AppColors.brandA),
                  title: const Text(
                    _label,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(_address),
                  trailing: IconButton(
                    tooltip: "Navigate",
                    icon: const Icon(Icons.directions_rounded),
                    onPressed: _openExternalNavigation,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _openExternalNavigation,
                    icon: const Icon(Icons.directions_rounded),
                    label: const Text(
                      "Navigate",
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
