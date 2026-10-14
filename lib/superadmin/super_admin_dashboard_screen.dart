import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/user_provider.dart';
import 'super_admin_common.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() =>
      _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState
    extends State<SuperAdminDashboardScreen> {
  late Future<_DashboardData> _future;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventsSub;
  bool _eventWatcherPrimed = false;

  @override
  void initState() {
    super.initState();

    if (FirebaseAuth.instance.currentUser != null) {
      _future = _load();
      _watchEvents();
    } else {
      _future = Future.value(_DashboardData.empty());
      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null && mounted) {
          setState(() => _future = _load());
          _watchEvents();
          _authSub?.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _eventsSub?.cancel();
    super.dispose();
  }

  // Refresh dashboard totals and dropdown options whenever the events
  // collection changes, including when an event is deleted.
  void _watchEvents() {
    _eventsSub?.cancel();
    _eventWatcherPrimed = false;

    _eventsSub = FirebaseFirestore.instance
        .collection('events')
        .snapshots()
        .listen(
          (_) {
        if (!mounted) return;

        // Ignore the initial snapshot; _load() already runs on startup.
        if (!_eventWatcherPrimed) {
          _eventWatcherPrimed = true;
          return;
        }

        setState(() => _future = _load());
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Dashboard event watcher error: $error');
      },
    );
  }

  Future<_DashboardData> _load() async {
    final db = FirebaseFirestore.instance;

    try {
      // Do not use limit(5000): every student, event, and attendance row
      // must be included for the totals and filters to be consistent.
      final snapshots = await Future.wait([
        db.collection('users').get(),
        db.collection('events').get(),
        db.collection('attendance').get(),
      ]);

      final usersSnapshot =
      snapshots[0] as QuerySnapshot<Map<String, dynamic>>;
      final eventsSnapshot =
      snapshots[1] as QuerySnapshot<Map<String, dynamic>>;
      final attendanceSnapshot =
      snapshots[2] as QuerySnapshot<Map<String, dynamic>>;

      // ------------------------------------------------------------
      // STUDENTS: read raw Firestore fields instead of relying only on
      // UserModel.isStudent. A single malformed/inconsistent model must
      // not silently remove a student from the count.
      // ------------------------------------------------------------
      final List<_StudentRecord> students = [];
      final Map<String, int> studentCourse = {};
      final Map<String, int> studentCollege = {};
      final Map<String, String> aliasToStudentKey = {};
      final Map<String, List<String>> nameCandidates = {};

      for (final doc in usersSnapshot.docs) {
        final raw = doc.data();
        if (!_isStudentRecord(raw)) continue;

        final course = _readText(raw, const [
          'course',
          'courseName',
          'course_name',
          'courseCode',
          'program',
          'programName',
          'degreeProgram',
          'departmentCourse',
        ]);
        final college = _readText(raw, const [
          'college',
          'collegeName',
          'department',
          'school',
          'faculty',
        ]);
        final fullName = _readText(raw, const [
          'fullName',
          'fullname',
          'full_name',
          'name',
          'studentName',
          'student_name',
        ]);

        // Use each Firestore student document as a distinct enrolled
        // record. Document IDs may be random, so collect other identifiers
        // as aliases for matching attendance rows to this student.
        final student = _StudentRecord(
          key: doc.id,
          fullName: fullName,
          course: course.trim(),
          college: college.isEmpty ? 'Unassigned College' : college,
          aliases: _studentAliases(doc.id, raw),
        );
        students.add(student);

        // Count only real course names in the course chart. Placeholder
        // values such as 'Unassigned Course' are intentionally omitted.
        if (_isAssignedCourse(student.course)) {
          _incrementLabelCount(studentCourse, student.course);
        }
        _incrementLabelCount(studentCollege, student.college);

        for (final alias in student.aliases) {
          aliasToStudentKey.putIfAbsent(alias, () => student.key);
        }

        if (fullName.isNotEmpty) {
          nameCandidates.putIfAbsent(_normalizeAlias(fullName), () => []).add(student.key);
        }
      }

      // Names are used only as a fallback when an attendance row has no
      // usable student ID. Avoid matching a name if it belongs to multiple
      // students.
      for (final entry in nameCandidates.entries) {
        if (entry.value.length == 1) {
          aliasToStudentKey.putIfAbsent(entry.key, () => entry.value.first);
        }
      }

      // ------------------------------------------------------------
      // EVENTS
      // ------------------------------------------------------------
      // Only actual, non-deleted event documents are displayed.
      // Attendance rows alone must never create event dropdown options.
      final events = eventsSnapshot.docs
          .where((doc) => !_isDeletedEvent(doc.data()))
          .toList()
        ..sort((a, b) {
          final aDate = _parseEventStartDate(a.data());
          final bDate = _parseEventStartDate(b.data());
          if (aDate == null && bDate == null) {
            return a.id.compareTo(b.id);
          }
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

      // Attendance documents in older versions of TRACE sometimes saved an
      // event name or reference path rather than the events document ID.
      // Resolve those values to one canonical event document ID first.
      final Map<String, String> eventAliasToId = {};
      for (final eventDoc in events) {
        final eventData = eventDoc.data();
        final aliases = <dynamic>[
          eventDoc.id,
          eventData['eventId'],
          eventData['eventID'],
          eventData['event_id'],
          eventData['eventDocId'],
          eventData['eventDocumentId'],
          eventData['eventName'],
          eventData['name'],
          eventData['title'],
        ];
        for (final alias in aliases) {
          if (alias == null) continue;
          final key = _normalizeAlias(alias is DocumentReference ? alias.id : alias.toString());
          if (key.isNotEmpty) eventAliasToId.putIfAbsent(key, () => eventDoc.id);
        }
      }

      // ------------------------------------------------------------
      // RAW ATTENDANCE: collapse duplicate records for the same student
      // in the same event. A student must not count twice for one event.
      // ------------------------------------------------------------
      final Map<String, Map<String, _RawAttendance>> rawByEvent = {};
      final List<_RawAttendance> attendanceWithoutEvent = [];
      final Set<String> todayAttendanceKeys = {};
      final nowManila = _nowInManila();
      final today = DateTime(nowManila.year, nowManila.month, nowManila.day);

      for (final doc in attendanceSnapshot.docs) {
        final data = doc.data();
        final rawEventId = _readEventId(data);
        final eventLookupKey = _normalizeAlias(rawEventId);
        final eventId = rawEventId.isEmpty
            ? ''
            : (eventAliasToId[eventLookupKey] ?? rawEventId);
        final studentKey = _matchStudentKey(data, aliasToStudentKey);
        final activityDate = _activityDate(data);
        final status = _normalizeAttendanceStatus(data);
        final hasExplicitStatus = _explicitAttendanceStatus(data) != null;
        final hasTimeIn = _parseDate(
          _firstValue(data, const ['timeIn', 'time_in', 'checkIn', 'checkInTime']),
        ) !=
            null;

        if (activityDate != null &&
            _sameCalendarDay(_toManila(activityDate), today)) {
          final uniqueTodayKey =
              '${eventId.isEmpty ? '(no-event)' : eventId}|${studentKey ?? doc.id}';
          todayAttendanceKeys.add(uniqueTodayKey);
        }

        final raw = _RawAttendance(
          attendanceId: doc.id,
          eventId: eventId,
          studentKey: studentKey,
          status: status,
          date: activityDate,
          hasExplicitStatus: hasExplicitStatus,
          hasTimeIn: hasTimeIn,
        );

        if (eventId.isEmpty) {
          if (studentKey != null) attendanceWithoutEvent.add(raw);
          continue;
        }

        // Attendance entries that cannot be matched to a registered
        // student are not assigned to a random student. They remain in the
        // raw Firestore KPI but cannot safely identify an absent/present
        // enrolled student.
        if (studentKey == null) continue;

        final eventMap = rawByEvent.putIfAbsent(eventId, () => {});
        final previous = eventMap[studentKey];
        if (previous == null || _preferAttendance(raw, previous)) {
          eventMap[studentKey] = raw;
        }
      }

      // ------------------------------------------------------------
      // BUILD EFFECTIVE PER-EVENT RECORDS
      // For past/completed events, all enrolled students are represented:
      // stored status if available, otherwise Absent. Upcoming events with
      // no attendance activity are left at zero instead of marking every
      // student absent before the event occurs.
      // ------------------------------------------------------------
      final List<_AttendanceRecord> attendanceRecords = [];
      final List<_EventAttendance> eventAttendance = [];
      final Set<int> attendanceYears = {nowManila.year};

      for (final eventDoc in events) {
        final eventData = eventDoc.data();
        final eventId = eventDoc.id;

        final matched = rawByEvent[eventId] ?? <String, _RawAttendance>{};
        DateTime? eventDate = _parseEventStartDate(eventData);
        eventDate ??= _firstNonNullDate(matched.values.map((e) => e.date));
        final eventEndDate = _parseEventEndDate(eventData);
        final storedStatus = (eventData['status'] ?? '').toString();
        final shouldFillMissing = _shouldCountUnrecordedAsAbsent(
          eventDate: eventDate,
          eventEndDate: eventEndDate,
          storedStatus: storedStatus,
          hasAttendance: matched.isNotEmpty,
          nowManila: nowManila,
        );

        int present = 0;
        int halfDay = 0;
        int absent = 0;

        if (shouldFillMissing) {
          for (final student in students) {
            final raw = matched[student.key];
            final status = raw?.status ?? AttendanceStatus.absent;
            final recordDate = raw?.date ?? eventDate;

            switch (status) {
              case AttendanceStatus.present:
                present++;
                break;
              case AttendanceStatus.halfDay:
                halfDay++;
                break;
              case AttendanceStatus.absent:
                absent++;
                break;
            }

            // Filter all student records for this event by the event's year,
            // not by a later check-out/update timestamp in the attendance row.
            final recordYear = eventDate != null
                ? _toManila(eventDate).year
                : (recordDate == null ? nowManila.year : _toManila(recordDate).year);
            if (recordYear != null) attendanceYears.add(recordYear);

            attendanceRecords.add(
              _AttendanceRecord(
                attendanceId: raw?.attendanceId ?? 'generated_absent_${eventId}_${student.key}',
                eventId: eventId,
                studentKey: student.key,
                status: status,
                date: recordDate,
                year: recordYear,
              ),
            );
          }
        } else {
          // For events that have not started and have no attendance yet,
          // only include any real records already present in Firestore.
          for (final raw in matched.values) {
            final recordYear = eventDate != null
                ? _toManila(eventDate).year
                : (raw.date == null ? nowManila.year : _toManila(raw.date!).year);
            if (recordYear != null) attendanceYears.add(recordYear);
            attendanceRecords.add(
              _AttendanceRecord(
                attendanceId: raw.attendanceId,
                eventId: eventId,
                studentKey: raw.studentKey,
                status: raw.status,
                date: raw.date ?? eventDate,
                year: recordYear,
              ),
            );
            switch (raw.status) {
              case AttendanceStatus.present:
                present++;
                break;
              case AttendanceStatus.halfDay:
                halfDay++;
                break;
              case AttendanceStatus.absent:
                absent++;
                break;
            }
          }
        }

        if (eventDate != null) attendanceYears.add(_toManila(eventDate).year);

        eventAttendance.add(
          _EventAttendance(
            eventId: eventId,
            eventName: _readText(eventData, const ['eventName', 'name', 'title']).isEmpty
                ? 'Untitled Event'
                : _readText(eventData, const ['eventName', 'name', 'title']),
            eventDate: eventDate,
            eventEndDate: eventEndDate,
            storedStatus: storedStatus,
            present: present,
            halfDay: halfDay,
            absent: absent,
          ),
        );
      }

      // Do not create dashboard breakdown rows for orphan attendance.
      // These records commonly belong to hard-deleted events. If the event
      // document no longer exists in "events", it must not appear in the
      // dropdown or affect event-based attendance totals.
      //
      // totalAttendance above still shows the raw number of attendance
      // documents stored in Firestore for auditing purposes.

      // Records without an event ID cannot be included in any event filter,
      // but can still contribute to the all-events breakdown.
      for (final raw in attendanceWithoutEvent) {
        final year = raw.date == null ? null : _toManila(raw.date!).year;
        if (year != null) attendanceYears.add(year);
        attendanceRecords.add(
          _AttendanceRecord(
            attendanceId: raw.attendanceId,
            eventId: '',
            studentKey: raw.studentKey,
            status: raw.status,
            date: raw.date,
            year: year,
          ),
        );
      }

      eventAttendance.sort((a, b) {
        if (a.eventDate == null && b.eventDate == null) return 0;
        if (a.eventDate == null) return 1;
        if (b.eventDate == null) return -1;
        return b.eventDate!.compareTo(a.eventDate!);
      });

      final sortedYears = attendanceYears.toList()
        ..sort((a, b) => b.compareTo(a));

      return _DashboardData(
        totalUsers: usersSnapshot.docs.length,
        totalStudents: students.length,
        totalEvents: events.length,
        // This KPI reports actual Firestore attendance documents. The chart
        // below uses unique student-per-event rows to avoid double counting.
        totalAttendance: attendanceSnapshot.docs.length,
        todayAttendance: todayAttendanceKeys.length,
        present: attendanceRecords.where((r) => r.status == AttendanceStatus.present).length,
        halfDay: attendanceRecords.where((r) => r.status == AttendanceStatus.halfDay).length,
        absent: attendanceRecords.where((r) => r.status == AttendanceStatus.absent).length,
        studentCourse: studentCourse,
        studentCollege: studentCollege,
        events: events,
        eventAttendance: eventAttendance,
        attendanceRecords: attendanceRecords,
        attendanceYears: sortedYears,
      );
    } catch (e, stackTrace) {
      debugPrint('Dashboard load error: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  bool _isDeletedEvent(Map<String, dynamic> data) {
    const deletedFlags = <String>[
      'isDeleted',
      'is_deleted',
      'deleted',
      'isRemoved',
      'is_removed',
    ];

    for (final key in deletedFlags) {
      final value = data[key];

      if (value == true) return true;
      if (value is num && value == 1) return true;

      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
      }
    }

    final status = (data['status'] ??
        data['eventStatus'] ??
        data['event_status'] ??
        '')
        .toString()
        .trim()
        .toLowerCase();

    return const <String>{
      'deleted',
      'removed',
      'soft deleted',
      'soft-deleted',
      'trashed',
      'trash',
    }.contains(status);
  }

  void _retry() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final userData = context.watch<UserProvider>().userData;
    UserModel? currentUser;

    if (userData != null) {
      try {
        currentUser = UserModel.fromMap(
          FirebaseAuth.instance.currentUser?.uid ?? '',
          userData,
        );
      } catch (_) {
        currentUser = null;
      }
    }

    return Scaffold(
      backgroundColor: TraceColors.canvas,
      body: SafeArea(
        child: FutureBuilder<_DashboardData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SuperAdminCommon.loading();
            }
            if (snapshot.hasError) {
              return _DashboardErrorView(error: snapshot.error, onRetry: _retry);
            }

            final data = snapshot.data ?? _DashboardData.empty();
            return LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 36),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(name: currentUser?.fullName ?? 'Super Admin'),
                        const SizedBox(height: 24),
                        _KpiGrid(data: data),
                        const SizedBox(height: 22),
                        _PremiumSection(
                          title: 'Attendance Breakdown',
                          subtitle: 'Select one event to view its attendance. Present, Half-day, and Absent show counts for that event only.',
                          icon: Icons.donut_large_rounded,
                          child: LayoutBuilder(
                            builder: (context, box) {
                              final compact = box.maxWidth < 620;
                              return SizedBox(
                                height: compact ? 610 : 390,
                                child: _AttendanceBreakdown(data: data),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 22),
                        _BottomGrid(data: data),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// STUDENT DETECTION AND DATA HELPERS
// ============================================================================

bool _isStudentRecord(Map<String, dynamic> data) {
  final roleValues = <dynamic>[
    data['role'],
    data['userRole'],
    data['user_role'],
    data['accountType'],
    data['account_type'],
    data['userType'],
    data['user_type'],
    data['type'],
    data['position'],
  ]
      .where((value) => value != null)
      .map((value) => _normalizeRole(value.toString()))
      .where((value) => value.isNotEmpty)
      .toList();

  if (roleValues.any((role) => role.contains('student'))) return true;
  if (_truthy(data['isStudent']) || _truthy(data['is_student'])) return true;

  // Exclude known non-student roles before falling back to profile fields.
  // Punctuation is normalized, so values such as "ssg_officer" are handled.
  bool isPrivilegedRole(String role) {
    if (role == 'ssg' || role == 'officer' || role == 'administrator') return true;
    return role.contains('admin') ||
        role.contains('officer') ||
        role.contains('faculty') ||
        role.contains('teacher') ||
        role.contains('lecturer') ||
        role.contains('instructor') ||
        role.contains('coordinator');
  }

  if (roleValues.any(isPrivilegedRole)) return false;

  final studentId = _readText(data, const [
    'studentId',
    'studentID',
    'student_id',
    'student_id_number',
    'studentNumber',
    'studentNo',
    'student_no',
    'idNumber',
    'schoolId',
    'schoolID',
    'studentCode',
    'student_code',
    'studentNumberId',
  ]);
  if (studentId.isNotEmpty) return true;

  final course = _readText(data, const [
    'course',
    'courseName',
    'course_name',
    'courseCode',
    'program',
    'programName',
    'degreeProgram',
    'degree',
    'departmentCourse',
  ]);
  final college = _readText(data, const ['college', 'collegeName', 'department', 'school', 'faculty']);
  final yearLevel = _readText(data, const ['yearLevel', 'year_level', 'year', 'yearOfStudy']);
  final fullName = _readText(data, const ['fullName', 'fullname', 'full_name', 'name', 'studentName', 'student_name']);

  if (course.isNotEmpty || yearLevel.isNotEmpty || college.isNotEmpty || fullName.isNotEmpty) {
    // In this app, a user profile with academic/profile data and no explicit
    // privileged role is treated as a student record. This also includes older
    // imports whose role is "user" or "member" and whose studentId is missing.
    return true;
  }

  return false;
}

bool _truthy(dynamic value) {
  if (value == true) return true;
  if (value is num) return value != 0;
  final text = _norm(value?.toString() ?? '');
  return text == 'true' || text == 'yes' || text == '1' || text == 'student';
}

String _normalizeRole(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

String _normalizeAlias(String value) {
  var normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return '';

  // QR codes in TRACE may store identifiers as TRACE_STUDENT|<studentId>.
  normalized = normalized.replaceFirst(
    RegExp(r'^(trace[_ -]?student|student|participant|trace[_ -]?event)\s*[|:]\s*'),
    '',
  );
  if (normalized.contains('/')) normalized = normalized.split('/').last;
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized;
}

Set<String> _studentAliases(String documentId, Map<String, dynamic> data) {
  final aliases = <String>{_normalizeAlias(documentId)};
  for (final field in const [
    'uid',
    'userId',
    'userID',
    'user_id',
    'studentId',
    'studentID',
    'student_id',
    'student_id_number',
    'studentNumber',
    'studentNo',
    'student_no',
    'idNumber',
    'schoolId',
    'schoolID',
    'email',
    'studentCode',
    'student_code',
    'studentDocId',
    'studentDocumentId',
    'userDocId',
    'id',
  ]) {
    final value = data[field];
    if (value != null && value.toString().trim().isNotEmpty) {
      aliases.add(_normalizeAlias(value.toString()));
    }
  }
  return aliases.where((alias) => alias.isNotEmpty).toSet();
}

String? _matchStudentKey(
    Map<String, dynamic> data,
    Map<String, String> aliasToStudentKey,
    ) {
  final fields = const [
    'studentId',
    'studentID',
    'student_id',
    'student_id_number',
    'studentNumber',
    'studentNo',
    'student_no',
    'idNumber',
    'schoolId',
    'schoolID',
    'studentUid',
    'studentUID',
    'uid',
    'userId',
    'userID',
    'user_id',
    'userUid',
    'participantId',
    'participantID',
    'studentCode',
    'student_code',
    'studentDocId',
    'studentDocumentId',
    'userDocId',
    'email',
    'studentName',
    'student_name',
    'fullName',
    'full_name',
    'name',
    'id',
  ];

  for (final field in fields) {
    final value = data[field];
    if (value == null || value.toString().trim().isEmpty) continue;
    final found = aliasToStudentKey[_normalizeAlias(value.toString())];
    if (found != null) return found;
  }

  // Some attendance rows store the student object/profile as a map.
  for (final field in const ['student', 'user', 'studentData', 'userData', 'participant']) {
    final value = data[field];
    if (value is Map) {
      for (final nestedField in fields) {
        final nestedValue = value[nestedField];
        if (nestedValue == null || nestedValue.toString().trim().isEmpty) continue;
        final found = aliasToStudentKey[_normalizeAlias(nestedValue.toString())];
        if (found != null) return found;
      }
    }
  }

  for (final field in const ['studentRef', 'userRef', 'student', 'user', 'participantRef']) {
    final value = data[field];
    if (value is DocumentReference) {
      final found = aliasToStudentKey[_normalizeAlias(value.id)];
      if (found != null) return found;
    } else if (value != null && value is! Map) {
      final text = value.toString();
      final lastSegment = text.contains('/') ? text.split('/').last : text;
      final found = aliasToStudentKey[_normalizeAlias(lastSegment)];
      if (found != null) return found;
    }
  }
  return null;
}

String _readEventId(Map<String, dynamic> data) {
  for (final key in const [
    'eventId',
    'eventID',
    'event_id',
    'eventDocId',
    'eventDocumentId',
    'event_doc_id',
    'eventKey',
  ]) {
    final value = data[key];
    if (value is DocumentReference) return value.id.trim();
    if (value != null && value.toString().trim().isNotEmpty) {
      final text = value.toString().trim();
      return text.contains('/') ? text.split('/').last : text;
    }
  }
  for (final key in const ['eventRef', 'eventReference', 'event']) {
    final value = data[key];
    if (value is DocumentReference) return value.id.trim();
    if (value != null && value is! Map && value.toString().trim().isNotEmpty) {
      final text = value.toString().trim();
      return text.contains('/') ? text.split('/').last : text;
    }
  }
  for (final key in const ['eventName', 'eventTitle', 'event_name']) {
    final value = data[key];
    if (value != null && value.toString().trim().isNotEmpty) return value.toString().trim();
  }
  return '';
}

String _readText(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return '';
}

/// Returns false for blank or placeholder course values. Students with a
/// missing course remain included in Total Students but are not shown as an
/// artificial course category in Students by Course.
bool _isAssignedCourse(String course) {
  final normalized = _norm(course);
  if (normalized.isEmpty) return false;
  const placeholders = {
    'unassigned course',
    'unassigned',
    'not assigned',
    'no course',
    'none',
    'n/a',
    'na',
    'unknown',
    '-',
    'null',
  };
  return !placeholders.contains(normalized);
}

void _incrementLabelCount(Map<String, int> map, String label) {
  final cleaned = label.trim().replaceAll(RegExp(r'\s+'), ' ');
  // Empty course/college fields are not synthetic categories. The student
  // remains in the overall student count, but is not assigned to a course.
  if (cleaned.isEmpty) return;

  String? existingKey;
  for (final key in map.keys) {
    if (_norm(key) == _norm(cleaned)) {
      existingKey = key;
      break;
    }
  }
  final key = existingKey ?? cleaned;
  map[key] = (map[key] ?? 0) + 1;
}

String _norm(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

DateTime _nowInManila() => DateTime.now().toUtc().add(const Duration(hours: 8));

bool _sameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _preferAttendance(_RawAttendance candidate, _RawAttendance current) {
  // An actual saved status is more trustworthy than a status inferred from
  // a missing field. This prevents a time-out-only duplicate from replacing
  // a valid present/half-day row with a guessed absent value.
  if (candidate.hasExplicitStatus != current.hasExplicitStatus) {
    return candidate.hasExplicitStatus;
  }

  // If one duplicate includes a time-in, it is evidence that the student
  // attended, unlike a row with no status and no check-in time.
  final candidateEvidence = candidate.hasTimeIn || candidate.status != AttendanceStatus.absent;
  final currentEvidence = current.hasTimeIn || current.status != AttendanceStatus.absent;
  if (candidateEvidence != currentEvidence) return candidateEvidence;

  if (candidate.date != null && current.date == null) return true;
  if (candidate.date == null && current.date != null) return false;
  if (candidate.date != null && current.date != null) {
    if (candidate.date!.isAfter(current.date!)) return true;
    if (candidate.date!.isBefore(current.date!)) return false;
  }

  int priority(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.halfDay:
        return 3;
      case AttendanceStatus.present:
        return 2;
      case AttendanceStatus.absent:
        return 1;
    }
  }
  return priority(candidate.status) > priority(current.status);
}

bool _shouldCountUnrecordedAsAbsent({
  required DateTime? eventDate,
  required DateTime? eventEndDate,
  required String storedStatus,
  required bool hasAttendance,
  required DateTime nowManila,
}) {
  final state = _norm(storedStatus);
  if ({'completed', 'complete', 'done', 'finished', 'closed'}.contains(state)) {
    return true;
  }
  if (hasAttendance) return true;
  if (eventDate == null) return false;

  final start = _toManila(eventDate);
  final end = eventEndDate == null ? null : _toManila(eventEndDate);
  if (end != null && !nowManila.isBefore(end)) return true;
  if (nowManila.isBefore(start)) return false;

  // If the event has a real time on it, compare the exact time. For a
  // date-only event, count it as started on that Manila calendar day.
  final hasExplicitTime = start.hour != 0 || start.minute != 0 || start.second != 0;
  if (hasExplicitTime) return !nowManila.isBefore(start);
  final today = DateTime(nowManila.year, nowManila.month, nowManila.day);
  final eventDay = DateTime(start.year, start.month, start.day);
  return !eventDay.isAfter(today);
}

DateTime? _firstNonNullDate(Iterable<DateTime?> values) {
  for (final value in values) {
    if (value != null) return value;
  }
  return null;
}

// ============================================================================
// KPI GRID / CARDS
// ============================================================================

class _KpiGrid extends StatelessWidget {
  final _DashboardData data;
  const _KpiGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _ModernStatCard(
        title: 'Total Users',
        value: _number(data.totalUsers),
        subtitle: 'Registered accounts',
        icon: Icons.people_alt_rounded,
        accent: TraceColors.accent,
      ),
      _ModernStatCard(
        title: 'Events',
        value: _number(data.totalEvents),
        subtitle: 'Total recorded events',
        icon: Icons.event_rounded,
        accent: TraceColors.warning,
      ),
      _ModernStatCard(
        title: 'Students',
        value: _number(data.totalStudents),
        subtitle: 'Registered student accounts',
        icon: Icons.school_rounded,
        accent: TraceColors.success,
      ),
      _ModernStatCard(
        title: 'Total Attendance',
        value: _number(data.totalAttendance),
        subtitle: '${_number(data.todayAttendance)} unique student/event records today',
        icon: Icons.fact_check_rounded,
        accent: TraceColors.accent,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 14) / 2;

        // Fixed responsive height prevents the title, value, and subtitle
        // from overflowing on narrow phone screens.
        final cardHeight = cardWidth < 170
            ? 122.0
            : cardWidth < 240
            ? 110.0
            : 104.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }
}

String _number(int value) => NumberFormat('#,###').format(value);

class _ModernStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const _ModernStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TraceColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: TraceColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TraceColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: TraceColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TraceColors.textTertiary,
                    fontSize: 8.5,
                    height: 1.2,
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

class _PremiumSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _PremiumSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 16),
      decoration: BoxDecoration(
        color: TraceColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TraceColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.018),
            blurRadius: 22,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: TraceColors.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: TraceColors.accent, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: TraceColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: TraceColors.textTertiary,
                        fontSize: 9.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: TraceColors.border),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

// ============================================================================
// ATTENDANCE BREAKDOWN
// ============================================================================

class _AttendanceBreakdown extends StatefulWidget {
  final _DashboardData data;
  const _AttendanceBreakdown({required this.data});

  @override
  State<_AttendanceBreakdown> createState() => _AttendanceBreakdownState();
}

class _AttendanceBreakdownState extends State<_AttendanceBreakdown> {
  int? _selectedYear;
  String? _selectedEventId;

  List<_EventAttendance> _eventsForYear(int? year) {
    final matching = widget.data.eventAttendance.where((event) {
      if (year == null) return true;
      if (event.eventDate == null) return event.total > 0;
      return _toManila(event.eventDate!).year == year;
    }).toList();

    matching.sort((a, b) {
      final aHasData = a.total > 0;
      final bHasData = b.total > 0;
      if (aHasData != bHasData) return aHasData ? -1 : 1;
      if (a.eventDate == null && b.eventDate == null) return 0;
      if (a.eventDate == null) return 1;
      if (b.eventDate == null) return -1;
      return b.eventDate!.compareTo(a.eventDate!);
    });
    return matching;
  }

  _EventAttendance? _defaultEventForYear(int? year) {
    final events = _eventsForYear(year);
    if (events.isEmpty) return null;
    for (final event in events) {
      if (event.total > 0) return event;
    }
    return events.first;
  }

  @override
  void initState() {
    super.initState();

    final defaultEvent = _defaultEventForYear(null);
    final years = widget.data.attendanceYears;
    _selectedYear = defaultEvent?.eventDate != null
        ? _toManila(defaultEvent!.eventDate!).year
        : (years.isEmpty ? null : years.first);

    final eventForSelectedYear = _defaultEventForYear(_selectedYear);
    _selectedEventId = eventForSelectedYear?.eventId ?? defaultEvent?.eventId;
  }

  @override
  void didUpdateWidget(covariant _AttendanceBreakdown oldWidget) {
    super.didUpdateWidget(oldWidget);

    final years = widget.data.attendanceYears;
    if (_selectedYear != null && !years.contains(_selectedYear)) {
      final defaultEvent = _defaultEventForYear(null);
      _selectedYear = defaultEvent?.eventDate != null
          ? _toManila(defaultEvent!.eventDate!).year
          : (years.isEmpty ? null : years.first);
    }

    final options = _eventsForYear(_selectedYear);
    if (_selectedEventId == null ||
        !options.any((event) => event.eventId == _selectedEventId)) {
      _selectedEventId = _defaultEventForYear(_selectedYear)?.eventId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventOptions = _eventsForYear(_selectedYear);
    final selectedEventId = eventOptions.any(
          (event) => event.eventId == _selectedEventId,
    )
        ? _selectedEventId
        : _defaultEventForYear(_selectedYear)?.eventId;

    // Counts are read from one event aggregate only. They are not summed
    // across all events, so one event with 41 students can total 41 records.
    _EventAttendance? selectedEvent;
    for (final event in eventOptions) {
      if (event.eventId == selectedEventId) {
        selectedEvent = event;
        break;
      }
    }

    final present = selectedEvent?.present ?? 0;
    final halfDay = selectedEvent?.halfDay ?? 0;
    final absent = selectedEvent?.absent ?? 0;
    final total = present + halfDay + absent;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        return Column(
          children: [
            if (compact)
              Column(
                children: [
                  _yearDropdown(),
                  const SizedBox(height: 10),
                  _eventDropdown(eventOptions, selectedEventId),
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: _yearDropdown()),
                  const SizedBox(width: 10),
                  Expanded(child: _eventDropdown(eventOptions, selectedEventId)),
                ],
              ),
            const SizedBox(height: 14),
            Expanded(
              child: total == 0
                  ? _emptyState()
                  : compact
                  ? _compact(present, halfDay, absent, total)
                  : _wide(present, halfDay, absent, total),
            ),
          ],
        );
      },
    );
  }

  Widget _yearDropdown() {
    final years = widget.data.attendanceYears;
    return DropdownButtonFormField<int?>(
      key: ValueKey('year-${_selectedYear ?? 'all'}'),
      initialValue: years.contains(_selectedYear) ? _selectedYear : null,
      isExpanded: true,
      menuMaxHeight: 300,
      decoration: _dropdownDecoration('Year', Icons.calendar_month_rounded),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('All Years')),
        ...years.map((year) => DropdownMenuItem<int?>(value: year, child: Text('$year'))),
      ],
      onChanged: (value) {
        setState(() {
          _selectedYear = value;
          _selectedEventId = _defaultEventForYear(value)?.eventId;
        });
      },
    );
  }

  Widget _eventDropdown(List<_EventAttendance> events, String? selectedEventId) {
    final safeValue = events.any((event) => event.eventId == selectedEventId)
        ? selectedEventId
        : (events.isEmpty ? null : events.first.eventId);

    return DropdownButtonFormField<String>(
      key: ValueKey('event-${safeValue ?? 'none'}-${_selectedYear ?? 'all'}'),
      initialValue: safeValue,
      isExpanded: true,
      menuMaxHeight: 320,
      hint: const Text('No events available'),
      decoration: _dropdownDecoration('Event', Icons.event_rounded),
      // There is intentionally no All Events option.
      items: events
          .map(
            (event) => DropdownMenuItem<String>(
          value: event.eventId,
          child: Text(
            event.eventName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      )
          .toList(),
      onChanged: events.isEmpty
          ? null
          : (value) {
        if (value == null) return;
        setState(() => _selectedEventId = value);
      },
    );
  }

  InputDecoration _dropdownDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 17, color: TraceColors.accent),
      isDense: true,
      filled: true,
      fillColor: TraceColors.canvas,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: TraceColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: TraceColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: TraceColors.accent, width: 1.2),
      ),
    );
  }

  Widget _wide(int present, int halfDay, int absent, int total) {
    return Row(
      children: [
        Expanded(flex: 3, child: _donut(present, halfDay, absent, total)),
        const SizedBox(width: 26),
        Expanded(flex: 2, child: _summary(present, halfDay, absent, total)),
      ],
    );
  }

  Widget _compact(int present, int halfDay, int absent, int total) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          SizedBox(height: 215, child: _donut(present, halfDay, absent, total)),
          const SizedBox(height: 12),
          _summary(present, halfDay, absent, total),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _donut(int present, int halfDay, int absent, int total) {
    final percent = total == 0 ? 0 : (present / total * 100).round();
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            centerSpaceRadius: 62,
            sectionsSpace: 4,
            sections: [
              _pieSection(present, total, TraceColors.success),
              _pieSection(halfDay, total, TraceColors.warning),
              _pieSection(absent, total, TraceColors.danger),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$percent%', style: const TextStyle(color: TraceColors.textPrimary, fontSize: 25, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            const Text('Present', style: TextStyle(color: TraceColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }

  PieChartSectionData _pieSection(int value, int total, Color color) {
    if (value <= 0 || total <= 0) {
      return PieChartSectionData(
        value: 0,
        color: color.withValues(alpha: 0.05),
        title: '',
        radius: 64,
      );
    }
    return PieChartSectionData(
      value: value.toDouble(),
      color: color,
      radius: 64,
      title: '${(value / total * 100).round()}%',
      titleStyle: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
    );
  }

  Widget _summary(int present, int halfDay, int absent, int total) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryItem(color: TraceColors.success, label: 'Present', value: present, percentage: total == 0 ? 0 : present / total),
        const SizedBox(height: 11),
        _SummaryItem(color: TraceColors.warning, label: 'Half-day', value: halfDay, percentage: total == 0 ? 0 : halfDay / total),
        const SizedBox(height: 11),
        _SummaryItem(color: TraceColors.danger, label: 'Absent', value: absent, percentage: total == 0 ? 0 : absent / total),
        const SizedBox(height: 13),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(color: TraceColors.canvas, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedEventId == null ? 'Total Student-Event Records' : 'Total for This Event',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: TraceColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Text(_number(total), style: const TextStyle(color: TraceColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: TraceColors.accentSoft, shape: BoxShape.circle),
            child: const Icon(Icons.pie_chart_outline_rounded, color: TraceColors.accent, size: 23),
          ),
          const SizedBox(height: 10),
          const Text('No attendance records', style: TextStyle(color: TraceColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('No attendance data matches the selected filters.', textAlign: TextAlign.center, style: TextStyle(color: TraceColors.textTertiary, fontSize: 9)),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  final double percentage;

  const _SummaryItem({required this.color, required this.label, required this.value, required this.percentage});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: const TextStyle(color: TraceColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w700))),
            Text(_number(value), style: const TextStyle(color: TraceColors.textPrimary, fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percentage.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: TraceColors.canvas,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// STUDENTS BY COURSE
// ============================================================================

class _StudentCourseChart extends StatelessWidget {
  final _DashboardData data;
  const _StudentCourseChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.studentCourse.isEmpty) {
      return SuperAdminCommon.empty('No student course data available.', icon: Icons.school_outlined);
    }

    final entries = data.studentCourse.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = entries.map((e) => e.value).fold<int>(1, math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 13),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: TraceColors.accentSoft, borderRadius: BorderRadius.circular(8)),
                        child: Text('${index + 1}', style: const TextStyle(color: TraceColors.accent, fontSize: 9, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          entry.key,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: TraceColors.textPrimary, fontSize: 10, fontWeight: FontWeight.w700, height: 1.25),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${entry.value}', style: const TextStyle(color: TraceColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      value: (entry.value / maxValue).clamp(0.0, 1.0),
                      backgroundColor: TraceColors.canvas,
                      valueColor: const AlwaysStoppedAnimation<Color>(TraceColors.accent),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// EVENTS PAGER AND EVENT ROW
// ============================================================================

class _EventsPager extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> events;
  const _EventsPager({required this.events});

  @override
  State<_EventsPager> createState() => _EventsPagerState();
}

class _EventsPagerState extends State<_EventsPager> {
  static const int pageSize = 5;
  int page = 0;

  int get pageCount => math.max(1, (widget.events.length / pageSize).ceil());

  @override
  void didUpdateWidget(covariant _EventsPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (page >= pageCount) page = math.max(0, pageCount - 1);
  }

  @override
  Widget build(BuildContext context) {
    final safePage = page.clamp(0, pageCount - 1);
    final start = safePage * pageSize;
    final end = math.min(start + pageSize, widget.events.length);
    final visible = widget.events.sublist(start, end);

    if (visible.isEmpty) {
      return SuperAdminCommon.empty('No events found.', icon: Icons.event_busy_rounded);
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(height: 9),
            itemBuilder: (context, index) => _EventRow(doc: visible[index]),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Page ${safePage + 1} of $pageCount', style: const TextStyle(color: TraceColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w700)),
            Row(
              children: [
                IconButton(
                  onPressed: safePage > 0 ? () => setState(() => page--) : null,
                  icon: const Icon(Icons.chevron_left_rounded, size: 19),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: safePage < pageCount - 1 ? () => setState(() => page++) : null,
                  icon: const Icon(Icons.chevron_right_rounded, size: 19),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _EventRow({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final name = _readText(data, const ['eventName', 'name', 'title']).isEmpty
        ? 'Untitled Event'
        : _readText(data, const ['eventName', 'name', 'title']);
    final venue = _readText(data, const ['venue', 'location', 'eventVenue']);
    final startDate = _parseEventStartDate(data);
    final event = _EventAttendance(
      eventId: doc.id,
      eventName: name,
      eventDate: startDate,
      eventEndDate: _parseEventEndDate(data),
      storedStatus: (data['status'] ?? '').toString(),
      present: 0,
      halfDay: 0,
      absent: 0,
    );
    final displayStatus = _getEventDisplayStatus(event);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: TraceColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TraceColors.border.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          Container(
            width: 37,
            height: 37,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: TraceColors.accentSoft, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.event_rounded, color: TraceColors.accent, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: TraceColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.2)),
                const SizedBox(height: 4),
                Text(
                  [
                    if (startDate != null) DateFormat('MMM d, yyyy').format(_toManila(startDate)),
                    if (venue.isNotEmpty) venue,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: TraceColors.textTertiary, fontSize: 8.5, height: 1.2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _EventStatusChip(status: displayStatus),
        ],
      ),
    );
  }
}

enum EventDisplayStatus { completed, active, upcoming }

String _eventStatusText(EventDisplayStatus status) {
  switch (status) {
    case EventDisplayStatus.completed:
      return 'Completed';
    case EventDisplayStatus.active:
      return 'Active';
    case EventDisplayStatus.upcoming:
      return 'Upcoming';
  }
}

EventDisplayStatus _getEventDisplayStatus(_EventAttendance event) {
  final now = _nowInManila();
  final start = event.eventDate == null ? null : _toManila(event.eventDate!);
  final end = event.eventEndDate == null ? null : _toManila(event.eventEndDate!);
  final stored = _norm(event.storedStatus);

  if ({'completed', 'complete', 'done', 'finished', 'closed'}.contains(stored)) {
    return EventDisplayStatus.completed;
  }
  if (start != null && end != null) {
    if (!now.isBefore(end)) return EventDisplayStatus.completed;
    if (!now.isBefore(start)) return EventDisplayStatus.active;
    return EventDisplayStatus.upcoming;
  }
  if (start != null) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(start.year, start.month, start.day);
    if (day.isBefore(today)) return EventDisplayStatus.completed;
    if (day.isAtSameMomentAs(today)) return EventDisplayStatus.active;
    return EventDisplayStatus.upcoming;
  }
  if ({'active', 'ongoing', 'on-going', 'in progress'}.contains(stored)) {
    return EventDisplayStatus.active;
  }
  return EventDisplayStatus.upcoming;
}

class _EventStatusChip extends StatelessWidget {
  final EventDisplayStatus status;
  const _EventStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    late Color foreground;
    late Color background;
    late IconData icon;
    switch (status) {
      case EventDisplayStatus.completed:
        foreground = TraceColors.textSecondary;
        background = TraceColors.border.withValues(alpha: 0.55);
        icon = Icons.check_circle_rounded;
        break;
      case EventDisplayStatus.active:
        foreground = TraceColors.success;
        background = TraceColors.success.withValues(alpha: 0.11);
        icon = Icons.radio_button_checked_rounded;
        break;
      case EventDisplayStatus.upcoming:
        foreground = TraceColors.accent;
        background = TraceColors.accent.withValues(alpha: 0.10);
        icon = Icons.schedule_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground, size: 11),
          const SizedBox(width: 4),
          Text(_eventStatusText(status), style: TextStyle(color: foreground, fontSize: 8, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ============================================================================
// HEADER
// ============================================================================

class _Header extends StatefulWidget {
  final String name;
  const _Header({required this.name});

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  DateTime? _manilaNow;
  Timer? _timer;
  static const String _timeApiUrl = 'https://gettimeapi.dev/v1/time?timezone=Asia/Manila';

  @override
  void initState() {
    super.initState();
    _loadManilaTime();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _loadManilaTime());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadManilaTime() async {
    try {
      final response = await http.get(Uri.parse(_timeApiUrl)).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) throw Exception('Time API unavailable');
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw Exception('Invalid time response');
      final date = decoded['date']?.toString();
      final time = decoded['time']?.toString();
      if (date == null || time == null) throw Exception('Missing date/time');
      final parsed = DateTime.tryParse('$date $time');
      if (parsed == null) throw Exception('Invalid date/time');
      if (!mounted) return;
      setState(() => _manilaNow = parsed);
    } catch (_) {
      if (!mounted) return;
      setState(() => _manilaNow = _nowInManila());
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = _manilaNow ?? _nowInManila();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_greeting(now), style: const TextStyle(color: TraceColors.textTertiary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
        const SizedBox(height: 6),
        Text(
          'Welcome back${widget.name.trim().isEmpty ? '' : ', ${widget.name}'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: TraceColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.7),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 12, color: TraceColors.textTertiary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${DateFormat('EEEE, MMMM d, yyyy').format(now)} · Philippine Standard Time',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: TraceColors.textSecondary, fontSize: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _greeting(DateTime time) {
    if (time.hour < 12) return 'GOOD MORNING';
    if (time.hour < 18) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }
}

// ============================================================================
// ERROR VIEW
// ============================================================================

class _DashboardErrorView extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  const _DashboardErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final errorText = error.toString();
    final permissionError = errorText.contains('permission-denied') ||
        errorText.contains('PERMISSION_DENIED') ||
        errorText.contains('Missing or insufficient permissions');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: TraceColors.dangerSoft, shape: BoxShape.circle),
              child: Icon(permissionError ? Icons.lock_outline_rounded : Icons.error_outline_rounded, color: TraceColors.danger, size: 27),
            ),
            const SizedBox(height: 15),
            Text(
              permissionError ? 'Dashboard access is blocked' : 'Unable to load dashboard data.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: TraceColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              permissionError
                  ? 'Firestore Security Rules are not allowing the signed-in super admin to read users, events, or attendance.'
                  : 'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: TraceColors.textTertiary, fontSize: 10.5, height: 1.4),
            ),
            if (permissionError) ...[
              const SizedBox(height: 8),
              const Text('Update Firestore Rules, then restart the app.', textAlign: TextAlign.center, style: TextStyle(color: TraceColors.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 17),
            ElevatedButton(onPressed: onRetry, style: SuperAdminCommon.primaryButtonStyle(), child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DATE / STATUS HELPERS
// ============================================================================

enum AttendanceStatus { present, halfDay, absent }

AttendanceStatus? _explicitAttendanceStatus(Map<String, dynamic> data) {
  final values = [
    data['attendanceStatus'],
    data['attendance_status'],
    data['attendance-status'],
    data['attendanceType'],
    data['attendance_type'],
    data['recordStatus'],
    data['record_status'],
    data['status'],
  ];

  for (final value in values) {
    if (value == null) continue;
    var status = _norm(value.toString()).replaceAll('_', ' ').replaceAll('-', ' ');
    if (status.isEmpty || status == 'null' || status == 'pending' || status == 'not marked') continue;
    if (status.contains('half day') || status.contains('halfday') || status.contains('partial')) {
      return AttendanceStatus.halfDay;
    }
    if (status == 'absent' || status == 'a' || status.contains('marked absent')) {
      return AttendanceStatus.absent;
    }
    if (status == 'present' ||
        status == 'p' ||
        status.contains('present') ||
        status == 'late' ||
        status == 'checked in' ||
        status == 'checked-in' ||
        status == 'time in' ||
        status == 'checked') {
      return AttendanceStatus.present;
    }
  }
  return null;
}

AttendanceStatus _normalizeAttendanceStatus(Map<String, dynamic> data) {
  final explicit = _explicitAttendanceStatus(data);
  if (explicit != null) return explicit;

  // A time-in is positive evidence of attendance even when an old record
  // has no explicit status field or stores it under a different key.
  if (_parseDate(_firstValue(data, const ['timeIn', 'time_in', 'checkIn', 'checkInTime'])) != null) {
    return AttendanceStatus.present;
  }
  return AttendanceStatus.absent;
}

dynamic _firstValue(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value != null) return value;
  }
  return null;
}

DateTime? _activityDate(Map<String, dynamic> data) {
  for (final key in const [
    'timeIn',
    'time_in',
    'checkIn',
    'checkInTime',
    'timeOut',
    'time_out',
    'checkOut',
    'checkOutTime',
    'createdAt',
    'timestamp',
    'markedAt',
    'date',
    'updatedAt',
  ]) {
    final parsed = _parseDate(data[key]);
    if (parsed != null) return parsed;
  }
  return null;
}

DateTime? _parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) {
    // Accept epoch milliseconds, not small year-like values.
    if (value > 1000000000) return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is String && value.trim().isNotEmpty) {
    final trimmed = value.trim();
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) return parsed;
    for (final pattern in const ['M/d/yyyy', 'MM/dd/yyyy', 'd/M/yyyy', 'dd/MM/yyyy']) {
      try {
        return DateFormat(pattern).parseStrict(trimmed);
      } catch (_) {
        // Try the next supported date format.
      }
    }
  }
  return null;
}

DateTime? _parseEventStartDate(Map<String, dynamic>? data) {
  if (data == null) return null;
  for (final key in const [
    'eventDate',
    'event_date',
    'startDate',
    'start_date',
    'eventStart',
    'eventStartDate',
    'startTime',
    'startAt',
    'date',
  ]) {
    final parsed = _parseDate(data[key]);
    if (parsed != null) return parsed;
  }
  return null;
}

DateTime? _parseEventEndDate(Map<String, dynamic>? data) {
  if (data == null) return null;
  for (final key in const ['endDate', 'end_date', 'eventEnd', 'eventEndDate', 'endTime', 'endAt']) {
    final parsed = _parseDate(data[key]);
    if (parsed != null) return parsed;
  }
  return null;
}

DateTime _toManila(DateTime value) => value.toUtc().add(const Duration(hours: 8));

// ============================================================================
// BOTTOM GRID
// ============================================================================

class _BottomGrid extends StatelessWidget {
  final _DashboardData data;
  const _BottomGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final topCourse = _largest(data.studentCourse);
    final subtitle = data.studentCourse.isEmpty
        ? 'No course information available in student profiles.'
        : 'Largest course: ${topCourse?.key} (${topCourse?.value} students)';

    final courses = _PremiumSection(
      title: 'Students by Course',
      subtitle: subtitle,
      icon: Icons.school_outlined,
      child: SizedBox(height: 350, child: _StudentCourseChart(data: data)),
    );
    final events = _PremiumSection(
      title: 'Events',
      subtitle: 'Showing 5 events per page.',
      icon: Icons.calendar_month_rounded,
      child: SizedBox(height: 350, child: _EventsPager(events: data.events)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(children: [courses, const SizedBox(height: 18), events]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: courses), const SizedBox(width: 18), Expanded(child: events)],
        );
      },
    );
  }
}

MapEntry<String, int>? _largest(Map<String, int> map) {
  if (map.isEmpty) return null;
  final values = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return values.first;
}

// ============================================================================
// DATA CLASSES
// ============================================================================

class _StudentRecord {
  final String key;
  final String fullName;
  final String course;
  final String college;
  final Set<String> aliases;

  const _StudentRecord({
    required this.key,
    required this.fullName,
    required this.course,
    required this.college,
    required this.aliases,
  });
}

class _RawAttendance {
  final String attendanceId;
  final String eventId;
  final String? studentKey;
  final AttendanceStatus status;
  final DateTime? date;
  final bool hasExplicitStatus;
  final bool hasTimeIn;

  const _RawAttendance({
    required this.attendanceId,
    required this.eventId,
    required this.studentKey,
    required this.status,
    required this.date,
    required this.hasExplicitStatus,
    required this.hasTimeIn,
  });
}

class _AttendanceRecord {
  final String attendanceId;
  final String eventId;
  final String? studentKey;
  final AttendanceStatus status;
  final DateTime? date;
  final int? year;

  const _AttendanceRecord({
    required this.attendanceId,
    required this.eventId,
    required this.studentKey,
    required this.status,
    required this.date,
    required this.year,
  });
}

class _EventAttendance {
  final String eventId;
  final String eventName;
  final DateTime? eventDate;
  final DateTime? eventEndDate;
  final String storedStatus;
  final int present;
  final int halfDay;
  final int absent;

  const _EventAttendance({
    required this.eventId,
    required this.eventName,
    required this.eventDate,
    required this.eventEndDate,
    required this.storedStatus,
    required this.present,
    required this.halfDay,
    required this.absent,
  });

  int get total => present + halfDay + absent;
}

class _DashboardData {
  final int totalUsers;
  final int totalStudents;
  final int totalEvents;
  final int totalAttendance;
  final int todayAttendance;
  final int present;
  final int halfDay;
  final int absent;
  final Map<String, int> studentCourse;
  final Map<String, int> studentCollege;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> events;
  final List<_EventAttendance> eventAttendance;
  final List<_AttendanceRecord> attendanceRecords;
  final List<int> attendanceYears;

  const _DashboardData({
    required this.totalUsers,
    required this.totalStudents,
    required this.totalEvents,
    required this.totalAttendance,
    required this.todayAttendance,
    required this.present,
    required this.halfDay,
    required this.absent,
    required this.studentCourse,
    required this.studentCollege,
    required this.events,
    required this.eventAttendance,
    required this.attendanceRecords,
    required this.attendanceYears,
  });

  factory _DashboardData.empty() => const _DashboardData(
    totalUsers: 0,
    totalStudents: 0,
    totalEvents: 0,
    totalAttendance: 0,
    todayAttendance: 0,
    present: 0,
    halfDay: 0,
    absent: 0,
    studentCourse: {},
    studentCollege: {},
    events: [],
    eventAttendance: [],
    attendanceRecords: [],
    attendanceYears: [],
  );
}