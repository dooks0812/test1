import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'shared/app_ui.dart';

// Screens (adjust paths if needed)
import 'user_dashboard.dart';
import 'packages_screen.dart';
import 'about_us_screen.dart';

/// REUSABLE APP SHELL (Bottom Navigation Wrapper)
class AppShell extends StatefulWidget {
  final int initialIndex;
  final List<Widget> screens;

  const AppShell({
    super.key,
    this.initialIndex = 0,
    required this.screens,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    final maxIndex = widget.screens.length - 1;
    final idx = widget.initialIndex;
    _selectedIndex = (idx < 0 || idx > maxIndex) ? 0 : idx;
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
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

/// NAVIGATION SCREEN (just passes screens into AppShell)
class NavigationScreen extends StatelessWidget {
  final int initialIndex;

  const NavigationScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AppShell(
      initialIndex: initialIndex,
      screens: const [
        UserDashboard(),  // 0 - Home
        PackagesScreen(), // 1 - Packages
        MapsTab(),        // 2 - Maps
        AboutUsScreen(),  // 3 - About
      ],
    );
  }
}

/// PUBLIC Maps tab (was _MapsTab)
class MapsTab extends StatefulWidget {
  const MapsTab({super.key});

  @override
  State<MapsTab> createState() => _MapsTabState();
}

class _MapsTabState extends State<MapsTab> {
  static const String _address = "Etwar Road, Ecroignard, Flacq, Mauritius";
  static const String _label = "Teknik Wash";

  ///coordinates of location
  static const LatLng _washLatLng = LatLng(-20.230395, 57.745369);

  ///Google Maps short link (exact location)
  static final Uri _pinnedGoogleLink =
      Uri.parse("https://maps.app.goo.gl/Bef1G15qk5ppxEAF9");

  late final Set<Marker> _markers;

  @override
  void initState() {
    super.initState();

    _markers = {
      Marker(
        markerId: const MarkerId("teknik_wash"),
        position: _washLatLng,
        infoWindow: const InfoWindow(
          title: _label,
          snippet: _address,
        ),
      ),
    };
  }

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
      // no AppBar -> modern map screen
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

          // Top overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Card(
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.place_rounded, color: AppColors.brandA),
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

          //Bottom CTA
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
