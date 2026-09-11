import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/attendance_model.dart';
import '../models/event_model.dart';
import '../models/user_model.dart';
import 'super_admin_common.dart';

class SuperAdminAttendanceScreen extends StatefulWidget {
  const SuperAdminAttendanceScreen({
    super.key,
  });

  @override
  State<SuperAdminAttendanceScreen> createState() =>
      _SuperAdminAttendanceScreenState();
}

class _SuperAdminAttendanceScreenState
    extends State<SuperAdminAttendanceScreen> {
  static const int _studentsPerPage = 10;

  final TextEditingController _searchController =
  TextEditingController();

  bool _loading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedEventId = 'all';
  String _selectedYear = 'all';
  String _selectedCourse = 'all';

  int _currentPage = 0;

  List<AttendanceModel> _attendanceRecords = [];
  Map<String, UserModel> _usersById = {};
  Map<String, EventModel> _eventsById = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD ALL DATA ONCE
  // ============================================================

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Student')
            .get(),
        FirebaseFirestore.instance
            .collection('events')
            .get(),
        FirebaseFirestore.instance
            .collection('attendance')
            .limit(5000)
            .get(),
      ]);

      final usersSnapshot =
      results[0] as QuerySnapshot<Map<String, dynamic>>;

      final eventsSnapshot =
      results[1] as QuerySnapshot<Map<String, dynamic>>;

      final attendanceSnapshot =
      results[2] as QuerySnapshot<Map<String, dynamic>>;

      final users = <String, UserModel>{};
      final events = <String, EventModel>{};

      for (final doc in usersSnapshot.docs) {
        final user = UserModel.fromFirestore(doc);
        users[user.id] = user;
      }

      for (final doc in eventsSnapshot.docs) {
        final event = EventModel.fromFirestore(doc);
        events[event.id] = event;
      }

      final attendance = attendanceSnapshot.docs
          .map(AttendanceModel.fromFirestore)
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _usersById = users;
        _eventsById = events;
        _attendanceRecords = attendance;
        _loading = false;
        _currentPage = 0;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = 'Unable to load attendance.';
      });
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim().toLowerCase();
      _currentPage = 0;
    });
  }

  // ============================================================
  // EVENT
  // ============================================================

  void _onEventChanged(String value) {
    setState(() {
      _selectedEventId = value;
      _currentPage = 0;
    });
  }

  // ============================================================
  // YEAR
  // ============================================================

  void _onYearChanged(String value) {
    setState(() {
      _selectedYear = value;
      _currentPage = 0;
    });
  }

  // ============================================================
  // COURSE
  // ============================================================

  void _onCourseChanged(String value) {
    setState(() {
      _selectedCourse = value;
      _currentPage = 0;
    });
  }

  // ============================================================
  // CLEAR FILTERS
  // ============================================================

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
      _selectedEventId = 'all';
      _selectedYear = 'all';
      _selectedCourse = 'all';
      _currentPage = 0;
    });
  }

  // ============================================================
  // FILTER STATE
  // ============================================================

  bool get _hasFilters {
    return _searchQuery.isNotEmpty ||
        _selectedEventId != 'all' ||
        _selectedYear != 'all' ||
        _selectedCourse != 'all';
  }

  // ============================================================
  // PREVIOUS PAGE
  // ============================================================

  void _goToPreviousPage() {
    if (_currentPage <= 0) {
      return;
    }

    setState(() {
      _currentPage--;
    });
  }

  // ============================================================
  // NEXT PAGE
  // ============================================================

  void _goToNextPage(int totalPages) {
    if (_currentPage >= totalPages - 1) {
      return;
    }

    setState(() {
      _currentPage++;
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: TraceColors.canvas,
        body: SuperAdminCommon.loading(),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: TraceColors.canvas,
        body: _ErrorState(
          onRetry: _loadData,
        ),
      );
    }

    // ==========================================================
    // OPTIONS
    // ==========================================================

    final courses = _usersById.values
        .map(
          (user) => user.course.trim(),
    )
        .where(
          (course) => course.isNotEmpty,
    )
        .toSet()
        .toList()
      ..sort(
            (a, b) => a.toLowerCase().compareTo(
          b.toLowerCase(),
        ),
      );

    final years = _eventsById.values
        .map(
          (event) => event.eventDate.year,
    )
        .toSet()
        .toList()
      ..sort(
            (a, b) => b.compareTo(a),
      );

    final events = _eventsById.values.toList()
      ..sort(
            (a, b) => a.eventName.toLowerCase().compareTo(
          b.eventName.toLowerCase(),
        ),
      );

    // ==========================================================
    // FILTER RECORDS LOCALLY
    // ==========================================================

    final filteredRecords = _attendanceRecords.where(
          (attendance) {
        final user =
        _usersById[attendance.userId];

        final event =
        _eventsById[attendance.eventId];

        // Student users only.
        if (user == null) {
          return false;
        }

        final studentName =
        user.fullName.trim().toLowerCase();

        final course =
        user.course.trim();

        final matchesSearch =
            _searchQuery.isEmpty ||
                studentName.contains(_searchQuery);

        final matchesEvent =
            _selectedEventId == 'all' ||
                attendance.eventId ==
                    _selectedEventId;

        final matchesYear =
            _selectedYear == 'all' ||
                (event != null &&
                    event.eventDate.year.toString() ==
                        _selectedYear);

        final matchesCourse =
            _selectedCourse == 'all' ||
                course == _selectedCourse;

        return matchesSearch &&
            matchesEvent &&
            matchesYear &&
            matchesCourse;
      },
    ).toList();

    // ==========================================================
    // UNIQUE STUDENTS
    // ==========================================================

    final studentIds = <String>{};

    for (final attendance in filteredRecords) {
      if (_usersById.containsKey(
        attendance.userId,
      )) {
        studentIds.add(
          attendance.userId,
        );
      }
    }

    final sortedStudentIds =
    studentIds.toList()
      ..sort(
            (a, b) {
          final userA = _usersById[a];
          final userB = _usersById[b];

          final nameA =
              userA?.fullName
                  .trim()
                  .toLowerCase() ??
                  '';

          final nameB =
              userB?.fullName
                  .trim()
                  .toLowerCase() ??
                  '';

          return nameA.compareTo(nameB);
        },
      );

    // ==========================================================
    // PAGINATION
    // ==========================================================

    final totalStudents =
        sortedStudentIds.length;

    final totalPages = totalStudents == 0
        ? 0
        : (totalStudents +
        _studentsPerPage -
        1) ~/
        _studentsPerPage;

    if (totalPages > 0 &&
        _currentPage >= totalPages) {
      _currentPage = totalPages - 1;
    }

    final startIndex = totalStudents == 0
        ? 0
        : _currentPage *
        _studentsPerPage;

    final endIndex = math.min(
      startIndex + _studentsPerPage,
      totalStudents,
    );

    final pageStudentIds = totalStudents == 0
        ? <String>[]
        : sortedStudentIds.sublist(
      startIndex,
      endIndex,
    );

    final pageStudentIdSet =
    pageStudentIds.toSet();

    // ==========================================================
    // PAGE RECORDS
    // ==========================================================

    final pageRecords = filteredRecords.where(
          (attendance) {
        return pageStudentIdSet.contains(
          attendance.userId,
        );
      },
    ).toList();

    // ==========================================================
    // COURSE CHART
    // ==========================================================

    final courseCounts = <String, int>{};

    for (final attendance in filteredRecords) {
      final user =
      _usersById[attendance.userId];

      if (user == null) {
        continue;
      }

      final course =
      user.course.trim();

      if (course.isEmpty) {
        continue;
      }

      courseCounts[course] =
          (courseCounts[course] ?? 0) + 1;
    }

    // ==========================================================
    // PAGE
    // ==========================================================

    return Scaffold(
      backgroundColor: TraceColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile =
                constraints.maxWidth < 700;

            return SingleChildScrollView(
              physics:
              const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 28,
                isMobile ? 20 : 28,
                isMobile ? 16 : 28,
                28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints:
                  const BoxConstraints(
                    maxWidth: 1440,
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                    children: [
                      _PageHeader(
                        totalAllRecords:
                        _attendanceRecords
                            .length,
                        totalFilteredRecords:
                        filteredRecords
                            .length,
                        totalStudents:
                        totalStudents,
                      ),
                      const SizedBox(height: 18),
                      _PremiumSection(
                        title:
                        'Attendance by Course',
                        subtitle:
                        _courseSubtitle(
                          filteredRecords.length,
                          _attendanceRecords.length,
                        ),
                        icon:
                        Icons.menu_book_rounded,
                        child: SizedBox(
                          height:
                          isMobile ? 275 : 310,
                          width: double.infinity,
                          child: _CourseChart(
                            values: courseCounts,
                            isMobile: isMobile,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _PremiumSection(
                        title:
                        'Attendance Records',
                        subtitle:
                        _recordsSubtitle(
                          pageStudentIds.length,
                          totalStudents,
                        ),
                        icon:
                        Icons.fact_check_rounded,
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                          children: [
                            _FilterPanel(
                              searchController:
                              _searchController,
                              searchQuery:
                              _searchQuery,
                              selectedEventId:
                              _selectedEventId,
                              selectedYear:
                              _selectedYear,
                              selectedCourse:
                              _selectedCourse,
                              events: events,
                              years: years,
                              courses: courses,
                              hasFilters:
                              _hasFilters,
                              onSearchChanged:
                              _onSearchChanged,
                              onEventChanged:
                              _onEventChanged,
                              onYearChanged:
                              _onYearChanged,
                              onCourseChanged:
                              _onCourseChanged,
                              onClear:
                              _clearFilters,
                            ),
                            const SizedBox(height: 14),
                            const Divider(
                              height: 1,
                              color:
                              TraceColors.border,
                            ),
                            const SizedBox(height: 14),
                            if (pageRecords.isEmpty)
                              SizedBox(
                                height: 200,
                                child:
                                SuperAdminCommon
                                    .empty(
                                  _hasFilters
                                      ? 'No attendance records match your filters.'
                                      : 'No attendance records found.',
                                  icon: Icons
                                      .fact_check_outlined,
                                ),
                              )
                            else ...[
                              _AttendanceTable(
                                records:
                                pageRecords,
                                usersById:
                                _usersById,
                                eventsById:
                                _eventsById,
                              ),
                              if (totalPages > 0) ...[
                                const SizedBox(height: 16),
                                _PaginationControls(
                                  currentPage:
                                  _currentPage,
                                  totalPages:
                                  totalPages,
                                  startStudent:
                                  startIndex + 1,
                                  endStudent:
                                  endIndex,
                                  totalStudents:
                                  totalStudents,
                                  onPrevious:
                                  _goToPreviousPage,
                                  onNext: () {
                                    _goToNextPage(
                                      totalPages,
                                    );
                                  },
                                ),
                              ],
                            ],
                          ],
                        ),
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

  // ============================================================
  // COURSE SUBTITLE
  // ============================================================

  String _courseSubtitle(
      int filtered,
      int total,
      ) {
    if (!_hasFilters) {
      return 'Attendance activity grouped by student course.';
    }

    return '$filtered of $total attendance records included in the current view.';
  }

  // ============================================================
  // RECORDS SUBTITLE
  // ============================================================

  String _recordsSubtitle(
      int pageStudents,
      int totalStudents,
      ) {
    if (totalStudents == 0) {
      return 'No students found.';
    }

    return 'Showing $pageStudents of $totalStudents students.';
  }
}

// ================================================================
// PAGE HEADER
// ================================================================

class _PageHeader extends StatelessWidget {
  final int totalAllRecords;
  final int totalFilteredRecords;
  final int totalStudents;

  const _PageHeader({
    required this.totalAllRecords,
    required this.totalFilteredRecords,
    required this.totalStudents,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: TraceColors.accentSoft,
            borderRadius:
            BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.fact_check_rounded,
            color: TraceColors.accent,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Text(
                'Attendance',
                style: TextStyle(
                  color: TraceColors.textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Review attendance activity by course and event.',
                maxLines: 2,
                overflow:
                TextOverflow.ellipsis,
                style: TextStyle(
                  color: TraceColors.textSecondary,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$totalStudents students • $totalFilteredRecords records',
                style: const TextStyle(
                  color: TraceColors.textTertiary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
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
// PREMIUM SECTION
// ================================================================

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
      decoration: BoxDecoration(
        color: TraceColors.surface,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: TraceColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: 0.015),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding:
        const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment:
                  Alignment.center,
                  decoration:
                  BoxDecoration(
                    color:
                    TraceColors
                        .accentSoft,
                    borderRadius:
                    BorderRadius
                        .circular(10),
                  ),
                  child: Icon(
                    icon,
                    color:
                    TraceColors
                        .accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                        const TextStyle(
                          color:
                          TraceColors
                              .textPrimary,
                          fontSize: 13.5,
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                      const SizedBox(
                          height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          color:
                          TraceColors
                              .textTertiary,
                          fontSize: 9.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            const Divider(
              height: 1,
              color: TraceColors.border,
            ),
            const SizedBox(height: 13),
            child,
          ],
        ),
      ),
    );
  }
}

// ================================================================
// FILTER PANEL
// ================================================================

class _FilterPanel extends StatelessWidget {
  final TextEditingController searchController;

  final String searchQuery;
  final String selectedEventId;
  final String selectedYear;
  final String selectedCourse;

  final List<EventModel> events;
  final List<int> years;
  final List<String> courses;

  final bool hasFilters;

  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onEventChanged;
  final ValueChanged<String> onYearChanged;
  final ValueChanged<String> onCourseChanged;

  final VoidCallback onClear;

  const _FilterPanel({
    required this.searchController,
    required this.searchQuery,
    required this.selectedEventId,
    required this.selectedYear,
    required this.selectedCourse,
    required this.events,
    required this.years,
    required this.courses,
    required this.hasFilters,
    required this.onSearchChanged,
    required this.onEventChanged,
    required this.onYearChanged,
    required this.onCourseChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile =
            constraints.maxWidth < 760;

        final search = TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            isDense: true,
            hintText:
            'Search student name...',
            hintStyle:
            const TextStyle(
              color:
              TraceColors.textTertiary,
              fontSize: 11.5,
            ),
            prefixIcon:
            const Icon(
              Icons.search_rounded,
              size: 18,
              color:
              TraceColors.textTertiary,
            ),
            suffixIcon:
            searchQuery.isNotEmpty
                ? IconButton(
              tooltip:
              'Clear search',
              onPressed: () {
                searchController
                    .clear();
                onSearchChanged('');
              },
              icon:
              const Icon(
                Icons.close_rounded,
                size: 17,
                color:
                TraceColors
                    .textTertiary,
              ),
            )
                : null,
            filled: true,
            fillColor:
            TraceColors.canvas,
            contentPadding:
            const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 13,
            ),
            border:
            OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(12),
              borderSide:
              BorderSide.none,
            ),
            enabledBorder:
            OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(12),
              borderSide:
              BorderSide.none,
            ),
            focusedBorder:
            OutlineInputBorder(
              borderRadius:
              BorderRadius.circular(12),
              borderSide:
              const BorderSide(
                color:
                TraceColors.accent,
                width: 1.1,
              ),
            ),
          ),
        );

        final event = _FilterDropdown(
          value: selectedEventId,
          icon:
          Icons.event_outlined,
          items: [
            const DropdownMenuItem<String>(
              value: 'all',
              child:
              Text('All Events'),
            ),
            ...events.map(
                  (item) =>
                  DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(
                      item.eventName,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                    ),
                  ),
            ),
          ],
          onChanged:
          onEventChanged,
        );

        final year = _FilterDropdown(
          value: selectedYear,
          icon:
          Icons.calendar_today_outlined,
          items: [
            const DropdownMenuItem<String>(
              value: 'all',
              child:
              Text('All Years'),
            ),
            ...years.map(
                  (item) =>
                  DropdownMenuItem<String>(
                    value:
                    item.toString(),
                    child: Text(
                      item.toString(),
                    ),
                  ),
            ),
          ],
          onChanged:
          onYearChanged,
        );

        final course = _FilterDropdown(
          value: selectedCourse,
          icon:
          Icons.school_outlined,
          items: [
            const DropdownMenuItem<String>(
              value: 'all',
              child:
              Text('All Courses'),
            ),
            ...courses.map(
                  (item) =>
                  DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                    ),
                  ),
            ),
          ],
          onChanged:
          onCourseChanged,
        );

        if (mobile) {
          return Column(
            crossAxisAlignment:
            CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: event,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: year,
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: course,
                  ),
                  if (hasFilters) ...[
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: onClear,
                      child:
                      const Text('Clear'),
                    ),
                  ],
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              flex: 2,
              child: search,
            ),
            const SizedBox(width: 9),
            Expanded(
              flex: 2,
              child: event,
            ),
            const SizedBox(width: 9),
            SizedBox(
              width: 145,
              child: year,
            ),
            const SizedBox(width: 9),
            Expanded(
              flex: 2,
              child: course,
            ),
            if (hasFilters)
              TextButton(
                onPressed: onClear,
                child:
                const Text('Clear'),
              ),
          ],
        );
      },
    );
  }
}

// ================================================================
// DROPDOWN
// ================================================================

class _FilterDropdown
    extends StatelessWidget {
  final String value;
  final IconData icon;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(
        Icons.expand_more_rounded,
        size: 18,
        color:
        TraceColors.textTertiary,
      ),
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: Icon(
          icon,
          size: 17,
          color:
          TraceColors.textTertiary,
        ),
        filled: true,
        fillColor:
        TraceColors.canvas,
        contentPadding:
        const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        border:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(12),
          borderSide:
          BorderSide.none,
        ),
        enabledBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(12),
          borderSide:
          BorderSide.none,
        ),
        focusedBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(12),
          borderSide:
          const BorderSide(
            color:
            TraceColors.accent,
            width: 1.1,
          ),
        ),
      ),
      items: items,
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

// ================================================================
// PAGINATION CONTROLS
// ================================================================

class _PaginationControls
    extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int startStudent;
  final int endStudent;
  final int totalStudents;

  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _PaginationControls({
    required this.currentPage,
    required this.totalPages,
    required this.startStudent,
    required this.endStudent,
    required this.totalStudents,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isFirstPage =
        currentPage == 0;

    final isLastPage =
        currentPage >= totalPages - 1;

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: TraceColors.canvas,
        borderRadius:
        BorderRadius.circular(12),
        border: Border.all(
          color:
          TraceColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$startStudent–$endStudent of $totalStudents students',
              style:
              const TextStyle(
                color:
                TraceColors
                    .textSecondary,
                fontSize: 10.5,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Previous',
            onPressed:
            isFirstPage
                ? null
                : onPrevious,
            icon:
            const Icon(
              Icons
                  .chevron_left_rounded,
              size: 22,
            ),
            color:
            TraceColors
                .textPrimary,
            disabledColor:
            TraceColors
                .textTertiary,
            visualDensity:
            VisualDensity.compact,
          ),
          Padding(
            padding:
            const EdgeInsets
                .symmetric(
              horizontal: 8,
            ),
            child: Text(
              'Page ${currentPage + 1} of $totalPages',
              style:
              const TextStyle(
                color:
                TraceColors
                    .textPrimary,
                fontSize: 10.5,
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next',
            onPressed:
            isLastPage
                ? null
                : onNext,
            icon:
            const Icon(
              Icons
                  .chevron_right_rounded,
              size: 22,
            ),
            color:
            TraceColors
                .textPrimary,
            disabledColor:
            TraceColors
                .textTertiary,
            visualDensity:
            VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ================================================================
// ATTENDANCE TABLE
// ================================================================

class _AttendanceTable
    extends StatelessWidget {
  final List<AttendanceModel> records;
  final Map<String, UserModel> usersById;
  final Map<String, EventModel> eventsById;

  const _AttendanceTable({
    required this.records,
    required this.usersById,
    required this.eventsById,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TraceColors.surface,
        borderRadius:
        BorderRadius.circular(14),
        border: Border.all(
          color:
          TraceColors.border,
        ),
      ),
      clipBehavior:
      Clip.antiAlias,
      child:
      SingleChildScrollView(
        scrollDirection:
        Axis.horizontal,
        child: DataTable(
          headingRowHeight: 44,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 48,
          horizontalMargin: 14,
          columnSpacing: 24,
          headingRowColor:
          WidgetStateProperty.all(
            TraceColors.canvas,
          ),
          dividerThickness: 0.5,
          columns: const [
            DataColumn(
              label:
              Text('Student'),
            ),
            DataColumn(
              label:
              Text('Course'),
            ),
            DataColumn(
              label:
              Text('Event'),
            ),
            DataColumn(
              label:
              Text('Status'),
            ),
          ],
          rows: records.map(
                (attendance) {
              final user =
              usersById[
              attendance.userId];

              final event =
              eventsById[
              attendance.eventId];

              final studentName =
                  user?.fullName
                      .trim() ??
                      '';

              final course =
                  user?.course
                      .trim() ??
                      '';

              final eventName =
                  event?.eventName
                      .trim() ??
                      '';

              return DataRow(
                cells: [
                  DataCell(
                    _StudentCell(
                      name:
                      studentName,
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints:
                      const BoxConstraints(
                        maxWidth: 160,
                      ),
                      child: Text(
                        course,
                        maxLines: 1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          color:
                          TraceColors
                              .textPrimary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints:
                      const BoxConstraints(
                        maxWidth: 220,
                      ),
                      child: Text(
                        eventName,
                        maxLines: 1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          color:
                          TraceColors
                              .textPrimary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    _AttendanceStatusChip(
                      attendance:
                      attendance,
                    ),
                  ),
                ],
              );
            },
          ).toList(),
        ),
      ),
    );
  }
}

// ================================================================
// STUDENT CELL
// ================================================================

class _StudentCell
    extends StatelessWidget {
  final String name;

  const _StudentCell({
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final text = name.trim();

    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize:
      MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment:
          Alignment.center,
          decoration:
          const BoxDecoration(
            color:
            TraceColors.accentSoft,
            shape:
            BoxShape.circle,
          ),
          child: Text(
            _initials(text),
            style:
            const TextStyle(
              color:
              TraceColors.accent,
              fontSize: 9,
              fontWeight:
              FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints:
          const BoxConstraints(
            maxWidth: 180,
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
            style:
            const TextStyle(
              color:
              TraceColors.textPrimary,
              fontSize: 11.5,
              fontWeight:
              FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  String _initials(String value) {
    final parts = value.split(
      RegExp(r'\s+'),
    );

    if (parts.length == 1) {
      return parts.first
          .substring(
        0,
        math.min(
          2,
          parts.first.length,
        ),
      )
          .toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'
        .toUpperCase();
  }
}

// ================================================================
// STATUS CHIP
// ================================================================

class _AttendanceStatusChip
    extends StatelessWidget {
  final AttendanceModel attendance;

  const _AttendanceStatusChip({
    required this.attendance,
  });

  @override
  Widget build(BuildContext context) {
    late String label;
    late Color color;

    if (attendance.isPresent) {
      label = 'Present';
      color =
          TraceColors.success;
    } else if (attendance.isHalfDay) {
      label = 'Half-day';
      color =
          TraceColors.warning;
    } else {
      label = 'Absent';
      color =
          TraceColors.danger;
    }

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration:
      BoxDecoration(
        color:
        color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
        BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style:
        TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight:
          FontWeight.w800,
        ),
      ),
    );
  }
}

// ================================================================
// COURSE CHART
// ================================================================

class _CourseChart
    extends StatelessWidget {
  final Map<String, int> values;
  final bool isMobile;

  const _CourseChart({
    required this.values,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return SuperAdminCommon.empty(
        'No course attendance data available.',
        icon:
        Icons.bar_chart_rounded,
      );
    }

    final entries =
    values.entries.toList()
      ..sort(
            (a, b) =>
            b.value.compareTo(
              a.value,
            ),
      );

    final visible =
    entries.take(8).toList();

    final maxValue = visible
        .map(
          (entry) => entry.value,
    )
        .fold<int>(
      1,
      math.max,
    );

    final maxY = math.max(
      2,
      maxValue + 2,
    ).toDouble();

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        alignment:
        BarChartAlignment
            .spaceAround,
        borderData:
        FlBorderData(
          show: false,
        ),
        gridData:
        FlGridData(
          show: true,
          drawVerticalLine:
          false,
          horizontalInterval:
          maxValue <= 5
              ? 1
              : null,
          getDrawingHorizontalLine:
              (value) {
            return FlLine(
              color:
              TraceColors
                  .border,
              strokeWidth: 1,
            );
          },
        ),
        titlesData:
        FlTitlesData(
          topTitles:
          const AxisTitles(
            sideTitles:
            SideTitles(
              showTitles: false,
            ),
          ),
          rightTitles:
          const AxisTitles(
            sideTitles:
            SideTitles(
              showTitles: false,
            ),
          ),
          leftTitles:
          AxisTitles(
            sideTitles:
            SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval:
              maxValue <= 5
                  ? 1
                  : null,
              getTitlesWidget:
                  (value, meta) {
                return Text(
                  value
                      .toInt()
                      .toString(),
                  style:
                  const TextStyle(
                    color:
                    TraceColors
                        .textTertiary,
                    fontSize: 8,
                  ),
                );
              },
            ),
          ),
          bottomTitles:
          AxisTitles(
            sideTitles:
            SideTitles(
              showTitles: true,
              reservedSize:
              isMobile
                  ? 48
                  : 45,
              getTitlesWidget:
                  (value, meta) {
                final index =
                value.toInt();

                if (index < 0 ||
                    index >=
                        visible
                            .length) {
                  return const SizedBox
                      .shrink();
                }

                return Padding(
                  padding:
                  const EdgeInsets
                      .only(
                    top: 7,
                  ),
                  child:
                  SizedBox(
                    width:
                    isMobile
                        ? 58
                        : 70,
                    child:
                    Text(
                      visible[
                      index]
                          .key,
                      maxLines: 2,
                      overflow:
                      TextOverflow
                          .ellipsis,
                      textAlign:
                      TextAlign
                          .center,
                      style:
                      TextStyle(
                        color:
                        TraceColors
                            .textTertiary,
                        fontSize:
                        isMobile
                            ? 7
                            : 7.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0;
          i < visible.length;
          i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY:
                  visible[i]
                      .value
                      .toDouble(),
                  width:
                  isMobile
                      ? 18
                      : 22,
                  color:
                  TraceColors
                      .accent,
                  borderRadius:
                  BorderRadius.circular(
                    5,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ================================================================
// ERROR STATE
// ================================================================

class _ErrorState
    extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment:
              Alignment.center,
              decoration:
              const BoxDecoration(
                color:
                TraceColors
                    .dangerSoft,
                shape:
                BoxShape.circle,
              ),
              child:
              const Icon(
                Icons
                    .error_outline_rounded,
                color:
                TraceColors
                    .danger,
                size: 26,
              ),
            ),
            const SizedBox(
              height: 15,
            ),
            const Text(
              'Unable to load attendance.',
              style:
              TextStyle(
                color:
                TraceColors
                    .textPrimary,
                fontSize: 14,
                fontWeight:
                FontWeight.w700,
              ),
            ),
            const SizedBox(
              height: 5,
            ),
            const Text(
              'Check your connection and try again.',
              textAlign:
              TextAlign.center,
              style:
              TextStyle(
                color:
                TraceColors
                    .textTertiary,
                fontSize: 11,
              ),
            ),
            const SizedBox(
              height: 17,
            ),
            ElevatedButton(
              onPressed: onRetry,
              style:
              SuperAdminCommon
                  .primaryButtonStyle(),
              child:
              const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}