import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import 'super_admin_common.dart';

class SuperAdminSettingsScreen
    extends StatefulWidget {
  const SuperAdminSettingsScreen({
    super.key,
  });

  @override
  State<SuperAdminSettingsScreen> createState() =>
      _SuperAdminSettingsScreenState();
}

class _SuperAdminSettingsScreenState
    extends State<
        SuperAdminSettingsScreen> {
  final _nameController =
  TextEditingController();

  bool _loading = true;
  bool _saving = false;

  String _email = '';
  String _role = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final doc =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data =
          doc.data() ?? {};

      _nameController.text =
          SuperAdminCommon.text(
            data,
            ['fullName'],
          );

      _email =
          user.email ??
              SuperAdminCommon.text(
                data,
                ['email'],
              );

      _role =
          SuperAdminCommon.text(
            data,
            ['role'],
            fallback: 'superadmin',
          );
    } catch (_) {
      // Keep the page usable with the
      // local Auth user information.
    }

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  Future<void> _save() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final name =
    _nameController.text.trim();

    if (name.isEmpty) {
      SuperAdminCommon.snack(
        context,
        'Name cannot be empty.',
        error: true,
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fullName': name,
        'updatedAt':
        FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      SuperAdminCommon.snack(
        context,
        'Profile updated successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      SuperAdminCommon.snack(
        context,
        'Unable to update profile.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _changePassword() async {
    final email =
        FirebaseAuth.instance
            .currentUser
            ?.email;

    if (email == null ||
        email.isEmpty) {
      return;
    }

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      SuperAdminCommon.snack(
        context,
        'Password reset email sent to $email.',
      );
    } catch (e) {
      if (!mounted) return;

      SuperAdminCommon.snack(
        context,
        'Unable to send password reset email.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser =
        FirebaseAuth.instance.currentUser;

    final provider =
    context.watch<UserProvider>();

    final fallbackName =
    provider.userData != null
        ? SuperAdminCommon.text(
      provider.userData!,
      ['fullName'],
    )
        : '';

    if (_loading &&
        _nameController.text.isEmpty) {
      return Scaffold(
        backgroundColor: TraceColors.canvas,
        body: SuperAdminCommon.loading(),
      );
    }

    return Scaffold(
      backgroundColor: TraceColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                SuperAdminCommon.pageHeader(
                  title: 'Settings',
                  subtitle:
                  'Manage your Super Admin profile and account security.',
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 800) {
                      return Column(
                        children: [
                          _profile(
                            authUser,
                            fallbackName,
                          ),
                          const SizedBox(height: 16),
                          _security(),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _profile(
                            authUser,
                            fallbackName,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: _security(),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profile(
      User? authUser,
      String fallbackName,
      ) {
    final currentName =
    _nameController.text.isNotEmpty
        ? _nameController.text
        : fallbackName;

    final displayEmail = _email.isNotEmpty
        ? _email
        : authUser?.email ?? '';

    final initial = currentName.isNotEmpty
        ? currentName.trim()[0].toUpperCase()
        : 'S';

    return SuperAdminCommon.section(
      title: 'Profile',
      subtitle: 'Your Super Admin account details.',
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: TraceColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: TraceColors.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentName.isNotEmpty
                          ? currentName
                          : 'Super Admin',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: TraceColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      displayEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: TraceColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SuperAdminCommon.groupLabel('Account details'),
          TextField(
            controller: _nameController,
            decoration: SuperAdminCommon.inputDecoration(
              label: 'Full Name',
              icon: Icons.badge_outlined,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            readOnly: true,
            controller: TextEditingController(
              text: displayEmail,
            ),
            decoration: SuperAdminCommon.inputDecoration(
              label: 'Email',
              icon: Icons.mail_outline_rounded,
              readOnly: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            readOnly: true,
            controller: TextEditingController(
              text: _role.isNotEmpty
                  ? _role
                  : 'superadmin',
            ),
            decoration: SuperAdminCommon.inputDecoration(
              label: 'Role',
              icon: Icons.verified_user_outlined,
              readOnly: true,
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              style: SuperAdminCommon.primaryButtonStyle(),
              icon: _saving
                  ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(
                Icons.check_rounded,
                size: 17,
              ),
              label: Text(
                _saving ? 'Saving…' : 'Save Changes',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _security() {
    return SuperAdminCommon.section(
      title: 'Security',
      subtitle: 'Manage account access and protection.',
      child: Column(
        children: [
          _securityRow(
            icon: Icons.lock_reset_rounded,
            iconColor: TraceColors.textSecondary,
            title: 'Reset Password',
            subtitle:
            'Send a password reset email to your account.',
            trailing: TextButton(
              onPressed: _changePassword,
              style: TextButton.styleFrom(
                foregroundColor: TraceColors.ink,
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Reset'),
            ),
          ),
          const SizedBox(height: 4),
          SuperAdminCommon.divider(),
          const SizedBox(height: 4),
          _securityRow(
            icon: Icons.verified_rounded,
            iconColor: TraceColors.accent,
            iconBackground: TraceColors.accentSoft,
            title: 'Protected Account',
            subtitle:
            'This is the system Super Admin account.',
            trailing: const Text(
              'Protected',
              style: TextStyle(
                color: TraceColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _securityRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    Color? iconBackground,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBackground ?? TraceColors.canvas,
              borderRadius:
              BorderRadius.circular(TraceRadius.sm),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: TraceColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: TraceColors.textTertiary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}