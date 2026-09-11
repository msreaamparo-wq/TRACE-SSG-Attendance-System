import 'package:flutter/material.dart';

import '../dashboard/dashboard_screen.dart';
import '../events/events_screen.dart';
import '../attendance/attendance_screen.dart';
import '../profile/profile_screen.dart';
import '../names/students.dart';

/// Root shell of the app: hosts the main tabs (Home, Events, Scan,
/// Attendance, Profile) behind a floating bottom navigation bar.
///
/// "Scan" reuses [AttendanceScreen], which already contains the
/// Select Event / Scan QR / Enter ID Number flow, so no separate
/// scan page is needed.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const List<_NavDestination> _destinations = [
    _NavDestination(icon: Icons.home_rounded, label: 'Home'),
    _NavDestination(icon: Icons.event_rounded, label: 'Events'),
    _NavDestination(icon: Icons.qr_code_scanner_rounded, label: 'Scan'),
    _NavDestination(icon: Icons.people_alt_rounded, label: 'Attendance'),
    _NavDestination(icon: Icons.person_rounded, label: 'Profile'),
  ];

  final List<Widget> _pages = const [
    DashboardScreen(),
    EventsScreen(),
    AttendanceScreen(),
    StudentsScreen(),
    ProfileScreen(),
  ];

  void _onDestinationSelected(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1B45),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _BottomNavBar(
        destinations: _destinations,
        currentIndex: _currentIndex,
        onSelected: _onDestinationSelected,
      ),
    );
  }
}

/// Static description of a single tab (icon + label).
class _NavDestination {
  final IconData icon;
  final String label;

  const _NavDestination({required this.icon, required this.label});
}

/// Floating, rounded bottom navigation bar.
class _BottomNavBar extends StatelessWidget {
  final List<_NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  const _BottomNavBar({
    required this.destinations,
    required this.currentIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: List.generate(destinations.length, (index) {
            final destination = destinations[index];
            return Expanded(
              child: _NavItem(
                icon: destination.icon,
                label: destination.label,
                selected: currentIndex == index,
                onTap: () => onSelected(index),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// A single tappable icon + label in the bottom navigation bar, with
/// an animated selected state (pill background, icon chip, and a
/// small indicator dash under the label).
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const Color _blue = Color(0xFF1565C0);
  static const Color _darkText = Color(0xFF0C1B45);
  static const Duration _animationDuration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: _animationDuration,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? _blue.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconChip(),
            const SizedBox(height: 3),
            _labelText(),
            const SizedBox(height: 3),
            _selectedIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _iconChip() {
    return AnimatedContainer(
      duration: _animationDuration,
      width: selected ? 34 : 30,
      height: selected ? 34 : 30,
      decoration: BoxDecoration(
        color: selected ? _blue.withOpacity(0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        icon,
        color: selected ? _blue : _darkText.withOpacity(0.50),
        size: selected ? 21 : 20,
      ),
    );
  }

  Widget _labelText() {
    return AnimatedDefaultTextStyle(
      duration: _animationDuration,
      style: TextStyle(
        color: selected ? _blue : _darkText.withOpacity(0.48),
        fontSize: selected ? 9 : 8.5,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        letterSpacing: 0.1,
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _selectedIndicator() {
    return AnimatedContainer(
      duration: _animationDuration,
      width: selected ? 14 : 0,
      height: selected ? 3 : 0,
      decoration: BoxDecoration(
        color: selected ? _blue : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}