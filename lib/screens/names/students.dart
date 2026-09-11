import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:attendance/models/attendance_model.dart';

// ================================================================
// STUDENTS SCREEN (Attendance tab) – Best UI Version
// ================================================================
class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

enum _StatusFilter { all, present, halfDay, absent }

class _StudentsScreenState extends State<StudentsScreen> {
  // ----------------------------------------------------------
  // COLORS
  // ----------------------------------------------------------
  static const Color navy = Color(0xFF071936);
  static const Color bgNavy = Color(0xFF081B3A);
  static const Color accentBlue = Color(0xFF4A90E2);
  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFE5E9F0);
  static const Color success = Color(0xFF20A96B);
  static const Color danger = Color(0xFFE0473C);
  static const Color warning = Color(0xFFF5A623);
  static const Color halfDay = Color(0xFFF5A623);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _StatusFilter _statusFilter = _StatusFilter.all;
  String? _selectedEventId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.removeListener(() {});
    _searchController.dispose();
    super.dispose();
  }

  /// Maps an `attendanceStatus` string to its display color.
  Color _colorForStatus(String status) {
    switch (status.toLowerCase()) {
      case AttendanceModel.statusPresent:
        return success;
      case AttendanceModel.statusHalfDay:
        return halfDay;
      default:
        return danger;
    }
  }

  /// Maps an `attendanceStatus` string to its display label.
  String _labelForStatus(String status) {
    switch (status.toLowerCase()) {
      case AttendanceModel.statusPresent:
        return 'Present';
      case AttendanceModel.statusHalfDay:
        return 'Half Day';
      default:
        return 'Absent';
    }
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '--';
    return DateFormat('h:mm a').format(ts.toDate());
  }

  String _formatEventDate(dynamic eventDate) {
    if (eventDate is Timestamp) {
      return DateFormat('MMM d, yyyy').format(eventDate.toDate());
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgNavy,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: navy,
        foregroundColor: Colors.white,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Student attendance records',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .orderBy('eventDate', descending: true)
            .snapshots(),
        builder: (context, eventSnapshot) {
          if (eventSnapshot.hasError) {
            return _buildMessage('Failed to load events.', isError: true);
          }
          if (!eventSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: accentBlue),
            );
          }

          final eventDocs = eventSnapshot.data!.docs;
          if (eventDocs.isEmpty) {
            return _buildMessage('No events yet. Create an event first.');
          }

          final validIds = eventDocs.map((d) => d.id).toSet();
          final String effectiveEventId =
          (_selectedEventId != null && validIds.contains(_selectedEventId))
              ? _selectedEventId!
              : eventDocs.first.id;

          final selectedEventDoc =
          eventDocs.firstWhere((d) => d.id == effectiveEventId);
          final selectedEventData =
          selectedEventDoc.data() as Map<String, dynamic>;
          final String selectedEventName =
              (selectedEventData['eventName'] as String?) ?? 'Untitled Event';

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'Student')
                .snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.hasError) {
                return _buildMessage('Failed to load students.',
                    isError: true);
              }
              if (!userSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: accentBlue),
                );
              }

              final userDocs = userSnapshot.data!.docs;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('attendance')
                    .where('eventId', isEqualTo: effectiveEventId)
                    .snapshots(),
                builder: (context, attendanceSnapshot) {
                  if (attendanceSnapshot.hasError) {
                    return _buildMessage('Failed to load attendance.',
                        isError: true);
                  }
                  if (!attendanceSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: accentBlue),
                    );
                  }

                  final Map<String, Map<String, dynamic>> attendanceByUser =
                  {};
                  for (final doc in attendanceSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final userId = data['userId'] as String?;
                    if (userId != null && userId.isNotEmpty) {
                      attendanceByUser[userId] = data;
                    }
                  }

                  List<_StudentRecord> students = userDocs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final userId = doc.id;
                    final attendance = attendanceByUser[userId];

                    final String status = attendance == null
                        ? AttendanceModel.statusAbsent
                        : ((attendance['attendanceStatus'] as String?) ??
                        AttendanceModel.statusAbsent);

                    return _StudentRecord(
                      userId: userId,
                      name: (data['fullName'] as String?) ?? 'Unknown',
                      studentId: (data['studentId'] as String?) ?? '',
                      course: (data['course'] as String?) ?? '',
                      yearLevel: (data['yearLevel'] as String?) ?? '',
                      status: status,
                      isPresent: status.toLowerCase() == AttendanceModel.statusPresent,
                      isHalfDay: status.toLowerCase() == AttendanceModel.statusHalfDay,
                      timeIn: attendance?['timeIn'] as Timestamp?,
                      timeOut: attendance?['timeOut'] as Timestamp?,
                    );
                  }).toList();

                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    students = students
                        .where((s) =>
                    s.name.toLowerCase().contains(q) ||
                        s.studentId.toLowerCase().contains(q))
                        .toList();
                  }

                  switch (_statusFilter) {
                    case _StatusFilter.present:
                      students = students.where((s) => s.isPresent).toList();
                      break;
                    case _StatusFilter.halfDay:
                      students = students.where((s) => s.isHalfDay).toList();
                      break;
                    case _StatusFilter.absent:
                      students = students
                          .where((s) => !s.isPresent && !s.isHalfDay)
                          .toList();
                      break;
                    case _StatusFilter.all:
                      break;
                  }

                  students.sort((a, b) => a.name.compareTo(b.name));

                  int presentCount = 0;
                  int halfDayCount = 0;
                  for (final a in attendanceByUser.values) {
                    final status = (a['attendanceStatus'] as String?)?.toLowerCase() ?? '';
                    if (status == AttendanceModel.statusPresent) {
                      presentCount++;
                    } else if (status == AttendanceModel.statusHalfDay) {
                      halfDayCount++;
                    }
                  }
                  final int totalStudents = userDocs.length;
                  final int absentCount =
                  (totalStudents - presentCount - halfDayCount) < 0
                      ? 0
                      : (totalStudents - presentCount - halfDayCount);

                  return Column(
                    children: [
                      // ==================================================
                      // HEADER (event picker + search + stats)
                      // ==================================================
                      Container(
                        color: navy,
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                        child: Column(
                          children: [
                            _buildEventPicker(
                              eventDocs: eventDocs,
                              selectedEventId: effectiveEventId,
                              selectedEventName: selectedEventName,
                            ),
                            const SizedBox(height: 12),
                            _buildSearchField(),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                _StatPill(
                                  label: 'Present',
                                  value: presentCount,
                                  icon: Icons.check_circle_rounded,
                                  color: success,
                                ),
                                const SizedBox(width: 8),
                                _StatPill(
                                  label: 'Half Day',
                                  value: halfDayCount,
                                  icon: Icons.timelapse_rounded,
                                  color: halfDay,
                                ),
                                const SizedBox(width: 8),
                                _StatPill(
                                  label: 'Absent',
                                  value: absentCount,
                                  icon: Icons.cancel_rounded,
                                  color: danger,
                                ),
                                const SizedBox(width: 8),
                                _StatPill(
                                  label: 'Total',
                                  value: totalStudents,
                                  icon: Icons.people_alt_rounded,
                                  color: accentBlue,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // ==================================================
                      // WHITE CARD (filters + list)
                      // ==================================================
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              _buildFilterChips(),
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: Color(0xFFEEEEEE),
                              ),
                              Expanded(
                                child: students.isEmpty
                                    ? _buildEmptyState()
                                    : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    12,
                                    14,
                                    30,
                                  ),
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: students.length,
                                  separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final s = students[index];
                                    return TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0, end: 1),
                                      duration: Duration(
                                          milliseconds: 250 + (index * 50)),
                                      builder: (context, value, child) {
                                        return Opacity(
                                          opacity: value,
                                          child: Transform.translate(
                                            offset: Offset(0, 12 * (1 - value)),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: _StudentCard(
                                        name: s.name,
                                        studentId: s.studentId,
                                        course: s.course,
                                        yearLevel: s.yearLevel,
                                        status: _labelForStatus(s.status),
                                        statusColor: _colorForStatus(s.status),
                                        timeIn: _formatTime(s.timeIn),
                                        timeOut: _formatTime(s.timeOut),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ================================================================
  // EVENT PICKER (with icon)
  // ================================================================
  Widget _buildEventPicker({
    required List<QueryDocumentSnapshot> eventDocs,
    required String selectedEventId,
    required String selectedEventName,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedEventId,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: accentBlue),
          style: const TextStyle(
            color: textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
          items: eventDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['eventName'] as String?) ?? 'Untitled Event';
            final dateLabel = _formatEventDate(data['eventDate']);
            return DropdownMenuItem<String>(
              value: doc.id,
              child: Row(
                children: [
                  const Icon(Icons.event_rounded, size: 16, color: accentBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dateLabel.isNotEmpty ? '$name  •  $dateLabel' : name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedEventId = value),
        ),
      ),
    );
  }

  // ================================================================
  // SEARCH FIELD
  // ================================================================
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: 'Search student...',
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.50),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: Colors.white.withOpacity(0.60),
        ),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
          onPressed: () {
            setState(() {
              _searchController.clear();
              _searchQuery = '';
            });
          },
          icon: Icon(
            Icons.close_rounded,
            color: Colors.white.withOpacity(0.60),
            size: 18,
          ),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: accentBlue.withOpacity(0.60),
            width: 1,
          ),
        ),
      ),
    );
  }

  // ================================================================
  // FILTER CHIPS
  // ================================================================
  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: _StatusFilter.values.map((filter) {
          final isSelected = filter == _statusFilter;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _FilterChip(
                label: _filterLabel(filter),
                selected: isSelected,
                onTap: () => setState(() => _statusFilter = filter),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _filterLabel(_StatusFilter filter) {
    switch (filter) {
      case _StatusFilter.all:
        return 'All';
      case _StatusFilter.present:
        return 'Present';
      case _StatusFilter.halfDay:
        return 'Half Day';
      case _StatusFilter.absent:
        return 'Absent';
    }
  }

  // ================================================================
  // EMPTY STATE
  // ================================================================
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.people_outline_rounded,
                size: 40,
                color: accentBlue.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No students found.',
              style: TextStyle(
                color: textPrimary.withOpacity(0.6),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(String message, {bool isError = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isError ? Colors.redAccent : textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ================================================================
// STAT PILL (with icon)
// ================================================================
class _StatPill extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 5),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$value',
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.60),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// FILTER CHIP
// ================================================================
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 42,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF3F8FF) : Colors.white,
          borderRadius: BorderRadius.circular(21), // full pill
          border: Border.all(
            color: selected
                ? const Color(0xFFBFD8F8)
                : const Color(0xFFE5E9F0),
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF4A90E2) : const Color(0xFF6B7280),
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// STUDENT RECORD MODEL
// ================================================================
class _StudentRecord {
  final String userId;
  final String name;
  final String studentId;
  final String course;
  final String yearLevel;
  final String status;
  final bool isPresent;
  final bool isHalfDay;
  final Timestamp? timeIn;
  final Timestamp? timeOut;

  _StudentRecord({
    required this.userId,
    required this.name,
    required this.studentId,
    required this.course,
    required this.yearLevel,
    required this.status,
    required this.isPresent,
    required this.isHalfDay,
    this.timeIn,
    this.timeOut,
  });
}

// ================================================================
// STUDENT CARD (with accent border and initials avatar)
// ================================================================
class _StudentCard extends StatelessWidget {
  final String name;
  final String studentId;
  final String course;
  final String yearLevel;
  final String status;
  final Color statusColor;
  final String timeIn;
  final String timeOut;

  const _StudentCard({
    required this.name,
    required this.studentId,
    required this.course,
    required this.yearLevel,
    required this.status,
    required this.statusColor,
    required this.timeIn,
    required this.timeOut,
  });

  @override
  Widget build(BuildContext context) {
    final String initials = name.trim().isNotEmpty
        ? name.trim().substring(0, 1).toUpperCase()
        : '?';
    final String subtitle = [
      if (course.isNotEmpty) course,
      if (yearLevel.isNotEmpty) yearLevel,
    ].join(' • ');

    // Show the time row whenever there's at least a time-in OR a time-out
    // on file — half-day students only have one of the two, and that
    // partial info is still worth surfacing.
    final bool hasAnyTime = timeIn != '--' || timeOut != '--';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E9F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left accent bar
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              // Avatar with initials
              CircleAvatar(
                radius: 22,
                backgroundColor: statusColor.withOpacity(0.12),
                child: Text(
                  initials,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name, ID, Course
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      studentId.isNotEmpty ? 'ID: $studentId' : 'ID: --',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Time in/out
          if (hasAnyTime) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.login_rounded,
                      size: 13, color: Color(0xFF4A90E2)),
                  const SizedBox(width: 4),
                  Text(
                    'In: $timeIn',
                    style: const TextStyle(
                      color: Color(0xFF172033),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Icon(Icons.logout_rounded,
                      size: 13, color: Color(0xFF4A90E2)),
                  const SizedBox(width: 4),
                  Text(
                    'Out: $timeOut',
                    style: const TextStyle(
                      color: Color(0xFF172033),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}