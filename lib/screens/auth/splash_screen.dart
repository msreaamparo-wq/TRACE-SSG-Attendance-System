import 'dart:async';

import 'package:attendance/providers/user_provider.dart';
import 'package:attendance/screens/auth/landing_page.dart';
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
  // ALWAYS START FROM LANDING PAGE
  // ============================================================

  Future<void> _checkSession() async {
    // Keep the splash screen visible briefly.
    await Future.delayed(
      const Duration(seconds: 2),
    );

    if (!mounted) return;

    // Clear Firebase login session so the previous account
    // will not automatically open the dashboard.
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Ignore sign-out errors and continue to Landing Page.
    }

    // Clear the locally cached user/session as well.
    final userProvider = Provider.of<UserProvider>(
      context,
      listen: false,
    );

    await userProvider.clearUser();

    if (!mounted) return;

    // Always open Landing Page when the app starts.
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