import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:attendance/models/attendance_model.dart';

// ================================================================
// SHARED COLORS
// ================================================================

const Color traceNavy = Color(0xFF071936);
const Color traceBgNavy = Color(0xFF081B3A);
const Color traceAccentBlue = Color(0xFF4A90E2);

const Color traceTextPrimary = Color(0xFF172033);
const Color traceTextSecondary = Color(0xFF6B7280);
const Color traceCardBorder = Color(0xFFE5E9F0);

const Color traceSuccess = Color(0xFF20A96B);
const Color traceDanger = Color(0xFFE0473C);
const Color traceHalfDay = Color(0xFFF5A623);

// ================================================================
// STUDENTS SCREEN
// ================================================================

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

enum _StatusFilter {
  all,
  present,
  halfDay,
  absent,
}

// ================================================================
// STUDENTS SCREEN STATE
// ================================================================

class _StudentsScreenState extends State<StudentsScreen> {
  // ==============================================================
  // CONTROLLER
  // ==============================================================

  final TextEditingController _searchController =
  TextEditingController();

  // ==============================================================
  // FILTER STATES
  // ==============================================================

  String _searchQuery = '';

  _StatusFilter _statusFilter =
      _StatusFilter.all;

  String? _selectedEventId;

  String _selectedYearLevel =
      'All Years';

  // Event year filter starts at 2026.
  String _selectedEventYear = '2026';

  // ==============================================================
  // INIT
  // ==============================================================

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      _onSearchChanged,
    );
  }

  // ==============================================================
  // SEARCH
  // ==============================================================

  void _onSearchChanged() {
    if (!mounted) {
      return;
    }

    final value =
    _searchController.text.trim();

    if (value == _searchQuery) {
      return;
    }

    setState(() {
      _searchQuery = value;
    });
  }

  // ==============================================================
  // DISPOSE
  // ==============================================================

  @override
  void dispose() {
    _searchController.removeListener(
      _onSearchChanged,
    );

    _searchController.dispose();

    super.dispose();
  }

  // ==============================================================
  // STATUS COLOR
  // ==============================================================

  Color _colorForStatus(
      String status,
      ) {
    switch (status.toLowerCase()) {
      case AttendanceModel.statusPresent:
        return traceSuccess;

      case AttendanceModel.statusHalfDay:
        return traceHalfDay;

      default:
        return traceDanger;
    }
  }

  // ==============================================================
  // STATUS LABEL
  // ==============================================================

  String _labelForStatus(
      String status,
      ) {
    switch (status.toLowerCase()) {
      case AttendanceModel.statusPresent:
        return 'Present';

      case AttendanceModel.statusHalfDay:
        return 'Half Day';

      default:
        return 'Absent';
    }
  }

  // ==============================================================
  // TIME FORMAT
  // ==============================================================

  String _formatTime(
      Timestamp? timestamp,
      ) {
    if (timestamp == null) {
      return '--';
    }

    return DateFormat(
      'h:mm a',
    ).format(
      timestamp.toDate(),
    );
  }

  // ==============================================================
  // EVENT DATE FORMAT
  // ==============================================================

  String _formatEventDate(
      dynamic eventDate,
      ) {
    if (eventDate is Timestamp) {
      return DateFormat(
        'MMM d, yyyy',
      ).format(
        eventDate.toDate(),
      );
    }

    return '';
  }

  // ==============================================================
  // GENERIC STRING READER
  // ==============================================================

  String _readString(
      Map<String, dynamic> data,
      List<String> keys,
      ) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) {
        continue;
      }

      final text =
      value.toString().trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }

  // ==============================================================
  // YEAR LEVEL
  // ==============================================================

  String _getYearLevel(
      Map<String, dynamic> data,
      ) {
    return _readString(
      data,
      [
        'yearLevel',
        'year',
        'yrLevel',
        'gradeLevel',
      ],
    );
  }

  // ==============================================================
  // ACADEMIC YEAR
  //
  // Supports several possible Firestore field names.
  // If your field is "academicYear", it will work directly.
  // ==============================================================

  String _getAcademicYear(
      Map<String, dynamic> data,
      ) {
    return _readString(
      data,
      [
        'academicYear',
        'schoolYear',
        'acadYear',
        'school_year',
      ],
    );
  }

  // ==============================================================
  // NORMALIZE YEAR LEVEL
  // ==============================================================

  String _normalizeYearLevel(
      String value,
      ) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    switch (normalized) {
      case '1':
      case '1st':
      case '1st year':
      case 'first year':
        return '1';

      case '2':
      case '2nd':
      case '2nd year':
      case 'second year':
        return '2';

      case '3':
      case '3rd':
      case '3rd year':
      case 'third year':
        return '3';

      case '4':
      case '4th':
      case '4th year':
      case 'fourth year':
        return '4';

      case '5':
      case '5th':
      case '5th year':
      case 'fifth year':
        return '5';

      default:
        return normalized;
    }
  }

  // ==============================================================
  // YEAR LEVEL SORT
  // ==============================================================

  int _compareYearLevels(
      String a,
      String b,
      ) {
    final aNumber =
    _yearNumber(a);

    final bNumber =
    _yearNumber(b);

    if (aNumber != null &&
        bNumber != null) {
      return aNumber.compareTo(
        bNumber,
      );
    }

    if (aNumber != null) {
      return -1;
    }

    if (bNumber != null) {
      return 1;
    }

    return a.compareTo(b);
  }

  // ==============================================================
  // YEAR NUMBER
  // ==============================================================

  int? _yearNumber(
      String value,
      ) {
    switch (
    _normalizeYearLevel(
      value,
    )) {
      case '1':
        return 1;

      case '2':
        return 2;

      case '3':
        return 3;

      case '4':
        return 4;

      case '5':
        return 5;

      default:
        return null;
    }
  }

  // ==============================================================
  // ACADEMIC YEAR SORT
  // ==============================================================

  int _compareAcademicYears(
      String a,
      String b,
      ) {
    final aYear =
    _extractAcademicYearNumber(
      a,
    );

    final bYear =
    _extractAcademicYearNumber(
      b,
    );

    if (aYear != null &&
        bYear != null) {
      return aYear.compareTo(
        bYear,
      );
    }

    if (aYear != null) {
      return -1;
    }

    if (bYear != null) {
      return 1;
    }

    return a.compareTo(b);
  }

  // ==============================================================
  // EXTRACT ACADEMIC YEAR
  // ==============================================================

  int? _extractAcademicYearNumber(
      String value,
      ) {
    final match = RegExp(
      r'20\d{2}',
    ).firstMatch(value);

    if (match == null) {
      return null;
    }

    return int.tryParse(
      match.group(0)!,
    );
  }

  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      traceBgNavy,

      // ==========================================================
      // APP BAR
      // ==========================================================

      appBar: AppBar(
        elevation: 0,
        backgroundColor:
        traceNavy,
        foregroundColor:
        Colors.white,
        surfaceTintColor:
        Colors.transparent,

        titleSpacing: 20,

        title: const Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance',
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Student attendance records',
              style: TextStyle(
                fontSize: 11,
                color:
                Colors.white70,
                fontWeight:
                FontWeight.w500,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {});
            },
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
        ],
      ),

      // ==========================================================
      // EVENTS STREAM
      // ==========================================================

      body:
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore
            .instance
            .collection('events')
            .orderBy(
          'eventDate',
          descending: true,
        )
            .snapshots(),

        builder: (
            context,
            eventSnapshot,
            ) {
          if (eventSnapshot.hasError) {
            return _buildMessage(
              'Failed to load events.',
              isError: true,
            );
          }

          if (!eventSnapshot.hasData) {
            return const Center(
              child:
              CircularProgressIndicator(
                color:
                traceAccentBlue,
              ),
            );
          }

          final allEventDocs =
              eventSnapshot.data!.docs;

          if (allEventDocs.isEmpty) {
            return _buildMessage(
              'No events yet. Create an event first.',
            );
          }

          // Build event-year options beginning with 2026.
          int latestEventYear = DateTime.now().year;
          for (final doc in allEventDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final eventDate = data['eventDate'];
            if (eventDate is Timestamp &&
                eventDate.toDate().year > latestEventYear) {
              latestEventYear = eventDate.toDate().year;
            }
          }

          final List<String> eventYearOptions = [
            for (int year = 2026; year <= latestEventYear; year++)
              year.toString(),
          ];

          if (eventYearOptions.isEmpty) {
            eventYearOptions.add('2026');
          }

          final effectiveEventYear =
          eventYearOptions.contains(_selectedEventYear)
              ? _selectedEventYear
              : eventYearOptions.first;

          final eventDocs = allEventDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final eventDate = data['eventDate'];
            return eventDate is Timestamp &&
                eventDate.toDate().year.toString() == effectiveEventYear;
          }).toList();

          if (eventDocs.isEmpty) {
            return Column(
              children: [
                Container(
                  width: double.infinity,
                  color: traceNavy,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: _buildEventYearPicker(
                    yearOptions: eventYearOptions,
                    selectedYear: effectiveEventYear,
                  ),
                ),
                Expanded(
                  child: _buildMessage(
                    'No events found for $effectiveEventYear.',
                  ),
                ),
              ],
            );
          }

          // ========================================================
          // EFFECTIVE EVENT
          // ========================================================

          final validIds = eventDocs.map((doc) => doc.id).toSet();

          final String effectiveEventId =
          (_selectedEventId != null &&
              validIds.contains(_selectedEventId))
              ? _selectedEventId!
              : eventDocs.first.id;

          final selectedEventDoc = eventDocs.firstWhere(
                (doc) => doc.id == effectiveEventId,
          );

          final selectedEventData =
          selectedEventDoc.data()
          as Map<String,
              dynamic>;

          final String
          selectedEventName =
              (
                  selectedEventData[
                  'eventName']
                  as String?
              ) ??
                  'Untitled Event';

          // ========================================================
          // STUDENTS STREAM
          // ========================================================

          return StreamBuilder<
              QuerySnapshot>(
            stream: FirebaseFirestore
                .instance
                .collection('users')
                .where(
              'role',
              isEqualTo:
              'Student',
            )
                .snapshots(),

            builder: (
                context,
                userSnapshot,
                ) {
              if (userSnapshot
                  .hasError) {
                return _buildMessage(
                  'Failed to load students.',
                  isError: true,
                );
              }

              if (!userSnapshot
                  .hasData) {
                return const Center(
                  child:
                  CircularProgressIndicator(
                    color:
                    traceAccentBlue,
                  ),
                );
              }

              final userDocs =
                  userSnapshot
                      .data!
                      .docs;

              // ====================================================
              // YEAR LEVEL OPTIONS
              // ====================================================

              final List<String>
              detectedYearLevels =
              userDocs
                  .map(
                    (doc) {
                  final data =
                  doc.data()
                  as Map<String,
                      dynamic>;

                  return _getYearLevel(
                    data,
                  );
                },
              )
                  .where(
                    (value) =>
                value
                    .trim()
                    .isNotEmpty,
              )
                  .toSet()
                  .toList();

              detectedYearLevels.sort(
                _compareYearLevels,
              );

              final List<String>
              yearOptions = [
                'All Years',
                ...detectedYearLevels,
              ];

              final String
              effectiveYearLevel =
              yearOptions.contains(
                _selectedYearLevel,
              )
                  ? _selectedYearLevel
                  : 'All Years';

              // ====================================================
              // ATTENDANCE STREAM
              // ====================================================

              return StreamBuilder<
                  QuerySnapshot>(
                stream: FirebaseFirestore
                    .instance
                    .collection(
                  'attendance',
                )
                    .where(
                  'eventId',
                  isEqualTo:
                  effectiveEventId,
                )
                    .snapshots(),

                builder: (
                    context,
                    attendanceSnapshot,
                    ) {
                  if (attendanceSnapshot
                      .hasError) {
                    return _buildMessage(
                      'Failed to load attendance.',
                      isError: true,
                    );
                  }

                  if (!attendanceSnapshot
                      .hasData) {
                    return const Center(
                      child:
                      CircularProgressIndicator(
                        color:
                        traceAccentBlue,
                      ),
                    );
                  }

                  // =================================================
                  // ATTENDANCE MAP
                  // =================================================

                  final Map<
                      String,
                      Map<String,
                          dynamic>>
                  attendanceByUser =
                  {};

                  for (final doc
                  in attendanceSnapshot
                      .data!
                      .docs) {
                    final data =
                    doc.data()
                    as Map<String,
                        dynamic>;

                    final userId =
                    data['userId']
                    as String?;

                    if (userId != null &&
                        userId
                            .isNotEmpty) {
                      attendanceByUser[
                      userId] = data;
                    }
                  }

                  // =================================================
                  // STUDENTS
                  // =================================================

                  List<_StudentRecord>
                  students =
                  userDocs.map(
                        (doc) {
                      final data =
                      doc.data()
                      as Map<String,
                          dynamic>;

                      final userId =
                          doc.id;

                      final attendance =
                      attendanceByUser[
                      userId];

                      final String
                      status =
                      attendance ==
                          null
                          ? AttendanceModel
                          .statusAbsent
                          : (
                          (
                              attendance[
                              'attendanceStatus']
                              as String?
                          ) ??
                              AttendanceModel
                                  .statusAbsent
                      );

                      return _StudentRecord(
                        userId:
                        userId,

                        name:
                        (
                            data[
                            'fullName']
                            as String?
                        ) ??
                            'Unknown',

                        studentId:
                        (
                            data[
                            'studentId']
                            as String?
                        ) ??
                            '',

                        course:
                        (
                            data[
                            'course']
                            as String?
                        ) ??
                            '',

                        yearLevel:
                        _getYearLevel(
                          data,
                        ),

                        academicYear:
                        _getAcademicYear(
                          data,
                        ),

                        status:
                        status,

                        isPresent:
                        status
                            .toLowerCase() ==
                            AttendanceModel
                                .statusPresent,

                        isHalfDay:
                        status
                            .toLowerCase() ==
                            AttendanceModel
                                .statusHalfDay,

                        timeIn:
                        attendance?[
                        'timeIn']
                        as Timestamp?,

                        timeOut:
                        attendance?[
                        'timeOut']
                        as Timestamp?,
                      );
                    },
                  ).toList();

                  // =================================================
                  // YEAR LEVEL FILTER
                  // =================================================

                  if (effectiveYearLevel !=
                      'All Years') {
                    students =
                        students
                            .where(
                              (student) =>
                          _normalizeYearLevel(
                            student
                                .yearLevel,
                          ) ==
                              _normalizeYearLevel(
                                effectiveYearLevel,
                              ),
                        )
                            .toList();
                  }

                  // =================================================
                  // SEARCH FILTER
                  // =================================================

                  if (_searchQuery
                      .isNotEmpty) {
                    final q =
                    _searchQuery
                        .toLowerCase();

                    students =
                        students
                            .where(
                              (student) {
                            return student
                                .name
                                .toLowerCase()
                                .contains(q) ||
                                student
                                    .studentId
                                    .toLowerCase()
                                    .contains(q) ||
                                student
                                    .course
                                    .toLowerCase()
                                    .contains(q) ||
                                student
                                    .yearLevel
                                    .toLowerCase()
                                    .contains(q) ||
                                student
                                    .academicYear
                                    .toLowerCase()
                                    .contains(q);
                          },
                        )
                            .toList();
                  }

                  // =================================================
                  // STATUS FILTER
                  // =================================================

                  switch (
                  _statusFilter) {
                    case _StatusFilter.present:
                      students =
                          students
                              .where(
                                (student) =>
                            student
                                .isPresent,
                          )
                              .toList();
                      break;

                    case _StatusFilter
                        .halfDay:
                      students =
                          students
                              .where(
                                (student) =>
                            student
                                .isHalfDay,
                          )
                              .toList();
                      break;

                    case _StatusFilter.absent:
                      students =
                          students
                              .where(
                                (student) =>
                            !student
                                .isPresent &&
                                !student
                                    .isHalfDay,
                          )
                              .toList();
                      break;

                    case _StatusFilter.all:
                      break;
                  }

                  // =================================================
                  // SORT
                  // =================================================

                  students.sort(
                        (
                        a,
                        b,
                        ) =>
                        a.name
                            .toLowerCase()
                            .compareTo(
                          b.name
                              .toLowerCase(),
                        ),
                  );

                  // =================================================
                  // STATISTICS
                  // =================================================

                  int presentCount =
                  0;

                  int halfDayCount =
                  0;

                  for (final record
                  in attendanceByUser
                      .values) {
                    final status =
                        (
                            record[
                            'attendanceStatus']
                            as String?
                        ) ??
                            '';

                    if (status
                        .toLowerCase() ==
                        AttendanceModel
                            .statusPresent) {
                      presentCount++;
                    } else if (status
                        .toLowerCase() ==
                        AttendanceModel
                            .statusHalfDay) {
                      halfDayCount++;
                    }
                  }

                  final int
                  totalStudents =
                      userDocs.length;

                  final int
                  absentCount =
                  (
                      totalStudents -
                          presentCount -
                          halfDayCount
                  ) <
                      0
                      ? 0
                      : (
                      totalStudents -
                          presentCount -
                          halfDayCount
                  );

                  // =================================================
                  // PAGE
                  // =================================================

                  return Column(
                    children: [
                      // =================================================
                      // HEADER
                      // =================================================

                      Container(
                        width:
                        double.infinity,
                        color:
                        traceNavy,

                        padding:
                        const EdgeInsets
                            .fromLTRB(
                          16,
                          8,
                          16,
                          16,
                        ),

                        child:
                        Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .stretch,

                          children: [
                            // =========================================
                            // EVENT
                            // =========================================

                            _buildEventYearPicker(
                              yearOptions: eventYearOptions,
                              selectedYear: effectiveEventYear,
                            ),

                            const SizedBox(height: 10),

                            _buildEventPicker(
                              eventDocs: eventDocs,
                              selectedEventId: effectiveEventId,
                              selectedEventName: selectedEventName,
                            ),

                            const SizedBox(height: 10),

                            _buildYearPicker(
                              yearOptions: yearOptions,
                              selectedYearLevel: effectiveYearLevel,
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            // =========================================
                            // SEARCH
                            // =========================================

                            _buildSearchField(),

                            const SizedBox(
                              height: 14,
                            ),

                            // =========================================
                            // STATISTICS
                            // =========================================

                            Row(
                              children: [
                                _StatPill(
                                  label:
                                  'Present',
                                  value:
                                  presentCount,
                                  icon:
                                  Icons
                                      .check_circle_rounded,
                                  color:
                                  traceSuccess,
                                ),

                                const SizedBox(
                                  width: 8,
                                ),

                                _StatPill(
                                  label:
                                  'Half Day',
                                  value:
                                  halfDayCount,
                                  icon:
                                  Icons
                                      .timelapse_rounded,
                                  color:
                                  traceHalfDay,
                                ),

                                const SizedBox(
                                  width: 8,
                                ),

                                _StatPill(
                                  label:
                                  'Absent',
                                  value:
                                  absentCount,
                                  icon:
                                  Icons
                                      .cancel_rounded,
                                  color:
                                  traceDanger,
                                ),

                                const SizedBox(
                                  width: 8,
                                ),

                                _StatPill(
                                  label:
                                  'Total',
                                  value:
                                  totalStudents,
                                  icon:
                                  Icons
                                      .people_alt_rounded,
                                  color:
                                  traceAccentBlue,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // =================================================
                      // WHITE CONTENT CARD
                      // =================================================

                      Expanded(
                        child:
                        Container(
                          margin:
                          const EdgeInsets
                              .fromLTRB(
                            16,
                            0,
                            16,
                            16,
                          ),

                          decoration:
                          BoxDecoration(
                            color:
                            Colors.white,

                            borderRadius:
                            BorderRadius
                                .circular(
                              20,
                            ),

                            boxShadow: [
                              BoxShadow(
                                color: Colors
                                    .black
                                    .withOpacity(
                                  0.08,
                                ),
                                blurRadius:
                                20,
                                offset:
                                const Offset(
                                  0,
                                  8,
                                ),
                              ),
                            ],
                          ),

                          clipBehavior:
                          Clip.antiAlias,

                          child:
                          Column(
                            children: [
                              // =======================================
                              // STATUS FILTERS
                              // =======================================

                              _buildFilterChips(),

                              const Divider(
                                height: 1,
                                thickness: 1,
                                color:
                                Color(
                                  0xFFEEEEEE,
                                ),
                              ),

                              // =======================================
                              // LIST
                              // =======================================

                              Expanded(
                                child:
                                students
                                    .isEmpty
                                    ? _buildEmptyState()
                                    : ListView
                                    .separated(
                                  padding:
                                  const EdgeInsets.fromLTRB(
                                    14,
                                    12,
                                    14,
                                    30,
                                  ),

                                  physics:
                                  const AlwaysScrollableScrollPhysics(),

                                  itemCount:
                                  students.length,

                                  separatorBuilder:
                                      (
                                      _,
                                      __,
                                      ) =>
                                  const SizedBox(
                                    height:
                                    10,
                                  ),

                                  itemBuilder:
                                      (
                                      context,
                                      index,
                                      ) {
                                    final student =
                                    students[
                                    index];

                                    return TweenAnimationBuilder<
                                        double>(
                                      tween:
                                      Tween(
                                        begin:
                                        0,
                                        end:
                                        1,
                                      ),

                                      duration:
                                      Duration(
                                        milliseconds:
                                        220 +
                                            (index *
                                                40),
                                      ),

                                      builder:
                                          (
                                          context,
                                          value,
                                          child,
                                          ) {
                                        return Opacity(
                                          opacity:
                                          value,
                                          child:
                                          Transform.translate(
                                            offset:
                                            Offset(
                                              0,
                                              10 *
                                                  (1 -
                                                      value),
                                            ),
                                            child:
                                            child,
                                          ),
                                        );
                                      },

                                      child:
                                      _StudentCard(
                                        name:
                                        student.name,
                                        studentId:
                                        student.studentId,
                                        course:
                                        student.course,
                                        yearLevel:
                                        student.yearLevel,
                                        academicYear:
                                        student.academicYear,
                                        status:
                                        _labelForStatus(
                                          student.status,
                                        ),
                                        statusColor:
                                        _colorForStatus(
                                          student.status,
                                        ),
                                        timeIn:
                                        _formatTime(
                                          student.timeIn,
                                        ),
                                        timeOut:
                                        _formatTime(
                                          student.timeOut,
                                        ),
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
  // EVENT YEAR PICKER
  // ================================================================

  Widget _buildEventYearPicker({
    required List<String> yearOptions,
    required String selectedYear,
  }) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
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
          value: selectedYear,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: traceAccentBlue,
            size: 20,
          ),
          style: const TextStyle(
            color: traceTextPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          items: yearOptions.map((year) {
            return DropdownMenuItem<String>(
              value: year,
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 17,
                    color: traceAccentBlue,
                  ),
                  const SizedBox(width: 8),
                  Text('Events in $year'),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedEventYear = value;
              _selectedEventId = null;
              _selectedYearLevel = 'All Years';
              _statusFilter = _StatusFilter.all;
            });
          },
        ),
      ),
    );
  }

  // ================================================================
  // EVENT PICKER
  // ================================================================

  Widget _buildEventPicker({
    required List<QueryDocumentSnapshot>
    eventDocs,
    required String selectedEventId,
    required String selectedEventName,
  }) {
    return Container(
      height: 52,

      padding:
      const EdgeInsets.symmetric(
        horizontal: 14,
      ),

      decoration:
      BoxDecoration(
        color:
        Colors.white,

        borderRadius:
        BorderRadius.circular(
          14,
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(
              0.10,
            ),
            blurRadius: 8,
            offset:
            const Offset(
              0,
              2,
            ),
          ),
        ],
      ),

      child:
      DropdownButtonHideUnderline(
        child:
        DropdownButton<String>(
          value:
          selectedEventId,

          isExpanded:
          true,

          icon: const Icon(
            Icons
                .keyboard_arrow_down_rounded,
            color:
            traceAccentBlue,
            size: 20,
          ),

          style:
          const TextStyle(
            color:
            traceTextPrimary,
            fontSize: 13,
            fontWeight:
            FontWeight.w700,
          ),

          items:
          eventDocs.map(
                (doc) {
              final data =
              doc.data()
              as Map<String,
                  dynamic>;

              final name =
                  (
                      data[
                      'eventName']
                      as String?
                  ) ??
                      'Untitled Event';

              final date =
              _formatEventDate(
                data['eventDate'],
              );

              return DropdownMenuItem<
                  String>(
                value:
                doc.id,

                child: Row(
                  children: [
                    const Icon(
                      Icons
                          .event_rounded,
                      size: 17,
                      color:
                      traceAccentBlue,
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    Expanded(
                      child: Text(
                        date.isNotEmpty
                            ? '$name  •  $date'
                            : name,
                        maxLines: 1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ).toList(),

          onChanged:
              (value) {
            if (value == null) {
              return;
            }

            setState(() {
              _selectedEventId =
                  value;

              _selectedYearLevel =
              'All Years';

              _statusFilter =
                  _StatusFilter.all;
            });
          },
        ),
      ),
    );
  }

  // ================================================================
  // YEAR LEVEL PICKER
  // ================================================================

  Widget _buildYearPicker({
    required List<String>
    yearOptions,
    required String
    selectedYearLevel,
  }) {
    return Container(
      height: 52,

      padding:
      const EdgeInsets.symmetric(
        horizontal: 12,
      ),

      decoration:
      BoxDecoration(
        color:
        Colors.white,

        borderRadius:
        BorderRadius.circular(
          14,
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(
              0.10,
            ),
            blurRadius: 8,
            offset:
            const Offset(
              0,
              2,
            ),
          ),
        ],
      ),

      child:
      DropdownButtonHideUnderline(
        child:
        DropdownButton<String>(
          value:
          selectedYearLevel,

          isExpanded:
          true,

          icon: const Icon(
            Icons
                .keyboard_arrow_down_rounded,
            color:
            traceAccentBlue,
            size: 19,
          ),

          style:
          const TextStyle(
            color:
            traceTextPrimary,
            fontSize: 12.5,
            fontWeight:
            FontWeight.w700,
          ),

          items:
          yearOptions.map(
                (year) {
              final bool isAll =
                  year ==
                      'All Years';

              return DropdownMenuItem<
                  String>(
                value:
                year,

                child: Row(
                  children: [
                    Icon(
                      isAll
                          ? Icons
                          .groups_outlined
                          : Icons
                          .school_outlined,
                      size: 16,
                      color:
                      traceAccentBlue,
                    ),

                    const SizedBox(
                      width: 7,
                    ),

                    Expanded(
                      child:
                      Text(
                        year,
                        maxLines: 1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ).toList(),

          onChanged:
              (value) {
            if (value == null) {
              return;
            }

            setState(() {
              _selectedYearLevel =
                  value;
            });
          },
        ),
      ),
    );
  }

  // ================================================================
  // SEARCH FIELD
  // ================================================================

  Widget _buildSearchField() {
    return SizedBox(
      height: 50,

      child:
      TextField(
        controller:
        _searchController,

        style:
        const TextStyle(
          color:
          Colors.white,
          fontSize: 14,
        ),

        decoration:
        InputDecoration(
          hintText:
          'Search student...',

          hintStyle:
          TextStyle(
            color:
            Colors.white
                .withOpacity(
              0.50,
            ),
            fontSize: 13.5,
          ),

          prefixIcon:
          Icon(
            Icons
                .search_rounded,
            color:
            Colors.white
                .withOpacity(
              0.60,
            ),
          ),

          suffixIcon:
          _searchQuery
              .isEmpty
              ? null
              : IconButton(
            onPressed: () {
              _searchController
                  .clear();
            },
            icon:
            Icon(
              Icons
                  .close_rounded,
              color: Colors
                  .white
                  .withOpacity(
                0.60,
              ),
              size: 18,
            ),
          ),

          filled:
          true,

          fillColor:
          Colors.white
              .withOpacity(
            0.08,
          ),

          contentPadding:
          const EdgeInsets
              .symmetric(
            vertical: 10,
          ),

          border:
          OutlineInputBorder(
            borderRadius:
            BorderRadius
                .circular(
              14,
            ),
            borderSide:
            BorderSide.none,
          ),

          enabledBorder:
          OutlineInputBorder(
            borderRadius:
            BorderRadius
                .circular(
              14,
            ),
            borderSide:
            BorderSide.none,
          ),

          focusedBorder:
          OutlineInputBorder(
            borderRadius:
            BorderRadius
                .circular(
              14,
            ),
            borderSide:
            BorderSide(
              color:
              traceAccentBlue
                  .withOpacity(
                0.60,
              ),
              width: 1,
            ),
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
      padding:
      const EdgeInsets
          .fromLTRB(
        12,
        10,
        12,
        10,
      ),

      child: Row(
        children:
        _StatusFilter.values
            .map(
              (filter) {
            final bool selected =
                filter ==
                    _statusFilter;

            return Expanded(
              child: Padding(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 3,
                ),

                child:
                _FilterChip(
                  label:
                  _filterLabel(
                    filter,
                  ),

                  selected:
                  selected,

                  onTap: () {
                    setState(() {
                      _statusFilter =
                          filter;
                    });
                  },
                ),
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  // ================================================================
  // FILTER LABEL
  // ================================================================

  String _filterLabel(
      _StatusFilter filter,
      ) {
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
    final bool hasFilter =
        _searchQuery.isNotEmpty ||
            _selectedYearLevel !=
                'All Years' ||
            _statusFilter !=
                _StatusFilter.all;

    return Center(
      child: Padding(
        padding:
        const EdgeInsets
            .symmetric(
          horizontal: 24,
          vertical: 40,
        ),

        child: Column(
          mainAxisAlignment:
          MainAxisAlignment
              .center,

          children: [
            Container(
              width: 80,
              height: 80,

              decoration:
              BoxDecoration(
                color:
                const Color(
                  0xFFEAF3FF,
                ),
                borderRadius:
                BorderRadius
                    .circular(
                  24,
                ),
              ),

              child: Icon(
                hasFilter
                    ? Icons
                    .person_search_rounded
                    : Icons
                    .people_outline_rounded,

                size: 40,

                color:
                traceAccentBlue
                    .withOpacity(
                  0.60,
                ),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            Text(
              hasFilter
                  ? 'No matching students.'
                  : 'No students found.',

              textAlign:
              TextAlign.center,

              style:
              TextStyle(
                color:
                traceTextPrimary
                    .withOpacity(
                  0.70,
                ),
                fontSize: 13,
                fontWeight:
                FontWeight.w600,
              ),
            ),

            if (hasFilter) ...[
              const SizedBox(
                height: 7,
              ),

              const Text(
                'Try another filter or search term.',
                textAlign:
                TextAlign.center,

                style:
                TextStyle(
                  color:
                  traceTextSecondary,
                  fontSize: 11.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ================================================================
  // MESSAGE
  // ================================================================

  Widget _buildMessage(
      String message, {
        bool isError = false,
      }) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(
          24,
        ),

        child: Text(
          message,

          textAlign:
          TextAlign.center,

          style:
          TextStyle(
            color: isError
                ? Colors.redAccent
                : traceTextPrimary,
            fontSize: 13,
            fontWeight:
            FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ================================================================
// STAT PILL
// ================================================================

class _StatPill
    extends StatelessWidget {
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
  Widget build(
      BuildContext context,
      ) {
    return Expanded(
      child: Container(
        padding:
        const EdgeInsets
            .symmetric(
          vertical: 10,
          horizontal: 6,
        ),

        decoration:
        BoxDecoration(
          color:
          Colors.white
              .withOpacity(
            0.06,
          ),

          borderRadius:
          BorderRadius
              .circular(
            12,
          ),

          border:
          Border.all(
            color:
            Colors.white
                .withOpacity(
              0.08,
            ),
          ),
        ),

        child: Row(
          mainAxisAlignment:
          MainAxisAlignment
              .center,

          children: [
            Icon(
              icon,
              color:
              color,
              size: 16,
            ),

            const SizedBox(
              width: 5,
            ),

            Flexible(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,

                mainAxisSize:
                MainAxisSize.min,

                children: [
                  Text(
                    '$value',

                    style:
                    TextStyle(
                      color:
                      color,
                      fontSize: 15,
                      fontWeight:
                      FontWeight
                          .w800,
                      height: 1.1,
                    ),
                  ),

                  Text(
                    label,

                    maxLines: 1,

                    overflow:
                    TextOverflow
                        .ellipsis,

                    style:
                    TextStyle(
                      color:
                      Colors
                          .white
                          .withOpacity(
                        0.60,
                      ),
                      fontSize: 8.5,
                      fontWeight:
                      FontWeight
                          .w600,
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

class _FilterChip
    extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return GestureDetector(
      onTap: onTap,

      child:
      AnimatedContainer(
        duration:
        const Duration(
          milliseconds: 200,
        ),

        height: 42,

        decoration:
        BoxDecoration(
          color: selected
              ? const Color(
            0xFFF3F8FF,
          )
              : Colors.white,

          borderRadius:
          BorderRadius
              .circular(
            21,
          ),

          border:
          Border.all(
            color: selected
                ? const Color(
              0xFFBFD8F8,
            )
                : const Color(
              0xFFE5E9F0,
            ),
          ),

          boxShadow: selected
              ? [
            BoxShadow(
              color:
              Colors
                  .blue
                  .withOpacity(
                0.10,
              ),
              blurRadius:
              6,
              offset:
              const Offset(
                0,
                2,
              ),
            ),
          ]
              : null,
        ),

        child:
        Center(
          child: Text(
            label,

            style:
            TextStyle(
              color: selected
                  ? traceAccentBlue
                  : traceTextSecondary,

              fontSize:
              11.5,

              fontWeight:
              selected
                  ? FontWeight
                  .w800
                  : FontWeight
                  .w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// STUDENT RECORD
// ================================================================

class _StudentRecord {
  final String userId;
  final String name;
  final String studentId;
  final String course;
  final String yearLevel;
  final String academicYear;
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
    required this.academicYear,
    required this.status,
    required this.isPresent,
    required this.isHalfDay,
    this.timeIn,
    this.timeOut,
  });
}

// ================================================================
// STUDENT CARD
// ================================================================

class _StudentCard
    extends StatelessWidget {
  final String name;
  final String studentId;
  final String course;
  final String yearLevel;
  final String academicYear;
  final String status;
  final Color statusColor;
  final String timeIn;
  final String timeOut;

  const _StudentCard({
    required this.name,
    required this.studentId,
    required this.course,
    required this.yearLevel,
    required this.academicYear,
    required this.status,
    required this.statusColor,
    required this.timeIn,
    required this.timeOut,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final String initials =
    name.trim().isNotEmpty
        ? name
        .trim()
        .substring(
      0,
      1,
    )
        .toUpperCase()
        : '?';

    final bool hasAnyTime =
        timeIn != '--' ||
            timeOut != '--';

    return Container(
      padding:
      const EdgeInsets.all(
        14,
      ),

      decoration:
      BoxDecoration(
        color:
        Colors.white,

        borderRadius:
        BorderRadius.circular(
          16,
        ),

        border:
        Border.all(
          color:
          traceCardBorder,
        ),

        boxShadow: [
          BoxShadow(
            color:
            Colors.black
                .withOpacity(
              0.04,
            ),
            blurRadius:
            10,
            offset:
            const Offset(
              0,
              3,
            ),
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
                .center,

            children: [
              // =====================================================
              // ACCENT BAR
              // =====================================================

              Container(
                width: 4,
                height: 60,

                decoration:
                BoxDecoration(
                  color:
                  statusColor,

                  borderRadius:
                  BorderRadius
                      .circular(
                    2,
                  ),
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              // =====================================================
              // AVATAR
              // =====================================================

              CircleAvatar(
                radius: 22,

                backgroundColor:
                statusColor
                    .withOpacity(
                  0.12,
                ),

                child: Text(
                  initials,

                  style:
                  TextStyle(
                    color:
                    statusColor,
                    fontSize: 16,
                    fontWeight:
                    FontWeight
                        .w800,
                  ),
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              // =====================================================
              // STUDENT INFORMATION
              // =====================================================

              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

                  children: [
                    Text(
                      name.isNotEmpty
                          ? name
                          : 'Unknown',

                      maxLines:
                      1,

                      overflow:
                      TextOverflow
                          .ellipsis,

                      style:
                      const TextStyle(
                        color:
                        traceTextPrimary,
                        fontSize: 14,
                        fontWeight:
                        FontWeight
                            .w800,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      studentId
                          .isNotEmpty
                          ? 'ID: $studentId'
                          : 'ID: --',

                      maxLines:
                      1,

                      overflow:
                      TextOverflow
                          .ellipsis,

                      style:
                      const TextStyle(
                        color:
                        traceTextSecondary,
                        fontSize: 11,
                        fontWeight:
                        FontWeight
                            .w500,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        if (course
                            .isNotEmpty)
                          _InfoTag(
                            icon: Icons
                                .school_outlined,
                            text:
                            course,
                          ),

                        if (yearLevel
                            .isNotEmpty)
                          _InfoTag(
                            icon: Icons
                                .layers_outlined,
                            text:
                            yearLevel,
                          ),

                        if (academicYear
                            .isNotEmpty)
                          _InfoTag(
                            icon: Icons
                                .calendar_today_outlined,
                            text:
                            academicYear,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              // =====================================================
              // STATUS
              // =====================================================

              Container(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),

                decoration:
                BoxDecoration(
                  color:
                  statusColor
                      .withOpacity(
                    0.10,
                  ),

                  borderRadius:
                  BorderRadius
                      .circular(
                    8,
                  ),
                ),

                child: Row(
                  mainAxisSize:
                  MainAxisSize
                      .min,

                  children: [
                    Container(
                      width: 7,
                      height: 7,

                      decoration:
                      BoxDecoration(
                        color:
                        statusColor,
                        shape:
                        BoxShape
                            .circle,
                      ),
                    ),

                    const SizedBox(
                      width: 4,
                    ),

                    Text(
                      status,

                      style:
                      TextStyle(
                        color:
                        statusColor,
                        fontSize: 10,
                        fontWeight:
                        FontWeight
                            .w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // =========================================================
          // TIME
          // =========================================================

          if (hasAnyTime) ...[
            const SizedBox(
              height: 10,
            ),

            Container(
              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 10,
                vertical: 8,
              ),

              decoration:
              BoxDecoration(
                color:
                const Color(
                  0xFFF7F9FC,
                ),

                borderRadius:
                BorderRadius
                    .circular(
                  10,
                ),
              ),

              child: Row(
                children: [
                  const Icon(
                    Icons
                        .login_rounded,
                    size: 13,
                    color:
                    traceAccentBlue,
                  ),

                  const SizedBox(
                    width: 4,
                  ),

                  Flexible(
                    child: Text(
                      'In: $timeIn',

                      overflow:
                      TextOverflow
                          .ellipsis,

                      style:
                      const TextStyle(
                        color:
                        traceTextPrimary,
                        fontSize: 10,
                        fontWeight:
                        FontWeight
                            .w600,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 14,
                  ),

                  const Icon(
                    Icons
                        .logout_rounded,
                    size: 13,
                    color:
                    traceAccentBlue,
                  ),

                  const SizedBox(
                    width: 4,
                  ),

                  Flexible(
                    child: Text(
                      'Out: $timeOut',

                      overflow:
                      TextOverflow
                          .ellipsis,

                      style:
                      const TextStyle(
                        color:
                        traceTextPrimary,
                        fontSize: 10,
                        fontWeight:
                        FontWeight
                            .w600,
                      ),
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

// ================================================================
// INFO TAG
// ================================================================

class _InfoTag
    extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoTag({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Container(
      padding:
      const EdgeInsets
          .symmetric(
        horizontal: 6,
        vertical: 3,
      ),

      decoration:
      BoxDecoration(
        color:
        const Color(
          0xFFF5F7FA,
        ),

        borderRadius:
        BorderRadius.circular(
          6,
        ),
      ),

      child: Row(
        mainAxisSize:
        MainAxisSize.min,

        children: [
          Icon(
            icon,
            size: 11,
            color:
            traceTextSecondary,
          ),

          const SizedBox(
            width: 3,
          ),

          ConstrainedBox(
            constraints:
            const BoxConstraints(
              maxWidth: 105,
            ),

            child: Text(
              text,

              maxLines:
              1,

              overflow:
              TextOverflow
                  .ellipsis,

              style:
              const TextStyle(
                color:
                traceTextSecondary,
                fontSize: 9,
                fontWeight:
                FontWeight
                    .w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
