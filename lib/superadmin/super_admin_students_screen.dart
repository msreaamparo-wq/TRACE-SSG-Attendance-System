import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import 'super_admin_common.dart';

// ================================================================
// LOCAL CHART COLORS
// ================================================================

const List<Color> _chartPalette = [
  TraceColors.accent,
  TraceColors.success,
  TraceColors.warning,
  TraceColors.danger,
  Color(0xFF6D5DD3),
  Color(0xFF2F82C3),
];

// ================================================================
// STUDENTS SCREEN
//
// This screen no longer owns search/filter state itself — that
// lives in `_StudentRecordsSection` below. Keeping it here meant
// every keystroke rebuilt the header, stat cards, and both charts
// along with the table, which briefly changed the page's total
// height and snapped the scroll position back to the top mid-type.
// Isolating search to its own widget means typing only rebuilds
// the table area.
// ================================================================

class SuperAdminStudentsScreen extends StatelessWidget {
  const SuperAdminStudentsScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TraceColors.canvas,
      body: SafeArea(
        child: StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          // ======================================================
          // IMPORTANT
          //
          // We intentionally do NOT use:
          //
          // .where('role', isEqualTo: 'student')
          //
          // because your Firestore contains "Student".
          // UserModel.isStudent normalizes the role.
          // ======================================================

          stream: FirebaseFirestore.instance
              .collection('users')
              .limit(2000)
              .snapshots(),

          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return SuperAdminCommon.loading();
            }

            if (snapshot.hasError) {
              return _ErrorState(
                onRetry: () {
                  // StreamBuilder auto-reconnects; this just gives
                  // the user visible feedback that a retry happened.
                  (context as Element).markNeedsBuild();
                },
              );
            }

            final allDocs = snapshot.data?.docs ?? [];

            // ==================================================
            // STUDENTS ONLY
            // ==================================================

            final students = allDocs.where((doc) {
              final user = UserModel.fromMap(
                doc.id,
                doc.data(),
              );

              return user.isStudent;
            }).toList();

            return _StudentsBody(students: students);
          },
        ),
      ),
    );
  }
}

// ================================================================
// BODY (header, stat cards, charts, records — everything that
// should NOT rebuild while the user is typing in the search box)
// ================================================================

class _StudentsBody extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> students;

  const _StudentsBody({required this.students});

  @override
  Widget build(BuildContext context) {
    // ==========================================================
    // COURSE + COLLEGE COUNTS
    // ==========================================================

    final Map<String, int> courseCounts = {};
    final Map<String, int> collegeCounts = {};

    for (final doc in students) {
      final user = UserModel.fromMap(doc.id, doc.data());

      final course = user.course.trim();
      final college = user.college.trim();

      if (course.isNotEmpty) {
        courseCounts[course] = (courseCounts[course] ?? 0) + 1;
      }

      if (college.isNotEmpty) {
        collegeCounts[college] = (collegeCounts[college] ?? 0) + 1;
      }
    }

    // ==========================================================
    // COLLEGE FILTER OPTIONS
    // ==========================================================

    final colleges = <String>{
      'All',
      ...collegeCounts.keys,
    }.toList()
      ..sort((a, b) {
        if (a == 'All') return -1;
        if (b == 'All') return 1;
        return a.compareTo(b);
      });

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 650;

        final double horizontalPadding = isMobile ? 16 : 28;
        final double verticalPadding = isMobile ? 20 : 28;

        return SingleChildScrollView(
          key: const PageStorageKey('studentsScreenScroll'),
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            verticalPadding,
            horizontalPadding,
            32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==============================================
                  // HEADER
                  // ==============================================

                  _PageHeader(totalStudents: students.length),

                  const SizedBox(height: 22),

                  // ==============================================
                  // SUMMARY CARDS
                  // ==============================================

                  _summaryCards(
                    students: students.length,
                    colleges: collegeCounts.length,
                    courses: courseCounts.length,
                    width: constraints.maxWidth,
                  ),

                  const SizedBox(height: 20),

                  // ==============================================
                  // ANALYTICS
                  // ==============================================

                  _charts(
                    width: constraints.maxWidth,
                    courseCounts: courseCounts,
                    collegeCounts: collegeCounts,
                  ),

                  const SizedBox(height: 20),

                  // ==============================================
                  // STUDENT RECORDS (owns its own search state)
                  // ==============================================

                  _StudentRecordsSection(
                    students: students,
                    colleges: colleges,
                    width: constraints.maxWidth,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // SUMMARY CARDS
  // ============================================================

  Widget _summaryCards({
    required int students,
    required int colleges,
    required int courses,
    required double width,
  }) {
    final cards = [
      _StudentStatCard(
        title: 'Total Students',
        value: NumberFormatHelper.format(students),
        subtitle: 'Registered student accounts',
        icon: Icons.school_rounded,
        accent: TraceColors.accent,
      ),
      _StudentStatCard(
        title: 'Colleges',
        value: NumberFormatHelper.format(colleges),
        subtitle: 'Colleges represented',
        icon: Icons.account_balance_rounded,
        accent: TraceColors.success,
      ),
      _StudentStatCard(
        title: 'Courses',
        value: NumberFormatHelper.format(courses),
        subtitle: 'Programs represented',
        icon: Icons.menu_book_rounded,
        accent: TraceColors.warning,
      ),
    ];

    if (width < 650) {
      return Column(
        children: [
          cards[0],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: cards[1]),
              const SizedBox(width: 12),
              Expanded(child: cards[2]),
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 16),
        Expanded(child: cards[1]),
        const SizedBox(width: 16),
        Expanded(child: cards[2]),
      ],
    );
  }

  // ============================================================
  // CHARTS
  // ============================================================

  Widget _charts({
    required double width,
    required Map<String, int> courseCounts,
    required Map<String, int> collegeCounts,
  }) {
    final topCourse = _largest(courseCounts);
    final topCollege = _largest(collegeCounts);

    final courseSection = _PremiumSection(
      title: 'Students by Course',
      subtitle: topCourse == null
          ? 'No course data available.'
          : 'Top course: ${topCourse.key} · ${topCourse.value} students',
      icon: Icons.menu_book_rounded,
      child: SizedBox(
        height: 290,
        child: _CourseChart(data: courseCounts),
      ),
    );

    final collegeSection = _PremiumSection(
      title: 'Students by College',
      subtitle: topCollege == null
          ? 'No college data available.'
          : 'Top college: ${topCollege.key} · ${topCollege.value} students',
      icon: Icons.account_balance_rounded,
      child: SizedBox(
        height: 290,
        child: _CollegeChart(data: collegeCounts),
      ),
    );

    if (width < 950) {
      return Column(
        children: [
          courseSection,
          const SizedBox(height: 18),
          collegeSection,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: courseSection),
        const SizedBox(width: 18),
        Expanded(child: collegeSection),
      ],
    );
  }
}

// ================================================================
// STUDENT RECORDS SECTION
//
// Owns the search controller, debounce timer, and college filter
// locally. Typing here only rebuilds this widget's subtree — the
// header, stat cards, and charts above it are untouched, so the
// page no longer jumps while a search is in progress.
// ================================================================

class _StudentRecordsSection extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> students;
  final List<String> colleges;
  final double width;

  const _StudentRecordsSection({
    required this.students,
    required this.colleges,
    required this.width,
  });

  @override
  State<_StudentRecordsSection> createState() =>
      _StudentRecordsSectionState();
}

class _StudentRecordsSectionState extends State<_StudentRecordsSection> {
  final TextEditingController _searchController = TextEditingController();

  String _collegeFilter = 'All';
  String _debouncedQuery = '';
  int _currentPage = 0;
  static const int _pageSize = 10;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Debounce so we filter (and rebuild the table) once the user
    // pauses typing, instead of on every keystroke.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _debouncedQuery = value.trim().toLowerCase();
        _currentPage = 0;
      });
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _debouncedQuery = '';
      _currentPage = 0;
    });
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: TraceColors.textTertiary,
        fontSize: 12,
      ),
      prefixIcon: Icon(
        icon,
        size: 18,
        color: TraceColors.textTertiary,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: TraceColors.canvas,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: TraceColors.accent,
          width: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colleges = widget.colleges.contains(_collegeFilter)
        ? widget.colleges
        : widget.colleges; // colleges list already includes 'All'

    if (!widget.colleges.contains(_collegeFilter)) {
      _collegeFilter = 'All';
    }

    // ==========================================================
    // FILTER STUDENTS (uses the debounced query, not live text)
    //
    // CONFIDENTIAL: Student ID and email are deliberately NOT
    // included in the searchable fields.
    // ==========================================================

    final filtered = widget.students.where((doc) {
      final user = UserModel.fromMap(doc.id, doc.data());

      final searchable = [
        user.fullName,
        user.course,
        user.college,
        user.yearLevel,
      ].join(' ').toLowerCase();

      final matchesSearch =
          _debouncedQuery.isEmpty || searchable.contains(_debouncedQuery);

      final matchesCollege = _collegeFilter == 'All' ||
          user.college.trim() == _collegeFilter;

      return matchesSearch && matchesCollege;
    }).toList();

    final bool narrow = widget.width < 720;
    final bool isFiltering =
        _debouncedQuery.isNotEmpty || _collegeFilter != 'All';

    return _PremiumSection(
      title: 'Student Records',
      subtitle: '${filtered.length} of ${widget.students.length} '
          'students shown',
      icon: Icons.badge_outlined,
      trailing: isFiltering
          ? _FilterChip(
        label: '${filtered.length} matched',
        onClear: () {
          _clearSearch();
          setState(() {
            _collegeFilter = 'All';
          });
        },
      )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ========================================================
          // FILTERS
          // ========================================================

          if (narrow)
            Column(
              children: [
                _buildSearchField(),
                const SizedBox(height: 10),
                _buildCollegeDropdown(colleges),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: _buildSearchField()),
                const SizedBox(width: 12),
                SizedBox(
                  width: 220,
                  child: _buildCollegeDropdown(colleges),
                ),
              ],
            ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: TraceColors.border),
          const SizedBox(height: 16),

          // ========================================================
          // TABLE — smoothly cross-fades when results change, so a
          // shrinking result set doesn't feel like a hard jump.
          // ========================================================

          Builder(
            builder: (context) {
              final totalPages =
              filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
              final safePage = _currentPage.clamp(0, totalPages - 1).toInt();
              final startIndex = safePage * _pageSize;
              final endIndex = math.min(startIndex + _pageSize, filtered.length);
              final pageStudents = filtered.isEmpty
                  ? <QueryDocumentSnapshot<Map<String, dynamic>>>[]
                  : filtered.sublist(startIndex, endIndex);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: filtered.isEmpty
                        ? SizedBox(
                      key: const ValueKey('empty'),
                      height: 240,
                      child: SuperAdminCommon.empty(
                        _debouncedQuery.isEmpty && _collegeFilter == 'All'
                            ? 'No students found.'
                            : 'No students match your search.',
                        icon: Icons.school_outlined,
                      ),
                    )
                        : _StudentTable(
                      key: ValueKey('table-$safePage-${filtered.length}'),
                      students: pageStudents,
                    ),
                  ),
                  if (filtered.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildPagination(
                      start: startIndex + 1,
                      end: endIndex,
                      total: filtered.length,
                      currentPage: safePage,
                      totalPages: totalPages,
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPagination({
    required int start,
    required int end,
    required int total,
    required int currentPage,
    required int totalPages,
  }) {
    final bool canGoPrevious = currentPage > 0;
    final bool canGoNext = currentPage < totalPages - 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 480;
        final rangeText = 'Showing $start–$end of $total students';

        final previousButton = OutlinedButton.icon(
          onPressed: canGoPrevious
              ? () => setState(() => _currentPage = currentPage - 1)
              : null,
          icon: const Icon(Icons.chevron_left_rounded, size: 18),
          label: const Text('Previous'),
          style: OutlinedButton.styleFrom(
            foregroundColor: TraceColors.textPrimary,
            disabledForegroundColor: TraceColors.textTertiary,
            side: const BorderSide(color: TraceColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        );

        final nextButton = ElevatedButton.icon(
          onPressed: canGoNext
              ? () => setState(() => _currentPage = currentPage + 1)
              : null,
          icon: const Text('Next'),
          label: const Icon(Icons.chevron_right_rounded, size: 18),
          iconAlignment: IconAlignment.end,
          style: ElevatedButton.styleFrom(
            backgroundColor: TraceColors.accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: TraceColors.canvas,
            disabledForegroundColor: TraceColors.textTertiary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                rangeText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: TraceColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: previousButton),
                  const SizedBox(width: 10),
                  Expanded(child: nextButton),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Page ${currentPage + 1} of $totalPages',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: TraceColors.textTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: Text(
                rangeText,
                style: const TextStyle(
                  color: TraceColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
            Text(
              'Page ${currentPage + 1} of $totalPages',
              style: const TextStyle(
                color: TraceColors.textTertiary,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 12),
            previousButton,
            const SizedBox(width: 8),
            nextButton,
          ],
        );
      },
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      decoration: _fieldDecoration(
        hint: 'Search by student name, course, or college...',
        icon: Icons.search_rounded,
        suffix: _searchController.text.isEmpty
            ? null
            : IconButton(
          icon: const Icon(
            Icons.close_rounded,
            size: 18,
            color: TraceColors.textTertiary,
          ),
          onPressed: _clearSearch,
        ),
      ),
    );
  }

  Widget _buildCollegeDropdown(List<String> colleges) {
    return DropdownButtonFormField<String>(
      initialValue: colleges.contains(_collegeFilter) ? _collegeFilter : 'All',
      decoration: _fieldDecoration(
        hint: 'College',
        icon: Icons.account_balance_outlined,
      ),
      icon: const Icon(
        Icons.expand_more_rounded,
        color: TraceColors.textTertiary,
      ),
      items: colleges.map((college) {
        return DropdownMenuItem<String>(
          value: college,
          child: Text(
            college == 'All' ? 'All colleges' : college,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: TraceColors.textPrimary,
              fontSize: 12,
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _collegeFilter = value;
          _currentPage = 0;
        });
      },
    );
  }
}

// ================================================================
// FILTER CHIP (shown in the section header while a filter is active)
// ================================================================

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onClear;

  const _FilterChip({
    required this.label,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: TraceColors.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: TraceColors.accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onClear,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 13,
                color: TraceColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// PAGE HEADER
// ================================================================

class _PageHeader extends StatelessWidget {
  final int totalStudents;

  const _PageHeader({required this.totalStudents});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: TraceColors.accentSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: TraceColors.accent.withValues(alpha: 0.15),
            ),
          ),
          child: const Icon(
            Icons.school_rounded,
            color: TraceColors.accent,
            size: 22,
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Students',
                style: TextStyle(
                  color: TraceColors.textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Monitor student enrollment, courses, and college '
                    'distribution.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: TraceColors.textSecondary,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 7),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: TraceColors.canvas,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: TraceColors.border),
                ),
                child: Text(
                  '$totalStudents registered students',
                  style: const TextStyle(
                    color: TraceColors.textTertiary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
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
// STAT CARD
// ================================================================

class _StudentStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const _StudentStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 122),
      decoration: BoxDecoration(
        color: TraceColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: TraceColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.022),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: accent.withValues(alpha: 0.16),
                ),
              ),
              child: Icon(icon, color: accent, size: 21),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
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

                  const SizedBox(height: 4),

                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TraceColors.textPrimary,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TraceColors.textTertiary,
                      fontSize: 8.5,
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
// PREMIUM SECTION
// ================================================================

class _PremiumSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _PremiumSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: TraceColors.accentSoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: TraceColors.accent, size: 18),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: TraceColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: TraceColors.textTertiary,
                          fontSize: 9.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),

                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),

            const SizedBox(height: 15),
            const Divider(height: 1, color: TraceColors.border),
            const SizedBox(height: 15),

            child,
          ],
        ),
      ),
    );
  }
}

// ================================================================
// STUDENT TABLE
// ================================================================

class _StudentTable extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> students;

  const _StudentTable({
    super.key,
    required this.students,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: TraceColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 46,
          dataRowMinHeight: 50,
          dataRowMaxHeight: 72,
          horizontalMargin: 14,
          columnSpacing: 24,
          headingRowColor: WidgetStateProperty.all(TraceColors.canvas),
          dividerThickness: 0.7,
          headingTextStyle: const TextStyle(
            color: TraceColors.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
          dataTextStyle: const TextStyle(
            color: TraceColors.textPrimary,
            fontSize: 11.5,
          ),

          // ======================================================
          // ONLY PUBLIC / NON-CONFIDENTIAL INFORMATION
          // ======================================================

          columns: const [
            DataColumn(label: Text('Student')),
            DataColumn(label: Text('Course')),
            DataColumn(label: Text('College')),
            DataColumn(label: Text('Year Level')),
          ],

          rows: students.map((doc) {
            final user = UserModel.fromMap(doc.id, doc.data());

            return DataRow(
              cells: [
                DataCell(_NameCell(name: user.fullName)),
                DataCell(
                  _SoftTag(
                    text: user.course.trim().isEmpty ? '—' : user.course,
                  ),
                ),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: Text(
                      user.college.trim().isEmpty ? '—' : user.college,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    user.yearLevel.trim().isEmpty ? '—' : user.yearLevel,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ================================================================
// NAME CELL
// ================================================================

class _NameCell extends StatelessWidget {
  final String name;

  const _NameCell({required this.name});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: TraceColors.accentSoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            _initials(name),
            style: const TextStyle(
              color: TraceColors.accent,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        const SizedBox(width: 9),

        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Text(
            name.trim().isEmpty ? 'Unnamed' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: TraceColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  String _initials(String value) {
    final text = value.trim();

    if (text.isEmpty) {
      return '?';
    }

    final parts = text.split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return parts.first
          .substring(0, math.min(2, parts.first.length))
          .toUpperCase();
    }

    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

// ================================================================
// SOFT TAG
// ================================================================

class _SoftTag extends StatelessWidget {
  final String text;

  const _SoftTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: TraceColors.accentSoft,
        borderRadius: BorderRadius.circular(7),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 210),
        child: Text(
          text,
          maxLines: 2,
          softWrap: true,
          overflow: TextOverflow.visible,
          style: const TextStyle(
            color: TraceColors.accent,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ================================================================
// COURSE CHART
// ================================================================

class _CourseChart extends StatelessWidget {
  final Map<String, int> data;

  const _CourseChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SuperAdminCommon.empty(
        'No course data available.',
        icon: Icons.bar_chart_rounded,
      );
    }

    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final visible = entries.take(6).toList();
    final maxValue = visible.map((entry) => entry.value).fold<int>(1, math.max);

    return Column(
      children: [
        for (int index = 0; index < visible.length; index++) ...[
          if (index > 0) const SizedBox(height: 11),
          _CourseBarRow(
            name: visible[index].key,
            count: visible[index].value,
            maxCount: maxValue,
            color: _chartPalette[index % _chartPalette.length],
          ),
        ],
      ],
    );
  }
}

class _CourseBarRow extends StatelessWidget {
  final String name;
  final int count;
  final int maxCount;
  final Color color;

  const _CourseBarRow({
    required this.name,
    required this.count,
    required this.maxCount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxCount == 0 ? 0.0 : count / maxCount;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 5,
          child: Text(
            name,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.visible,
            style: const TextStyle(
              color: TraceColors.textSecondary,
              fontSize: 10,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: TraceColors.canvas,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 28,
          child: Text(
            '$count',
            textAlign: TextAlign.end,
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
// COLLEGE CHART
// ================================================================

class _CollegeChart extends StatelessWidget {
  final Map<String, int> data;

  const _CollegeChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SuperAdminCommon.empty(
        'No college data available.',
        icon: Icons.pie_chart_outline_rounded,
      );
    }

    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final visible = entries.take(6).toList();

    final total = visible.fold<int>(0, (sum, item) => sum + item.value);

    if (total == 0) {
      return SuperAdminCommon.empty(
        'No college data available.',
        icon: Icons.pie_chart_outline_rounded,
      );
    }

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 48,
              sectionsSpace: 3,
              sections: List.generate(visible.length, (i) {
                final entry = visible[i];
                final percentage = entry.value / total * 100;

                return PieChartSectionData(
                  value: entry.value.toDouble(),
                  color: _chartPalette[i % _chartPalette.length],
                  title: '${percentage.toStringAsFixed(0)}%',
                  radius: 58,
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                );
              }),
            ),
          ),
        ),

        const SizedBox(height: 10),

        Wrap(
          spacing: 12,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: List.generate(visible.length, (i) {
            final entry = visible[i];

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _chartPalette[i % _chartPalette.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: Text(
                    entry.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TraceColors.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

// ================================================================
// ERROR STATE
// ================================================================

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TraceColors.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: TraceColors.danger,
                size: 26,
              ),
            ),

            const SizedBox(height: 15),

            const Text(
              'Unable to load students.',
              style: TextStyle(
                color: TraceColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: TraceColors.textTertiary,
                fontSize: 11,
              ),
            ),

            const SizedBox(height: 17),

            ElevatedButton(
              onPressed: onRetry,
              style: SuperAdminCommon.primaryButtonStyle(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// NUMBER FORMAT
// ================================================================

class NumberFormatHelper {
  static String format(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }

    return value.toString();
  }
}

// ================================================================
// LARGEST
// ================================================================

MapEntry<String, int>? _largest(Map<String, int> map) {
  if (map.isEmpty) {
    return null;
  }

  final values = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return values.first;
}