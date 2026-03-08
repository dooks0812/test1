import 'package:flutter/material.dart';
import 'package:car_wash_app/services/notification_service.dart';

import 'login_screen.dart';
import 'shared/app_ui.dart';

// ✅ Your new pages
import 'admin_crud.dart';
import 'admin_view_booking.dart';

// ✅ ADD THIS
import 'admin_booking_trends.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  /// Logout and return to LoginScreen
  void _logout(BuildContext context) {
    // Uses your universal navigation helper from app_ui.dart
    context.pushReplaceAll(const LoginScreen());
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Fix overflow: make tiles a bit taller on smaller screens
    final double tileRatio = context.isMdUp ? context.tileAspectRatio : 1.15;

    return Scaffold(
      body: Column(
        children: [
          /// Top gradient header
          AppGradientHeader(
            title: "Admin Dashboard",
            subtitle: "Administrator",
            description: "Manage packages and monitor bookings.",
            trailing: IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              tooltip: "Logout",
              onPressed: () => _logout(context),
            ),
          ),

          /// Main content
          Expanded(
            child: AppPage(
              child: GridView(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: context.gridCount(xs: 2, md: 3, lg: 4),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: tileRatio, // ✅ changed only here
                ),
                children: [
                  /// ✅ Manage packages (CRUD)
                  AppActionTile(
                    icon: Icons.local_car_wash_rounded,
                    title: "Manage Packages",
                    subtitle: "Create / update / delete packages",
                    onTap: () => context.push(const AdminCrudScreen()),
                  ),

                  /// ✅ View bookings
                  AppActionTile(
                    icon: Icons.book_online_rounded,
                    title: "View Bookings",
                    subtitle: "Approve / cancel user bookings",
                    onTap: () => context.push(const AdminViewBookingScreen()),
                  ),

                  /// ✅ NEW TILE: Booking Trends
                  AppActionTile(
                    icon: Icons.insights_rounded,
                    title: "Booking Trends",
                    subtitle: "Analytics & trends",
                    onTap: () => context.push(const AdminBookingTrendsScreen()),
                    // If your class name differs, replace AdminBookingTrendsScreen
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
