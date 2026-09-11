import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event_model.dart';
import 'super_admin_common.dart';

class SuperAdminEventsScreen extends StatefulWidget {
  const SuperAdminEventsScreen({
    super.key,
  });

  @override
  State<SuperAdminEventsScreen> createState() =>
      _SuperAdminEventsScreenState();
}

class _SuperAdminEventsScreenState
    extends State<SuperAdminEventsScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  late final Stream<QuerySnapshot<Map<String, dynamic>>>
  _eventsStream;

  static const int _pageSize = 4;

  int _currentPage = 0;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _eventsStream = FirebaseFirestore.instance
        .collection('events')
        .orderBy(
      'eventDate',
      descending: false,
    )
        .limit(500)
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
  // CLEAR SEARCH
  // ============================================================

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
      _currentPage = 0;
    });
  }

  // ============================================================
  // MANILA TIME
  // ============================================================

  static const Duration _manilaOffset =
  Duration(hours: 8);

  static DateTime _nowManila() {
    return DateTime.now()
        .toUtc()
        .add(_manilaOffset);
  }

  // ============================================================
  // STATUS
  // ============================================================

  String _computeStatus(
      DateTime eventDate, {
        String? existingStatus,
      }) {
    if ((existingStatus ?? '')
        .toLowerCase()
        .trim() ==
        'cancelled') {
      return 'cancelled';
    }

    final now = _nowManila();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final day = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
    );

    if (day.isAfter(today)) {
      return 'upcoming';
    }

    if (day.isAtSameMomentAs(today)) {
      return 'active';
    }

    return 'ended';
  }

  String _displayStatus(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Ongoing';
      case 'ended':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'upcoming':
      default:
        return 'Upcoming';
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return TraceColors.warning;
      case 'ended':
        return TraceColors.success;
      case 'cancelled':
        return TraceColors.danger;
      case 'upcoming':
      default:
        return const Color(0xFF2563EB);
    }
  }

  // ============================================================
  // STATS
  // ============================================================

  Widget _stats(
      int total,
      int upcoming,
      int ongoing,
      int completed,
      double width,
      ) {
    final cards = [
      _StatCard(
        title: 'Total',
        value: '$total',
        icon: Icons.event_rounded,
        accent: TraceColors.accent,
      ),
      _StatCard(
        title: 'Upcoming',
        value: '$upcoming',
        icon: Icons.upcoming_rounded,
        accent: const Color(0xFF2563EB),
      ),
      _StatCard(
        title: 'Ongoing',
        value: '$ongoing',
        icon:
        Icons.play_circle_outline_rounded,
        accent: TraceColors.warning,
      ),
      _StatCard(
        title: 'Completed',
        value: '$completed',
        icon:
        Icons.check_circle_outline_rounded,
        accent: TraceColors.success,
      ),
    ];

    if (width < 650) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: cards[0],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: cards[1],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: cards[2],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: cards[3],
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: cards[0],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: cards[1],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: cards[2],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: cards[3],
        ),
      ],
    );
  }

  // ============================================================
  // DIALOG FIELD DECORATION
  // ============================================================

  InputDecoration _dialogDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
        color: TraceColors.textSecondary,
        fontSize: 11.5,
      ),
      hintStyle: const TextStyle(
        color: TraceColors.textTertiary,
        fontSize: 11.5,
      ),
      prefixIcon: Icon(
        icon,
        size: 18,
        color: TraceColors.textTertiary,
      ),
      filled: true,
      fillColor: TraceColors.canvas,
      contentPadding:
      const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      border: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: TraceColors.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: TraceColors.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: TraceColors.accent,
          width: 1.2,
        ),
      ),
    );
  }

  // ============================================================
  // CREATE / EDIT EVENT
  // ============================================================

  Future<void> _showEventDialog({
    String? id,
    Map<String, dynamic>? data,
  }) async {
    final eventNameController =
    TextEditingController(
      text: SuperAdminCommon.text(
        data ?? {},
        ['eventName'],
      ),
    );

    final venueController =
    TextEditingController(
      text: SuperAdminCommon.text(
        data ?? {},
        ['venue'],
      ),
    );

    final descriptionController =
    TextEditingController(
      text: SuperAdminCommon.text(
        data ?? {},
        ['description'],
      ),
    );

    DateTime selectedDate =
        SuperAdminCommon.date(
          data ?? {},
          ['eventDate'],
        ) ??
            DateTime.now();

    final existingStatus =
    SuperAdminCommon.text(
      data ?? {},
      ['status'],
    );

    TimeOfDay? timeInStart =
    _parseTime(
      SuperAdminCommon.text(
        data ?? {},
        ['timeInStart'],
      ),
    );

    TimeOfDay? timeInEnd =
    _parseTime(
      SuperAdminCommon.text(
        data ?? {},
        ['timeInEnd'],
      ),
    );

    TimeOfDay? timeOutStart =
    _parseTime(
      SuperAdminCommon.text(
        data ?? {},
        ['timeOutStart'],
      ),
    );

    TimeOfDay? timeOutEnd =
    _parseTime(
      SuperAdminCommon.text(
        data ?? {},
        ['timeOutEnd'],
      ),
    );

    final formKey =
    GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            final previewStatus =
            _computeStatus(
              selectedDate,
              existingStatus:
              existingStatus,
            );

            final previewColor =
            _statusColor(
              previewStatus,
            );

            return Dialog(
              backgroundColor:
              TraceColors.surface,
              insetPadding:
              const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints:
                const BoxConstraints(
                  maxWidth: 640,
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    padding:
                    const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              alignment:
                              Alignment.center,
                              decoration:
                              BoxDecoration(
                                color: TraceColors
                                    .accentSoft,
                                borderRadius:
                                BorderRadius.circular(
                                  12,
                                ),
                              ),
                              child:
                              const Icon(
                                Icons.event_rounded,
                                color:
                                TraceColors
                                    .accent,
                                size: 20,
                              ),
                            ),
                            const SizedBox(
                              width: 12,
                            ),
                            Expanded(
                              child:
                              Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [
                                  Text(
                                    id == null
                                        ? 'Create Event'
                                        : 'Edit Event',
                                    style:
                                    const TextStyle(
                                      color:
                                      TraceColors
                                          .textPrimary,
                                      fontSize: 17,
                                      fontWeight:
                                      FontWeight
                                          .w800,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 3,
                                  ),
                                  Text(
                                    id == null
                                        ? 'Create a new school event.'
                                        : 'Update the event details.',
                                    style:
                                    const TextStyle(
                                      color:
                                      TraceColors
                                          .textTertiary,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        TextFormField(
                          controller:
                          eventNameController,
                          textCapitalization:
                          TextCapitalization
                              .sentences,
                          decoration:
                          _dialogDecoration(
                            label: 'Event Name',
                            hint:
                            'Enter event name',
                            icon:
                            Icons.title_rounded,
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Please enter an event name.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(
                          height: 13,
                        ),
                        TextFormField(
                          controller:
                          venueController,
                          textCapitalization:
                          TextCapitalization
                              .words,
                          decoration:
                          _dialogDecoration(
                            label: 'Venue',
                            hint:
                            'Enter event venue',
                            icon: Icons
                                .location_on_outlined,
                          ),
                        ),
                        const SizedBox(
                          height: 13,
                        ),
                        TextFormField(
                          controller:
                          descriptionController,
                          textCapitalization:
                          TextCapitalization
                              .sentences,
                          maxLines: 4,
                          decoration:
                          _dialogDecoration(
                            label:
                            'Description',
                            hint:
                            'Enter a short description',
                            icon: Icons
                                .description_outlined,
                          ),
                        ),
                        const SizedBox(
                          height: 13,
                        ),
                        _DateField(
                          selectedDate:
                          selectedDate,
                          onTap: () async {
                            final picked =
                            await showDatePicker(
                              context: context,
                              firstDate:
                              DateTime(2020),
                              lastDate:
                              DateTime(2035),
                              initialDate:
                              selectedDate,
                            );

                            if (picked == null) {
                              return;
                            }

                            setDialogState(() {
                              selectedDate =
                                  picked;
                            });
                          },
                        ),
                        const SizedBox(
                          height: 13,
                        ),
                        Container(
                          width:
                          double.infinity,
                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          decoration:
                          BoxDecoration(
                            color:
                            TraceColors
                                .canvas,
                            borderRadius:
                            BorderRadius.circular(
                              12,
                            ),
                            border:
                            Border.all(
                              color:
                              TraceColors
                                  .border,
                            ),
                          ),
                          child:
                          Row(
                            children: [
                              const Icon(
                                Icons.flag_outlined,
                                size: 18,
                                color:
                                TraceColors
                                    .textTertiary,
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              Container(
                                width: 9,
                                height: 9,
                                decoration:
                                BoxDecoration(
                                  color:
                                  previewColor,
                                  shape:
                                  BoxShape.circle,
                                ),
                              ),
                              const SizedBox(
                                width: 7,
                              ),
                              Text(
                                _displayStatus(
                                  previewStatus,
                                ),
                                style:
                                TextStyle(
                                  color:
                                  previewColor,
                                  fontSize: 12.5,
                                  fontWeight:
                                  FontWeight
                                      .w800,
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'Auto based on date',
                                style:
                                TextStyle(
                                  color:
                                  TraceColors
                                      .textTertiary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        const Text(
                          'Attendance Schedule',
                          style: TextStyle(
                            color:
                            TraceColors
                                .textPrimary,
                            fontSize: 12.5,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                        const SizedBox(
                          height: 3,
                        ),
                        const Text(
                          'Set the available Time In and Time Out windows.',
                          style: TextStyle(
                            color:
                            TraceColors
                                .textTertiary,
                            fontSize: 9.5,
                          ),
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child:
                              _TimeField(
                                label:
                                'Time In Start',
                                value:
                                timeInStart,
                                icon:
                                Icons
                                    .login_rounded,
                                onTap:
                                    () async {
                                  final picked =
                                  await _pickTime(
                                    context,
                                    timeInStart,
                                  );

                                  if (picked != null) {
                                    setDialogState(() {
                                      timeInStart =
                                          picked;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child:
                              _TimeField(
                                label:
                                'Time In End',
                                value:
                                timeInEnd,
                                icon:
                                Icons
                                    .schedule_rounded,
                                onTap:
                                    () async {
                                  final picked =
                                  await _pickTime(
                                    context,
                                    timeInEnd,
                                  );

                                  if (picked != null) {
                                    setDialogState(() {
                                      timeInEnd =
                                          picked;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child:
                              _TimeField(
                                label:
                                'Time Out Start',
                                value:
                                timeOutStart,
                                icon:
                                Icons
                                    .logout_rounded,
                                onTap:
                                    () async {
                                  final picked =
                                  await _pickTime(
                                    context,
                                    timeOutStart,
                                  );

                                  if (picked != null) {
                                    setDialogState(() {
                                      timeOutStart =
                                          picked;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child:
                              _TimeField(
                                label:
                                'Time Out End',
                                value:
                                timeOutEnd,
                                icon:
                                Icons
                                    .schedule_rounded,
                                onTap:
                                    () async {
                                  final picked =
                                  await _pickTime(
                                    context,
                                    timeOutEnd,
                                  );

                                  if (picked != null) {
                                    setDialogState(() {
                                      timeOutEnd =
                                          picked;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 22,
                        ),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(
                                  dialogContext,
                                );
                              },
                              child:
                              const Text(
                                'Cancel',
                              ),
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            ElevatedButton.icon(
                              onPressed:
                                  () async {
                                if (!(formKey
                                    .currentState
                                    ?.validate() ??
                                    false)) {
                                  return;
                                }

                                final resolvedStatus =
                                _computeStatus(
                                  selectedDate,
                                  existingStatus:
                                  existingStatus,
                                );

                                final payload =
                                <String, dynamic>{
                                  'eventName':
                                  eventNameController
                                      .text
                                      .trim(),
                                  'description':
                                  descriptionController
                                      .text
                                      .trim(),
                                  'venue':
                                  venueController
                                      .text
                                      .trim(),
                                  'eventDate':
                                  Timestamp.fromDate(
                                    selectedDate,
                                  ),
                                  'timeInStart':
                                  _formatTime(
                                    timeInStart,
                                  ),
                                  'timeInEnd':
                                  _formatTime(
                                    timeInEnd,
                                  ),
                                  'timeOutStart':
                                  _formatTime(
                                    timeOutStart,
                                  ),
                                  'timeOutEnd':
                                  _formatTime(
                                    timeOutEnd,
                                  ),
                                  'status':
                                  resolvedStatus,
                                  'updatedAt':
                                  FieldValue
                                      .serverTimestamp(),
                                };

                                try {
                                  final collection =
                                  FirebaseFirestore
                                      .instance
                                      .collection(
                                    'events',
                                  );

                                  if (id == null) {
                                    await collection
                                        .add({
                                      ...payload,
                                      'createdAt':
                                      FieldValue
                                          .serverTimestamp(),
                                    });
                                  } else {
                                    await collection
                                        .doc(id)
                                        .update(
                                      payload,
                                    );
                                  }

                                  if (!dialogContext
                                      .mounted) {
                                    return;
                                  }

                                  Navigator.pop(
                                    dialogContext,
                                  );

                                  if (!mounted) {
                                    return;
                                  }

                                  SuperAdminCommon
                                      .snack(
                                    context,
                                    id == null
                                        ? 'Event created successfully.'
                                        : 'Event updated successfully.',
                                  );
                                } catch (_) {
                                  if (!dialogContext
                                      .mounted) {
                                    return;
                                  }

                                  SuperAdminCommon
                                      .snack(
                                    dialogContext,
                                    'Unable to save event.',
                                    error: true,
                                  );
                                }
                              },
                              icon:
                              const Icon(
                                Icons.check_rounded,
                                size: 17,
                              ),
                              label:
                              Text(
                                id == null
                                    ? 'Create Event'
                                    : 'Save Changes',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    eventNameController.dispose();
    venueController.dispose();
    descriptionController.dispose();
  }

  // ============================================================
  // TIME PICKER
  // ============================================================

  Future<TimeOfDay?> _pickTime(
      BuildContext context,
      TimeOfDay? initial,
      ) {
    return showTimePicker(
      context: context,
      initialTime:
      initial ?? TimeOfDay.now(),
    );
  }

  // ============================================================
  // DELETE EVENT
  // ============================================================

  Future<void> _deleteEvent(
      String id,
      String eventName,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
          TraceColors.surface,
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(18),
          ),
          title:
          const Text(
            'Delete Event',
            style:
            TextStyle(
              fontSize: 16,
              fontWeight:
              FontWeight.w800,
            ),
          ),
          content:
          Text(
            'Are you sure you want to delete "$eventName"?',
            style:
            const TextStyle(
              color:
              TraceColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
              const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                TraceColors.danger,
                foregroundColor:
                Colors.white,
                elevation: 0,
              ),
              child:
              const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(id)
          .delete();

      if (!mounted) {
        return;
      }

      SuperAdminCommon.snack(
        context,
        'Event deleted successfully.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      SuperAdminCommon.snack(
        context,
        'Unable to delete event.',
        error: true,
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      TraceColors.canvas,
      body:
      SafeArea(
        child:
        StreamBuilder<
            QuerySnapshot<
                Map<String, dynamic>>>(
          stream:
          _eventsStream,
          builder: (
              context,
              snapshot,
              ) {
            // ==================================================
            // INITIAL LOADING ONLY
            // ==================================================

            if (snapshot.connectionState ==
                ConnectionState.waiting &&
                !snapshot.hasData) {
              return SuperAdminCommon.loading();
            }

            // ==================================================
            // ERROR
            // ==================================================

            if (snapshot.hasError) {
              return _ErrorState(
                onRetry: () {
                  setState(() {});
                },
              );
            }

            final docs =
                snapshot.data?.docs ??
                    [];

            // ==================================================
            // LOCAL SEARCH
            // ==================================================

            final filteredDocs =
            docs.where(
                  (doc) {
                final data =
                doc.data();

                final eventName =
                SuperAdminCommon
                    .text(
                  data,
                  ['eventName'],
                ).trim().toLowerCase();

                return _searchQuery.isEmpty ||
                    eventName.contains(
                      _searchQuery,
                    );
              },
            ).toList();

            // ==================================================
            // STATS
            // ==================================================

            final total =
                docs.length;

            int upcoming = 0;
            int ongoing = 0;
            int completed = 0;

            for (final doc in docs) {
              final data =
              doc.data();

              final event =
              EventModel.fromFirestore(
                doc,
              );

              final rawStatus =
              SuperAdminCommon
                  .text(
                data,
                ['status'],
              );

              final status =
              _computeStatus(
                event.eventDate,
                existingStatus:
                rawStatus,
              );

              switch (status) {
                case 'upcoming':
                  upcoming++;
                  break;
                case 'active':
                  ongoing++;
                  break;
                case 'ended':
                  completed++;
                  break;
                case 'cancelled':
                  break;
              }
            }

            // ==================================================
            // PAGINATION
            //
            // EXACTLY 7 EVENTS PER PAGE
            // ==================================================

            final totalPages =
            filteredDocs.isEmpty
                ? 1
                : (filteredDocs.length /
                _pageSize)
                .ceil();

            final maxPage =
                totalPages - 1;

            final safePage =
            _currentPage.clamp(
              0,
              maxPage,
            );

            final startIndex =
                safePage * _pageSize;

            final pagedDocs =
            filteredDocs
                .skip(
              startIndex,
            )
                .take(
              _pageSize,
            )
                .toList();

            final isFirstPage =
                safePage == 0;

            final isLastPage =
                safePage >= maxPage;

            // ==================================================
            // PAGE
            // ==================================================

            return LayoutBuilder(
              builder: (
                  context,
                  constraints,
                  ) {
                final width =
                    constraints.maxWidth;

                final isMobile =
                    width < 650;

                return SingleChildScrollView(
                  physics:
                  const BouncingScrollPhysics(),
                  padding:
                  EdgeInsets.fromLTRB(
                    isMobile ? 16 : 28,
                    isMobile ? 20 : 28,
                    isMobile ? 16 : 28,
                    32,
                  ),
                  child:
                  Center(
                    child:
                    ConstrainedBox(
                      constraints:
                      const BoxConstraints(
                        maxWidth: 1440,
                      ),
                      child:
                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .stretch,
                        children: [
                          _PageHeader(
                            onAdd:
                            _showEventDialog,
                          ),
                          const SizedBox(
                            height: 22,
                          ),
                          _stats(
                            total,
                            upcoming,
                            ongoing,
                            completed,
                            width,
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          _EventsSection(
                            filteredCount:
                            filteredDocs
                                .length,
                            totalCount:
                            total,
                            searchController:
                            _searchController,
                            searchQuery:
                            _searchQuery,
                            events:
                            pagedDocs,
                            totalPages:
                            totalPages,
                            currentPage:
                            safePage,
                            onSearchChanged:
                            _onSearchChanged,
                            onClearSearch:
                            _clearSearch,
                            onPreviousPage:
                            isFirstPage
                                ? null
                                : () {
                              setState(() {
                                _currentPage =
                                    safePage -
                                        1;
                              });
                            },
                            onNextPage:
                            isLastPage
                                ? null
                                : () {
                              setState(() {
                                _currentPage =
                                    safePage +
                                        1;
                              });
                            },
                            onEdit:
                                (doc) {
                              _showEventDialog(
                                id:
                                doc.id,
                                data:
                                doc.data(),
                              );
                            },
                            onDelete:
                                (
                                id,
                                name,
                                ) {
                              _deleteEvent(
                                id,
                                name,
                              );
                            },
                            computeStatus:
                            _computeStatus,
                            displayStatus:
                            _displayStatus,
                            statusColor:
                            _statusColor,
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

// ================================================================
// STAT CARD
// ================================================================

class _StatCard
    extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width:
      double.infinity,
      constraints:
      const BoxConstraints(
        minHeight: 104,
      ),
      padding:
      const EdgeInsets.all(14),
      decoration:
      BoxDecoration(
        color:
        TraceColors.surface,
        borderRadius:
        BorderRadius.circular(16),
        border:
        Border.all(
          color:
          TraceColors.border,
        ),
      ),
      child:
      Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment:
            Alignment.center,
            decoration:
            BoxDecoration(
              color:
              accent.withValues(
                alpha: 0.10,
              ),
              borderRadius:
              BorderRadius.circular(12),
            ),
            child:
            Icon(
              icon,
              color:
              accent,
              size: 20,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child:
            Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                  const TextStyle(
                    color:
                    TraceColors
                        .textTertiary,
                    fontSize: 9.5,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  value,
                  style:
                  const TextStyle(
                    color:
                    TraceColors
                        .textPrimary,
                    fontSize: 21,
                    fontWeight:
                    FontWeight.w800,
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

// ================================================================
// PAGE HEADER
// ================================================================

class _PageHeader
    extends StatelessWidget {
  final VoidCallback onAdd;

  const _PageHeader({
    required this.onAdd,
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
          alignment:
          Alignment.center,
          decoration:
          BoxDecoration(
            color:
            TraceColors.accentSoft,
            borderRadius:
            BorderRadius.circular(13),
          ),
          child:
          const Icon(
            Icons.event_rounded,
            color:
            TraceColors.accent,
            size: 21,
          ),
        ),
        const SizedBox(
          width: 13,
        ),
        Expanded(
          child:
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Text(
                'Events',
                style:
                TextStyle(
                  color:
                  TraceColors
                      .textPrimary,
                  fontSize: 25,
                  fontWeight:
                  FontWeight.w800,
                  letterSpacing:
                  -0.5,
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              const Text(
                'Manage school events, schedules, and attendance windows.',
                maxLines: 2,
                overflow:
                TextOverflow.ellipsis,
                style:
                TextStyle(
                  color:
                  TraceColors
                      .textSecondary,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(
          width: 12,
        ),
        ElevatedButton.icon(
          onPressed:
          onAdd,
          icon:
          const Icon(
            Icons.add_rounded,
            size: 17,
          ),
          label:
          const Text(
            'Add Event',
          ),
          style:
          ElevatedButton.styleFrom(
            backgroundColor:
            TraceColors.accent,
            foregroundColor:
            TraceColors.ink,
            elevation:
            0,
            padding:
            const EdgeInsets
                .symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            textStyle:
            const TextStyle(
              fontSize: 11.5,
              fontWeight:
              FontWeight.w800,
            ),
            shape:
            RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(
                11,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// EVENTS SECTION
// ================================================================

class _EventsSection
    extends StatelessWidget {
  final int filteredCount;
  final int totalCount;

  final TextEditingController
  searchController;

  final String searchQuery;

  final List<
      QueryDocumentSnapshot<
          Map<String, dynamic>>> events;

  final int totalPages;
  final int currentPage;

  final ValueChanged<String>
  onSearchChanged;

  final VoidCallback
  onClearSearch;

  final VoidCallback?
  onPreviousPage;

  final VoidCallback?
  onNextPage;

  final void Function(
      QueryDocumentSnapshot<
          Map<String, dynamic>>)
  onEdit;

  final void Function(
      String id,
      String name,
      ) onDelete;

  final String Function(
      DateTime, {
      String? existingStatus,
      }) computeStatus;

  final String Function(
      String,
      ) displayStatus;

  final Color Function(
      String,
      ) statusColor;

  const _EventsSection({
    required this.filteredCount,
    required this.totalCount,
    required this.searchController,
    required this.searchQuery,
    required this.events,
    required this.totalPages,
    required this.currentPage,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onEdit,
    required this.onDelete,
    required this.computeStatus,
    required this.displayStatus,
    required this.statusColor,
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
        BorderRadius.circular(19),
        border:
        Border.all(
          color:
          TraceColors.border,
        ),
      ),
      child:
      Padding(
        padding:
        const EdgeInsets.all(18),
        child:
        Column(
          crossAxisAlignment:
          CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment:
                  Alignment.center,
                  decoration:
                  BoxDecoration(
                    color:
                    TraceColors
                        .accentSoft,
                    borderRadius:
                    BorderRadius.circular(
                      11,
                    ),
                  ),
                  child:
                  const Icon(
                    Icons
                        .calendar_month_rounded,
                    color:
                    TraceColors.accent,
                    size: 18,
                  ),
                ),
                const SizedBox(
                  width: 11,
                ),
                Expanded(
                  child:
                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Event Management',
                        style:
                        TextStyle(
                          color:
                          TraceColors
                              .textPrimary,
                          fontSize: 13.5,
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        '$filteredCount of $totalCount events shown',
                        style:
                        const TextStyle(
                          color:
                          TraceColors
                              .textTertiary,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 16,
            ),
            TextField(
              controller:
              searchController,
              onChanged:
              onSearchChanged,
              decoration:
              InputDecoration(
                isDense: true,
                hintText:
                'Search event name...',
                hintStyle:
                const TextStyle(
                  color:
                  TraceColors
                      .textTertiary,
                  fontSize: 11.5,
                ),
                prefixIcon:
                const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color:
                  TraceColors
                      .textTertiary,
                ),
                suffixIcon:
                searchQuery.isNotEmpty
                    ? IconButton(
                  tooltip:
                  'Clear search',
                  onPressed:
                  onClearSearch,
                  icon:
                  const Icon(
                    Icons
                        .close_rounded,
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
                const EdgeInsets
                    .symmetric(
                  horizontal: 12,
                  vertical: 13,
                ),
                border:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                  borderSide:
                  BorderSide.none,
                ),
                enabledBorder:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                  borderSide:
                  BorderSide.none,
                ),
                focusedBorder:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                  borderSide:
                  const BorderSide(
                    color:
                    TraceColors
                        .accent,
                    width: 1.1,
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: 14,
            ),
            const Divider(
              height: 1,
              color:
              TraceColors.border,
            ),
            const SizedBox(
              height: 16,
            ),
            if (events.isEmpty)
              SizedBox(
                height: 220,
                child:
                SuperAdminCommon.empty(
                  searchQuery.isNotEmpty
                      ? 'No events match your search.'
                      : 'No events found.',
                  icon:
                  Icons
                      .event_busy_rounded,
                ),
              )
            else
              ListView.separated(
                shrinkWrap:
                true,
                physics:
                const NeverScrollableScrollPhysics(),
                itemCount:
                events.length,
                separatorBuilder:
                    (
                    context,
                    index,
                    ) =>
                const SizedBox(
                  height: 10,
                ),
                itemBuilder:
                    (
                    context,
                    index,
                    ) {
                  return _EventCard(
                    doc:
                    events[index],
                    onEdit:
                    onEdit,
                    onDelete:
                    onDelete,
                    computeStatus:
                    computeStatus,
                    displayStatus:
                    displayStatus,
                    statusColor:
                    statusColor,
                  );
                },
              ),
            if (totalPages > 1) ...[
              const SizedBox(
                height: 16,
              ),
              const Divider(
                height: 1,
                color:
                TraceColors.border,
              ),
              const SizedBox(
                height: 13,
              ),
              Row(
                mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
                children: [
                  Text(
                    'Page ${currentPage + 1} of $totalPages',
                    style:
                    const TextStyle(
                      color:
                      TraceColors
                          .textTertiary,
                      fontSize: 10,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      _PagerButton(
                        icon:
                        Icons
                            .chevron_left_rounded,
                        onTap:
                        onPreviousPage,
                      ),
                      const SizedBox(
                        width: 7,
                      ),
                      _PagerButton(
                        icon:
                        Icons
                            .chevron_right_rounded,
                        onTap:
                        onNextPage,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ================================================================
// EVENT CARD
// ================================================================

class _EventCard
    extends StatelessWidget {
  final QueryDocumentSnapshot<
      Map<String, dynamic>> doc;

  final void Function(
      QueryDocumentSnapshot<
          Map<String, dynamic>>)
  onEdit;

  final void Function(
      String id,
      String name,
      ) onDelete;

  final String Function(
      DateTime, {
      String? existingStatus,
      }) computeStatus;

  final String Function(
      String,
      ) displayStatus;

  final Color Function(
      String,
      ) statusColor;

  const _EventCard({
    required this.doc,
    required this.onEdit,
    required this.onDelete,
    required this.computeStatus,
    required this.displayStatus,
    required this.statusColor,
  });

  @override
  Widget build(
      BuildContext context) {
    final data =
    doc.data();

    final event =
    EventModel.fromFirestore(
      doc,
    );

    final rawStatus =
    SuperAdminCommon.text(
      data,
      ['status'],
    );

    final resolvedStatus =
    computeStatus(
      event.eventDate,
      existingStatus:
      rawStatus,
    );

    final status =
    displayStatus(
      resolvedStatus,
    );

    final color =
    statusColor(
      resolvedStatus,
    );

    return Container(
      padding:
      const EdgeInsets.all(13),
      decoration:
      BoxDecoration(
        color:
        TraceColors.canvas,
        borderRadius:
        BorderRadius.circular(14),
        border:
        Border.all(
          color:
          TraceColors.border
              .withValues(
            alpha: 0.75,
          ),
        ),
      ),
      child:
      Row(
        crossAxisAlignment:
        CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment:
            Alignment.center,
            decoration:
            BoxDecoration(
              color:
              TraceColors.accentSoft,
              borderRadius:
              BorderRadius.circular(12),
            ),
            child:
            Icon(
              event.icon,
              color:
              TraceColors.accent,
              size: 19,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child:
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child:
                      Text(
                        event.eventName
                            .trim()
                            .isEmpty
                            ? 'Untitled Event'
                            : event.eventName,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style:
                        const TextStyle(
                          color:
                          TraceColors
                              .textPrimary,
                          fontSize: 13,
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    _StatusBadge(
                      label:
                      status,
                      color:
                      color,
                    ),
                  ],
                ),
                const SizedBox(
                  height: 7,
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 5,
                  children: [
                    _EventMeta(
                      icon:
                      Icons
                          .calendar_today_rounded,
                      text:
                      DateFormat(
                        'MMM d, yyyy',
                      ).format(
                        event.eventDate,
                      ),
                    ),
                    if (event.venue
                        .trim()
                        .isNotEmpty)
                      _EventMeta(
                        icon:
                        Icons
                            .location_on_outlined,
                        text:
                        event.venue,
                      ),
                  ],
                ),
                if (event
                    .formattedCheckInWindow !=
                    null ||
                    event
                        .formattedCheckOutWindow !=
                        null) ...[
                  const SizedBox(
                    height: 7,
                  ),
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    children: [
                      if (event
                          .formattedCheckInWindow !=
                          null)
                        _SmallChip(
                          label:
                          'IN',
                          value:
                          event
                              .formattedCheckInWindow!,
                        ),
                      if (event
                          .formattedCheckOutWindow !=
                          null)
                        _SmallChip(
                          label:
                          'OUT',
                          value:
                          event
                              .formattedCheckOutWindow!,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(
            width: 4,
          ),
          PopupMenuButton<String>(
            tooltip:
            'Event actions',
            icon:
            const Icon(
              Icons.more_vert_rounded,
              color:
              TraceColors
                  .textTertiary,
              size: 20,
            ),
            onSelected:
                (value) {
              if (value ==
                  'edit') {
                onEdit(doc);
              }

              if (value ==
                  'delete') {
                onDelete(
                  doc.id,
                  event.eventName,
                );
              }
            },
            itemBuilder:
                (context) =>
            const [
              PopupMenuItem(
                value:
                'edit',
                child:
                Row(
                  children: [
                    Icon(
                      Icons
                          .edit_outlined,
                      size: 17,
                    ),
                    SizedBox(
                      width: 9,
                    ),
                    Text(
                      'Edit Event',
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value:
                'delete',
                child:
                Row(
                  children: [
                    Icon(
                      Icons
                          .delete_outline_rounded,
                      size: 17,
                      color:
                      TraceColors
                          .danger,
                    ),
                    SizedBox(
                      width: 9,
                    ),
                    Text(
                      'Delete Event',
                    ),
                  ],
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
// EVENT META
// ================================================================

class _EventMeta
    extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EventMeta({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(
      BuildContext context) {
    return Row(
      mainAxisSize:
      MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color:
          TraceColors
              .textTertiary,
        ),
        const SizedBox(
          width: 4,
        ),
        ConstrainedBox(
          constraints:
          const BoxConstraints(
            maxWidth: 210,
          ),
          child:
          Text(
            text,
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
            style:
            const TextStyle(
              color:
              TraceColors
                  .textSecondary,
              fontSize: 9.5,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// SMALL TIME CHIP
// ================================================================

class _SmallChip
    extends StatelessWidget {
  final String label;
  final String value;

  const _SmallChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
      BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration:
      BoxDecoration(
        color:
        TraceColors.surface,
        borderRadius:
        BorderRadius.circular(7),
        border:
        Border.all(
          color:
          TraceColors.border,
        ),
      ),
      child:
      RichText(
        text:
        TextSpan(
          children: [
            TextSpan(
              text:
              '$label  ',
              style:
              const TextStyle(
                color:
                TraceColors
                    .accent,
                fontSize: 8,
                fontWeight:
                FontWeight.w800,
              ),
            ),
            TextSpan(
              text:
              value,
              style:
              const TextStyle(
                color:
                TraceColors
                    .textSecondary,
                fontSize: 8,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// STATUS BADGE
// ================================================================

class _StatusBadge
    extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(
      BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 8,
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
      child:
      Text(
        label,
        style:
        TextStyle(
          color:
          color,
          fontSize: 8.5,
          fontWeight:
          FontWeight.w800,
        ),
      ),
    );
  }
}

// ================================================================
// PAGINATION BUTTON
// ================================================================

class _PagerButton
    extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _PagerButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context) {
    final enabled =
        onTap != null;

    return Material(
      color:
      TraceColors.canvas,
      borderRadius:
      BorderRadius.circular(9),
      child:
      InkWell(
        onTap:
        onTap,
        borderRadius:
        BorderRadius.circular(9),
        child:
        Container(
          width: 32,
          height: 32,
          alignment:
          Alignment.center,
          decoration:
          BoxDecoration(
            borderRadius:
            BorderRadius.circular(9),
            border:
            Border.all(
              color:
              TraceColors.border,
            ),
          ),
          child:
          Icon(
            icon,
            size: 18,
            color: enabled
                ? TraceColors
                .textSecondary
                : TraceColors
                .textTertiary
                .withValues(
              alpha: 0.45,
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// DATE FIELD
// ================================================================

class _DateField
    extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onTap;

  const _DateField({
    required this.selectedDate,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context) {
    return InkWell(
      onTap:
      onTap,
      borderRadius:
      BorderRadius.circular(12),
      child:
      InputDecorator(
        decoration:
        const InputDecoration(
          labelText:
          'Event Date',
          labelStyle:
          TextStyle(
            color:
            TraceColors
                .textSecondary,
            fontSize: 11.5,
          ),
          prefixIcon:
          Icon(
            Icons
                .calendar_month_outlined,
            size: 18,
            color:
            TraceColors
                .textTertiary,
          ),
          suffixIcon:
          Icon(
            Icons
                .expand_more_rounded,
            color:
            TraceColors
                .textTertiary,
          ),
          filled:
          true,
          fillColor:
          TraceColors.canvas,
          contentPadding:
          EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.all(
              Radius.circular(12),
            ),
            borderSide:
            BorderSide(
              color:
              TraceColors
                  .border,
            ),
          ),
          enabledBorder:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.all(
              Radius.circular(12),
            ),
            borderSide:
            BorderSide(
              color:
              TraceColors
                  .border,
            ),
          ),
        ),
        child:
        Text(
          DateFormat(
            'MMMM d, yyyy',
          ).format(
            selectedDate,
          ),
          style:
          const TextStyle(
            color:
            TraceColors
                .textPrimary,
            fontSize:
            12,
            fontWeight:
            FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ================================================================
// TIME FIELD
// ================================================================

class _TimeField
    extends StatelessWidget {
  final String label;
  final TimeOfDay? value;
  final IconData icon;
  final VoidCallback onTap;

  const _TimeField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context) {
    return InkWell(
      onTap:
      onTap,
      borderRadius:
      BorderRadius.circular(12),
      child:
      Container(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        decoration:
        BoxDecoration(
          color:
          TraceColors.canvas,
          borderRadius:
          BorderRadius.circular(12),
          border:
          Border.all(
            color:
            TraceColors.border,
          ),
        ),
        child:
        Row(
          children: [
            Icon(
              icon,
              size: 17,
              color:
              TraceColors
                  .textTertiary,
            ),
            const SizedBox(
              width: 8,
            ),
            Expanded(
              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style:
                    const TextStyle(
                      color:
                      TraceColors
                          .textTertiary,
                      fontSize: 8,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
                  Text(
                    value == null
                        ? 'Select time'
                        : value!.format(
                      context,
                    ),
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style:
                    TextStyle(
                      color:
                      value == null
                          ? TraceColors
                          .textTertiary
                          : TraceColors
                          .textPrimary,
                      fontSize: 10.5,
                      fontWeight:
                      FontWeight.w700,
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
// TIME PARSER
// ================================================================

TimeOfDay? _parseTime(
    String value,
    ) {
  final text =
  value.trim();

  if (text.isEmpty) {
    return null;
  }

  final amPm =
  RegExp(
    r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
    caseSensitive: false,
  ).firstMatch(text);

  if (amPm != null) {
    int hour = int.parse(
      amPm.group(1)!,
    );

    final minute = int.parse(
      amPm.group(2)!,
    );

    final period =
    amPm.group(3)!.toUpperCase();

    if (period == 'PM' &&
        hour != 12) {
      hour += 12;
    }

    if (period == 'AM' &&
        hour == 12) {
      hour = 0;
    }

    if (hour >= 0 &&
        hour <= 23 &&
        minute >= 0 &&
        minute <= 59) {
      return TimeOfDay(
        hour: hour,
        minute: minute,
      );
    }

    return null;
  }

  final twentyFour =
  RegExp(
    r'^(\d{1,2}):(\d{2})$',
  ).firstMatch(text);

  if (twentyFour != null) {
    final hour =
    int.parse(
      twentyFour.group(1)!,
    );

    final minute =
    int.parse(
      twentyFour.group(2)!,
    );

    if (hour >= 0 &&
        hour <= 23 &&
        minute >= 0 &&
        minute <= 59) {
      return TimeOfDay(
        hour: hour,
        minute: minute,
      );
    }
  }

  return null;
}

// ================================================================
// TIME FORMATTER
// ================================================================

String _formatTime(
    TimeOfDay? time,
    ) {
  if (time == null) {
    return '';
  }

  final hour =
  time.hourOfPeriod == 0
      ? 12
      : time.hourOfPeriod;

  final minute =
  time.minute.toString().padLeft(
    2,
    '0',
  );

  final period =
  time.period == DayPeriod.am
      ? 'AM'
      : 'PM';

  return '$hour:$minute $period';
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
      child:
      Padding(
        padding:
        const EdgeInsets.all(24),
        child:
        Column(
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
              'Unable to load events.',
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