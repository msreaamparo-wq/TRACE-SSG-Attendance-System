import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------
/// Design tokens
///
/// This is the single source of truth for color, spacing and radius
/// across the Super Admin module. Other Super Admin screens that
/// haven't been redesigned yet still reference the legacy names
/// (background, white, mutedWhite, darkText, gold) below, so those
/// are kept as aliases pointing at the refreshed palette — nothing
/// downstream breaks, it just inherits the new look for free.
/// ---------------------------------------------------------------------
class TraceColors {
  TraceColors._();

  // Core neutrals
  static const Color ink = Color(0xFF10131C);
  static const Color inkMuted = Color(0xFF9AA3B2);
  static const Color canvas = Color(0xFFF5F6FA);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE8E9F1);
  static const Color borderStrong = Color(0xFFD9DBE5);

  // Text
  static const Color textPrimary = Color(0xFF12141C);
  static const Color textSecondary = Color(0xFF6B7180);
  static const Color textTertiary = Color(0xFF9BA0AD);

  // Accent
  static const Color accent = Color(0xFFC7972E);
  static const Color accentSoft = Color(0xFFF8F0DE);

  // Semantic
  static const Color success = Color(0xFF15803D);
  static const Color successSoft = Color(0xFFE7F5EC);
  static const Color warning = Color(0xFFB45309);
  static const Color warningSoft = Color(0xFFFBF0DF);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFCE9E9);

  // Legacy aliases
  static const Color background = ink;
  static const Color white = Colors.white;
  static const Color mutedWhite = inkMuted;
  static const Color darkText = textPrimary;
  static const Color gold = accent;
}

class TraceRadius {
  TraceRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double pill = 999;
}

class TraceSpacing {
  TraceSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class SuperAdminCommon {
  SuperAdminCommon._();

  static final FirebaseFirestore db =
      FirebaseFirestore.instance;

  // -------------------------------------------------------------
  // Data helpers
  // -------------------------------------------------------------

  static String text(
      Map<String, dynamic> data,
      List<String> keys, {
        String fallback = '',
      }) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      final result = value.toString().trim();

      if (result.isNotEmpty) {
        return result;
      }
    }

    return fallback;
  }

  static DateTime? date(
      Map<String, dynamic> data,
      List<String> keys,
      ) {
    for (final key in keys) {
      final value = data[key];

      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is DateTime) {
        return value;
      }

      if (value is String) {
        final parsed = DateTime.tryParse(value);

        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
  }

  static String status(
      Map<String, dynamic> data,
      ) {
    final value = text(
      data,
      [
        'status',
        'attendanceStatus',
        'attendance_status',
      ],
    ).toLowerCase();

    if (value.contains('present')) {
      return 'Present';
    }

    if (value.contains('late')) {
      return 'Late';
    }

    if (value.contains('absent')) {
      return 'Absent';
    }

    if (value.isEmpty) {
      return 'Unknown';
    }

    return value;
  }

  static String formatDate(
      DateTime? date,
      ) {
    if (date == null) return '—';

    return '${_month(date.month)} ${date.day}, ${date.year}';
  }

  static String formatTime(
      DateTime? date,
      ) {
    if (date == null) return '—';

    final hour = date.hour > 12
        ? date.hour - 12
        : date.hour;

    final displayHour = hour == 0 ? 12 : hour;

    final minute = date.minute
        .toString()
        .padLeft(2, '0');

    final suffix = date.hour >= 12 ? 'PM' : 'AM';

    return '$displayHour:$minute $suffix';
  }

  static String _month(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return months[month];
  }

  static Color statusColor(
      String status,
      ) {
    switch (status.toLowerCase()) {
      case 'present':
        return TraceColors.success;

      case 'late':
        return TraceColors.warning;

      case 'absent':
        return TraceColors.danger;

      default:
        return TraceColors.textTertiary;
    }
  }

  // -------------------------------------------------------------
  // Feedback
  // -------------------------------------------------------------

  static void snack(
      BuildContext context,
      String message, {
        bool error = false,
      }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: error
              ? TraceColors.danger
              : TraceColors.ink,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              TraceRadius.sm,
            ),
          ),
          elevation: 0,
        ),
      );
  }

  // -------------------------------------------------------------
  // States
  // -------------------------------------------------------------

  static Widget loading() {
    return const Center(
      child: SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(
          color: TraceColors.accent,
          strokeWidth: 2.4,
        ),
      ),
    );
  }

  static Widget empty(
      String message, {
        IconData icon = Icons.inbox_outlined,
      }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: TraceColors.canvas,
              shape: BoxShape.circle,
              border: Border.all(
                color: TraceColors.border,
              ),
            ),
            child: Icon(
              icon,
              size: 24,
              color: TraceColors.textTertiary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: TraceColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Layout primitives
  // -------------------------------------------------------------

  /// Page-level title + subtitle, with an optional trailing action.
  /// Used at the top of every Super Admin screen.
  static Widget pageHeader({
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: TraceColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: TraceColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 16),
          action,
        ],
      ],
    );
  }

  /// A neutral card surface. Every content block on a Super Admin
  /// screen should live inside one of these for visual consistency.
  static Widget section({
    required String title,
    String? subtitle,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(22),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: TraceColors.surface,
        borderRadius: BorderRadius.circular(
          TraceRadius.lg,
        ),
        border: Border.all(
          color: TraceColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: TraceColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                color: TraceColors.textTertiary,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  /// Small uppercase eyebrow label, used to group related fields or
  /// rows within a section without adding another full card.
  static Widget groupLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: TraceColors.textTertiary,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  static Widget divider() {
    return const Divider(
      color: TraceColors.border,
      height: 1,
    );
  }

  /// Consistent text field styling shared by every Super Admin form.
  static InputDecoration inputDecoration({
    required String label,
    IconData? icon,
    bool readOnly = false,
  }) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: readOnly
          ? TraceColors.canvas
          : TraceColors.surface,
      prefixIcon: icon != null
          ? Icon(
        icon,
        size: 19,
        color: TraceColors.textTertiary,
      )
          : null,
      labelStyle: const TextStyle(
        color: TraceColors.textSecondary,
        fontSize: 13,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          TraceRadius.sm,
        ),
        borderSide: const BorderSide(
          color: TraceColors.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          TraceRadius.sm,
        ),
        borderSide: const BorderSide(
          color: TraceColors.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          TraceRadius.sm,
        ),
        borderSide: const BorderSide(
          color: TraceColors.accent,
          width: 1.4,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          TraceRadius.sm,
        ),
        borderSide: const BorderSide(
          color: TraceColors.border,
        ),
      ),
    );
  }

  static ButtonStyle primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: TraceColors.ink,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),
      textStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          TraceRadius.sm,
        ),
      ),
    );
  }

  static ButtonStyle outlinedButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: TraceColors.textPrimary,
      side: const BorderSide(
        color: TraceColors.border,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),
      textStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          TraceRadius.sm,
        ),
      ),
    );
  }
}

/// Compact metric card used across dashboard-style screens.
class SuperAdminStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const SuperAdminStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color = TraceColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TraceColors.surface,
        borderRadius: BorderRadius.circular(
          TraceRadius.md,
        ),
        border: Border.all(
          color: TraceColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(
                TraceRadius.sm,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TraceColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TraceColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small status pill (Present / Late / Absent / etc).
class SuperAdminStatusChip extends StatelessWidget {
  final String status;

  const SuperAdminStatusChip({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color = SuperAdminCommon.statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(
          TraceRadius.pill,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}