import 'package:attendance/providers/user_provider.dart';
import 'package:attendance/screens/auth/landing_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ================================================================
// PROFILE COLORS
// Shared across the whole file
// ================================================================

const Color profileNavy = Color(0xFF071936);
const Color profileLightNavy = Color(0xFF102A52);
const Color profileBgNavy = Color(0xFF081B3A);

const Color profileCardBg = Colors.white;
const Color profileCardBorder = Color(0xFFE8ECF2);

const Color profileTextPrimary = Color(0xFF1B2432);
const Color profileTextSecondary = Color(0xFF6B7280);

const Color profileBlue = Color(0xFF4A90E2);
const Color profilePurple = Color(0xFF7C5CFC);

const Color profileLogoutRed = Color(0xFFE0473C);

// ================================================================
// PROFILE SCREEN
// ================================================================

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // ==============================================================
  // LOGOUT
  // ==============================================================

  Future<void> _logout(
      BuildContext context,
      ) async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LandingPage(),
        ),
            (route) => false,
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logout failed: $e',
          ),
          backgroundColor: profileLogoutRed,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }

  // ==============================================================
  // CONFIRM LOGOUT
  // ==============================================================

  Future<void> _confirmLogout(
      BuildContext context,
      ) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              24,
              24,
              24,
              20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --------------------------------------------------
                // ICON
                // --------------------------------------------------

                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: profileLogoutRed.withOpacity(
                      0.09,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: profileLogoutRed,
                    size: 29,
                  ),
                ),

                const SizedBox(height: 18),

                // --------------------------------------------------
                // TITLE
                // --------------------------------------------------

                const Text(
                  'Logout',
                  style: TextStyle(
                    color: profileTextPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Are you sure you want to log out of TRACE?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: profileTextSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 24),

                // --------------------------------------------------
                // BUTTONS
                // --------------------------------------------------

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(
                            dialogContext,
                          ).pop(false);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                          profileTextPrimary,
                          minimumSize: const Size(
                            0,
                            48,
                          ),
                          side: const BorderSide(
                            color: profileCardBorder,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(
                              14,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight:
                            FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(
                            dialogContext,
                          ).pop(true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          profileLogoutRed,
                          foregroundColor:
                          Colors.white,
                          elevation: 0,
                          minimumSize: const Size(
                            0,
                            48,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(
                              14,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Logout',
                          style: TextStyle(
                            fontWeight:
                            FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldLogout == true &&
        context.mounted) {
      await _logout(context);
    }
  }

  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final userData =
        Provider.of<UserProvider>(
          context,
          listen: true,
        ).userData;

    // ============================================================
    // SAFE USER DATA
    // ============================================================

    String fullName = 'User';
    String role = 'User';

    if (userData != null) {
      final fullNameValue =
      userData['fullName'];

      if (fullNameValue != null &&
          fullNameValue
              .toString()
              .trim()
              .isNotEmpty) {
        fullName =
            fullNameValue
                .toString()
                .trim();
      }

      final roleValue =
      userData['role'];

      if (roleValue != null &&
          roleValue
              .toString()
              .trim()
              .isNotEmpty) {
        role =
            roleValue
                .toString()
                .trim();
      }
    }

    // ============================================================
    // INITIAL
    // ============================================================

    final String firstLetter =
    fullName.trim().isNotEmpty
        ? fullName
        .trim()
        .substring(
      0,
      1,
    )
        .toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: profileBgNavy,

      body: SafeArea(
        top: false,

        child: SingleChildScrollView(
          physics:
          const BouncingScrollPhysics(),

          child: Column(
            children: [
              // ===================================================
              // PROFILE HERO
              // ===================================================

              Container(
                width: double.infinity,

                decoration:
                const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      profileNavy,
                      profileLightNavy,
                    ],
                    begin:
                    Alignment.topLeft,
                    end:
                    Alignment.bottomRight,
                  ),
                  borderRadius:
                  BorderRadius.vertical(
                    bottom:
                    Radius.circular(
                      36,
                    ),
                  ),
                ),

                child: Stack(
                  children: [
                    // ------------------------------------------------
                    // DECORATIVE CIRCLES
                    // ------------------------------------------------

                    Positioned(
                      top: -55,
                      right: -40,
                      child:
                      _GlowCircle(
                        size: 160,
                        color: profileBlue
                            .withOpacity(
                          0.10,
                        ),
                      ),
                    ),

                    Positioned(
                      top: 90,
                      left: -55,
                      child:
                      _GlowCircle(
                        size: 115,
                        color: profilePurple
                            .withOpacity(
                          0.07,
                        ),
                      ),
                    ),

                    Positioned(
                      top: 45,
                      right: 70,
                      child:
                      _GlowCircle(
                        size: 48,
                        color: Colors
                            .white
                            .withOpacity(
                          0.04,
                        ),
                      ),
                    ),

                    // ------------------------------------------------
                    // CONTENT
                    // ------------------------------------------------

                    Padding(
                      padding:
                      EdgeInsets.fromLTRB(
                        24,
                        MediaQuery.of(
                          context,
                        ).padding.top +
                            38,
                        24,
                        56,
                      ),

                      child: Column(
                        children: [
                          // =========================================
                          // AVATAR
                          // =========================================

                          Container(
                            padding:
                            const EdgeInsets.all(
                              3,
                            ),

                            decoration:
                            BoxDecoration(
                              shape:
                              BoxShape.circle,

                              gradient:
                              const LinearGradient(
                                colors: [
                                  profileBlue,
                                  profilePurple,
                                ],
                                begin:
                                Alignment.topLeft,
                                end:
                                Alignment.bottomRight,
                              ),

                              boxShadow: [
                                BoxShadow(
                                  color: Colors
                                      .black
                                      .withOpacity(
                                    0.18,
                                  ),
                                  blurRadius:
                                  22,
                                  offset:
                                  const Offset(
                                    0,
                                    9,
                                  ),
                                ),
                              ],
                            ),

                            child:
                            CircleAvatar(
                              radius: 45,

                              backgroundColor:
                              const Color(
                                0xFF17345F,
                              ),

                              child:
                              Text(
                                firstLetter,

                                style:
                                const TextStyle(
                                  color:
                                  Colors.white,
                                  fontSize:
                                  38,
                                  fontWeight:
                                  FontWeight.w800,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 20,
                          ),

                          // =========================================
                          // NAME
                          // =========================================

                          Text(
                            fullName,

                            textAlign:
                            TextAlign.center,

                            maxLines:
                            2,

                            overflow:
                            TextOverflow.ellipsis,

                            style:
                            const TextStyle(
                              color:
                              Colors.white,
                              fontSize:
                              25,
                              height:
                              1.15,
                              fontWeight:
                              FontWeight.w800,
                            ),
                          ),

                          const SizedBox(
                            height: 11,
                          ),

                          // =========================================
                          // ROLE BADGE
                          // =========================================

                          Container(
                            padding:
                            const EdgeInsets
                                .symmetric(
                              horizontal:
                              14,
                              vertical: 7,
                            ),

                            decoration:
                            BoxDecoration(
                              color:
                              Colors.white
                                  .withOpacity(
                                0.10,
                              ),

                              borderRadius:
                              BorderRadius
                                  .circular(
                                20,
                              ),

                              border:
                              Border.all(
                                color:
                                Colors.white
                                    .withOpacity(
                                  0.16,
                                ),
                              ),
                            ),

                            child:
                            Row(
                              mainAxisSize:
                              MainAxisSize
                                  .min,

                              children: [
                                Container(
                                  width:
                                  7,
                                  height:
                                  7,

                                  decoration:
                                  const BoxDecoration(
                                    color:
                                    Color(
                                      0xFF65D6A0,
                                    ),
                                    shape:
                                    BoxShape.circle,
                                  ),
                                ),

                                const SizedBox(
                                  width: 7,
                                ),

                                Text(
                                  role
                                      .toUpperCase(),

                                  style:
                                  const TextStyle(
                                    color:
                                    Colors.white,
                                    fontSize:
                                    11,
                                    fontWeight:
                                    FontWeight.w700,
                                    letterSpacing:
                                    1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          // =========================================
                          // TRACE ACCOUNT
                          // =========================================

                          Text(
                            'TRACE Account',

                            style:
                            TextStyle(
                              color: Colors
                                  .white
                                  .withOpacity(
                                0.40,
                              ),
                              fontSize:
                              10.5,
                              fontWeight:
                              FontWeight.w500,
                              letterSpacing:
                              0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ===================================================
              // MAIN CONTENT
              // ===================================================

              Transform.translate(
                offset:
                const Offset(
                  0,
                  -22,
                ),

                child: Padding(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 18,
                  ),

                  child: Column(
                    children: [
                      // ==========================================
                      // ACCOUNT CARD
                      // ==========================================

                      Container(
                        width:
                        double.infinity,

                        padding:
                        const EdgeInsets
                            .all(
                          18,
                        ),

                        decoration:
                        BoxDecoration(
                          color:
                          profileCardBg,

                          borderRadius:
                          BorderRadius.circular(
                            20,
                          ),

                          border:
                          Border.all(
                            color:
                            profileCardBorder,
                          ),

                          boxShadow: [
                            BoxShadow(
                              color: Colors
                                  .black
                                  .withOpacity(
                                0.07,
                              ),
                              blurRadius:
                              22,
                              offset:
                              const Offset(
                                0,
                                8,
                              ),
                            ),
                          ],
                        ),

                        child:
                        Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                          children: [
                            // --------------------------------------
                            // TITLE
                            // --------------------------------------

                            Row(
                              children: [
                                Container(
                                  width:
                                  40,
                                  height:
                                  40,

                                  decoration:
                                  BoxDecoration(
                                    color:
                                    profileBlue
                                        .withOpacity(
                                      0.10,
                                    ),
                                    borderRadius:
                                    BorderRadius
                                        .circular(
                                      12,
                                    ),
                                  ),

                                  child:
                                  const Icon(
                                    Icons
                                        .person_outline_rounded,
                                    color:
                                    profileBlue,
                                    size:
                                    21,
                                  ),
                                ),

                                const SizedBox(
                                  width:
                                  11,
                                ),

                                const Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,

                                  children: [
                                    Text(
                                      'Account',
                                      style:
                                      TextStyle(
                                        color:
                                        profileTextPrimary,
                                        fontSize:
                                        14,
                                        fontWeight:
                                        FontWeight.w800,
                                      ),
                                    ),

                                    SizedBox(
                                      height:
                                      2,
                                    ),

                                    Text(
                                      'Your TRACE profile',
                                      style:
                                      TextStyle(
                                        color:
                                        profileTextSecondary,
                                        fontSize:
                                        11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(
                              height:
                              16,
                            ),

                            // --------------------------------------
                            // DIVIDER
                            // --------------------------------------

                            Container(
                              height:
                              1,
                              color:
                              profileCardBorder,
                            ),

                            // --------------------------------------
                            // PROFILE ROWS
                            // --------------------------------------

                            const SizedBox(
                              height:
                              4,
                            ),

                            _ProfileRow(
                              icon: Icons
                                  .badge_outlined,
                              label:
                              'Name',
                              value:
                              fullName,
                            ),

                            _ProfileRow(
                              icon: Icons
                                  .verified_user_outlined,
                              label:
                              'Role',
                              value:
                              role,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height:
                        14,
                      ),

                      // ==========================================
                      // LOGOUT CARD
                      // ==========================================

                      Container(
                        width:
                        double.infinity,

                        decoration:
                        BoxDecoration(
                          color:
                          profileCardBg,

                          borderRadius:
                          BorderRadius.circular(
                            20,
                          ),

                          border:
                          Border.all(
                            color:
                            profileCardBorder,
                          ),

                          boxShadow: [
                            BoxShadow(
                              color: Colors
                                  .black
                                  .withOpacity(
                                0.05,
                              ),
                              blurRadius:
                              18,
                              offset:
                              const Offset(
                                0,
                                6,
                              ),
                            ),
                          ],
                        ),

                        child:
                        Material(
                          color:
                          Colors.transparent,

                          child:
                          InkWell(
                            borderRadius:
                            BorderRadius
                                .circular(
                              20,
                            ),

                            onTap: () =>
                                _confirmLogout(
                                  context,
                                ),

                            child:
                            Padding(
                              padding:
                              const EdgeInsets
                                  .all(
                                16,
                              ),

                              child:
                              Row(
                                children: [
                                  // ==================================
                                  // ICON
                                  // ==================================

                                  Container(
                                    width:
                                    46,
                                    height:
                                    46,

                                    decoration:
                                    BoxDecoration(
                                      color:
                                      profileLogoutRed
                                          .withOpacity(
                                        0.09,
                                      ),
                                      borderRadius:
                                      BorderRadius
                                          .circular(
                                        13,
                                      ),
                                    ),

                                    child:
                                    const Icon(
                                      Icons
                                          .logout_rounded,
                                      color:
                                      profileLogoutRed,
                                      size:
                                      22,
                                    ),
                                  ),

                                  const SizedBox(
                                    width:
                                    14,
                                  ),

                                  // ==================================
                                  // TEXT
                                  // ==================================

                                  const Expanded(
                                    child:
                                    Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,

                                      children: [
                                        Text(
                                          'Logout',
                                          style:
                                          TextStyle(
                                            color:
                                            profileTextPrimary,
                                            fontSize:
                                            15,
                                            fontWeight:
                                            FontWeight.w800,
                                          ),
                                        ),

                                        SizedBox(
                                          height:
                                          3,
                                        ),

                                        Text(
                                          'Sign out of your TRACE account',
                                          style:
                                          TextStyle(
                                            color:
                                            profileTextSecondary,
                                            fontSize:
                                            11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ==================================
                                  // ARROW
                                  // ==================================

                                  Container(
                                    width:
                                    32,
                                    height:
                                    32,

                                    decoration:
                                    BoxDecoration(
                                      color:
                                      const Color(
                                        0xFFF6F7F9,
                                      ),

                                      borderRadius:
                                      BorderRadius
                                          .circular(
                                        10,
                                      ),
                                    ),

                                    child:
                                    const Icon(
                                      Icons
                                          .arrow_forward_ios_rounded,
                                      color:
                                      profileTextSecondary,
                                      size:
                                      13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height:
                        18,
                      ),

                      // ==========================================
                      // FOOTER
                      // ==========================================

                      Text(
                        'TRACE • Attendance System',

                        style:
                        TextStyle(
                          color: Colors
                              .white
                              .withOpacity(
                            0.38,
                          ),
                          fontSize:
                          10.5,
                          fontWeight:
                          FontWeight.w500,
                          letterSpacing:
                          0.4,
                        ),
                      ),

                      const SizedBox(
                        height:
                        14,
                      ),
                    ],
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

// ================================================================
// PROFILE ROW
// ================================================================

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 10,
      ),

      child:
      Row(
        crossAxisAlignment:
        CrossAxisAlignment.center,

        children: [
          // --------------------------------------------------------
          // ICON
          // --------------------------------------------------------

          Container(
            width:
            34,
            height:
            34,

            decoration:
            BoxDecoration(
              color:
              const Color(
                0xFFF5F7FA,
              ),

              borderRadius:
              BorderRadius.circular(
                10,
              ),
            ),

            child:
            Icon(
              icon,
              color:
              Colors.blueGrey
                  .shade500,
              size:
              17,
            ),
          ),

          const SizedBox(
            width:
            11,
          ),

          // --------------------------------------------------------
          // LABEL
          // --------------------------------------------------------

          SizedBox(
            width:
            54,

            child:
            Text(
              label,

              style:
              const TextStyle(
                color:
                profileTextSecondary,
                fontSize:
                11,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(
            width:
            10,
          ),

          // --------------------------------------------------------
          // VALUE
          // --------------------------------------------------------

          Expanded(
            child:
            Text(
              value,

              textAlign:
              TextAlign.right,

              maxLines:
              2,

              overflow:
              TextOverflow.ellipsis,

              style:
              const TextStyle(
                color:
                profileTextPrimary,
                fontSize:
                12.5,
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// GLOW CIRCLE
// ================================================================

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      width:
      size,
      height:
      size,

      decoration:
      BoxDecoration(
        shape:
        BoxShape.circle,
        color:
        color,
      ),
    );
  }
}