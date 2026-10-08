import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'scan_qr_screen.dart';
import '../../models/event_model.dart';
import '../../models/attendance_model.dart';
import '../../services/firestore_service.dart';
import '../../services/attendance_queue_service.dart';

// ================================================================
// SHARED COLORS + SMALL REUSABLE WIDGETS
// ================================================================

class AttendanceColors {
  AttendanceColors._();

  static const navy = Color(0xFF071936);
  static const navyLight = Color(0xFF11284F);
  static const bgNavy = Color(0xFF081B3A);
  static const accentBlue = Color(0xFF4A90E2);
  static const textPrimary = Color(0xFF172033);
  static const textSecondary = Color(0xFF6B7280);
  static const success = Color(0xFF20A96B);
  static const warning = Color(0xFFE8A33D);
  static const danger = Color(0xFFE0473C);
  static const surface = Color(0xFFF7F9FC);
  static const border = Color(0xFFE5E9F0);

  static const halfDay = Color(0xFFE8A33D);

  static const List<Color> pageGradient = [
    Color(0xFFE9F1FC),
    Color(0xFFDCE9FB),
  ];

  static const List<Color> heroGradient = [
    navy,
    navyLight,
  ];

  static const List<Color> buttonGradient = [
    navy,
    navyLight,
  ];

  static BoxShadow softShadow({
    double opacity = 0.06,
  }) {
    return BoxShadow(
      color: Colors.black.withValues(alpha: opacity),
      blurRadius: 18,
      offset: const Offset(0, 6),
    );
  }

  static Color forStatus(String status) {
    switch (status.toLowerCase()) {
      case AttendanceModel.statusPresent:
        return success;

      case AttendanceModel.statusHalfDay:
        return halfDay;

      default:
        return danger;
    }
  }

  static String labelForStatus(String status) {
    switch (status.toLowerCase()) {
      case AttendanceModel.statusPresent:
        return 'Present';

      case AttendanceModel.statusHalfDay:
        return 'Half Day';

      default:
        return 'Absent';
    }
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool solid;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: solid
            ? color
            : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: solid
            ? null
            : Border.all(
          color: color.withValues(alpha: 0.35),
        ),
        boxShadow: solid
            ? [
          AttendanceColors.softShadow(
            opacity: 0.18,
          ),
        ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: solid ? Colors.white : color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: solid ? Colors.white : color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingSyncBadge extends StatelessWidget {
  const _PendingSyncBadge();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: AttendanceQueueService
          .instance
          .pendingCountStream,
      initialData: AttendanceQueueService
          .instance
          .pendingCount,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        if (count <= 0) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(
            right: 10,
          ),
          child: GestureDetector(
            onTap: () =>
                AttendanceQueueService
                    .instance
                    .syncPending(),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AttendanceColors.warning
                    .withValues(alpha: 0.18),
                borderRadius:
                BorderRadius.circular(20),
                border: Border.all(
                  color: AttendanceColors.warning
                      .withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 14,
                    color: AttendanceColors.warning,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$count pending',
                    style: const TextStyle(
                      color: AttendanceColors.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$value $label',
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 4,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AttendanceColors.border,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.15),
                      color.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 16,
                ),
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(
                  milliseconds: 300,
                ),
                transitionBuilder:
                    (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: Text(
                  value,
                  key: ValueKey(value),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AttendanceColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScheduleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const ScheduleRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: 0.15),
                accent.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            size: 18,
            color: accent,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AttendanceColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AttendanceColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AttendanceColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AttendanceColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 4,
      margin: const EdgeInsets.only(
        bottom: 18,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _DialogShell extends StatelessWidget {
  final Widget child;

  const _DialogShell({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 28,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _IconBadge({
    required this.icon,
    required this.color,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: size * 0.46,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            onPressed();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AttendanceColors.navy,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// ATTENDANCE-TAKING FLOW
// ================================================================

enum AttendanceMethod {
  scan,
  manualId,
}

Future<void> startAttendanceFlow(
    BuildContext context,
    EventModel event,
    ) async {
  final session = await _pickSession(
    context,
    event,
  );

  if (session == null || !context.mounted) {
    return;
  }

  if (!event.isSessionOpen(session)) {
    await _showBlockedDialog(
      context,
      event,
      session,
    );
    return;
  }

  final method = await _pickMethod(
    context,
    session,
  );

  if (method == null || !context.mounted) {
    return;
  }

  String? studentId;

  if (method == AttendanceMethod.scan) {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ScanQRScreen(),
      ),
    );

    studentId = result?.toString().trim();
  } else {
    studentId = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
      const EnterStudentIdDialog(),
    );
  }

  if (studentId == null ||
      studentId.trim().isEmpty ||
      !context.mounted) {
    return;
  }

  await _processAttendance(
    context,
    event,
    session,
    studentId.trim(),
  );
}

// ================================================================
// STEP 1 — PICK SESSION
// ================================================================

Future<AttendanceSession?> _pickSession(
    BuildContext context,
    EventModel event,
    ) {
  return showModalBottomSheet<AttendanceSession>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(26),
      ),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            14,
            20,
            26,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Center(
                child: SheetHandle(),
              ),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AttendanceColors.accentBlue
                              .withValues(alpha: 0.15),
                          AttendanceColors.accentBlue
                              .withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius:
                      BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.fact_check_rounded,
                      color:
                      AttendanceColors.accentBlue,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Start Attendance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color:
                        AttendanceColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose which checkpoint you\'re recording.',
                style: TextStyle(
                  fontSize: 13,
                  color:
                  AttendanceColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              _SessionOption(
                event: event,
                session: AttendanceSession.timeIn,
                sheetContext: sheetContext,
              ),
              const SizedBox(height: 12),
              _SessionOption(
                event: event,
                session: AttendanceSession.timeOut,
                sheetContext: sheetContext,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SessionOption extends StatelessWidget {
  final EventModel event;
  final AttendanceSession session;
  final BuildContext sheetContext;

  const _SessionOption({
    required this.event,
    required this.session,
    required this.sheetContext,
  });

  @override
  Widget build(BuildContext context) {
    final isOpen = event.isSessionOpen(session);
    final notStarted =
    event.hasSessionNotStarted(session);

    late final String statusText;
    late final Color statusColor;

    if (!event.hasSessionWindow(session)) {
      statusText = 'No schedule set';
      statusColor =
          AttendanceColors.textSecondary;
    } else if (isOpen) {
      statusText = 'Open now';
      statusColor = AttendanceColors.success;
    } else if (notStarted) {
      statusText =
      'Opens at ${event.sessionStartLabel(session)}';
      statusColor = AttendanceColors.warning;
    } else {
      statusText = 'Closed';
      statusColor = AttendanceColors.danger;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(sheetContext).pop(session);
        },
        child: Semantics(
          button: true,
          label: '${session.fullLabel}, $statusText',
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isOpen
                  ? AttendanceColors.accentBlue
                  .withValues(alpha: 0.06)
                  : AttendanceColors.surface,
              borderRadius:
              BorderRadius.circular(18),
              border: Border.all(
                color: isOpen
                    ? AttendanceColors.accentBlue
                    .withValues(alpha: 0.4)
                    : AttendanceColors.border,
                width: isOpen ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient:
                    const LinearGradient(
                      colors:
                      AttendanceColors.heroGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                    BorderRadius.circular(13),
                  ),
                  child: Icon(
                    session.icon,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.fullLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight:
                          FontWeight.w800,
                          color:
                          AttendanceColors
                              .textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        event.sessionWindowLabel(
                          session,
                        ),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color:
                          AttendanceColors
                              .textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor
                        .withValues(alpha: 0.14),
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// STEP 2 — PICK METHOD
// ================================================================

Future<AttendanceMethod?> _pickMethod(
    BuildContext context,
    AttendanceSession session,
    ) {
  return showModalBottomSheet<AttendanceMethod>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(26),
      ),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            14,
            20,
            26,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Center(
                child: SheetHandle(),
              ),
              const Text(
                'Choose Attendance Method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AttendanceColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Recording ${session.fullLabel.toLowerCase()}',
                style: const TextStyle(
                  fontSize: 13,
                  color:
                  AttendanceColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              _MethodOption(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Scan QR Code',
                subtitle:
                'Fastest way to check a student in',
                highlighted: true,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(sheetContext).pop(
                    AttendanceMethod.scan,
                  );
                },
              ),
              const SizedBox(height: 12),
              _MethodOption(
                icon: Icons.badge_outlined,
                title: 'Enter ID Number',
                subtitle:
                'Type the student ID manually',
                highlighted: false,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(sheetContext).pop(
                    AttendanceMethod.manualId,
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _MethodOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlighted;
  final VoidCallback onTap;

  const _MethodOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: highlighted
                ? const LinearGradient(
              colors:
              AttendanceColors.heroGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : null,
            color: highlighted ? null : Colors.white,
            borderRadius:
            BorderRadius.circular(18),
            border: Border.all(
              color: highlighted
                  ? Colors.transparent
                  : AttendanceColors.border,
              width: 1.4,
            ),
            boxShadow: highlighted
                ? [
              AttendanceColors.softShadow(
                opacity: 0.15,
              ),
            ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: highlighted
                      ? Colors.white
                      .withValues(alpha: 0.14)
                      : AttendanceColors.accentBlue
                      .withValues(alpha: 0.12),
                  borderRadius:
                  BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: highlighted
                      ? Colors.white
                      : AttendanceColors.accentBlue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: highlighted
                            ? Colors.white
                            : AttendanceColors
                            .textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: highlighted
                            ? Colors.white
                            .withValues(alpha: 0.72)
                            : AttendanceColors
                            .textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: highlighted
                    ? Colors.white70
                    : AttendanceColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// LOCATION VERIFICATION — BISU CANDIJAY CAMPUS
// ================================================================

class _CampusPoint {
  final double latitude;
  final double longitude;

  const _CampusPoint(
      this.latitude,
      this.longitude,
      );
}

const List<_CampusPoint> _bisuCampusBoundary = [
  _CampusPoint(
    9.835566447396426,
    124.5287464454387,
  ),
  _CampusPoint(
    9.834304116669841,
    124.529710122783,
  ),
  _CampusPoint(
    9.835514731606484,
    124.5314254747796,
  ),
  _CampusPoint(
    9.835848090958301,
    124.5316678768501,
  ),
  _CampusPoint(
    9.836421686477973,
    124.5311400580185,
  ),
  _CampusPoint(
    9.836531855944516,
    124.530902138374,
  ),
  _CampusPoint(
    9.836044312413289,
    124.53010168822,
  ),
  _CampusPoint(
    9.835793041525093,
    124.5297432108856,
  ),
  _CampusPoint(
    9.836130325276699,
    124.5293618494416,
  ),
];

class LocationVerificationResult {
  final bool verified;
  final double latitude;
  final double longitude;
  final double accuracy;

  const LocationVerificationResult({
    required this.verified,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });
}

bool _isPointInsideCampus(
    double latitude,
    double longitude,
    ) {
  bool inside = false;

  final points = _bisuCampusBoundary;

  if (points.length < 3) {
    return false;
  }

  int j = points.length - 1;

  for (int i = 0; i < points.length; i++) {
    final current = points[i];
    final previous = points[j];

    final currentLat = current.latitude;
    final currentLng = current.longitude;

    final previousLat = previous.latitude;
    final previousLng = previous.longitude;

    final intersects =
        ((currentLat > latitude) !=
            (previousLat > latitude)) &&
            (longitude <
                (previousLng - currentLng) *
                    (latitude - currentLat) /
                    (previousLat - currentLat) +
                    currentLng);

    if (intersects) {
      inside = !inside;
    }

    j = i;
  }

  return inside;
}

Future<LocationVerificationResult?>
_verifyCampusLocation(
    BuildContext context,
    ) async {
  try {
    final serviceEnabled =
    await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (!context.mounted) {
        return null;
      }

      await _showMessageDialog(
        context,
        icon: Icons.location_off_rounded,
        iconColor: AttendanceColors.danger,
        title: 'Location Is Off',
        message:
        'Please turn on Location/GPS on this device before recording attendance.',
      );

      return null;
    }

    var permission =
    await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
      await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (!context.mounted) {
        return null;
      }

      await _showMessageDialog(
        context,
        icon: Icons.location_disabled_rounded,
        iconColor: AttendanceColors.danger,
        title: 'Location Permission Required',
        message:
        'TRACE needs location permission to verify that attendance is being recorded inside BISU Candijay Campus.',
      );

      return null;
    }

    if (permission ==
        LocationPermission.deniedForever) {
      if (!context.mounted) {
        return null;
      }

      await _showMessageDialog(
        context,
        icon: Icons.location_disabled_rounded,
        iconColor: AttendanceColors.danger,
        title: 'Location Permission Blocked',
        message:
        'Location permission is permanently denied. Please enable it in the device Settings before recording attendance.',
      );

      return null;
    }

    final position =
    await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    final insideCampus =
    _isPointInsideCampus(
      position.latitude,
      position.longitude,
    );

    if (!insideCampus) {
      if (!context.mounted) {
        return null;
      }

      await _showMessageDialog(
        context,
        icon: Icons.location_off_rounded,
        iconColor: AttendanceColors.danger,
        title: 'Outside Campus',
        message:
        'Attendance cannot be recorded because the SSG device is outside the mapped BISU Candijay Campus boundary.',
      );

      return null;
    }

    return LocationVerificationResult(
      verified: true,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
    );
  } catch (_) {
    if (!context.mounted) {
      return null;
    }

    await _showMessageDialog(
      context,
      icon: Icons.location_off_rounded,
      iconColor: AttendanceColors.danger,
      title: 'Location Verification Failed',
      message:
      'TRACE could not verify the device location. Please make sure GPS is enabled and try again.',
    );

    return null;
  }
}

// ================================================================
// STEP 3 — PROCESS ATTENDANCE
// ================================================================

Future<void> _processAttendance(
    BuildContext context,
    EventModel event,
    AttendanceSession session,
    String studentId,
    ) async {
  _showLoadingDialog(
    context,
    message: 'Looking up student…',
  );

  try {
    final studentRecord =
    await FirestoreService.instance
        .getStudentRecordById(
      studentId,
    );

    if (!context.mounted) {
      return;
    }

    Navigator.of(
      context,
      rootNavigator: true,
    ).pop();

    if (studentRecord == null) {
      await _showMessageDialog(
        context,
        icon: Icons.person_off_rounded,
        iconColor: AttendanceColors.danger,
        title: 'Student Not Found',
        message:
        'No student record matches ID "$studentId".\n\n'
            'Make sure this student has already been cached on this SSG device.',
      );

      return;
    }

    final info =
    FirestoreService.instance
        .extractStudentDisplayInfo(
      studentRecord.data,
    );

    if ((info['fullName'] ?? '')
        .trim()
        .isEmpty) {
      await _showMessageDialog(
        context,
        icon: Icons.error_outline_rounded,
        iconColor: AttendanceColors.danger,
        title: 'Incomplete Record',
        message:
        'This student\'s name is missing in the database.',
      );

      return;
    }

    if (!context.mounted) {
      return;
    }

    if (session == AttendanceSession.timeIn) {
      await _handleTimeIn(
        context,
        event,
        studentRecord.id,
        studentId,
        info,
      );
    } else {
      await _handleTimeOut(
        context,
        event,
        studentRecord.id,
        studentId,
        info,
      );
    }
  } catch (e) {
    if (!context.mounted) {
      return;
    }

    if (Navigator.of(
      context,
      rootNavigator: true,
    ).canPop()) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop();
    }

    final already =
    e.toString().contains(
      'already marked Present',
    );

    await _showMessageDialog(
      context,
      icon: Icons.error_outline_rounded,
      iconColor: AttendanceColors.warning,
      title: already
          ? 'Already Recorded'
          : 'Something Went Wrong',
      message: already
          ? 'This student is already marked Present for this event.'
          : e.toString().replaceFirst(
        'Exception: ',
        '',
      ),
    );
  }
}

// ================================================================
// TIME IN
// ================================================================

Future<void> _handleTimeIn(
    BuildContext context,
    EventModel event,
    String userId,
    String studentId,
    Map<String, String> info,
    ) async {
  if (event.hasSessionEnded(
    AttendanceSession.timeIn,
  )) {
    await _showBlockedDialog(
      context,
      event,
      AttendanceSession.timeIn,
    );

    return;
  }

  final location =
  await _verifyCampusLocation(
    context,
  );

  if (location == null || !context.mounted) {
    return;
  }

  _showLoadingDialog(
    context,
    message: 'Recording time in…',
  );

  try {
    final result =
    await FirestoreService.instance.recordTimeIn(
      eventId: event.id,
      userId: userId,
      studentId: studentId,
      timeInStatus: 'on-time',
      latitude: location.latitude,
      longitude: location.longitude,
      locationVerified: location.verified,
      locationAccuracy: location.accuracy,
    );

    if (!context.mounted) {
      return;
    }

    Navigator.of(
      context,
      rootNavigator: true,
    ).pop();

    await _showSuccessDialog(
      context,
      event: event,
      session: AttendanceSession.timeIn,
      studentId: studentId,
      info: info,
      isOffline:
      result == AttendanceWriteResult.queued,
    );
  } catch (e) {
    if (!context.mounted) {
      return;
    }

    if (Navigator.of(
      context,
      rootNavigator: true,
    ).canPop()) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop();
    }

    final already =
    e.toString().contains(
      'already marked Present',
    );

    await _showMessageDialog(
      context,
      icon: Icons.error_outline_rounded,
      iconColor: AttendanceColors.warning,
      title: already
          ? 'Already Recorded'
          : 'Something Went Wrong',
      message: already
          ? 'This student is already marked Present for this event.'
          : e.toString().replaceFirst(
        'Exception: ',
        '',
      ),
    );
  }
}

// ================================================================
// TIME OUT
// ================================================================

Future<void> _handleTimeOut(
    BuildContext context,
    EventModel event,
    String userId,
    String studentId,
    Map<String, String> info,
    ) async {
  _showLoadingDialog(
    context,
    message: 'Checking existing record…',
  );

  final lookup =
  await FirestoreService.instance
      .findTimeOutCandidate(
    eventId: event.id,
    studentId: studentId,
  );

  if (!context.mounted) {
    return;
  }

  Navigator.of(
    context,
    rootNavigator: true,
  ).pop();

  if (lookup.status ==
      TimeOutLookupStatus.alreadyDone) {
    await _showMessageDialog(
      context,
      icon: Icons.check_circle_outline_rounded,
      iconColor: AttendanceColors.textSecondary,
      title: 'Already Timed Out',
      message:
      '${info['fullName']} has already been recorded for time out.',
    );

    return;
  }

  final willBeHalfDay = !lookup.hasTimeIn;

  final confirmed =
  await _showConfirmDialog(
    context,
    event: event,
    session: AttendanceSession.timeOut,
    info: info,
    note: willBeHalfDay
        ? 'No time-in on file for this student — this will be recorded as Half Day.'
        : null,
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  if (event.hasSessionEnded(
    AttendanceSession.timeOut,
  )) {
    await _showBlockedDialog(
      context,
      event,
      AttendanceSession.timeOut,
    );

    return;
  }

  final location =
  await _verifyCampusLocation(
    context,
  );

  if (location == null || !context.mounted) {
    return;
  }

  _showLoadingDialog(
    context,
    message: 'Recording time out…',
  );

  try {
    final result =
    await FirestoreService.instance.recordTimeOut(
      eventId: event.id,
      userId: userId,
      studentId: studentId,
      timeOutStatus: 'on-time',
      latitude: location.latitude,
      longitude: location.longitude,
      locationVerified: location.verified,
      locationAccuracy: location.accuracy,
    );

    if (!context.mounted) {
      return;
    }

    Navigator.of(
      context,
      rootNavigator: true,
    ).pop();

    await _showSuccessDialog(
      context,
      event: event,
      session: AttendanceSession.timeOut,
      studentId: studentId,
      info: info,
      statusOverrideLabel:
      willBeHalfDay ? 'Half Day' : null,
      isOffline:
      result == AttendanceWriteResult.queued,
    );
  } catch (e) {
    if (!context.mounted) {
      return;
    }

    if (Navigator.of(
      context,
      rootNavigator: true,
    ).canPop()) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop();
    }

    await _showMessageDialog(
      context,
      icon: Icons.error_outline_rounded,
      iconColor: AttendanceColors.danger,
      title: 'Something Went Wrong',
      message:
      e.toString().replaceFirst(
        'Exception: ',
        '',
      ),
    );
  }
}

// ================================================================
// DIALOGS
// ================================================================

void _showLoadingDialog(
    BuildContext context, {
      String message = 'Please wait…',
    }) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogShell(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 30,
          vertical: 34,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                color: AttendanceColors.accentBlue,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13.5,
                color: AttendanceColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _now12h() {
  final now = DateTime.now();

  final hour12 =
  now.hour % 12 == 0 ? 12 : now.hour % 12;

  final minute =
  now.minute.toString().padLeft(2, '0');

  final meridiem =
  now.hour >= 12 ? 'PM' : 'AM';

  return '$hour12:$minute $meridiem';
}

String _todayLabel() {
  const months = [
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

  final now = DateTime.now();

  return '${months[now.month - 1]} ${now.day}, ${now.year}';
}

// ================================================================
// SUCCESS DIALOG
// NOTE:
// Feedback QR is intentionally NOT shown here.
// It is shown from Event Details after the event's
// Afternoon / Time Out session has ended.
// ================================================================

Future<void> _showSuccessDialog(
    BuildContext context, {
      required EventModel event,
      required AttendanceSession session,
      required String studentId,
      required Map<String, String> info,
      String? statusOverrideLabel,
      bool isOffline = false,
    }) {
  HapticFeedback.mediumImpact();

  final isHalfDay =
      statusOverrideLabel == 'Half Day';

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _DialogShell(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            24,
            30,
            24,
            20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconBadge(
                icon: isOffline
                    ? Icons.cloud_off_rounded
                    : (isHalfDay
                    ? Icons.timelapse_rounded
                    : Icons.check_circle_rounded),
                color: isOffline
                    ? AttendanceColors.warning
                    : (isHalfDay
                    ? AttendanceColors.halfDay
                    : AttendanceColors.success),
                size: 72,
              ),
              const SizedBox(height: 18),
              Text(
                isOffline
                    ? 'Saved Offline'
                    : (isHalfDay
                    ? 'Recorded as Half Day'
                    : 'Attendance Recorded'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AttendanceColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isOffline
                    ? 'No connection — will sync automatically once online.'
                    : '${session.fullLabel} · ${event.eventName}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AttendanceColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AttendanceColors.surface,
                  borderRadius:
                  BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    DetailRow(
                      label: 'Name',
                      value: info['fullName'] ?? '',
                    ),
                    DetailRow(
                      label: 'ID Number',
                      value: studentId,
                    ),
                    DetailRow(
                      label: 'Course',
                      value: info['course'] ?? '',
                    ),
                    DetailRow(
                      label: 'Year Level',
                      value: info['yearLevel'] ?? '',
                    ),
                    DetailRow(
                      label: 'College',
                      value: info['college'] ?? '',
                    ),
                    DetailRow(
                      label: session.actionLabel,
                      value:
                      '${_now12h()} · ${_todayLabel()}',
                    ),
                    if (statusOverrideLabel != null)
                      DetailRow(
                        label: 'Status',
                        value: statusOverrideLabel,
                      ),
                    if (isOffline)
                      const DetailRow(
                        label: 'Sync Status',
                        value: 'Pending',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _PrimaryButton(
                label: 'Done',
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool?> _showConfirmDialog(
    BuildContext context, {
      required EventModel event,
      required AttendanceSession session,
      required Map<String, String> info,
      String? note,
    }) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return _DialogShell(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            24,
            28,
            24,
            20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconBadge(
                icon: session.icon,
                color: AttendanceColors.accentBlue,
                size: 62,
              ),
              const SizedBox(height: 16),
              Text(
                'Record ${session.fullLabel}?',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AttendanceColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'for ${info['fullName']} · ${event.eventName}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AttendanceColors.textSecondary,
                ),
              ),
              if (note != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AttendanceColors.halfDay
                        .withValues(alpha: 0.12),
                    borderRadius:
                    BorderRadius.circular(12),
                    border: Border.all(
                      color: AttendanceColors.halfDay
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AttendanceColors.halfDay,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          note,
                          style: const TextStyle(
                            fontSize: 12,
                            color:
                            AttendanceColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(dialogContext)
                                .pop(false),
                        style:
                        OutlinedButton.styleFrom(
                          foregroundColor:
                          AttendanceColors
                              .textSecondary,
                          side: const BorderSide(
                            color: AttendanceColors.border,
                            width: 1.4,
                          ),
                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.of(dialogContext)
                                .pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          AttendanceColors.navy,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
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
}

Future<void> _showBlockedDialog(
    BuildContext context,
    EventModel event,
    AttendanceSession session,
    ) {
  final notStarted =
  event.hasSessionNotStarted(session);

  final title = notStarted
      ? '${session.fullLabel} Not Yet Open'
      : '${session.fullLabel} Closed';

  final message = notStarted
      ? '${session.periodLabel} ${session.actionLabel.toLowerCase()} opens at ${event.sessionStartLabel(session)}.'
      : '${session.periodLabel} ${session.actionLabel.toLowerCase()} ended at ${event.sessionEndLabel(session)}. '
      'Please contact the event administrator for attendance.';

  return _showMessageDialog(
    context,
    icon: notStarted
        ? Icons.schedule_rounded
        : Icons.lock_clock_rounded,
    iconColor: AttendanceColors.warning,
    title: title,
    message: message,
  );
}

Future<void> _showMessageDialog(
    BuildContext context, {
      required IconData icon,
      required Color iconColor,
      required String title,
      required String message,
    }) {
  return showDialog(
    context: context,
    builder: (dialogContext) {
      return _DialogShell(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            24,
            28,
            24,
            20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconBadge(
                icon: icon,
                color: iconColor,
                size: 62,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AttendanceColors.textPrimary,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AttendanceColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              _PrimaryButton(
                label: 'OK',
                onPressed: () =>
                    Navigator.of(dialogContext).pop(),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ================================================================
// ENTER STUDENT ID
// ================================================================

class EnterStudentIdDialog
    extends StatefulWidget {
  const EnterStudentIdDialog({
    super.key,
  });

  @override
  State<EnterStudentIdDialog> createState() =>
      _EnterStudentIdDialogState();
}

class _EnterStudentIdDialogState
    extends State<EnterStudentIdDialog> {
  late final TextEditingController _controller;

  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final studentId =
    _controller.text.trim();

    if (studentId.isEmpty) {
      setState(
            () => _errorText =
        'Please enter the student ID number.',
      );
      return;
    }

    Navigator.of(context).pop(studentId);
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          24,
          26,
          24,
          20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AttendanceColors.accentBlue
                            .withValues(alpha: 0.15),
                        AttendanceColors.accentBlue
                            .withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    color:
                    AttendanceColors.accentBlue,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Enter ID Number',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color:
                      AttendanceColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction:
              TextInputAction.done,
              onChanged: (_) {
                if (_errorText != null) {
                  setState(
                        () => _errorText = null,
                  );
                }
              },
              onSubmitted: (_) => _submit(),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: 'Student ID Number',
                hintText: 'e.g. 21-00123',
                errorText: _errorText,
                prefixIcon: const Icon(
                  Icons.badge_outlined,
                  size: 20,
                ),
                filled: true,
                fillColor:
                AttendanceColors.surface,
                border: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(13),
                  borderSide: BorderSide.none,
                ),
                enabledBorder:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(13),
                  borderSide: const BorderSide(
                    color:
                    AttendanceColors.border,
                    width: 1.2,
                  ),
                ),
                focusedBorder:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(13),
                  borderSide: const BorderSide(
                    color:
                    AttendanceColors.accentBlue,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(),
                      style:
                      OutlinedButton.styleFrom(
                        foregroundColor:
                        AttendanceColors
                            .textSecondary,
                        side: const BorderSide(
                          color:
                          AttendanceColors.border,
                          width: 1.4,
                        ),
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        AttendanceColors.navy,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'Submit',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
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
  }
}

// ================================================================
// ATTENDANCE SCREEN
// ================================================================

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
  });

  @override
  State<AttendanceScreen> createState() =>
      _AttendanceScreenState();
}

class _AttendanceScreenState
    extends State<AttendanceScreen> {
  int _refreshKey = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AttendanceColors.bgNavy,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Event Attendance',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            fontSize: 20,
          ),
        ),
        backgroundColor: AttendanceColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: const [
          _PendingSyncBadge(),
        ],
      ),
      body: Container(
        color: AttendanceColors.bgNavy,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16,
          ),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(24),
              boxShadow: [
                AttendanceColors.softShadow(
                  opacity: 0.25,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              key: ValueKey(_refreshKey),
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const _EventListSkeleton();
                }

                if (snapshot.hasError) {
                  return _CenteredState(
                    child: Column(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        const _IconBadge(
                          icon:
                          Icons.wifi_off_rounded,
                          color:
                          AttendanceColors.danger,
                          size: 72,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Couldn\'t Load Events',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                            FontWeight.w800,
                            color:
                            AttendanceColors
                                .textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${snapshot.error}',
                          textAlign:
                          TextAlign.center,
                          style:
                          const TextStyle(
                            color:
                            AttendanceColors
                                .textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            setState(
                                  () => _refreshKey++,
                            );
                          },
                          icon: const Icon(
                            Icons.refresh_rounded,
                          ),
                          label:
                          const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final eventDocs =
                    snapshot.data?.docs ?? [];

                final activeEvents =
                eventDocs.where((doc) {
                  final event =
                  EventModel.fromFirestore(doc);

                  return event.statusLabel
                      .toLowerCase() ==
                      'active';
                }).toList();

                if (activeEvents.isEmpty) {
                  return const _CenteredState(
                    child: Column(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        _IconBadge(
                          icon: Icons
                              .event_available_rounded,
                          color:
                          AttendanceColors
                              .accentBlue,
                          size: 80,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'No Events Currently Active',
                          textAlign:
                          TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight:
                            FontWeight.w800,
                            color:
                            AttendanceColors
                                .textPrimary,
                          ),
                        ),
                        SizedBox(height: 7),
                        Text(
                          'There are no events ongoing right now.\nPlease check back later.',
                          textAlign:
                          TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            color:
                            AttendanceColors
                                .textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await FirebaseFirestore
                        .instance
                        .collection('events')
                        .get();

                    await AttendanceQueueService
                        .instance
                        .syncPending();
                  },
                  color: AttendanceColors.navy,
                  child: ListView.builder(
                    physics:
                    const AlwaysScrollableScrollPhysics(),
                    padding:
                    const EdgeInsets.fromLTRB(
                      16,
                      20,
                      16,
                      24,
                    ),
                    itemCount:
                    activeEvents.length,
                    itemBuilder:
                        (context, index) {
                      final eventDoc =
                      activeEvents[index];

                      final event =
                      EventModel.fromFirestore(
                        eventDoc,
                      );

                      return TweenAnimationBuilder<
                          double>(
                        tween: Tween(
                          begin: 0,
                          end: 1,
                        ),
                        duration: Duration(
                          milliseconds:
                          300 + (index * 80),
                        ),
                        builder: (
                            context,
                            value,
                            child,
                            ) {
                          return Opacity(
                            opacity: value,
                            child:
                            Transform.translate(
                              offset: Offset(
                                0,
                                20 * (1 - value),
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: Padding(
                          padding:
                          const EdgeInsets.only(
                            bottom: 20,
                          ),
                          child:
                          _ActiveEventCard(
                            event: event,
                            onStartAttendance: () =>
                                startAttendanceFlow(
                                  context,
                                  event,
                                ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// SKELETON
// ================================================================

class _EventListSkeleton
    extends StatelessWidget {
  const _EventListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics:
      const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        16,
        20,
        16,
        24,
      ),
      itemCount: 3,
      itemBuilder: (context, index) =>
      const Padding(
        padding: EdgeInsets.only(
          bottom: 20,
        ),
        child: _EventCardSkeleton(),
      ),
    );
  }
}

class _EventCardSkeleton
    extends StatelessWidget {
  const _EventCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(22),
        border: Border.all(
          color: AttendanceColors.border,
        ),
        boxShadow: [
          AttendanceColors.softShadow(),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            height: 190,
            color: Colors.grey.shade200,
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: 180,
                  height: 20,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 12),
                Container(
                  width: 140,
                  height: 14,
                  color: Colors.grey.shade200,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 80,
                  color: Colors.grey.shade200,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 48,
                  color: Colors.grey.shade200,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// REUSABLE SMALL WIDGETS
// ================================================================

class _CenteredState extends StatelessWidget {
  final Widget child;

  const _CenteredState({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: child,
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;

  const _SectionHeading({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w800,
        color: AttendanceColors.textPrimary,
        letterSpacing: 0.1,
      ),
    );
  }
}

class _ActiveEventCard
    extends StatelessWidget {
  final EventModel event;
  final VoidCallback onStartAttendance;

  const _ActiveEventCard({
    required this.event,
    required this.onStartAttendance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(22),
        border: Border.all(
          color: AttendanceColors.border,
        ),
        boxShadow: [
          AttendanceColors.softShadow(),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Hero(
                tag:
                'event-image-${event.id}',
                child: SizedBox(
                  width: double.infinity,
                  height: 190,
                  child: event.eventImage
                      .trim()
                      .isEmpty
                      ? _EventImageFallback(
                    icon: event.icon,
                  )
                      : Image.network(
                    event.eventImage,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) =>
                        _EventImageFallback(
                          icon: event.icon,
                        ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                bottom: 14,
                child: StatusBadge(
                  label:
                  event.statusDisplayLabel,
                  color: event.statusColor,
                  solid: true,
                ),
              ),
            ],
          ),
          Padding(
            padding:
            const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  event.eventName,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color:
                    AttendanceColors
                        .textPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                if (event.venue.trim().isNotEmpty)
                  Padding(
                    padding:
                    const EdgeInsets.only(
                      bottom: 8,
                    ),
                    child: Row(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 17,
                          color:
                          AttendanceColors
                              .textSecondary,
                        ),
                        const SizedBox(
                          width: 7,
                        ),
                        Expanded(
                          child: Text(
                            event.venue,
                            style:
                            const TextStyle(
                              fontSize: 14,
                              color:
                              AttendanceColors
                                  .textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    const Icon(
                      Icons
                          .calendar_today_rounded,
                      size: 15,
                      color:
                      AttendanceColors
                          .textSecondary,
                    ),
                    const SizedBox(
                      width: 7,
                    ),
                    Text(
                      event.formattedDate,
                      style:
                      const TextStyle(
                        fontSize: 14,
                        color:
                        AttendanceColors
                            .textSecondary,
                      ),
                    ),
                  ],
                ),
                if (event.description
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const _SectionHeading(
                    title: 'About',
                  ),
                  const SizedBox(height: 7),
                  Text(
                    event.description,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color:
                      AttendanceColors
                          .textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                const _SectionHeading(
                  title: 'Schedule',
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.all(16),
                  decoration:
                  BoxDecoration(
                    color:
                    AttendanceColors.surface,
                    borderRadius:
                    BorderRadius.circular(16),
                    border: Border.all(
                      color:
                      AttendanceColors.border,
                    ),
                  ),
                  child: Column(
                    children: [
                      ScheduleRow(
                        icon:
                        Icons.login_rounded,
                        label:
                        'Morning · Time In',
                        value:
                        event.sessionWindowLabel(
                          AttendanceSession.timeIn,
                        ),
                        accent:
                        AttendanceColors
                            .success,
                      ),
                      const Padding(
                        padding:
                        EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                        child: Divider(
                          height: 1,
                          color:
                          AttendanceColors
                              .border,
                        ),
                      ),
                      ScheduleRow(
                        icon:
                        Icons.logout_rounded,
                        label:
                        'Afternoon · Time Out',
                        value:
                        event.sessionWindowLabel(
                          AttendanceSession.timeOut,
                        ),
                        accent:
                        AttendanceColors
                            .accentBlue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const _SectionHeading(
                  title: 'Attendance',
                ),
                const SizedBox(height: 10),
                StreamBuilder<Map<String, int>>(
                  stream:
                  FirestoreService.instance
                      .attendanceStatsStream(
                    event.id,
                  ),
                  builder:
                      (context, snapshot) {
                    final stats =
                        snapshot.data ??
                            const {
                              'total': 0,
                              'present': 0,
                              'halfDay': 0,
                              'absent': 0,
                            };

                    return Row(
                      children: [
                        StatTile(
                          label: 'Total',
                          value:
                          '${stats['total']}',
                          color:
                          AttendanceColors
                              .navy,
                          icon:
                          Icons.groups_rounded,
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        StatTile(
                          label: 'Present',
                          value:
                          '${stats['present']}',
                          color:
                          AttendanceColors
                              .success,
                          icon: Icons
                              .check_circle_outline_rounded,
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        StatTile(
                          label: 'Half Day',
                          value:
                          '${stats['halfDay']}',
                          color:
                          AttendanceColors
                              .halfDay,
                          icon:
                          Icons.timelapse_rounded,
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        StatTile(
                          label: 'Absent',
                          value:
                          '${stats['absent']}',
                          color:
                          AttendanceColors
                              .danger,
                          icon: Icons
                              .highlight_off_rounded,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Semantics(
                  button: true,
                  label:
                  'Start attendance for ${event.eventName}',
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child:
                    ElevatedButton.icon(
                      onPressed:
                      onStartAttendance,
                      icon: const Icon(
                        Icons
                            .qr_code_scanner_rounded,
                        size: 23,
                      ),
                      label: const Text(
                        'Start Attendance',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton
                          .styleFrom(
                        backgroundColor:
                        AttendanceColors
                            .navy,
                        foregroundColor:
                        Colors.white,
                        elevation: 0,
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(
                            15,
                          ),
                        ),
                      ),
                    ),
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

class _EventImageFallback
    extends StatelessWidget {
  final IconData icon;

  const _EventImageFallback({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors:
          AttendanceColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white24,
          size: 72,
        ),
      ),
    );
  }
}

// ================================================================
// EVENT ATTENDANCE SCREEN
// ================================================================

class EventAttendanceScreen
    extends StatelessWidget {
  final EventModel event;

  const EventAttendanceScreen({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      AttendanceColors.bgNavy,
      body: Container(
        color: AttendanceColors.bgNavy,
        child: StreamBuilder<EventModel?>(
          stream:
          FirestoreService.instance.eventStream(
            event.id,
          ),
          initialData: event,
          builder: (
              context,
              eventSnapshot,
              ) {
            final liveEvent =
                eventSnapshot.data ?? event;

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 230,
                  backgroundColor:
                  AttendanceColors.navy,
                  foregroundColor:
                  Colors.white,
                  elevation: 0,
                  iconTheme:
                  const IconThemeData(
                    color: Colors.white,
                  ),
                  actions: const [
                    _PendingSyncBadge(),
                  ],
                  flexibleSpace:
                  FlexibleSpaceBar(
                    background:
                    _EventHero(
                      event: liveEvent,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                    const EdgeInsets.fromLTRB(
                      16,
                      20,
                      16,
                      20,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding:
                      const EdgeInsets.all(20),
                      decoration:
                      BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                        BorderRadius.circular(
                          24,
                        ),
                        boxShadow: [
                          AttendanceColors
                              .softShadow(
                            opacity: 0.25,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Row(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              Expanded(
                                child: Text(
                                  liveEvent.eventName,
                                  style:
                                  const TextStyle(
                                    fontSize: 22,
                                    fontWeight:
                                    FontWeight
                                        .w800,
                                    color:
                                    AttendanceColors
                                        .textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              StatusBadge(
                                label: liveEvent
                                    .statusDisplayLabel,
                                color:
                                liveEvent.statusColor,
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          if (liveEvent.venue
                              .isNotEmpty)
                            Padding(
                              padding:
                              const EdgeInsets
                                  .only(
                                bottom: 6,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons
                                        .place_outlined,
                                    color:
                                    AttendanceColors
                                        .textSecondary,
                                    size: 16,
                                  ),
                                  const SizedBox(
                                    width: 6,
                                  ),
                                  Expanded(
                                    child:
                                    Text(
                                      liveEvent.venue,
                                      style:
                                      const TextStyle(
                                        color:
                                        AttendanceColors
                                            .textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Row(
                            children: [
                              const Icon(
                                Icons
                                    .calendar_today_rounded,
                                color:
                                AttendanceColors
                                    .textSecondary,
                                size: 14,
                              ),
                              const SizedBox(
                                width: 6,
                              ),
                              Text(
                                liveEvent
                                    .formattedDate,
                                style:
                                const TextStyle(
                                  color:
                                  AttendanceColors
                                      .textSecondary,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                          if (liveEvent
                              .description
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(
                              height: 20,
                            ),
                            const _SectionHeading(
                              title: 'About',
                            ),
                            const SizedBox(
                              height: 7,
                            ),
                            Text(
                              liveEvent.description,
                              style:
                              const TextStyle(
                                color:
                                AttendanceColors
                                    .textSecondary,
                                fontSize: 13.5,
                                height: 1.5,
                              ),
                            ),
                          ],
                          const SizedBox(
                            height: 24,
                          ),
                          const _SectionHeading(
                            title: 'Schedule',
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Container(
                            padding:
                            const EdgeInsets.all(
                              16,
                            ),
                            decoration:
                            BoxDecoration(
                              color:
                              AttendanceColors
                                  .surface,
                              borderRadius:
                              BorderRadius.circular(
                                16,
                              ),
                              border:
                              Border.all(
                                color:
                                AttendanceColors
                                    .border,
                              ),
                            ),
                            child: Column(
                              children: [
                                ScheduleRow(
                                  icon:
                                  Icons.login_rounded,
                                  label:
                                  'Morning · Time In',
                                  value:
                                  liveEvent
                                      .sessionWindowLabel(
                                    AttendanceSession
                                        .timeIn,
                                  ),
                                  accent:
                                  AttendanceColors
                                      .success,
                                ),
                                const Padding(
                                  padding:
                                  EdgeInsets
                                      .symmetric(
                                    vertical: 13,
                                  ),
                                  child: Divider(
                                    height: 1,
                                    color:
                                    AttendanceColors
                                        .border,
                                  ),
                                ),
                                ScheduleRow(
                                  icon:
                                  Icons.logout_rounded,
                                  label:
                                  'Afternoon · Time Out',
                                  value:
                                  liveEvent
                                      .sessionWindowLabel(
                                    AttendanceSession
                                        .timeOut,
                                  ),
                                  accent:
                                  AttendanceColors
                                      .accentBlue,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            height: 24,
                          ),
                          const _SectionHeading(
                            title: 'Attendance',
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          StreamBuilder<
                              Map<String, int>>(
                            stream:
                            FirestoreService
                                .instance
                                .attendanceStatsStream(
                              liveEvent.id,
                            ),
                            builder: (
                                context,
                                statsSnapshot,
                                ) {
                              final stats =
                                  statsSnapshot
                                      .data ??
                                      const {
                                        'total': 0,
                                        'present': 0,
                                        'halfDay': 0,
                                        'absent': 0,
                                      };

                              return Row(
                                children: [
                                  StatTile(
                                    label: 'Total',
                                    value:
                                    '${stats['total']}',
                                    color:
                                    AttendanceColors
                                        .navy,
                                    icon:
                                    Icons
                                        .groups_rounded,
                                  ),
                                  const SizedBox(
                                    width: 8,
                                  ),
                                  StatTile(
                                    label:
                                    'Present',
                                    value:
                                    '${stats['present']}',
                                    color:
                                    AttendanceColors
                                        .success,
                                    icon: Icons
                                        .check_circle_outline_rounded,
                                  ),
                                  const SizedBox(
                                    width: 8,
                                  ),
                                  StatTile(
                                    label:
                                    'Half Day',
                                    value:
                                    '${stats['halfDay']}',
                                    color:
                                    AttendanceColors
                                        .halfDay,
                                    icon:
                                    Icons
                                        .timelapse_rounded,
                                  ),
                                  const SizedBox(
                                    width: 8,
                                  ),
                                  StatTile(
                                    label:
                                    'Absent',
                                    value:
                                    '${stats['absent']}',
                                    color:
                                    AttendanceColors
                                        .danger,
                                    icon: Icons
                                        .highlight_off_rounded,
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(
                            height: 28,
                          ),

                          // ==================================================
                          // START ATTENDANCE
                          // ==================================================

                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child:
                            ElevatedButton.icon(
                              onPressed: () =>
                                  startAttendanceFlow(
                                    context,
                                    liveEvent,
                                  ),
                              icon: const Icon(
                                Icons
                                    .qr_code_scanner_rounded,
                                size: 24,
                              ),
                              label: const Text(
                                'Start Attendance',
                                style:
                                TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                  FontWeight.w700,
                                ),
                              ),
                              style:
                              ElevatedButton
                                  .styleFrom(
                                backgroundColor:
                                AttendanceColors
                                    .navy,
                                foregroundColor:
                                Colors.white,
                                elevation: 0,
                                shape:
                                RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                    16,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ================================================================
// EVENT HERO
// ================================================================

class _EventHero extends StatelessWidget {
  final EventModel event;

  const _EventHero({
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'event-image-${event.id}',
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (event.eventImage.trim().isEmpty)
            _EventImageFallback(
              icon: event.icon,
            )
          else
            Image.network(
              event.eventImage,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) =>
                  _EventImageFallback(
                    icon: event.icon,
                  ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}