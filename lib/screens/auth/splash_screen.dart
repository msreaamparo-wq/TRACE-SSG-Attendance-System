
import 'dart:async';

import 'package:attendance/providers/user_provider.dart';
import 'package:attendance/screens/auth/landing_page.dart';
import 'package:attendance/screens/navigation/home_screen.dart';
import 'package:attendance/services/local_storage_service.dart';
import 'package:attendance/superadmin/super_admin_navigation_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
const SplashScreen({super.key});

@override
State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
@override
void initState() {
super.initState();

_checkSession();
}

// ============================================================
// CHECK LOGIN SESSION
// ============================================================

Future<void> _checkSession() async {
// Give the splash screen a short display time.
await Future.delayed(
const Duration(seconds: 2),
);

if (!mounted) return;

// ==========================================================
// 1. CHECK FIREBASE AUTH SESSION
// ==========================================================

final User? firebaseUser =
FirebaseAuth.instance.currentUser;

// ==========================================================
// FIREBASE USER EXISTS
// ==========================================================

if (firebaseUser != null) {
// Load the locally cached user first.
final userProvider =
Provider.of<UserProvider>(
context,
listen: false,
);

userProvider.loadCachedUser();

// Get cached user data.
final cachedUser =
LocalStorageService.getUserSession();

String role = '';

if (cachedUser != null) {
role = (cachedUser['role'] ?? '')
    .toString()
    .trim()
    .toLowerCase();
}

// --------------------------------------------------------
// SUPER ADMIN
// --------------------------------------------------------

if (role == 'superadmin') {
_navigateTo(
const SuperAdminNavigationScreen(),
);

return;
}

// --------------------------------------------------------
// ADMIN
// --------------------------------------------------------

if (role == 'admin') {
_navigateTo(
const HomeScreen(),
);

return;
}

// --------------------------------------------------------
// FIREBASE USER EXISTS BUT NO LOCAL ROLE
// --------------------------------------------------------

// This can happen when the user was previously authenticated
// but the local Hive session was cleared.
//
// We do not assume the account role here because role
// information is stored in Firestore and this splash screen
// should not block waiting for a network request.
//
// Send the user to Landing Page so they can sign in again.
_navigateTo(
const LandingPage(),
);

return;
}

// ==========================================================
// 2. NO FIREBASE USER
// ==========================================================
//
// Check the local Hive session.
// This allows the app to restore the last known account
// information even when Firebase does not provide a current
// authenticated session.

final cachedUser =
LocalStorageService.getUserSession();

if (cachedUser != null) {
// Restore cached user into UserProvider.
final userProvider =
Provider.of<UserProvider>(
context,
listen: false,
);

userProvider.loadCachedUser();

final role = (cachedUser['role'] ?? '')
    .toString()
    .trim()
    .toLowerCase();

// --------------------------------------------------------
// SUPER ADMIN
// --------------------------------------------------------

if (role == 'superadmin') {
_navigateTo(
const SuperAdminNavigationScreen(),
);

return;
}

// --------------------------------------------------------
// ADMIN
// --------------------------------------------------------

if (role == 'admin') {
_navigateTo(
const HomeScreen(),
);

return;
}
}

// ==========================================================
// 3. NO SESSION
// ==========================================================

_navigateTo(
const LandingPage(),
);
}

// ============================================================
// NAVIGATION HELPER
// ============================================================

void _navigateTo(Widget screen) {
if (!mounted) return;

Navigator.pushReplacement(
context,
MaterialPageRoute(
builder: (_) => screen,
),
);
}

// ============================================================
// BUILD
// ============================================================

@override
Widget build(BuildContext context) {
return const Scaffold(
backgroundColor: Color(0xFF0C1B45),
body: Center(
child: FlutterLogo(
size: 120,
),
),
);
}
}

