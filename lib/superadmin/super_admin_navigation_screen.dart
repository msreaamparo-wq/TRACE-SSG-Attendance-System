import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../screens/auth/login_screen.dart';

import 'super_admin_attendance_screen.dart';
import 'super_admin_common.dart' as common;
import 'super_admin_dashboard_screen.dart';
import 'super_admin_events_screen.dart';
import 'super_admin_feedback_screen.dart';
import 'super_admin_reports_screen.dart';
import 'super_admin_settings_screen.dart';
import 'super_admin_students_screen.dart';

class SuperAdminNavigationScreen extends StatefulWidget {
  const SuperAdminNavigationScreen({
    super.key,
  });

  @override
  State<SuperAdminNavigationScreen> createState() =>
      _SuperAdminNavigationScreenState();
}

class _SuperAdminNavigationScreenState
    extends State<SuperAdminNavigationScreen> {
  int _currentIndex = 0;

  // ============================================================
  // NAVIGATION ITEMS
  // ============================================================

  static const List<_NavItem> _items = [
    _NavItem(
      title: 'Dashboard',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
    ),
    _NavItem(
      title: 'Students',
      icon: Icons.school_outlined,
      activeIcon: Icons.school_rounded,
    ),
    _NavItem(
      title: 'Attendance',
      icon: Icons.fact_check_outlined,
      activeIcon: Icons.fact_check_rounded,
    ),
    _NavItem(
      title: 'Events',
      icon: Icons.event_outlined,
      activeIcon: Icons.event_rounded,
    ),
    _NavItem(
      title: 'Reports',
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
    ),
    _NavItem(
      title: 'Feedback',
      icon: Icons.rate_review_outlined,
      activeIcon: Icons.rate_review_rounded,
    ),
    _NavItem(
      title: 'Settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
    ),
  ];

  // ============================================================
  // SCREENS
  // IMPORTANT:
  // Do NOT use const here because your individual screens
  // may not have const constructors.
  // ============================================================

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    _screens = [
      SuperAdminDashboardScreen(),
      SuperAdminStudentsScreen(),
      SuperAdminAttendanceScreen(),
      SuperAdminEventsScreen(),
      SuperAdminReportsScreen(),
      const SuperAdminFeedbackScreen(),
      SuperAdminSettingsScreen(),
    ];
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final userData =
        context.watch<UserProvider>().userData;

    final currentUser = userData != null
        ? UserModel.fromMap(
      FirebaseAuth.instance.currentUser?.uid ?? '',
      userData,
    )
        : null;

    // ==========================================================
    // ACCESS CHECK
    // ==========================================================

    if (currentUser == null ||
        !currentUser.isSuperAdmin) {
      return _AccessDeniedScreen(
        onBackToLogin: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            ),
                (route) => false,
          );
        },
      );
    }

    // ==========================================================
    // RESPONSIVE NAVIGATION
    // ==========================================================

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1000) {
          return _shell(
            expanded: true,
          );
        }

        if (constraints.maxWidth >= 700) {
          return _shell(
            expanded: false,
          );
        }

        return _mobile();
      },
    );
  }

  // ============================================================
  // DESKTOP / TABLET
  // ============================================================

  Widget _shell({
    required bool expanded,
  }) {
    return Scaffold(
      backgroundColor:
      common.TraceColors.canvas,
      body: Row(
        children: [
          _sidebar(
            expanded: expanded,
          ),

          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MOBILE
  // ============================================================

  Widget _mobile() {
    return Scaffold(
      backgroundColor:
      common.TraceColors.canvas,

      appBar: AppBar(
        backgroundColor:
        common.TraceColors.ink,
        foregroundColor:
        common.TraceColors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        title: Text(
          _items[_currentIndex].title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ),

      drawer: Drawer(
        backgroundColor:
        common.TraceColors.ink,
        width: 272,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(
                height: 12,
              ),

              _brand(
                expanded: true,
              ),

              const SizedBox(
                height: 20,
              ),

              Padding(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                child:
                common.SuperAdminCommon
                    .divider(),
              ),

              const SizedBox(
                height: 12,
              ),

              Expanded(
                child: ListView(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 12,
                  ),
                  children: [
                    for (
                    int i = 0;
                    i < _items.length;
                    i++
                    )
                      _navItem(
                        i,
                        expanded: true,
                        closeDrawer: true,
                      ),
                  ],
                ),
              ),

              _logout(
                expanded: true,
              ),
            ],
          ),
        ),
      ),

      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
    );
  }

  // ============================================================
  // SIDEBAR
  // ============================================================

  Widget _sidebar({
    required bool expanded,
  }) {
    return Container(
      width: expanded ? 252 : 80,
      color:
      common.TraceColors.ink,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(
              height: 20,
            ),

            _brand(
              expanded: expanded,
            ),

            const SizedBox(
              height: 20,
            ),

            Padding(
              padding:
              EdgeInsets.symmetric(
                horizontal:
                expanded ? 20 : 18,
              ),
              child:
              common.SuperAdminCommon
                  .divider(),
            ),

            const SizedBox(
              height: 12,
            ),

            Expanded(
              child: ListView(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                children: [
                  for (
                  int i = 0;
                  i < _items.length;
                  i++
                  )
                    _navItem(
                      i,
                      expanded: expanded,
                    ),
                ],
              ),
            ),

            _logout(
              expanded: expanded,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BRAND
  // ============================================================

  Widget _brand({
    required bool expanded,
  }) {
    if (!expanded) {
      return Container(
        width: 40,
        height: 40,
        decoration:
        BoxDecoration(
          color:
          common.TraceColors.accent
              .withValues(
            alpha: 0.14,
          ),
          borderRadius:
          BorderRadius.circular(
            common.TraceRadius.sm,
          ),
        ),
        child: const Icon(
          Icons.shield_moon_rounded,
          color:
          common.TraceColors.accent,
          size: 20,
        ),
      );
    }

    return Padding(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
            BoxDecoration(
              color:
              common.TraceColors.accent
                  .withValues(
                alpha: 0.14,
              ),
              borderRadius:
              BorderRadius.circular(
                common.TraceRadius.sm,
              ),
            ),
            child: const Icon(
              Icons.shield_moon_rounded,
              color:
              common.TraceColors.accent,
              size: 20,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Super Admin',
                  style:
                  TextStyle(
                    color:
                    common.TraceColors.white,
                    fontSize: 14.5,
                    fontWeight:
                    FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),

                SizedBox(
                  height: 2,
                ),

                Text(
                  'TRACE',
                  style:
                  TextStyle(
                    color:
                    common.TraceColors
                        .mutedWhite,
                    fontSize: 10.5,
                    fontWeight:
                    FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NAVIGATION ITEM
  // ============================================================

  Widget _navItem(
      int index, {
        required bool expanded,
        bool closeDrawer = false,
      }) {
    final item = _items[index];
    final selected =
        _currentIndex == index;

    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 3,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
          BorderRadius.circular(
            common.TraceRadius.sm,
          ),

          onTap: () {
            setState(() {
              _currentIndex =
                  index;
            });

            if (closeDrawer) {
              Navigator.pop(
                context,
              );
            }
          },

          child:
          AnimatedContainer(
            duration:
            const Duration(
              milliseconds: 160,
            ),

            padding:
            EdgeInsets.symmetric(
              horizontal:
              expanded ? 12 : 0,
              vertical: 11,
            ),

            decoration:
            BoxDecoration(
              color: selected
                  ? Colors.white.withValues(
                alpha: 0.06,
              )
                  : Colors.transparent,
              borderRadius:
              BorderRadius.circular(
                common.TraceRadius.sm,
              ),
            ),

            child:
            Row(
              mainAxisAlignment:
              expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,

              children: [
                if (expanded &&
                    selected)
                  Container(
                    width: 3,
                    height: 16,
                    margin:
                    const EdgeInsets.only(
                      right: 9,
                    ),
                    decoration:
                    BoxDecoration(
                      color:
                      common.TraceColors
                          .accent,
                      borderRadius:
                      BorderRadius.circular(
                        common.TraceRadius
                            .pill,
                      ),
                    ),
                  ),

                Icon(
                  selected
                      ? item.activeIcon
                      : item.icon,
                  color: selected
                      ? common
                      .TraceColors
                      .accent
                      : common
                      .TraceColors
                      .mutedWhite,
                  size: 19,
                ),

                if (expanded) ...[
                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow:
                      TextOverflow
                          .ellipsis,
                      style:
                      TextStyle(
                        color: selected
                            ? common
                            .TraceColors
                            .white
                            : common
                            .TraceColors
                            .mutedWhite,
                        fontSize: 12.5,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Widget _logout({
    required bool expanded,
  }) {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        12,
        4,
        12,
        12,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
          BorderRadius.circular(
            common.TraceRadius.sm,
          ),

          onTap:
          _logoutAction,

          child:
          Padding(
            padding:
            EdgeInsets.symmetric(
              horizontal:
              expanded ? 12 : 0,
              vertical: 11,
            ),

            child:
            Row(
              mainAxisAlignment:
              expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,

              children: [
                const Icon(
                  Icons.logout_rounded,
                  color:
                  common.TraceColors
                      .mutedWhite,
                  size: 19,
                ),

                if (expanded) ...[
                  const SizedBox(
                    width: 12,
                  ),

                  const Text(
                    'Log out',
                    style:
                    TextStyle(
                      color:
                      common.TraceColors
                          .mutedWhite,
                      fontSize: 12.5,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logoutAction() async {
    final confirmed =
    await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) =>
          AlertDialog(
            backgroundColor:
            common.TraceColors.surface,

            shape:
            RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(
                common.TraceRadius.md,
              ),
            ),

            title:
            const Text(
              'Log out',
              style:
              TextStyle(
                fontWeight:
                FontWeight.w800,
                fontSize:
                16,
              ),
            ),

            content:
            const Text(
              'Are you sure you want to log out?',
              style:
              TextStyle(
                fontSize:
                13,
                color:
                common.TraceColors
                    .textSecondary,
              ),
            ),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
                },
                child:
                const Text(
                  'Cancel',
                ),
              ),

              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },
                style:
                common.SuperAdminCommon
                    .primaryButtonStyle(),
                child:
                const Text(
                  'Log out',
                ),
              ),
            ],
          ),
    );

    if (confirmed != true) {
      return;
    }

    await FirebaseAuth.instance.signOut();

    if (!mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
        const LoginScreen(),
      ),
          (route) => false,
    );
  }
}

// ================================================================
// NAV ITEM MODEL
// ================================================================

class _NavItem {
  final String title;
  final IconData icon;
  final IconData activeIcon;

  const _NavItem({
    required this.title,
    required this.icon,
    required this.activeIcon,
  });
}

// ================================================================
// ACCESS DENIED
// ================================================================

class _AccessDeniedScreen
    extends StatelessWidget {
  final VoidCallback onBackToLogin;

  const _AccessDeniedScreen({
    required this.onBackToLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      common.TraceColors.ink,

      body: Center(
        child: Container(
          constraints:
          const BoxConstraints(
            maxWidth: 380,
          ),

          margin:
          const EdgeInsets.all(
            24,
          ),

          padding:
          const EdgeInsets.fromLTRB(
            28,
            32,
            28,
            28,
          ),

          decoration:
          BoxDecoration(
            color:
            Colors.white.withValues(
              alpha: 0.04,
            ),
            borderRadius:
            BorderRadius.circular(
              common.TraceRadius.lg,
            ),
            border:
            Border.all(
              color:
              Colors.white.withValues(
                alpha: 0.08,
              ),
            ),
          ),

          child:
          Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              Container(
                width:
                56,
                height:
                56,
                decoration:
                BoxDecoration(
                  color:
                  common.TraceColors
                      .accent
                      .withValues(
                    alpha: 0.14,
                  ),
                  shape:
                  BoxShape.circle,
                ),
                child:
                const Icon(
                  Icons
                      .lock_outline_rounded,
                  color:
                  common.TraceColors
                      .accent,
                  size:
                  26,
                ),
              ),

              const SizedBox(
                height:
                20,
              ),

              const Text(
                'Access Restricted',
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  color:
                  common.TraceColors
                      .white,
                  fontSize:
                  19,
                  fontWeight:
                  FontWeight.w800,
                  letterSpacing:
                  -0.2,
                ),
              ),

              const SizedBox(
                height:
                8,
              ),

              const Text(
                'This section is limited to Super Admin accounts.',
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  color:
                  common.TraceColors
                      .mutedWhite,
                  fontSize:
                  13,
                  height:
                  1.5,
                ),
              ),

              const SizedBox(
                height:
                24,
              ),

              SizedBox(
                width:
                double.infinity,
                child:
                ElevatedButton(
                  onPressed:
                  onBackToLogin,
                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    common
                        .TraceColors
                        .accent,
                    foregroundColor:
                    common
                        .TraceColors
                        .ink,
                    elevation:
                    0,
                    padding:
                    const EdgeInsets
                        .symmetric(
                      vertical:
                      14,
                    ),
                    textStyle:
                    const TextStyle(
                      fontSize:
                      13,
                      fontWeight:
                      FontWeight.w700,
                    ),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius
                          .circular(
                        common
                            .TraceRadius
                            .sm,
                      ),
                    ),
                  ),
                  child:
                  const Text(
                    'Back to Login',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}