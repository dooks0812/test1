import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'shared/app_ui.dart';


import 'user_dashboard.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  //Your contact details
  static const String _phone = "+23058095168"; // no spaces for tel:
  static const String _phoneDisplay = "+230 5809 5168";

  static const String _email = "bhuvishkadookhooah@gmail.com";

  static const String _address = "Etwar Road Ecroignard, Flacq, Mauritius";

  // Optional: exact Google Maps query
  static const String _mapsQuery =
      "Etwar Road Ecroignard, Flacq, Mauritius";

  Future<void> _openUri(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not open: ${uri.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //Top image in AppBar area
      appBar: AppBar(
        title: const Text(
          "About Us",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        toolbarHeight: 70,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,

        //ADD: Back button → UserDashboard
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: "Back",
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => const UserDashboard(),
              ),
              (route) => false,
            );
          },
        ),

        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/images/top.jpg"),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            // overlay for readability (NOT blur)
            color: Colors.black.withValues(alpha: 0.25),
          ),
        ),
      ),

      //Background image (NOT blurred)
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/images/bg.jpg",
              fit: BoxFit.cover,
            ),
          ),

          // light overlay so text stays readable (NOT blur)
          Positioned.fill(
            child: Container(
              color: const Color(0xFFEAF1FF).withValues(alpha: 0.82),
            ),
          ),

          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Header card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Container(
                              height: 64,
                              width: 64,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.brandA.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Image.asset(
                                "assets/images/logo.png",
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Smart Car Wash System",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "IoT-based booking & live wash tracking",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    //Who are we
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Who Are We?",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              "We are a modern car wash service dedicated to saving your time and enhancing your car care experience. "
                              "With our IoT-based and mobile app solution, users can easily book slots, navigate to our service station, "
                              "track wash progress, and receive instant notifications.",
                              style: TextStyle(fontSize: 15, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    //Mission
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Our Mission",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              "To revolutionize traditional car wash services using Internet of Things, automation, and seamless mobile technology.",
                              style: TextStyle(fontSize: 15, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    //Contact + redirects
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(12, 12, 12, 6),
                              child: Text(
                                "Contact Us",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            ListTile(
                              leading: Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.brandA.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.phone,
                                    color: AppColors.brandA),
                              ),
                              title: const Text("Phone"),
                              subtitle: const Text(_phoneDisplay),
                              trailing: const Icon(Icons.open_in_new),
                              onTap: () => _openUri(
                                context,
                                Uri.parse("tel:$_phone"),
                              ),
                            ),

                            ListTile(
                              leading: Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.brandA.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.email,
                                    color: AppColors.brandA),
                              ),
                              title: const Text("Email"),
                              subtitle: const Text(_email),
                              trailing: const Icon(Icons.open_in_new),
                              onTap: () => _openUri(
                                context,
                                Uri(
                                  scheme: "mailto",
                                  path: _email,
                                  query: Uri.encodeQueryComponent(
                                    "subject=Smart Car Wash Enquiry&body=Hello,",
                                  ),
                                ),
                              ),
                            ),

                            ListTile(
                              leading: Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.brandA.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.location_on,
                                    color: AppColors.brandA),
                              ),
                              title: const Text("Location"),
                              subtitle: const Text(_address),
                              trailing: const Icon(Icons.open_in_new),
                              onTap: () => _openUri(
                                context,
                                Uri.parse(
                                  "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(_mapsQuery)}",
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Center(
                      child: Text(
                        "© 2025 Smart Car Wash. All Rights Reserved.",
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
