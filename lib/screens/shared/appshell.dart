import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.local_car_wash_rounded), label: "Packages"),
          BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: "Maps"),
          BottomNavigationBarItem(icon: Icon(Icons.info_outline_rounded), label: "About"),
        ],
      ),
    );
  }
}
