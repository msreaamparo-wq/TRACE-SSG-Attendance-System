import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'super_admin_common.dart';

const String _allColleges = 'All Colleges';
const String _allCourses = 'All Courses';
const String _allEvents = 'All Events';
const String _allYears = 'All Year Levels';

// ================================================================
// YEAR LEVEL HELPERS
// ================================================================

String _normalizeYearLevel(String value) {
  final text = value.trim().toLowerCase();

  if (text.isEmpty) return 'Unspecified';

  if (text == '1' ||
      text == '1st' ||
      text == '1st year' ||
      text == 'first' ||
      text == 'first year' ||
      text.contains('first year')) {
    return '1st Year';
  }

  if (text == '2' ||
      text == '2nd' ||
      text == '2nd year' ||
      text == 'second' ||
      text == 'second year' ||
      text.contains('second year')) {
    return '2nd Year';
  }

  if (text == '3' ||
      text == '3rd' ||
      text == '3rd year' ||
      text == 'third' ||
      text == 'third year' ||
      text.contains('third year')) {
    return '3rd Year';
  }

  if (text == '4' ||
      text == '4th' ||
      text == '4th year' ||
      text == 'fourth' ||
      text == 'fourth year' ||
      text.contains('fourth year')) {
    return '4th Year';
  }

  return value.trim();
}

int _yearLevelRank(String value) {
  switch (_normalizeYearLevel(value)) {
    case '1st Year':
      return 1;
    case '2nd Year':
      return 2;
    case '3rd Year':
      return 3;
    case '4th Year':
      return 4;
    default:
      return 99;
  }
}

const List<String> _yearLevelOrder = [
  '1st Year',
  '2nd Year',
  '3rd Year',
  '4th Year',
];

// ================================================================
// REPORT RECORD
// ================================================================

class _ReportRecord {
  final String attendanceId;
  final String studentName;
  final String studentId;
  final String college;
  final String course;
  final String yearLevel;
  final String eventName;
  final String eventId;
  final DateTime? timeIn;
  final DateTime? timeOut;
  final String status;

  const _ReportRecord({
    required this.attendanceId,
    required this.studentName,
    required this.studentId,
    required this.college,
    required this.course,
    required this.yearLevel,
    required this.eventName,
    required this.eventId,
    required this.timeIn,
    required this.timeOut,
    required this.status,
  });
}

// ================================================================
// OPTIONS
// ================================================================

class _ReportOptions {
  final List<String> colleges;
  final List<String> courses;
  final List<String> events;
  final List<String> years;

  const _ReportOptions({
    required this.colleges,
    required this.courses,
    required this.events,
    required this.years,
  });

  factory _ReportOptions.from(List<_ReportRecord> records) {
    final colleges = records
        .map((e) => e.college)
        .where((e) => e.trim().isNotEmpty && e != 'Unspecified')
        .toSet()
        .toList()
      ..sort();

    final courses = records
        .map((e) => e.course)
        .where((e) => e.trim().isNotEmpty && e != 'Unspecified')
        .toSet()
        .toList()
      ..sort();

    final events = records
        .map((e) => e.eventName)
        .where((e) => e.trim().isNotEmpty && e != 'Unknown Event')
        .toSet()
        .toList()
      ..sort();

    final years = records
        .map((e) => _normalizeYearLevel(e.yearLevel))
        .where((e) => e != 'Unspecified')
        .toSet()
        .toList()
      ..sort(
            (a, b) => _yearLevelRank(a).compareTo(_yearLevelRank(b)),
      );

    return _ReportOptions(
      colleges: colleges,
      courses: courses,
      events: events,
      years: years,
    );
  }
}

// ================================================================
// SCREEN
// ================================================================

class SuperAdminReportsScreen extends StatefulWidget {
  const SuperAdminReportsScreen({super.key});

  @override
  State<SuperAdminReportsScreen> createState() =>
      _SuperAdminReportsScreenState();
}

class _SuperAdminReportsScreenState
    extends State<SuperAdminReportsScreen> {
  String _college = _allColleges;
  String _course = _allCourses;
  String _event = _allEvents;
  String _year = _allYears;

  late Future<List<_ReportRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _recordsFuture = _loadReportRecords();
  }

  // ==============================================================
  // LOAD REPORT DATA
  // ==============================================================

  Future<List<_ReportRecord>> _loadReportRecords() async {
    final firestore = FirebaseFirestore.instance;

    final attendanceSnapshot =
    await firestore.collection('attendance').limit(5000).get();

    if (attendanceSnapshot.docs.isEmpty) {
      return [];
    }

    final userIds = <String>{};
    final studentIds = <String>{};
    final eventIds = <String>{};

    for (final doc in attendanceSnapshot.docs) {
      final data = doc.data();

      final userId = (data['userId'] ?? '').toString().trim();
      final studentId = (data['studentId'] ?? '').toString().trim();
      final eventId = (data['eventId'] ?? '').toString().trim();

      if (userId.isNotEmpty) userIds.add(userId);
      if (studentId.isNotEmpty) studentIds.add(studentId);
      if (eventId.isNotEmpty) eventIds.add(eventId);
    }

    // ============================================================
    // FETCH STUDENTS
    // ============================================================

    final usersById = <String, Map<String, dynamic>>{};
    final usersByStudentId = <String, Map<String, dynamic>>{};

    for (final userId in userIds) {
      try {
        final doc =
        await firestore.collection('users').doc(userId).get();

        if (!doc.exists) continue;

        final data = doc.data();
        if (data == null) continue;

        final role =
        (data['role'] ?? '').toString().trim().toLowerCase();

        if (role == 'student') {
          usersById[userId] = data;
        }
      } catch (_) {
        continue;
      }
    }

    // Fallback when attendance.userId does not equal the user doc id.
    if (studentIds.isNotEmpty) {
      final studentList = studentIds.toList();

      for (int start = 0; start < studentList.length; start += 10) {
        final end = start + 10 > studentList.length
            ? studentList.length
            : start + 10;

        final chunk = studentList.sublist(start, end);

        try {
          final snapshot = await firestore
              .collection('users')
              .where('studentId', whereIn: chunk)
              .get();

          for (final doc in snapshot.docs) {
            final data = doc.data();

            final role =
            (data['role'] ?? '').toString().trim().toLowerCase();

            if (role != 'student') continue;

            final studentId =
            (data['studentId'] ?? '').toString().trim();

            if (studentId.isNotEmpty) {
              usersByStudentId[studentId] = data;
            }
          }
        } catch (_) {
          continue;
        }
      }
    }

    // ============================================================
    // FETCH EVENTS
    // ============================================================

    final eventsById = <String, Map<String, dynamic>>{};

    for (final eventId in eventIds) {
      try {
        final doc =
        await firestore.collection('events').doc(eventId).get();

        if (!doc.exists) continue;

        final data = doc.data();
        if (data != null) {
          eventsById[eventId] = data;
        }
      } catch (_) {
        continue;
      }
    }

    // ============================================================
    // JOIN DATA
    // ============================================================

    final records = <_ReportRecord>[];

    for (final attendanceDoc in attendanceSnapshot.docs) {
      final attendance = attendanceDoc.data();

      final userId =
      (attendance['userId'] ?? '').toString().trim();
      final studentId =
      (attendance['studentId'] ?? '').toString().trim();
      final eventId =
      (attendance['eventId'] ?? '').toString().trim();

      Map<String, dynamic>? userData = usersById[userId];
      userData ??= usersByStudentId[studentId];

      if (userData == null) {
        continue;
      }

      final eventData = eventsById[eventId];

      final studentName =
      (userData['fullName'] ?? '').toString().trim();

      final resolvedStudentId =
      (userData['studentId'] ?? studentId).toString().trim();

      final college =
      (userData['college'] ?? '').toString().trim();

      final course =
      (userData['course'] ?? '').toString().trim();

      final yearLevel = _normalizeYearLevel(
        (userData['yearLevel'] ?? '').toString(),
      );

      final eventName =
      (eventData?['eventName'] ?? '').toString().trim();

      final timeIn = _parseDate(attendance['timeIn']);
      final timeOut = _parseDate(attendance['timeOut']);

      final rawStatus =
      (attendance['attendanceStatus'] ?? 'absent')
          .toString()
          .trim()
          .toLowerCase();

      records.add(
        _ReportRecord(
          attendanceId: attendanceDoc.id,
          studentName:
          studentName.isEmpty ? 'Unknown Student' : studentName,
          studentId: resolvedStudentId,
          college: college.isEmpty ? 'Unspecified' : college,
          course: course.isEmpty ? 'Unspecified' : course,
          yearLevel: yearLevel,
          eventName:
          eventName.isEmpty ? 'Unknown Event' : eventName,
          eventId: eventId,
          timeIn: timeIn,
          timeOut: timeOut,
          status: _displayStatus(rawStatus),
        ),
      );
    }

    _sortRecords(records);

    return records;
  }

  static void _sortRecords(List<_ReportRecord> records) {
    records.sort((a, b) {
      final yearCompare =
      _yearLevelRank(a.yearLevel).compareTo(_yearLevelRank(b.yearLevel));

      if (yearCompare != 0) return yearCompare;

      final nameCompare = a.studentName
          .toLowerCase()
          .compareTo(b.studentName.toLowerCase());

      if (nameCompare != 0) return nameCompare;

      return a.eventName.toLowerCase().compareTo(
        b.eventName.toLowerCase(),
      );
    });
  }

  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }

    return null;
  }

  String _displayStatus(String status) {
    switch (status) {
      case 'present':
        return 'Present';
      case 'half-day':
        return 'Half-day';
      case 'absent':
      default:
        return 'Absent';
    }
  }

  // ==============================================================
  // FILTER
  // ==============================================================

  List<_ReportRecord> _applyFilters(List<_ReportRecord> records) {
    final filtered = records.where((record) {
      if (_college != _allColleges && record.college != _college) {
        return false;
      }

      if (_course != _allCourses && record.course != _course) {
        return false;
      }

      if (_event != _allEvents && record.eventName != _event) {
        return false;
      }

      if (_year != _allYears &&
          _normalizeYearLevel(record.yearLevel) !=
              _normalizeYearLevel(_year)) {
        return false;
      }

      return true;
    }).toList();

    _sortRecords(filtered);
    return filtered;
  }

  List<String> _coursesForCollege(List<_ReportRecord> records) {
    final courses = records
        .where(
          (record) =>
      _college == _allColleges || record.college == _college,
    )
        .map((record) => record.course)
        .where((course) => course != 'Unspecified')
        .toSet()
        .toList()
      ..sort();

    return courses;
  }

  Map<String, List<_ReportRecord>> _groupByYearLevel(
      List<_ReportRecord> records,
      ) {
    final grouped = <String, List<_ReportRecord>>{
      '1st Year': [],
      '2nd Year': [],
      '3rd Year': [],
      '4th Year': [],
    };

    for (final record in records) {
      final year = _normalizeYearLevel(record.yearLevel);

      if (grouped.containsKey(year)) {
        grouped[year]!.add(record);
      }
    }

    for (final key in grouped.keys) {
      _sortRecords(grouped[key]!);
    }

    return grouped;
  }

  // ==============================================================
  // REFRESH
  // ==============================================================

  void _refresh() {
    setState(() {
      _recordsFuture = _loadReportRecords();
    });
  }

  // ==============================================================
  // REVIEW
  // ==============================================================

  Future<void> _reviewReport(List<_ReportRecord> records) async {
    if (records.isEmpty) {
      SuperAdminCommon.snack(
        context,
        'No attendance records match the selected filters.',
        error: true,
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _ReportReviewDialog(
          records: records,
          course: _course,
          event: _event,
          year: _year,
          onPdf: () async {
            Navigator.pop(dialogContext);
            await _exportPdf(records);
          },
          onExcel: () async {
            Navigator.pop(dialogContext);
            await _exportExcel(records);
          },
        );
      },
    );
  }

  // ==============================================================
  // PDF
  // ==============================================================

  Future<void> _exportPdf(List<_ReportRecord> records) async {
    try {
      final document = pw.Document();

      final present =
          records.where((e) => e.status == 'Present').length;
      final halfDay =
          records.where((e) => e.status == 'Half-day').length;
      final absent =
          records.where((e) => e.status == 'Absent').length;

      final grouped = _groupByYearLevel(records);

      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(28),
          build: (context) {
            final widgets = <pw.Widget>[
              pw.Text(
                'Attendance Report',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Generated: ${_formatGeneratedDate()}',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Course: $_course   •   Event: $_event   •   Year Level: $_year',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.grey300,
                  ),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _pdfSummary(
                      'Total',
                      records.length.toString(),
                    ),
                    _pdfSummary(
                      'Present',
                      present.toString(),
                    ),
                    _pdfSummary(
                      'Half-day',
                      halfDay.toString(),
                    ),
                    _pdfSummary(
                      'Absent',
                      absent.toString(),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),
            ];

            for (final yearLevel in _yearLevelOrder) {
              final yearRecords = grouped[yearLevel] ?? [];
              if (yearRecords.isEmpty) continue;

              widgets.addAll([
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  child: pw.Text(
                    '$yearLevel Students',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.TableHelper.fromTextArray(
                  headers: const [
                    'Student',
                    'Course',
                    'Event',
                    'Status',
                    'Date',
                    'Time In',
                    'Time Out',
                  ],
                  data: yearRecords
                      .map(
                        (record) => [
                      record.studentName,
                      record.course,
                      record.eventName,
                      record.status,
                      _formatDate(
                        record.timeIn ?? record.timeOut,
                      ),
                      _formatTime(record.timeIn),
                      _formatTime(record.timeOut),
                    ],
                  )
                      .toList(),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 7.5,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 7),
                  cellPadding: const pw.EdgeInsets.all(4),
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 0.5,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                  ),
                ),
                pw.SizedBox(height: 14),
              ]);
            }

            final otherRecords = records.where((record) {
              return !_yearLevelOrder.contains(
                _normalizeYearLevel(record.yearLevel),
              );
            }).toList();

            if (otherRecords.isNotEmpty) {
              widgets.addAll([
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  child: pw.Text(
                    'Other Students',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.TableHelper.fromTextArray(
                  headers: const [
                    'Student',
                    'Course',
                    'Event',
                    'Status',
                    'Date',
                    'Time In',
                    'Time Out',
                  ],
                  data: otherRecords
                      .map(
                        (record) => [
                      record.studentName,
                      record.course,
                      record.eventName,
                      record.status,
                      _formatDate(
                        record.timeIn ?? record.timeOut,
                      ),
                      _formatTime(record.timeIn),
                      _formatTime(record.timeOut),
                    ],
                  )
                      .toList(),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 7.5,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 7),
                  cellPadding: const pw.EdgeInsets.all(4),
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 0.5,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                  ),
                ),
              ]);
            }

            return widgets;
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => document.save(),
      );
    } catch (_) {
      if (!mounted) return;

      SuperAdminCommon.snack(
        context,
        'Unable to generate PDF report.',
        error: true,
      );
    }
  }

  // ==============================================================
  // EXCEL
  // ==============================================================

  Future<void> _exportExcel(List<_ReportRecord> records) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Attendance'];
      final grouped = _groupByYearLevel(records);

      bool firstSection = true;

      for (final yearLevel in _yearLevelOrder) {
        final yearRecords = grouped[yearLevel] ?? [];
        if (yearRecords.isEmpty) continue;

        if (!firstSection) {
          sheet.appendRow([]);
          sheet.appendRow([]);
        }

        firstSection = false;

        sheet.appendRow([
          '$yearLevel Students',
        ]);

        sheet.appendRow([
          'Student',
          'Course',
          'Event',
          'Status',
          'Date',
          'Time In',
          'Time Out',
        ]);

        for (final record in yearRecords) {
          sheet.appendRow([
            record.studentName,
            record.course,
            record.eventName,
            record.status,
            _formatDate(record.timeIn ?? record.timeOut),
            _formatTime(record.timeIn),
            _formatTime(record.timeOut),
          ]);
        }
      }

      final otherRecords = records.where((record) {
        return !_yearLevelOrder.contains(
          _normalizeYearLevel(record.yearLevel),
        );
      }).toList();

      if (otherRecords.isNotEmpty) {
        if (!firstSection) {
          sheet.appendRow([]);
          sheet.appendRow([]);
        }

        sheet.appendRow([
          'Other Students',
        ]);

        sheet.appendRow([
          'Student',
          'Course',
          'Event',
          'Status',
          'Date',
          'Time In',
          'Time Out',
        ]);

        for (final record in otherRecords) {
          sheet.appendRow([
            record.studentName,
            record.course,
            record.eventName,
            record.status,
            _formatDate(record.timeIn ?? record.timeOut),
            _formatTime(record.timeIn),
            _formatTime(record.timeOut),
          ]);
        }
      }

      final List<int>? bytes = excel.encode();

      if (bytes == null) {
        throw Exception('Unable to create Excel file.');
      }

      final fileBytes = Uint8List.fromList(bytes);

      final Uri? savedFile = await FilePicker.saveFile(
        dialogTitle: 'Save Attendance Report',
        fileName: 'attendance_report.xlsx',
        bytes: fileBytes,
      );

      if (!mounted) return;

      if (savedFile != null) {
        SuperAdminCommon.snack(
          context,
          'Excel report saved successfully.',
        );
      }
    } catch (_) {
      if (!mounted) return;

      SuperAdminCommon.snack(
        context,
        'Unable to export Excel report.',
        error: true,
      );
    }
  }

  // ==============================================================
  // FORMATTERS
  // ==============================================================

  String _formatDate(DateTime? date) {
    if (date == null) return '—';

    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');

    return '$m/$d/${date.year}';
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '—';

    final hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $suffix';
  }

  String _formatGeneratedDate() {
    final now = DateTime.now();

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  pw.Widget _pdfSummary(String title, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          title,
          style: const pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey600,
          ),
        ),
      ],
    );
  }

  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TraceColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final horizontalPadding = width < 520
                ? 12.0
                : width < 900
                ? 18.0
                : 28.0;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                width < 520 ? 16 : 22,
                horizontalPadding,
                32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: width < 1200 ? width : 1120,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _PageHeader(),
                      const SizedBox(height: 20),
                      FutureBuilder<List<_ReportRecord>>(
                        future: _recordsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const _ReportCardLoading();
                          }

                          if (snapshot.hasError) {
                            return _ReportCardError(
                              onRetry: _refresh,
                            );
                          }

                          final records = snapshot.data ?? [];
                          final options =
                          _ReportOptions.from(records);
                          final courses =
                          _coursesForCollege(records);

                          final safeCourse =
                          courses.contains(_course)
                              ? _course
                              : _allCourses;

                          if (_course != safeCourse) {
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) {
                              if (!mounted) return;

                              setState(() {
                                _course = safeCourse;
                              });
                            });
                          }

                          final filtered = _applyFilters(records);

                          return _ReportCard(
                            college: _college,
                            course: safeCourse,
                            event: _event,
                            year: _year,
                            colleges: [
                              _allColleges,
                              ...options.colleges,
                            ],
                            courses: [
                              _allCourses,
                              ...courses,
                            ],
                            events: [
                              _allEvents,
                              ...options.events,
                            ],
                            years: [
                              _allYears,
                              ...options.years,
                            ],
                            matchCount: filtered.length,
                            totalCount: records.length,
                            onCollegeChanged: (value) {
                              setState(() {
                                _college = value;
                                _course = _allCourses;
                              });
                            },
                            onCourseChanged: (value) {
                              setState(() {
                                _course = value;
                              });
                            },
                            onEventChanged: (value) {
                              setState(() {
                                _event = value;
                              });
                            },
                            onYearChanged: (value) {
                              setState(() {
                                _year = value;
                              });
                            },
                            onReviewReport: filtered.isEmpty
                                ? null
                                : () => _reviewReport(filtered),
                          );
                        },
                      ),
                    ],
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

// ================================================================
// PAGE HEADER
// ================================================================

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: TraceColors.accentSoft,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.description_rounded,
            color: TraceColors.accent,
            size: 21,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reports',
                style: TextStyle(
                  color: TraceColors.textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Build, review, and export attendance reports.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: TraceColors.textSecondary,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ================================================================
// REPORT CARD
// ================================================================

class _ReportCard extends StatelessWidget {
  final String college;
  final String course;
  final String event;
  final String year;

  final List<String> colleges;
  final List<String> courses;
  final List<String> events;
  final List<String> years;

  final int matchCount;
  final int totalCount;

  final ValueChanged<String> onCollegeChanged;
  final ValueChanged<String> onCourseChanged;
  final ValueChanged<String> onEventChanged;
  final ValueChanged<String> onYearChanged;

  final VoidCallback? onReviewReport;

  const _ReportCard({
    required this.college,
    required this.course,
    required this.event,
    required this.year,
    required this.colleges,
    required this.courses,
    required this.events,
    required this.years,
    required this.matchCount,
    required this.totalCount,
    required this.onCollegeChanged,
    required this.onCourseChanged,
    required this.onEventChanged,
    required this.onYearChanged,
    required this.onReviewReport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: TraceColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: TraceColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.018),
            blurRadius: 22,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 650;

          final fields = [
            _FilterDropdown(
              label: 'College',
              icon: Icons.account_balance_outlined,
              value: college,
              items: colleges,
              onChanged: onCollegeChanged,
            ),
            _FilterDropdown(
              label: 'Course',
              icon: Icons.school_outlined,
              value: course,
              items: courses,
              onChanged: onCourseChanged,
            ),
            _FilterDropdown(
              label: 'Event',
              icon: Icons.event_outlined,
              value: event,
              items: events,
              onChanged: onEventChanged,
            ),
            _FilterDropdown(
              label: 'Year Level',
              icon: Icons.calendar_today_outlined,
              value: year,
              items: years,
              onChanged: onYearChanged,
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: TraceColors.accentSoft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: TraceColors.accent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Generate Report',
                          style: TextStyle(
                            color: TraceColors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Select the records you want to include.',
                          style: TextStyle(
                            color: TraceColors.textTertiary,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(
                height: 1,
                color: TraceColors.border,
              ),
              const SizedBox(height: 18),
              if (narrow)
                Column(
                  children: [
                    for (int i = 0; i < fields.length; i++) ...[
                      fields[i],
                      if (i != fields.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: fields.map((field) {
                    final itemWidth =
                    constraints.maxWidth >= 1050
                        ? (constraints.maxWidth - 36) / 4
                        : (constraints.maxWidth - 12) / 2;

                    return SizedBox(
                      width: itemWidth,
                      child: field,
                    );
                  }).toList(),
                ),
              const SizedBox(height: 20),
              const Divider(
                height: 1,
                color: TraceColors.border,
              ),
              const SizedBox(height: 16),
              if (narrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryBox(
                      matchCount: matchCount,
                      totalCount: totalCount,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: onReviewReport,
                        icon: const Icon(
                          Icons.preview_rounded,
                          size: 18,
                        ),
                        label: const Text('Review Report'),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    _SummaryBox(
                      matchCount: matchCount,
                      totalCount: totalCount,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 190,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: onReviewReport,
                        icon: const Icon(
                          Icons.preview_rounded,
                          size: 18,
                        ),
                        label: const Text('Review Report'),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

// ================================================================
// SUMMARY BOX
// ================================================================

class _SummaryBox extends StatelessWidget {
  final int matchCount;
  final int totalCount;

  const _SummaryBox({
    required this.matchCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: TraceColors.canvas,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.insert_chart_outlined_rounded,
            size: 16,
            color: TraceColors.textTertiary,
          ),
          const SizedBox(width: 7),
          Text(
            '$matchCount of $totalCount records',
            style: const TextStyle(
              color: TraceColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// FILTER DROPDOWN
// ================================================================

class _FilterDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue =
    items.contains(value) ? value : items.first;

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: TraceColors.textSecondary,
          fontSize: 11,
        ),
        prefixIcon: Icon(
          icon,
          size: 17,
          color: TraceColors.textTertiary,
        ),
        filled: true,
        fillColor: TraceColors.canvas,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: TraceColors.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: TraceColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: TraceColors.accent,
            width: 1.2,
          ),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
            ),
          ),
        ),
      )
          .toList(),
      onChanged: (selected) {
        if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }
}

// ================================================================
// REVIEW DIALOG
// ================================================================

class _ReportReviewDialog extends StatelessWidget {
  final List<_ReportRecord> records;
  final String course;
  final String event;
  final String year;

  final VoidCallback onPdf;
  final VoidCallback onExcel;

  const _ReportReviewDialog({
    required this.records,
    required this.course,
    required this.event,
    required this.year,
    required this.onPdf,
    required this.onExcel,
  });

  Map<String, List<_ReportRecord>> _groupByYearLevel() {
    final grouped = <String, List<_ReportRecord>>{
      '1st Year': [],
      '2nd Year': [],
      '3rd Year': [],
      '4th Year': [],
    };

    for (final record in records) {
      final normalized = _normalizeYearLevel(record.yearLevel);

      if (grouped.containsKey(normalized)) {
        grouped[normalized]!.add(record);
      }
    }

    for (final key in grouped.keys) {
      _sortRecords(grouped[key]!);
    }

    return grouped;
  }

  static void _sortRecords(List<_ReportRecord> list) {
    list.sort((a, b) {
      final yearCompare =
      _yearLevelRank(a.yearLevel).compareTo(_yearLevelRank(b.yearLevel));

      if (yearCompare != 0) return yearCompare;

      final nameCompare = a.studentName
          .toLowerCase()
          .compareTo(b.studentName.toLowerCase());

      if (nameCompare != 0) return nameCompare;

      return a.eventName
          .toLowerCase()
          .compareTo(b.eventName.toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final present =
        records.where((e) => e.status == 'Present').length;
    final halfDay =
        records.where((e) => e.status == 'Half-day').length;
    final absent =
        records.where((e) => e.status == 'Absent').length;

    final grouped = _groupByYearLevel();

    return Dialog(
      backgroundColor: TraceColors.surface,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 18,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = MediaQuery.sizeOf(context).width;
          final height = MediaQuery.sizeOf(context).height;

          final dialogWidth =
          width < 560 ? width - 24 : 1080.0;
          final dialogHeight =
          height < 700 ? height - 36 : 800.0;

          return SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: Padding(
              padding: EdgeInsets.all(
                width < 560 ? 12 : 20,
              ),
              child: Column(
                children: [
                  _ReviewHeader(
                    onClose: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 12),
                  _ReviewFilterSummary(
                    course: course,
                    event: event,
                    year: year,
                  ),
                  const SizedBox(height: 12),
                  _ReviewStats(
                    total: records.length,
                    present: present,
                    halfDay: halfDay,
                    absent: absent,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _GroupedReviewContent(
                      grouped: grouped,
                      records: records,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ReviewActions(
                    onCancel: () => Navigator.pop(context),
                    onExcel: onExcel,
                    onPdf: onPdf,
                    compact: width < 560,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ================================================================
// REVIEW HEADER
// ================================================================

class _ReviewHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _ReviewHeader({
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: TraceColors.accentSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.preview_rounded,
            color: TraceColors.accent,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Review Report',
                style: TextStyle(
                  color: TraceColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Check the selected records before exporting.',
                style: TextStyle(
                  color: TraceColors.textSecondary,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

// ================================================================
// REVIEW FILTER SUMMARY
// ================================================================

class _ReviewFilterSummary extends StatelessWidget {
  final String course;
  final String event;
  final String year;

  const _ReviewFilterSummary({
    required this.course,
    required this.event,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TraceColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: TraceColors.border,
        ),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _ReviewInfo(
            label: 'Course',
            value: course,
          ),
          _ReviewInfo(
            label: 'Event',
            value: event,
          ),
          _ReviewInfo(
            label: 'Year Level',
            value: year,
          ),
        ],
      ),
    );
  }
}

// ================================================================
// REVIEW INFO
// ================================================================

class _ReviewInfo extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewInfo({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: TraceColors.textTertiary,
            fontSize: 10,
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: TraceColors.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// REVIEW STATS
// ================================================================

class _ReviewStats extends StatelessWidget {
  final int total;
  final int present;
  final int halfDay;
  final int absent;

  const _ReviewStats({
    required this.total,
    required this.present,
    required this.halfDay,
    required this.absent,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;

        final items = [
          _ReviewStat(
            label: 'Total',
            value: total.toString(),
          ),
          _ReviewStat(
            label: 'Present',
            value: present.toString(),
          ),
          _ReviewStat(
            label: 'Half-day',
            value: halfDay.toString(),
          ),
          _ReviewStat(
            label: 'Absent',
            value: absent.toString(),
          ),
        ];

        if (compact) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.5,
            children: items,
          );
        }

        return Row(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              Expanded(child: items[i]),
              if (i != items.length - 1)
                const SizedBox(width: 8),
            ],
          ],
        );
      },
    );
  }
}

// ================================================================
// REVIEW STAT
// ================================================================

class _ReviewStat extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: TraceColors.canvas,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: TraceColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: TraceColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: TraceColors.textTertiary,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// GROUPED REVIEW CONTENT
// ================================================================

class _GroupedReviewContent extends StatelessWidget {
  final Map<String, List<_ReportRecord>> grouped;
  final List<_ReportRecord> records;

  const _GroupedReviewContent({
    required this.grouped,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final otherRecords = records.where((record) {
      return !_yearLevelOrder.contains(
        _normalizeYearLevel(record.yearLevel),
      );
    }).toList();

    return Scrollbar(
      thumbVisibility: MediaQuery.sizeOf(context).width > 700,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          for (final yearLevel in _yearLevelOrder)
            if ((grouped[yearLevel] ?? []).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _YearLevelReviewSection(
                  yearLevel: yearLevel,
                  records: grouped[yearLevel]!,
                ),
              ),
          if (otherRecords.isNotEmpty)
            _YearLevelReviewSection(
              yearLevel: 'Other',
              records: otherRecords,
            ),
        ],
      ),
    );
  }
}

// ================================================================
// YEAR LEVEL SECTION
// ================================================================

class _YearLevelReviewSection extends StatelessWidget {
  final String yearLevel;
  final List<_ReportRecord> records;

  const _YearLevelReviewSection({
    required this.yearLevel,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 600;

    return Container(
      decoration: BoxDecoration(
        color: TraceColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: TraceColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            color: TraceColors.accentSoft,
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: TraceColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: TraceColors.accent,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  '$yearLevel Students',
                  style: const TextStyle(
                    color: TraceColors.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: TraceColors.surface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    records.length.toString(),
                    style: const TextStyle(
                      color: TraceColors.accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (mobile)
            _MobileReviewList(records: records)
          else
            _DesktopReviewTable(records: records),
        ],
      ),
    );
  }
}

// ================================================================
// MOBILE REVIEW LIST
// ================================================================

class _MobileReviewList extends StatelessWidget {
  final List<_ReportRecord> records;

  const _MobileReviewList({
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < records.length; i++) ...[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  records[i].studentName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TraceColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  records[i].course,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TraceColors.textSecondary,
                    fontSize: 9.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  records[i].eventName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TraceColors.textSecondary,
                    fontSize: 9.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _recordDate(records[i]),
                        style: const TextStyle(
                          color: TraceColors.textTertiary,
                          fontSize: 8.5,
                        ),
                      ),
                    ),
                    _StatusBadge(
                      status: records[i].status,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (i != records.length - 1)
            const Divider(
              height: 1,
              color: TraceColors.border,
            ),
        ],
      ],
    );
  }

  String _recordDate(_ReportRecord record) {
    final date = record.timeIn ?? record.timeOut;
    if (date == null) return '—';

    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');

    return '$m/$d/${date.year}';
  }
}

// ================================================================
// DESKTOP REVIEW TABLE
// ================================================================

class _DesktopReviewTable extends StatelessWidget {
  final List<_ReportRecord> records;

  const _DesktopReviewTable({
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 760,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
              child: Row(
                children: [
                  _ReviewHeaderCell(
                    text: 'Student',
                    width: 220,
                  ),
                  _ReviewHeaderCell(
                    text: 'Course',
                    width: 180,
                  ),
                  _ReviewHeaderCell(
                    text: 'Event',
                    width: 230,
                  ),
                  _ReviewHeaderCell(
                    text: 'Status',
                    width: 100,
                  ),
                ],
              ),
            ),
            const Divider(
              height: 1,
              color: TraceColors.border,
            ),
            for (int i = 0; i < records.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    _ReviewCell(
                      text: records[i].studentName,
                      width: 220,
                    ),
                    _ReviewCell(
                      text: records[i].course,
                      width: 180,
                    ),
                    _ReviewCell(
                      text: records[i].eventName,
                      width: 230,
                    ),
                    SizedBox(
                      width: 100,
                      child: _StatusBadge(
                        status: records[i].status,
                      ),
                    ),
                  ],
                ),
              ),
              if (i != records.length - 1)
                const Divider(
                  height: 1,
                  color: TraceColors.border,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewHeaderCell extends StatelessWidget {
  final String text;
  final double width;

  const _ReviewHeaderCell({
    required this.text,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          color: TraceColors.textTertiary,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ReviewCell extends StatelessWidget {
  final String text;
  final double width;

  const _ReviewCell({
    required this.text,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: TraceColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

// ================================================================
// STATUS BADGE
// ================================================================

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color color;

    switch (status.toLowerCase()) {
      case 'present':
        color = TraceColors.success;
        break;
      case 'half-day':
        color = TraceColors.warning;
        break;
      case 'absent':
        color = TraceColors.danger;
        break;
      default:
        color = TraceColors.textTertiary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ================================================================
// REVIEW ACTIONS
// ================================================================

class _ReviewActions extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onExcel;
  final VoidCallback onPdf;
  final bool compact;

  const _ReviewActions({
    required this.onCancel,
    required this.onExcel,
    required this.onPdf,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onExcel,
            icon: const Icon(
              Icons.table_chart_rounded,
              size: 17,
            ),
            label: const Text('Export Excel'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: onPdf,
            icon: const Icon(
              Icons.picture_as_pdf_rounded,
              size: 17,
            ),
            label: const Text('Export PDF'),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onExcel,
            icon: const Icon(
              Icons.table_chart_rounded,
              size: 17,
            ),
            label: const Text('Export Excel'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onPdf,
            icon: const Icon(
              Icons.picture_as_pdf_rounded,
              size: 17,
            ),
            label: const Text('Export PDF'),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// LOADING
// ================================================================

class _ReportCardLoading extends StatelessWidget {
  const _ReportCardLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: TraceColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: TraceColors.border,
        ),
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: TraceColors.accent,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Preparing report data...',
            style: TextStyle(
              color: TraceColors.textTertiary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// ERROR
// ================================================================

class _ReportCardError extends StatelessWidget {
  final VoidCallback onRetry;

  const _ReportCardError({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: TraceColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: TraceColors.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SuperAdminCommon.empty(
            'Unable to load report data.',
            icon: Icons.error_outline_rounded,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            style: SuperAdminCommon.primaryButtonStyle(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
