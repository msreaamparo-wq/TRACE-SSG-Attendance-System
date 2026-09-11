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

  @override
  void initState() {
    super.initState();

    if (FirebaseAuth.instance.currentUser != null) {
      // Auth is already confirmed (e.g. hot restart while signed in).
      _future = _load();
    } else {
      // Don't hit Firestore until FirebaseAuth has actually confirmed a
      // signed-in user — reading before that races the security rules
      // and returns PERMISSION_DENIED even though the user is about to
      // be signed in successfully.
      _future = Future.value(_DashboardData.empty());

      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null && mounted) {
          setState(() {
            _future = _load();
          });
          _authSub?.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<_DashboardData> _load() async {
    final db = FirebaseFirestore.instance;

    try {
      // ============================================================
      // LOAD DATA
      // ============================================================

      final results = await Future.wait([
        db.collection('users').count().get(),
        db.collection('events').count().get(),
        db.collection('attendance').count().get(),
        db.collection('users').limit(5000).get(),
        db.collection('attendance').limit(5000).get(),
        db
            .collection('events')
            .orderBy(
          'eventDate',
          descending: true,
        )
            .limit(100)
            .get(),
      ]);

      final userCountSnapshot =
      results[0] as AggregateQuerySnapshot;

      final eventCountSnapshot =
      results[1] as AggregateQuerySnapshot;

      final attendanceCountSnapshot =
      results[2] as AggregateQuerySnapshot;

      final usersSnapshot =
      results[3]
      as QuerySnapshot<Map<String, dynamic>>;

      final attendanceSnapshot =
      results[4]
      as QuerySnapshot<Map<String, dynamic>>;

      final eventsSnapshot =
      results[5]
      as QuerySnapshot<Map<String, dynamic>>;

      // ============================================================
      // STUDENTS
      // ============================================================

      int totalStudents = 0;

      final Map<String, int> studentCourse = {};
      final Map<String, int> studentCollege = {};

      for (final doc in usersSnapshot.docs) {
        final data = doc.data();

        try {
          final model = UserModel.fromMap(
            doc.id,
            data,
          );

          if (!model.isStudent) {
            continue;
          }

          totalStudents++;

          final course = model.course.trim();
          final college = model.college.trim();

          if (course.isNotEmpty) {
            studentCourse[course] =
                (studentCourse[course] ?? 0) + 1;
          }

          if (college.isNotEmpty) {
            studentCollege[college] =
                (studentCollege[college] ?? 0) + 1;
          }
        } catch (_) {
          // Ignore malformed user records so the
          // dashboard can continue loading.
          continue;
        }
      }

      // ============================================================
      // EVENT MAP
      // ============================================================

      final eventDocsById =
      <String,
          QueryDocumentSnapshot<
              Map<String, dynamic>>>{
        for (final doc in eventsSnapshot.docs)
          doc.id: doc,
      };

      // ============================================================
      // ATTENDANCE
      // ============================================================

      int present = 0;
      int halfDay = 0;
      int absent = 0;
      int todayAttendance = 0;

      final Set<int> attendanceYears = {};

      final List<_AttendanceRecord>
      attendanceRecords = [];

      final Map<String, _MutableEventAttendance>
      attendanceByEvent = {};

      final nowManila = DateTime.now()
          .toUtc()
          .add(
        const Duration(hours: 8),
      );

      final todayDate = DateTime(
        nowManila.year,
        nowManila.month,
        nowManila.day,
      );

      for (final doc
      in attendanceSnapshot.docs) {
        final data = doc.data();

        final status =
        _normalizeAttendanceStatus(
          data['attendanceStatus'],
        );

        final eventId =
        (data['eventId'] ?? '')
            .toString()
            .trim();

        DateTime? activityDate =
        _parseDate(
          data['timeIn'],
        );

        activityDate ??=
            _parseDate(
              data['timeOut'],
            );

        activityDate ??=
            _parseDate(
              data['createdAt'],
            );

        int? year;

        if (activityDate != null) {
          final manila =
          _toManila(
            activityDate,
          );

          year = manila.year;

          attendanceYears.add(
            year,
          );

          final activityDay =
          DateTime(
            manila.year,
            manila.month,
            manila.day,
          );

          if (activityDay ==
              todayDate) {
            todayAttendance++;
          }
        }

        // Fallback to event year.
        if (year == null &&
            eventId.isNotEmpty) {
          final event =
          eventDocsById[eventId];

          final eventDate =
          _parseEventStartDate(
            event?.data(),
          );

          if (eventDate != null) {
            year =
                _toManila(
                  eventDate,
                ).year;

            attendanceYears.add(
              year,
            );
          }
        }

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

        attendanceRecords.add(
          _AttendanceRecord(
            attendanceId:
            doc.id,
            eventId:
            eventId,
            status:
            status,
            date:
            activityDate,
            year:
            year,
          ),
        );

        // ----------------------------------------------------------
        // EVENT ATTENDANCE TOTAL
        // ----------------------------------------------------------

        if (eventId.isEmpty) {
          continue;
        }

        final event =
        eventDocsById[eventId];

        final eventData =
        event?.data();

        final item =
        attendanceByEvent.putIfAbsent(
          eventId,
              () => _MutableEventAttendance(
            eventId:
            eventId,
            eventName:
            (eventData?['eventName'] ??
                'Untitled Event')
                .toString(),
            eventDate:
            _parseEventStartDate(
              eventData,
            ),
          ),
        );

        switch (status) {
          case AttendanceStatus.present:
            item.present++;
            break;

          case AttendanceStatus.halfDay:
            item.halfDay++;
            break;

          case AttendanceStatus.absent:
            item.absent++;
            break;
        }
      }

      // ============================================================
      // ADD EVENT YEARS
      // ============================================================

      for (final event
      in eventsSnapshot.docs) {
        final date =
        _parseEventStartDate(
          event.data(),
        );

        if (date != null) {
          attendanceYears.add(
            _toManila(date).year,
          );
        }
      }

      // Always include current year.
      attendanceYears.add(
        nowManila.year,
      );

      final sortedYears =
      attendanceYears.toList()
        ..sort(
              (a, b) =>
              b.compareTo(a),
        );

      // ============================================================
      // EVENT ATTENDANCE LIST
      // ============================================================

      final List<_EventAttendance>
      eventAttendance = [];

      for (final event
      in eventsSnapshot.docs) {
        final data =
        event.data();

        final existing =
        attendanceByEvent[
        event.id];

        eventAttendance.add(
          _EventAttendance(
            eventId:
            event.id,
            eventName:
            (data['eventName'] ??
                'Untitled Event')
                .toString(),
            eventDate:
            _parseEventStartDate(
              data,
            ),
            eventEndDate:
            _parseEventEndDate(
              data,
            ),
            storedStatus:
            (data['status'] ??
                '')
                .toString(),
            present:
            existing?.present ??
                0,
            halfDay:
            existing?.halfDay ??
                0,
            absent:
            existing?.absent ??
                0,
          ),
        );
      }

      return _DashboardData(
        totalUsers:
        userCountSnapshot.count ?? 0,
        totalStudents:
        totalStudents,
        totalEvents:
        eventCountSnapshot.count ?? 0,
        totalAttendance:
        attendanceCountSnapshot.count ??
            0,
        todayAttendance:
        todayAttendance,
        present:
        present,
        halfDay:
        halfDay,
        absent:
        absent,
        studentCourse:
        studentCourse,
        studentCollege:
        studentCollege,
        events:
        eventsSnapshot.docs,
        eventAttendance:
        eventAttendance,
        attendanceRecords:
        attendanceRecords,
        attendanceYears:
        sortedYears,
      );
    } catch (e) {
      debugPrint(
        'Dashboard load error: $e',
      );

      rethrow;
    }
  }

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userData =
        context.watch<UserProvider>().userData;

    final currentUser =
    userData != null
        ? UserModel.fromMap(
      FirebaseAuth
          .instance
          .currentUser
          ?.uid ??
          '',
      userData,
    )
        : null;

    return Scaffold(
      backgroundColor:
      TraceColors.canvas,
      body: SafeArea(
        child:
        FutureBuilder<
            _DashboardData>(
          future: _future,
          builder:
              (
              context,
              snapshot,
              ) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return SuperAdminCommon
                  .loading();
            }

            if (snapshot.hasError) {
              return _DashboardErrorView(
                error:
                snapshot.error,
                onRetry:
                _retry,
              );
            }

            final data =
                snapshot.data ??
                    _DashboardData
                        .empty();

            return LayoutBuilder(
              builder:
                  (
                  context,
                  constraints,
                  ) {
                return SingleChildScrollView(
                  physics:
                  const BouncingScrollPhysics(),
                  padding:
                  const EdgeInsets
                      .fromLTRB(
                    18,
                    22,
                    18,
                    36,
                  ),
                  child: Center(
                    child:
                    ConstrainedBox(
                      constraints:
                      const BoxConstraints(
                        maxWidth:
                        1440,
                      ),
                      child:
                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          _Header(
                            name:
                            currentUser
                                ?.fullName ??
                                'Super Admin',
                          ),

                          const SizedBox(
                            height:
                            24,
                          ),

                          // ==================================================
                          // 2 x 2 KPI
                          // ==================================================

                          _KpiGrid(
                            data:
                            data,
                          ),

                          const SizedBox(
                            height:
                            22,
                          ),

                          // ==================================================
                          // ATTENDANCE BREAKDOWN
                          // ==================================================

                          _PremiumSection(
                            title:
                            'Attendance Breakdown',
                            subtitle:
                            'View attendance records by year and event.',
                            icon:
                            Icons
                                .donut_large_rounded,
                            child:
                            LayoutBuilder(
                              builder:
                                  (
                                  context,
                                  box,
                                  ) {
                                final mobile =
                                    box.maxWidth <
                                        620;

                                return SizedBox(
                                  height:
                                  mobile
                                      ? 610
                                      : 390,
                                  child:
                                  _AttendanceBreakdown(
                                    data:
                                    data,
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(
                            height:
                            22,
                          ),

                          _BottomGrid(
                            data:
                            data,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// KPI GRID
// ============================================================================

class _KpiGrid
    extends StatelessWidget {
  final _DashboardData data;

  const _KpiGrid({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _ModernStatCard(
        title:
        'Total Users',
        value:
        NumberFormat(
          '#,###',
        ).format(
          data.totalUsers,
        ),
        subtitle:
        'Registered accounts',
        icon:
        Icons.people_alt_rounded,
        accent:
        TraceColors.accent,
      ),
      _ModernStatCard(
        title:
        'Events',
        value:
        NumberFormat(
          '#,###',
        ).format(
          data.totalEvents,
        ),
        subtitle:
        'Total recorded events',
        icon:
        Icons.event_rounded,
        accent:
        TraceColors.warning,
      ),
      _ModernStatCard(
        title:
        'Students',
        value:
        NumberFormat(
          '#,###',
        ).format(
          data.totalStudents,
        ),
        subtitle:
        'Student accounts',
        icon:
        Icons.school_rounded,
        accent:
        TraceColors.success,
      ),
      _ModernStatCard(
        title:
        'Total Attendance',
        value:
        NumberFormat(
          '#,###',
        ).format(
          data.totalAttendance,
        ),
        subtitle:
        '${NumberFormat('#,###').format(data.todayAttendance)} recorded today',
        icon:
        Icons.fact_check_rounded,
        accent:
        TraceColors.accent,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Two columns, 14px gutter between them.
        final cardWidth =
            (constraints.maxWidth - 14) / 2;

        // Fixed aspect ratios made cards too short to
        // hold title + value + subtitle on narrow phones,
        // causing a RenderFlex overflow. Give narrow cards
        // proportionally more height.
        final aspectRatio = cardWidth < 170 ? 1.7 : 2.35;

        return GridView.builder(
          shrinkWrap:
          true,
          physics:
          const NeverScrollableScrollPhysics(),
          itemCount:
          cards.length,
          gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:
            2,
            crossAxisSpacing:
            14,
            mainAxisSpacing:
            14,
            childAspectRatio:
            aspectRatio,
          ),
          itemBuilder:
              (
              context,
              index,
              ) =>
          cards[index],
        );
      },
    );
  }
}

// ============================================================================
// KPI CARD
// ============================================================================

class _ModernStatCard
    extends StatelessWidget {
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
      width:
      double.infinity,
      decoration:
      BoxDecoration(
        color:
        TraceColors.surface,
        borderRadius:
        BorderRadius.circular(
          17,
        ),
        border:
        Border.all(
          color:
          TraceColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withValues(
              alpha:
              0.025,
            ),
            blurRadius:
            20,
            offset:
            const Offset(
              0,
              6,
            ),
          ),
        ],
      ),
      padding:
      const EdgeInsets.all(
        15,
      ),
      child:
      Row(
        children: [
          Container(
            width:
            46,
            height:
            46,
            decoration:
            BoxDecoration(
              color:
              accent.withValues(
                alpha:
                0.10,
              ),
              borderRadius:
              BorderRadius
                  .circular(
                13,
              ),
            ),
            child:
            Icon(
              icon,
              color:
              accent,
              size:
              22,
            ),
          ),

          const SizedBox(
            width:
            12,
          ),

          Expanded(
            child:
            // FittedBox keeps the text column from
            // overflowing when the card is squeezed
            // (very narrow screens, unexpected aspect
            // ratios, large font/text-scale settings).
            LayoutBuilder(
              builder: (context, innerConstraints) {
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: innerConstraints.maxWidth,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          title,
                          maxLines:
                          1,
                          overflow:
                          TextOverflow
                              .ellipsis,
                          style:
                          const TextStyle(
                            color:
                            TraceColors
                                .textSecondary,
                            fontSize:
                            10.5,
                            fontWeight:
                            FontWeight
                                .w700,
                          ),
                        ),

                        const SizedBox(
                          height:
                          3,
                        ),

                        Text(
                          value,
                          maxLines:
                          1,
                          style:
                          const TextStyle(
                            color:
                            TraceColors
                                .textPrimary,
                            fontSize:
                            24,
                            fontWeight:
                            FontWeight
                                .w800,
                            letterSpacing:
                            -0.5,
                          ),
                        ),

                        const SizedBox(
                          height:
                          3,
                        ),

                        Text(
                          subtitle,
                          maxLines:
                          2,
                          overflow:
                          TextOverflow
                              .ellipsis,
                          style:
                          const TextStyle(
                            color:
                            TraceColors
                                .textTertiary,
                            fontSize:
                            8.5,
                            height:
                            1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PREMIUM SECTION
// ============================================================================

class _PremiumSection
    extends StatelessWidget {
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
      width:
      double.infinity,
      decoration:
      BoxDecoration(
        color:
        TraceColors.surface,
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        border:
        Border.all(
          color:
          TraceColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color:
            Colors.black
                .withValues(
              alpha:
              0.018,
            ),
            blurRadius:
            22,
            offset:
            const Offset(
              0,
              7,
            ),
          ),
        ],
      ),
      padding:
      const EdgeInsets.fromLTRB(
        17,
        17,
        17,
        16,
      ),
      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment
            .start,
        children: [
          Row(
            crossAxisAlignment:
            CrossAxisAlignment
                .start,
            children: [
              Container(
                width:
                36,
                height:
                36,
                alignment:
                Alignment.center,
                decoration:
                BoxDecoration(
                  color:
                  TraceColors
                      .accentSoft,
                  borderRadius:
                  BorderRadius
                      .circular(
                    10,
                  ),
                ),
                child:
                Icon(
                  icon,
                  color:
                  TraceColors
                      .accent,
                  size:
                  17,
                ),
              ),

              const SizedBox(
                width:
                10,
              ),

              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      title,
                      maxLines:
                      2,
                      overflow:
                      TextOverflow
                          .ellipsis,
                      style:
                      const TextStyle(
                        color:
                        TraceColors
                            .textPrimary,
                        fontSize:
                        13,
                        fontWeight:
                        FontWeight
                            .w800,
                      ),
                    ),
                    const SizedBox(
                      height:
                      3,
                    ),
                    Text(
                      subtitle,
                      maxLines:
                      3,
                      overflow:
                      TextOverflow
                          .ellipsis,
                      style:
                      const TextStyle(
                        color:
                        TraceColors
                            .textTertiary,
                        fontSize:
                        9.5,
                        height:
                        1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
            14,
          ),

          const Divider(
            height:
            1,
            color:
            TraceColors.border,
          ),

          const SizedBox(
            height:
            13,
          ),

          child,
        ],
      ),
    );
  }
}

// ============================================================================
// ATTENDANCE BREAKDOWN
// ============================================================================

class _AttendanceBreakdown
    extends StatefulWidget {
  final _DashboardData data;

  const _AttendanceBreakdown({
    required this.data,
  });

  @override
  State<_AttendanceBreakdown>
  createState() =>
      _AttendanceBreakdownState();
}

class _AttendanceBreakdownState
    extends State<_AttendanceBreakdown> {
  int? _selectedYear;
  String? _selectedEventId;

  @override
  void initState() {
    super.initState();

    final years =
        widget.data.attendanceYears;

    _selectedYear =
    years.isNotEmpty
        ? years.first
        : null;
  }

  @override
  void didUpdateWidget(
      covariant _AttendanceBreakdown
      oldWidget,
      ) {
    super.didUpdateWidget(
      oldWidget,
    );

    final years =
        widget.data.attendanceYears;

    if (_selectedYear != null &&
        !years.contains(
          _selectedYear,
        )) {
      _selectedYear =
      years.isNotEmpty
          ? years.first
          : null;

      _selectedEventId =
      null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final records =
    widget.data.attendanceRecords
        .where(
          (record) {
        final matchesYear =
            _selectedYear ==
                null ||
                record.year ==
                    _selectedYear;

        final matchesEvent =
            _selectedEventId ==
                null ||
                record.eventId ==
                    _selectedEventId;

        return matchesYear &&
            matchesEvent;
      },
    )
        .toList();

    int present = 0;
    int halfDay = 0;
    int absent = 0;

    for (final record in records) {
      switch (record.status) {
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

    final total =
        present +
            halfDay +
            absent;

    final eventOptions =
    widget.data.eventAttendance
        .where(
          (event) {
        if (event.eventDate ==
            null) {
          return false;
        }

        if (_selectedYear ==
            null) {
          return event.total > 0;
        }

        return _toManila(
          event.eventDate!,
        ).year ==
            _selectedYear;
      },
    )
        .toList();

    final selectedEventStillExists =
        _selectedEventId == null ||
            eventOptions.any(
                  (event) =>
              event.eventId ==
                  _selectedEventId,
            );

    if (!selectedEventStillExists) {
      WidgetsBinding.instance
          .addPostFrameCallback(
            (_) {
          if (!mounted) {
            return;
          }

          setState(() {
            _selectedEventId =
            null;
          });
        },
      );
    }

    return LayoutBuilder(
      builder:
          (
          context,
          constraints,
          ) {
        final compact =
            constraints.maxWidth <
                620;

        return Column(
          children: [
            // ========================================================
            // FILTERS
            // ========================================================

            if (compact)
              Column(
                children: [
                  _buildYearDropdown(),
                  const SizedBox(
                    height:
                    10,
                  ),
                  _buildEventDropdown(
                    eventOptions,
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child:
                    _buildYearDropdown(),
                  ),
                  const SizedBox(
                    width:
                    10,
                  ),
                  Expanded(
                    child:
                    _buildEventDropdown(
                      eventOptions,
                    ),
                  ),
                ],
              ),

            const SizedBox(
              height:
              14,
            ),

            // ========================================================
            // CONTENT
            // ========================================================

            Expanded(
              child:
              total == 0
                  ? _buildEmptyState()
                  : compact
                  ? _buildCompact(
                present,
                halfDay,
                absent,
                total,
              )
                  : _buildWide(
                present,
                halfDay,
                absent,
                total,
              ),
            ),
          ],
        );
      },
    );
  }

  // ==================================================================
  // YEAR DROPDOWN
  // ==================================================================

  Widget _buildYearDropdown() {
    final years =
        widget.data.attendanceYears;

    final safeValue =
    years.contains(
      _selectedYear,
    )
        ? _selectedYear
        : null;

    return DropdownButtonFormField<int?>(
      initialValue:
      safeValue,
      isExpanded:
      true,
      menuMaxHeight:
      300,
      decoration:
      _dropdownDecoration(
        'Year',
        Icons.calendar_month_rounded,
      ),
      items: [
        const DropdownMenuItem<int?>(
          value:
          null,
          child:
          Text(
            'All Years',
          ),
        ),

        ...years.map(
              (year) =>
              DropdownMenuItem<int?>(
                value:
                year,
                child:
                Text(
                  year.toString(),
                ),
              ),
        ),
      ],
      onChanged:
          (value) {
        setState(() {
          _selectedYear =
              value;

          _selectedEventId =
          null;
        });
      },
    );
  }

  // ==================================================================
  // EVENT DROPDOWN
  // ==================================================================

  Widget _buildEventDropdown(
      List<_EventAttendance>
      events,
      ) {
    final safeValue =
    events.any(
          (event) =>
      event.eventId ==
          _selectedEventId,
    )
        ? _selectedEventId
        : null;

    return DropdownButtonFormField<String?>(
      initialValue:
      safeValue,
      isExpanded:
      true,
      menuMaxHeight:
      320,
      decoration:
      _dropdownDecoration(
        'Event',
        Icons.event_rounded,
      ),
      items: [
        const DropdownMenuItem<String?>(
          value:
          null,
          child:
          Text(
            'All Events',
          ),
        ),

        ...events.map(
              (event) =>
              DropdownMenuItem<String?>(
                value:
                event.eventId,
                child:
                Text(
                  event.eventName,
                  maxLines:
                  2,
                  overflow:
                  TextOverflow
                      .ellipsis,
                ),
              ),
        ),
      ],
      onChanged:
          (value) {
        setState(() {
          _selectedEventId =
              value;
        });
      },
    );
  }

  InputDecoration _dropdownDecoration(
      String label,
      IconData icon,
      ) {
    return InputDecoration(
      labelText:
      label,
      prefixIcon:
      Icon(
        icon,
        size:
        17,
        color:
        TraceColors
            .accent,
      ),
      isDense:
      true,
      filled:
      true,
      fillColor:
      TraceColors.canvas,
      contentPadding:
      const EdgeInsets
          .symmetric(
        horizontal:
        10,
        vertical:
        11,
      ),
      border:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          11,
        ),
        borderSide:
        const BorderSide(
          color:
          TraceColors.border,
        ),
      ),
      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          11,
        ),
        borderSide:
        const BorderSide(
          color:
          TraceColors.border,
        ),
      ),
      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          11,
        ),
        borderSide:
        const BorderSide(
          color:
          TraceColors.accent,
          width:
          1.2,
        ),
      ),
    );
  }

  // ==================================================================
  // WIDE
  // ==================================================================

  Widget _buildWide(
      int present,
      int halfDay,
      int absent,
      int total,
      ) {
    return Row(
      children: [
        Expanded(
          flex:
          3,
          child:
          _buildDonut(
            present,
            halfDay,
            absent,
            total,
          ),
        ),
        const SizedBox(
          width:
          26,
        ),
        Expanded(
          flex:
          2,
          child:
          _buildSummary(
            present,
            halfDay,
            absent,
            total,
          ),
        ),
      ],
    );
  }

  // ==================================================================
  // COMPACT
  // ==================================================================

  Widget _buildCompact(
      int present,
      int halfDay,
      int absent,
      int total,
      ) {
    return SingleChildScrollView(
      physics:
      const BouncingScrollPhysics(),
      child:
      Column(
        children: [
          SizedBox(
            height:
            215,
            child:
            _buildDonut(
              present,
              halfDay,
              absent,
              total,
            ),
          ),

          const SizedBox(
            height:
            12,
          ),

          _buildSummary(
            present,
            halfDay,
            absent,
            total,
          ),

          const SizedBox(
            height:
            8,
          ),
        ],
      ),
    );
  }

  // ==================================================================
  // DONUT
  // ==================================================================

  Widget _buildDonut(
      int present,
      int halfDay,
      int absent,
      int total,
      ) {
    final percentage =
    total == 0
        ? 0
        : ((present /
        total) *
        100)
        .round();

    return Stack(
      alignment:
      Alignment.center,
      children: [
        PieChart(
          PieChartData(
            centerSpaceRadius:
            62,
            sectionsSpace:
            4,
            sections: [
              _pieSection(
                present,
                total,
                TraceColors
                    .success,
              ),
              _pieSection(
                halfDay,
                total,
                TraceColors
                    .warning,
              ),
              _pieSection(
                absent,
                total,
                TraceColors
                    .danger,
              ),
            ],
          ),
        ),

        Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Text(
              '$percentage%',
              style:
              const TextStyle(
                color:
                TraceColors
                    .textPrimary,
                fontSize:
                25,
                fontWeight:
                FontWeight
                    .w800,
              ),
            ),
            const SizedBox(
              height:
              2,
            ),
            const Text(
              'Present',
              style:
              TextStyle(
                color:
                TraceColors
                    .textTertiary,
                fontSize:
                9,
                fontWeight:
                FontWeight
                    .w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  PieChartSectionData _pieSection(
      int value,
      int total,
      Color color,
      ) {
    if (value <= 0 ||
        total <= 0) {
      return PieChartSectionData(
        value:
        0,
        color:
        color.withValues(
          alpha:
          0.05,
        ),
        title:
        '',
        radius:
        64,
      );
    }

    return PieChartSectionData(
      value:
      value.toDouble(),
      color:
      color,
      radius:
      64,
      title:
      '${((value / total) * 100).round()}%',
      titleStyle:
      const TextStyle(
        color:
        Colors.white,
        fontSize:
        9,
        fontWeight:
        FontWeight
            .w800,
      ),
    );
  }

  // ==================================================================
  // SUMMARY
  // ==================================================================

  Widget _buildSummary(
      int present,
      int halfDay,
      int absent,
      int total,
      ) {
    return Column(
      mainAxisAlignment:
      MainAxisAlignment
          .center,
      crossAxisAlignment:
      CrossAxisAlignment
          .start,
      children: [
        _SummaryItem(
          color:
          TraceColors
              .success,
          label:
          'Present',
          value:
          present,
          percentage:
          total == 0
              ? 0
              : present /
              total,
        ),

        const SizedBox(
          height:
          11,
        ),

        _SummaryItem(
          color:
          TraceColors
              .warning,
          label:
          'Half-day',
          value:
          halfDay,
          percentage:
          total == 0
              ? 0
              : halfDay /
              total,
        ),

        const SizedBox(
          height:
          11,
        ),

        _SummaryItem(
          color:
          TraceColors
              .danger,
          label:
          'Absent',
          value:
          absent,
          percentage:
          total == 0
              ? 0
              : absent /
              total,
        ),

        const SizedBox(
          height:
          13,
        ),

        Container(
          width:
          double.infinity,
          padding:
          const EdgeInsets
              .symmetric(
            horizontal:
            11,
            vertical:
            9,
          ),
          decoration:
          BoxDecoration(
            color:
            TraceColors.canvas,
            borderRadius:
            BorderRadius
                .circular(
              10,
            ),
          ),
          child:
          Row(
            children: [
              const Expanded(
                child:
                Text(
                  'Total Records',
                  style:
                  TextStyle(
                    color:
                    TraceColors
                        .textSecondary,
                    fontSize:
                    9,
                    fontWeight:
                    FontWeight
                        .w700,
                  ),
                ),
              ),
              Text(
                NumberFormat(
                  '#,###',
                ).format(
                  total,
                ),
                style:
                const TextStyle(
                  color:
                  TraceColors
                      .textPrimary,
                  fontSize:
                  11,
                  fontWeight:
                  FontWeight
                      .w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================================================================
  // EMPTY
  // ==================================================================

  Widget _buildEmptyState() {
    return Center(
      child:
      Column(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Container(
            width:
            48,
            height:
            48,
            alignment:
            Alignment.center,
            decoration:
            BoxDecoration(
              color:
              TraceColors
                  .accentSoft,
              shape:
              BoxShape.circle,
            ),
            child:
            const Icon(
              Icons
                  .pie_chart_outline_rounded,
              color:
              TraceColors
                  .accent,
              size:
              23,
            ),
          ),

          const SizedBox(
            height:
            10,
          ),

          const Text(
            'No attendance records',
            style:
            TextStyle(
              color:
              TraceColors
                  .textPrimary,
              fontSize:
              12,
              fontWeight:
              FontWeight
                  .w700,
            ),
          ),

          const SizedBox(
            height:
            4,
          ),

          const Text(
            'No attendance data matches the selected filters.',
            textAlign:
            TextAlign.center,
            style:
            TextStyle(
              color:
              TraceColors
                  .textTertiary,
              fontSize:
              9,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SUMMARY ITEM
// ============================================================================

class _SummaryItem
    extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  final double percentage;

  const _SummaryItem({
    required this.color,
    required this.label,
    required this.value,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment
          .start,
      children: [
        Row(
          children: [
            Container(
              width:
              8,
              height:
              8,
              decoration:
              BoxDecoration(
                color:
                color,
                shape:
                BoxShape
                    .circle,
              ),
            ),

            const SizedBox(
              width:
              6,
            ),

            Expanded(
              child:
              Text(
                label,
                style:
                const TextStyle(
                  color:
                  TraceColors
                      .textSecondary,
                  fontSize:
                  9,
                  fontWeight:
                  FontWeight
                      .w700,
                ),
              ),
            ),

            Text(
              NumberFormat(
                '#,###',
              ).format(
                value,
              ),
              style:
              const TextStyle(
                color:
                TraceColors
                    .textPrimary,
                fontSize:
                10,
                fontWeight:
                FontWeight
                    .w800,
              ),
            ),
          ],
        ),

        const SizedBox(
          height:
          5,
        ),

        ClipRRect(
          borderRadius:
          BorderRadius.circular(
            999,
          ),
          child:
          LinearProgressIndicator(
            value:
            percentage.clamp(
              0.0,
              1.0,
            ),
            minHeight:
            5,
            backgroundColor:
            TraceColors.canvas,
            valueColor:
            AlwaysStoppedAnimation<
                Color>(
              color,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// STUDENTS BY COURSE
// ============================================================================

class _StudentCourseChart
    extends StatelessWidget {
  final _DashboardData data;

  const _StudentCourseChart({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (data.studentCourse.isEmpty) {
      return SuperAdminCommon.empty(
        'No student course data available.',
        icon:
        Icons.school_outlined,
      );
    }

    final entries =
    data.studentCourse.entries
        .toList()
      ..sort(
            (a, b) =>
            b.value.compareTo(
              a.value,
            ),
      );

    final visible =
    entries.take(6).toList();

    final maxValue =
    visible
        .map(
          (e) => e.value,
    )
        .fold<int>(
      1,
      math.max,
    );

    return ListView.separated(
      physics:
      const BouncingScrollPhysics(),
      padding:
      EdgeInsets.zero,
      itemCount:
      visible.length,
      separatorBuilder:
          (
          _,
          __,
          ) =>
      const SizedBox(
        height:
        13,
      ),
      itemBuilder:
          (
          context,
          index,
          ) {
        final entry =
        visible[index];

        final progress =
        (entry.value /
            maxValue)
            .clamp(
          0.0,
          1.0,
        );

        return Column(
          crossAxisAlignment:
          CrossAxisAlignment
              .start,
          children: [
            Row(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Container(
                  width:
                  24,
                  height:
                  24,
                  alignment:
                  Alignment.center,
                  decoration:
                  BoxDecoration(
                    color:
                    TraceColors
                        .accentSoft,
                    borderRadius:
                    BorderRadius
                        .circular(
                      8,
                    ),
                  ),
                  child:
                  Text(
                    '${index + 1}',
                    style:
                    const TextStyle(
                      color:
                      TraceColors
                          .accent,
                      fontSize:
                      9,
                      fontWeight:
                      FontWeight
                          .w800,
                    ),
                  ),
                ),

                const SizedBox(
                  width:
                  9,
                ),

                Expanded(
                  child:
                  Text(
                    entry.key,
                    maxLines:
                    3,
                    overflow:
                    TextOverflow
                        .ellipsis,
                    style:
                    const TextStyle(
                      color:
                      TraceColors
                          .textPrimary,
                      fontSize:
                      10,
                      fontWeight:
                      FontWeight
                          .w700,
                      height:
                      1.25,
                    ),
                  ),
                ),

                const SizedBox(
                  width:
                  8,
                ),

                Text(
                  '${entry.value}',
                  style:
                  const TextStyle(
                    color:
                    TraceColors
                        .textSecondary,
                    fontSize:
                    10,
                    fontWeight:
                    FontWeight
                        .w800,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height:
              7,
            ),

            ClipRRect(
              borderRadius:
              BorderRadius.circular(
                999,
              ),
              child:
              LinearProgressIndicator(
                minHeight:
                7,
                value:
                progress,
                backgroundColor:
                TraceColors
                    .canvas,
                valueColor:
                const AlwaysStoppedAnimation<
                    Color>(
                  TraceColors
                      .accent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// EVENTS PAGER
// ============================================================================

class _EventsPager
    extends StatefulWidget {
  final List<
      QueryDocumentSnapshot<
          Map<String, dynamic>>>
  events;

  const _EventsPager({
    required this.events,
  });

  @override
  State<_EventsPager> createState() =>
      _EventsPagerState();
}

class _EventsPagerState
    extends State<_EventsPager> {
  static const int pageSize =
  5;

  int page = 0;

  int get pageCount =>
      math.max(
        1,
        (widget.events.length /
            pageSize)
            .ceil(),
      );

  @override
  void didUpdateWidget(
      covariant _EventsPager
      oldWidget,
      ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (page >= pageCount) {
      page =
          math.max(
            0,
            pageCount - 1,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final safePage =
    page.clamp(
      0,
      pageCount - 1,
    );

    final start =
        safePage * pageSize;

    final end = math.min(
      start + pageSize,
      widget.events.length,
    );

    final visible =
    widget.events.sublist(
      start,
      end,
    );

    if (visible.isEmpty) {
      return SuperAdminCommon.empty(
        'No events found.',
        icon:
        Icons.event_busy_rounded,
      );
    }

    return Column(
      children: [
        Expanded(
          child:
          ListView.separated(
            physics:
            const BouncingScrollPhysics(),
            itemCount:
            visible.length,
            separatorBuilder:
                (
                _,
                __,
                ) =>
            const SizedBox(
              height:
              9,
            ),
            itemBuilder:
                (
                context,
                index,
                ) {
              return _EventRow(
                doc:
                visible[index],
              );
            },
          ),
        ),

        const SizedBox(
          height:
          7,
        ),

        Row(
          mainAxisAlignment:
          MainAxisAlignment
              .spaceBetween,
          children: [
            Text(
              'Page ${safePage + 1} of $pageCount',
              style:
              const TextStyle(
                color:
                TraceColors
                    .textTertiary,
                fontSize:
                9,
                fontWeight:
                FontWeight
                    .w700,
              ),
            ),

            Row(
              children: [
                IconButton(
                  onPressed:
                  safePage > 0
                      ? () {
                    setState(() {
                      page--;
                    });
                  }
                      : null,
                  icon:
                  const Icon(
                    Icons
                        .chevron_left_rounded,
                    size:
                    19,
                  ),
                  visualDensity:
                  VisualDensity
                      .compact,
                ),

                IconButton(
                  onPressed:
                  safePage <
                      pageCount -
                          1
                      ? () {
                    setState(() {
                      page++;
                    });
                  }
                      : null,
                  icon:
                  const Icon(
                    Icons
                        .chevron_right_rounded,
                    size:
                    19,
                  ),
                  visualDensity:
                  VisualDensity
                      .compact,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// EVENT ROW
// ============================================================================

class _EventRow
    extends StatelessWidget {
  final QueryDocumentSnapshot<
      Map<String, dynamic>>
  doc;

  const _EventRow({
    required this.doc,
  });

  @override
  Widget build(BuildContext context) {
    final data =
    doc.data();

    final name =
    (data['eventName'] ??
        'Untitled Event')
        .toString();

    final venue =
    (data['venue'] ?? '')
        .toString();

    final startDate =
    _parseEventStartDate(
      data,
    );

    final endDate =
    _parseEventEndDate(
      data,
    );

    final event =
    _EventAttendance(
      eventId:
      doc.id,
      eventName:
      name,
      eventDate:
      startDate,
      eventEndDate:
      endDate,
      storedStatus:
      (data['status'] ??
          '')
          .toString(),
      present:
      0,
      halfDay:
      0,
      absent:
      0,
    );

    final displayStatus =
    _getEventDisplayStatus(
      event,
    );

    return Container(
      padding:
      const EdgeInsets.all(
        10,
      ),
      decoration:
      BoxDecoration(
        color:
        TraceColors.canvas,
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        border:
        Border.all(
          color:
          TraceColors.border
              .withValues(
            alpha:
            0.65,
          ),
        ),
      ),
      child:
      Row(
        crossAxisAlignment:
        CrossAxisAlignment
            .center,
        children: [
          Container(
            width:
            37,
            height:
            37,
            alignment:
            Alignment.center,
            decoration:
            BoxDecoration(
              color:
              TraceColors
                  .accentSoft,
              borderRadius:
              BorderRadius
                  .circular(
                10,
              ),
            ),
            child:
            const Icon(
              Icons
                  .event_rounded,
              color:
              TraceColors
                  .accent,
              size:
              17,
            ),
          ),

          const SizedBox(
            width:
            10,
          ),

          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  name,
                  maxLines:
                  2,
                  overflow:
                  TextOverflow
                      .ellipsis,
                  style:
                  const TextStyle(
                    color:
                    TraceColors
                        .textPrimary,
                    fontSize:
                    11.5,
                    fontWeight:
                    FontWeight
                        .w700,
                    height:
                    1.2,
                  ),
                ),

                const SizedBox(
                  height:
                  4,
                ),

                Text(
                  [
                    if (startDate !=
                        null)
                      DateFormat(
                        'MMM d, yyyy',
                      ).format(
                        _toManila(
                          startDate,
                        ),
                      ),
                    if (venue
                        .trim()
                        .isNotEmpty)
                      venue,
                  ].join(
                    ' · ',
                  ),
                  maxLines:
                  2,
                  overflow:
                  TextOverflow
                      .ellipsis,
                  style:
                  const TextStyle(
                    color:
                    TraceColors
                        .textTertiary,
                    fontSize:
                    8.5,
                    height:
                    1.2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width:
            8,
          ),

          _EventStatusChip(
            status:
            displayStatus,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EVENT STATUS
// ============================================================================

class _EventStatusChip
    extends StatelessWidget {
  final EventDisplayStatus status;

  const _EventStatusChip({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    late Color foreground;
    late Color background;
    late IconData icon;

    switch (status) {
      case EventDisplayStatus.completed:
        foreground =
            TraceColors
                .textSecondary;
        background =
            TraceColors
                .border
                .withValues(
              alpha:
              0.55,
            );
        icon =
            Icons
                .check_circle_rounded;
        break;

      case EventDisplayStatus.active:
        foreground =
            TraceColors.success;
        background =
            TraceColors
                .success
                .withValues(
              alpha:
              0.11,
            );
        icon = Icons
            .radio_button_checked_rounded;
        break;

      case EventDisplayStatus.upcoming:
        foreground =
            TraceColors.accent;
        background =
            TraceColors
                .accent
                .withValues(
              alpha:
              0.10,
            );
        icon =
            Icons.schedule_rounded;
        break;
    }

    return Container(
      padding:
      const EdgeInsets
          .symmetric(
        horizontal:
        8,
        vertical:
        5,
      ),
      decoration:
      BoxDecoration(
        color:
        background,
        borderRadius:
        BorderRadius.circular(
          999,
        ),
      ),
      child:
      Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            icon,
            color:
            foreground,
            size:
            11,
          ),
          const SizedBox(
            width:
            4,
          ),
          Text(
            _eventStatusText(
              status,
            ),
            style:
            TextStyle(
              color:
              foreground,
              fontSize:
              8,
              fontWeight:
              FontWeight
                  .w800,
            ),
          ),
        ],
      ),
    );
  }
}

enum EventDisplayStatus {
  completed,
  active,
  upcoming,
}

String _eventStatusText(
    EventDisplayStatus status,
    ) {
  switch (status) {
    case EventDisplayStatus
        .completed:
      return 'Completed';

    case EventDisplayStatus
        .active:
      return 'Active';

    case EventDisplayStatus
        .upcoming:
      return 'Upcoming';
  }
}

EventDisplayStatus
_getEventDisplayStatus(
    _EventAttendance event,
    ) {
  final now =
  DateTime.now()
      .toUtc()
      .add(
    const Duration(
      hours: 8,
    ),
  );

  final start =
  event.eventDate != null
      ? _toManila(
    event.eventDate!,
  )
      : null;

  final end =
  event.eventEndDate != null
      ? _toManila(
    event.eventEndDate!,
  )
      : null;

  final stored =
  event.storedStatus
      .trim()
      .toLowerCase();

  // --------------------------------------------------------------
  // Explicit completed status
  // --------------------------------------------------------------

  if (stored == 'completed' ||
      stored == 'complete' ||
      stored == 'done' ||
      stored == 'finished') {
    return EventDisplayStatus
        .completed;
  }

  // --------------------------------------------------------------
  // Event with start + end
  // --------------------------------------------------------------

  if (start != null &&
      end != null) {
    if (now.isAfter(end)) {
      return EventDisplayStatus
          .completed;
    }

    if (!now.isBefore(start) &&
        !now.isAfter(end)) {
      return EventDisplayStatus
          .active;
    }

    return EventDisplayStatus
        .upcoming;
  }

  // --------------------------------------------------------------
  // Event with date only
  // --------------------------------------------------------------

  if (start != null) {
    final today =
    DateTime(
      now.year,
      now.month,
      now.day,
    );

    final eventDay =
    DateTime(
      start.year,
      start.month,
      start.day,
    );

    if (eventDay.isBefore(
      today,
    )) {
      return EventDisplayStatus
          .completed;
    }

    if (eventDay
        .isAtSameMomentAs(
      today,
    )) {
      return EventDisplayStatus
          .active;
    }

    return EventDisplayStatus
        .upcoming;
  }

  // Fallback to stored status.
  if (stored == 'active' ||
      stored == 'ongoing' ||
      stored == 'on-going' ||
      stored == 'in progress') {
    return EventDisplayStatus
        .active;
  }

  return EventDisplayStatus
      .upcoming;
}

// ============================================================================
// HEADER
// ============================================================================

class _Header
    extends StatefulWidget {
  final String name;

  const _Header({
    required this.name,
  });

  @override
  State<_Header> createState() =>
      _HeaderState();
}

class _HeaderState
    extends State<_Header> {
  DateTime? _manilaNow;

  Timer? _timer;

  static const String
  _timeApiUrl =
      'https://gettimeapi.dev/v1/time?timezone=Asia/Manila';

  @override
  void initState() {
    super.initState();

    _loadManilaTime();

    _timer = Timer.periodic(
      const Duration(
        minutes: 1,
      ),
          (_) =>
          _loadManilaTime(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void>
  _loadManilaTime() async {
    try {
      final response =
      await http
          .get(
        Uri.parse(
          _timeApiUrl,
        ),
      )
          .timeout(
        const Duration(
          seconds: 8,
        ),
      );

      if (response.statusCode !=
          200) {
        throw Exception();
      }

      final decoded =
      jsonDecode(
        response.body,
      );

      if (decoded
      is! Map<String,
          dynamic>) {
        throw Exception();
      }

      final date =
      decoded['date']
          ?.toString();

      final time =
      decoded['time']
          ?.toString();

      if (date == null ||
          time == null) {
        throw Exception();
      }

      final dateParts =
      date.split('-');

      final timeParts =
      time.split(':');

      if (dateParts.length !=
          3 ||
          timeParts.length <
              2) {
        throw Exception();
      }

      final parsed =
      DateTime(
        int.parse(
          dateParts[0],
        ),
        int.parse(
          dateParts[1],
        ),
        int.parse(
          dateParts[2],
        ),
        int.parse(
          timeParts[0],
        ),
        int.parse(
          timeParts[1],
        ),
        timeParts.length >=
            3
            ? int.tryParse(
          timeParts[2]
              .split('.')
              .first,
        ) ??
            0
            : 0,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _manilaNow =
            parsed;
      });
    } catch (_) {
      final fallback =
      DateTime.now()
          .toUtc()
          .add(
        const Duration(
          hours: 8,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _manilaNow =
            fallback;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now =
        _manilaNow ??
            DateTime.now()
                .toUtc()
                .add(
              const Duration(
                hours: 8,
              ),
            );

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment
          .start,
      children: [
        Text(
          _greeting(now),
          style:
          const TextStyle(
            color:
            TraceColors
                .textTertiary,
            fontSize:
            10,
            fontWeight:
            FontWeight
                .w800,
            letterSpacing:
            1.4,
          ),
        ),

        const SizedBox(
          height:
          6,
        ),

        Text(
          'Welcome back${widget.name.trim().isEmpty ? '' : ', ${widget.name}'}',
          maxLines:
          2,
          overflow:
          TextOverflow
              .ellipsis,
          style:
          const TextStyle(
            color:
            TraceColors
                .textPrimary,
            fontSize:
            26,
            fontWeight:
            FontWeight
                .w800,
            letterSpacing:
            -0.7,
          ),
        ),

        const SizedBox(
          height:
          7,
        ),

        Row(
          children: [
            const Icon(
              Icons
                  .calendar_today_rounded,
              size:
              12,
              color:
              TraceColors
                  .textTertiary,
            ),

            const SizedBox(
              width:
              6,
            ),

            Expanded(
              child:
              Text(
                '${DateFormat('EEEE, MMMM d, yyyy').format(now)} · Philippine Standard Time',
                maxLines:
                1,
                overflow:
                TextOverflow
                    .ellipsis,
                style:
                const TextStyle(
                  color:
                  TraceColors
                      .textSecondary,
                  fontSize:
                  10,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _greeting(
      DateTime time,
      ) {
    if (time.hour < 12) {
      return 'GOOD MORNING';
    }

    if (time.hour < 18) {
      return 'GOOD AFTERNOON';
    }

    return 'GOOD EVENING';
  }
}

// ============================================================================
// ERROR
// ============================================================================

class _DashboardErrorView
    extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _DashboardErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final errorText =
    error.toString();

    final permissionError =
        errorText.contains(
          'permission-denied',
        ) ||
            errorText.contains(
              'PERMISSION_DENIED',
            ) ||
            errorText.contains(
              'Missing or insufficient permissions',
            );

    return Center(
      child:
      SingleChildScrollView(
        padding:
        const EdgeInsets.all(
          24,
        ),
        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Container(
              width:
              58,
              height:
              58,
              alignment:
              Alignment.center,
              decoration:
              BoxDecoration(
                color:
                TraceColors
                    .dangerSoft,
                shape:
                BoxShape.circle,
              ),
              child:
              Icon(
                permissionError
                    ? Icons
                    .lock_outline_rounded
                    : Icons
                    .error_outline_rounded,
                color:
                TraceColors
                    .danger,
                size:
                27,
              ),
            ),

            const SizedBox(
              height:
              15,
            ),

            Text(
              permissionError
                  ? 'Dashboard access is blocked'
                  : 'Unable to load dashboard data.',
              textAlign:
              TextAlign.center,
              style:
              const TextStyle(
                color:
                TraceColors
                    .textPrimary,
                fontSize:
                14,
                fontWeight:
                FontWeight
                    .w800,
              ),
            ),

            const SizedBox(
              height:
              7,
            ),

            Text(
              permissionError
                  ? 'Your Firestore Security Rules are not allowing the signed-in super admin to read users, events, or attendance.'
                  : 'Check your connection and try again.',
              textAlign:
              TextAlign.center,
              style:
              const TextStyle(
                color:
                TraceColors
                    .textTertiary,
                fontSize:
                10.5,
                height:
                1.4,
              ),
            ),

            if (permissionError) ...[
              const SizedBox(
                height:
                8,
              ),
              const Text(
                'Update Firestore Rules, then restart the app.',
                textAlign:
                TextAlign.center,
                style:
                TextStyle(
                  color:
                  TraceColors
                      .textSecondary,
                  fontSize:
                  9.5,
                  fontWeight:
                  FontWeight
                      .w700,
                ),
              ),
            ],

            const SizedBox(
              height:
              17,
            ),

            ElevatedButton(
              onPressed:
              onRetry,
              style:
              SuperAdminCommon
                  .primaryButtonStyle(),
              child:
              const Text(
                'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ATTENDANCE
// ============================================================================

enum AttendanceStatus {
  present,
  halfDay,
  absent,
}

AttendanceStatus
_normalizeAttendanceStatus(
    dynamic value,
    ) {
  final raw =
      value?.toString()
          .trim()
          .toLowerCase() ??
          '';

  switch (raw) {
    case 'present':
      return AttendanceStatus
          .present;

    case 'half-day':
    case 'half day':
    case 'halfday':
      return AttendanceStatus
          .halfDay;

    case 'absent':
      return AttendanceStatus
          .absent;

    default:
      return AttendanceStatus
          .absent;
  }
}

// ============================================================================
// DATE HELPERS
// ============================================================================

DateTime? _parseDate(
    dynamic value,
    ) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  if (value is String &&
      value.trim().isNotEmpty) {
    return DateTime.tryParse(
      value.trim(),
    );
  }

  return null;
}

DateTime? _parseEventStartDate(
    Map<String, dynamic>? data,
    ) {
  if (data == null) {
    return null;
  }

  final values = [
    data['eventDate'],
    data['startDate'],
    data['eventStart'],
    data['startTime'],
  ];

  for (final value in values) {
    final parsed =
    _parseDate(value);

    if (parsed != null) {
      return parsed;
    }
  }

  return null;
}

DateTime? _parseEventEndDate(
    Map<String, dynamic>? data,
    ) {
  if (data == null) {
    return null;
  }

  final values = [
    data['endDate'],
    data['eventEnd'],
    data['endTime'],
  ];

  for (final value in values) {
    final parsed =
    _parseDate(value);

    if (parsed != null) {
      return parsed;
    }
  }

  return null;
}

DateTime _toManila(
    DateTime value,
    ) {
  return value
      .toUtc()
      .add(
    const Duration(
      hours: 8,
    ),
  );
}

// ============================================================================
// BOTTOM GRID
// ============================================================================

class _BottomGrid
    extends StatelessWidget {
  final _DashboardData data;

  const _BottomGrid({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final topCourse =
    _largest(
      data.studentCourse,
    );

    final subtitle =
    data.studentCourse.isEmpty
        ? 'No student course data available.'
        : 'Largest group: ${topCourse?.key} · ${topCourse?.value} students';

    return LayoutBuilder(
      builder:
          (
          context,
          constraints,
          ) {
        final courses =
        _PremiumSection(
          title:
          'Students by Course',
          subtitle:
          subtitle,
          icon:
          Icons.school_outlined,
          child:
          SizedBox(
            height:
            350,
            child:
            _StudentCourseChart(
              data:
              data,
            ),
          ),
        );

        final events =
        _PremiumSection(
          title:
          'Events',
          subtitle:
          'Showing 5 events per page.',
          icon:
          Icons.calendar_month_rounded,
          child:
          SizedBox(
            height:
            350,
            child:
            _EventsPager(
              events:
              data.events,
            ),
          ),
        );

        if (constraints.maxWidth <
            900) {
          return Column(
            children: [
              courses,
              const SizedBox(
                height:
                18,
              ),
              events,
            ],
          );
        }

        return Row(
          crossAxisAlignment:
          CrossAxisAlignment
              .start,
          children: [
            Expanded(
              child:
              courses,
            ),
            const SizedBox(
              width:
              18,
            ),
            Expanded(
              child:
              events,
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// DATA CLASSES
// ============================================================================

class _AttendanceRecord {
  final String attendanceId;
  final String eventId;
  final AttendanceStatus status;
  final DateTime? date;
  final int? year;

  const _AttendanceRecord({
    required this.attendanceId,
    required this.eventId,
    required this.status,
    required this.date,
    required this.year,
  });
}

class _MutableEventAttendance {
  final String eventId;
  final String eventName;
  final DateTime? eventDate;

  int present = 0;
  int halfDay = 0;
  int absent = 0;

  _MutableEventAttendance({
    required this.eventId,
    required this.eventName,
    required this.eventDate,
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

  int get total =>
      present +
          halfDay +
          absent;
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

  final Map<String, int>
  studentCourse;

  final Map<String, int>
  studentCollege;

  final List<
      QueryDocumentSnapshot<
          Map<String, dynamic>>>
  events;

  final List<_EventAttendance>
  eventAttendance;

  final List<_AttendanceRecord>
  attendanceRecords;

  final List<int>
  attendanceYears;

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

  factory _DashboardData.empty() {
    return const _DashboardData(
      totalUsers:
      0,
      totalStudents:
      0,
      totalEvents:
      0,
      totalAttendance:
      0,
      todayAttendance:
      0,
      present:
      0,
      halfDay:
      0,
      absent:
      0,
      studentCourse:
      {},
      studentCollege:
      {},
      events:
      [],
      eventAttendance:
      [],
      attendanceRecords:
      [],
      attendanceYears:
      [],
    );
  }
}

// ============================================================================
// LARGEST
// ============================================================================

MapEntry<String, int>? _largest(
    Map<String, int> map,
    ) {
  if (map.isEmpty) {
    return null;
  }

  final values =
  map.entries.toList()
    ..sort(
          (a, b) =>
          b.value.compareTo(
            a.value,
          ),
    );

  return values.first;
}