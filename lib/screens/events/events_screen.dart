import 'dart:async';

import 'package:attendance/models/event_model.dart';
import 'package:attendance/screens/events/add_event_screen.dart';
import 'package:attendance/screens/events/edit_event_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

enum EventFilter {
  all,
  upcoming,
  ongoing,
  completed,
}

class _EventsScreenState extends State<EventsScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color navy = Color(0xFF071936);
  static const Color bgNavy = Color(0xFF081B3A);
  static const Color accentBlue = Color(0xFF4A90E2);

  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF6B7280);

  static const Color danger = Color(0xFFE05252);
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF5A623);

  static const double radiusL = 18;
  static const double radiusM = 14;
  static const double radiusS = 10;

  // ============================================================
  // STATE
  // ============================================================

  EventFilter _selectedFilter = EventFilter.all;

  String _searchQuery = '';

  final TextEditingController _searchController =
  TextEditingController();

  Timer? _debounce;

  int _animationVersion = 0;

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    _debounce = Timer(
      const Duration(milliseconds: 300),
          () {
        if (!mounted) return;

        setState(() {
          _searchQuery = value.trim();
          _animationVersion++;
        });
      },
    );

    setState(() {});
  }

  void _clearSearch() {
    _debounce?.cancel();

    _searchController.clear();

    setState(() {
      _searchQuery = '';
      _animationVersion++;
    });
  }

  // ============================================================
  // FILTER
  // ============================================================

  void _changeFilter(EventFilter filter) {
    if (_selectedFilter == filter) return;

    setState(() {
      _selectedFilter = filter;
      _animationVersion++;
    });
  }

  bool _matchesFilter(
      EventModel event,
      EventFilter filter,
      ) {
    switch (filter) {
      case EventFilter.all:
        break;

      case EventFilter.upcoming:
        if (event.statusLabel != 'Upcoming') {
          return false;
        }
        break;

      case EventFilter.ongoing:
        if (event.statusLabel != 'Active') {
          return false;
        }
        break;

      case EventFilter.completed:
        if (event.statusLabel != 'Ended') {
          return false;
        }
        break;
    }

    if (_searchQuery.isEmpty) {
      return true;
    }

    final query = _searchQuery.toLowerCase();

    return event.title.toLowerCase().contains(query) ||
        event.venue.toLowerCase().contains(query);
  }

  String _filterLabel(EventFilter filter) {
    switch (filter) {
      case EventFilter.all:
        return 'All';

      case EventFilter.upcoming:
        return 'Upcoming';

      case EventFilter.ongoing:
        return 'Ongoing';

      case EventFilter.completed:
        return 'Completed';
    }
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _openAddEvent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddEventScreen(),
      ),
    );
  }

  void _openEditEvent(
      String docId,
      Map<String, dynamic> rawData,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditEventScreen(
          id: docId,
          event: rawData,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgNavy,

      appBar: AppBar(
        backgroundColor: navy,
        elevation: 0,
        centerTitle: true,

        title: const Text(
          'Events',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),

        iconTheme: const IconThemeData(
          color: Colors.white,
        ),

        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: 12,
            ),
            child: IconButton(
              tooltip: 'Add event',
              onPressed: _openAddEvent,
              style: IconButton.styleFrom(
                backgroundColor:
                Colors.white.withOpacity(0.10),
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),

      // ============================================================
      // FIRESTORE
      // ============================================================

      body: StreamBuilder<QuerySnapshot>(
        // IMPORTANT:
        // Do NOT use orderBy('createdAt') because older
        // documents may not contain createdAt.
        stream: FirebaseFirestore.instance
            .collection('events')
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const _LoadingView();
          }

          if (snapshot.hasError) {
            return const _ErrorView();
          }

          // ========================================================
          // LOAD ALL EVENTS
          // ========================================================

          final allEvents = (snapshot.data?.docs ?? [])
              .map(
                (doc) => MapEntry(
              doc,
              EventModel.fromFirestore(doc),
            ),
          )
              .toList();

          // ========================================================
          // SORT NEWEST FIRST
          // ========================================================

          allEvents.sort(
                (a, b) {
              final aData =
              a.key.data()
              as Map<String, dynamic>?;

              final bData =
              b.key.data()
              as Map<String, dynamic>?;

              final aCreatedAt =
              _getCreatedAt(aData);

              final bCreatedAt =
              _getCreatedAt(bData);

              if (aCreatedAt != null &&
                  bCreatedAt != null) {
                return bCreatedAt.compareTo(
                  aCreatedAt,
                );
              }

              if (aCreatedAt != null &&
                  bCreatedAt == null) {
                return -1;
              }

              if (aCreatedAt == null &&
                  bCreatedAt != null) {
                return 1;
              }

              return 0;
            },
          );

          // ========================================================
          // FILTER EVENTS
          // ========================================================

          final filtered = allEvents
              .where(
                (entry) => _matchesFilter(
              entry.value,
              _selectedFilter,
            ),
          )
              .toList();

          // ========================================================
          // COUNTS
          // ========================================================

          final upcomingCount = allEvents
              .where(
                (entry) =>
            entry.value.statusLabel ==
                'Upcoming',
          )
              .length;

          final ongoingCount = allEvents
              .where(
                (entry) =>
            entry.value.statusLabel ==
                'Active',
          )
              .length;

          // ========================================================
          // PAGE
          // ========================================================

          return Column(
            children: [
              _buildHeaderCard(
                total: allEvents.length,
                upcoming: upcomingCount,
                ongoing: ongoingCount,
              ),

              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.circular(radiusL),
                    boxShadow: [
                      BoxShadow(
                        color:
                        Colors.black.withOpacity(0.10),
                        blurRadius: 16,
                        offset:
                        const Offset(0, 6),
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
                        color:
                        Color(0xFFEEEEEE),
                      ),

                      Expanded(
                        child: AnimatedSwitcher(
                          duration:
                          const Duration(
                            milliseconds: 300,
                          ),
                          reverseDuration:
                          const Duration(
                            milliseconds: 220,
                          ),
                          switchInCurve:
                          Curves.easeOutCubic,
                          switchOutCurve:
                          Curves.easeInCubic,

                          layoutBuilder:
                              (
                              currentChild,
                              previousChildren,
                              ) {
                            return Stack(
                              alignment:
                              Alignment.topCenter,
                              children: [
                                ...previousChildren,
                                if (currentChild != null)
                                  currentChild,
                              ],
                            );
                          },

                          transitionBuilder:
                              (
                              child,
                              animation,
                              ) {
                            final curved =
                            CurvedAnimation(
                              parent: animation,
                              curve:
                              Curves.easeOutCubic,
                            );

                            final slide =
                            Tween<Offset>(
                              begin:
                              const Offset(
                                0.02,
                                0,
                              ),
                              end: Offset.zero,
                            ).animate(curved);

                            return FadeTransition(
                              opacity: curved,
                              child:
                              SlideTransition(
                                position: slide,
                                child: child,
                              ),
                            );
                          },

                          child: SizedBox(
                            key: ValueKey(
                              '${_selectedFilter.name}-'
                                  '$_searchQuery-'
                                  '$_animationVersion',
                            ),
                            width:
                            double.infinity,

                            child: allEvents.isEmpty
                                ? const _EmptyState(
                              title:
                              'No events yet',
                              subtitle:
                              'Create your first event to get started.',
                            )
                                : filtered.isEmpty
                                ? _EmptyState(
                              title:
                              'No matching events',
                              subtitle:
                              'Try another filter or search term.',
                              onClear: () {
                                setState(() {
                                  _selectedFilter =
                                      EventFilter.all;
                                  _searchQuery =
                                  '';
                                  _searchController
                                      .clear();
                                  _animationVersion++;
                                });
                              },
                            )
                                : _buildEventList(
                              filtered,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // CREATED AT
  // ============================================================

  DateTime? _getCreatedAt(
      Map<String, dynamic>? data,
      ) {
    if (data == null) {
      return null;
    }

    final value = data['createdAt'];

    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeaderCard({
    required int total,
    required int upcoming,
    required int ongoing,
  }) {
    return Container(
      color: navy,

      padding: const EdgeInsets.fromLTRB(
        16,
        6,
        16,
        16,
      ),

      child: Column(
        children: [
          // ========================================================
          // SEARCH
          // ========================================================

          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,

            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),

            decoration: InputDecoration(
              hintText:
              'Search events or venues...',

              hintStyle: TextStyle(
                color:
                Colors.white.withOpacity(0.50),
                fontSize: 14,
              ),

              prefixIcon: Icon(
                Icons.search_rounded,
                color:
                Colors.white.withOpacity(0.60),
              ),

              suffixIcon:
              _searchController.text.isEmpty
                  ? null
                  : IconButton(
                onPressed:
                _clearSearch,
                icon: Icon(
                  Icons.close_rounded,
                  color:
                  Colors.white
                      .withOpacity(0.60),
                  size: 18,
                ),
              ),

              filled: true,

              fillColor:
              Colors.white.withOpacity(0.08),

              contentPadding:
              const EdgeInsets.symmetric(
                vertical: 10,
              ),

              border: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(radiusM),
                borderSide:
                BorderSide.none,
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(radiusM),
                borderSide:
                BorderSide.none,
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(radiusM),
                borderSide: BorderSide(
                  color:
                  accentBlue.withOpacity(0.60),
                  width: 1,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ========================================================
          // STATS
          // ========================================================

          Row(
            children: [
              _statPill(
                label: 'Total',
                value: total,
                color: accentBlue,
              ),

              const SizedBox(width: 10),

              _statPill(
                label: 'Upcoming',
                value: upcoming,
                color: warning,
              ),

              const SizedBox(width: 10),

              _statPill(
                label: 'Ongoing',
                value: ongoing,
                color: success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STAT PILL
  // ============================================================

  Widget _statPill({
    required String label,
    required int value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding:
        const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 8,
        ),

        decoration: BoxDecoration(
          color:
          Colors.white.withOpacity(0.06),
          borderRadius:
          BorderRadius.circular(radiusS),
          border: Border.all(
            color:
            Colors.white.withOpacity(0.08),
          ),
        ),

        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight:
                FontWeight.w800,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              label,
              style: TextStyle(
                color:
                Colors.white.withOpacity(0.60),
                fontSize: 10.5,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FILTER BUTTONS
  // ============================================================

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10,
      ),

      child: Row(
        children: EventFilter.values.map(
              (filter) {
            final isSelected =
                filter ==
                    _selectedFilter;

            return Expanded(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 3,
                ),

                child:
                _TextFilterButton(
                  label:
                  _filterLabel(filter),
                  selected:
                  isSelected,
                  onTap: () =>
                      _changeFilter(
                        filter,
                      ),
                ),
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  // ============================================================
  // EVENT LIST
  // ============================================================

  Widget _buildEventList(
      List<
          MapEntry<
              DocumentSnapshot,
              EventModel
          >>
      events,
      ) {
    return RefreshIndicator(
      color: accentBlue,

      onRefresh: () async {
        await Future.delayed(
          const Duration(
            milliseconds: 300,
          ),
        );
      },

      child: ListView.separated(
        key: PageStorageKey(
          'events-${_selectedFilter.name}-'
              '$_searchQuery',
        ),

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
        events.length,

        separatorBuilder:
            (_, __) =>
        const SizedBox(
          height: 8,
        ),

        itemBuilder:
            (context, index) {
          final doc =
              events[index].key;

          final event =
              events[index].value;

          final rawData =
          doc.data()
          as Map<String, dynamic>;

          return _AnimatedEventCard(
            key: ValueKey(
              '${doc.id}-'
                  '$_animationVersion',
            ),

            index: index,

            event: event,

            // Whole card is clickable.
            onTap: () =>
                _openEditEvent(
                  doc.id,
                  rawData,
                ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// TEXT FILTER BUTTON
// ============================================================================

class _TextFilterButton extends StatelessWidget {
  const _TextFilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  // IMPORTANT:
  // These are local to this class so there is no undefined getter error.
  static const Color accentBlue =
  Color(0xFF4A90E2);

  static const Color textSecondary =
  Color(0xFF6B7280);

  @override
  Widget build(
      BuildContext context,
      ) {
    final Color textColor =
    selected ? accentBlue : textSecondary;

    return AnimatedContainer(
      duration:
      const Duration(
        milliseconds: 180,
      ),

      curve:
      Curves.easeOutCubic,

      height: 42,

      decoration:
      BoxDecoration(
        color: selected
            ? const Color(0xFFF3F8FF)
            : Colors.white,

        borderRadius:
        BorderRadius.circular(
          11,
        ),

        border:
        Border.all(
          color: selected
              ? const Color(0xFFBFD8F8)
              : const Color(0xFFE5E9F0),
        ),
      ),

      child: Material(
        color:
        Colors.transparent,

        child: InkWell(
          borderRadius:
          BorderRadius.circular(
            11,
          ),

          onTap: onTap,

          child: Center(
            child: FittedBox(
              fit:
              BoxFit.scaleDown,

              child: Text(
                label,

                maxLines: 1,

                softWrap: false,

                style:
                TextStyle(
                  color: textColor,

                  fontSize: 11.5,

                  fontWeight: selected
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ANIMATED EVENT CARD
// ============================================================================

class _AnimatedEventCard
    extends StatelessWidget {
  const _AnimatedEventCard({
    super.key,
    required this.index,
    required this.event,
    required this.onTap,
  });

  final int index;
  final EventModel event;
  final VoidCallback onTap;

  @override
  Widget build(
      BuildContext context,
      ) {
    final delay =
    (index * 40).clamp(
      0,
      180,
    );

    return TweenAnimationBuilder<double>(
      tween:
      Tween(
        begin: 0,
        end: 1,
      ),

      duration:
      Duration(
        milliseconds:
        240 + delay,
      ),

      curve:
      Curves.easeOutCubic,

      child:
      _EventCard(
        event: event,
        onTap: onTap,
      ),

      builder: (
          context,
          value,
          child,
          ) {
        final slideValue =
            10 * (1 - value);

        return Opacity(
          opacity: value,

          child:
          Transform.translate(
            offset:
            Offset(
              0,
              slideValue,
            ),

            child: child,
          ),
        );
      },
    );
  }
}

// ============================================================================
// CLEAN EVENT CARD
// ============================================================================

class _EventCard
    extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.onTap,
  });

  final EventModel event;
  final VoidCallback onTap;

  static const Color primaryBlue =
  Color(0xFF4A90E2);

  static const Color textPrimary =
  Color(0xFF172033);

  static const Color textSecondary =
  Color(0xFF6B7280);

  static const Color borderColor =
  Color(0xFFE5E9F0);

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _statusColor() {
    switch (event.statusLabel) {
      case 'Active':
        return const Color(
          0xFF20A96B,
        );

      case 'Upcoming':
        return const Color(
          0xFFF59E0B,
        );

      case 'Ended':
        return const Color(
          0xFF7B8794,
        );

      default:
        return textSecondary;
    }
  }

  // ============================================================
  // STATUS TEXT
  // ============================================================

  String _statusText() {
    switch (event.statusLabel) {
      case 'Active':
        return 'Ongoing';

      case 'Upcoming':
        return 'Upcoming';

      case 'Ended':
        return 'Completed';

      default:
        return event.statusLabel;
    }
  }

  // ============================================================
  // CARD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final statusColor =
    _statusColor();

    return Material(
      color: Colors.white,

      borderRadius:
      BorderRadius.circular(
        16,
      ),

      clipBehavior:
      Clip.antiAlias,

      child: InkWell(
        onTap: onTap,

        borderRadius:
        BorderRadius.circular(
          16,
        ),

        splashColor:
        primaryBlue.withOpacity(
          0.05,
        ),

        highlightColor:
        primaryBlue.withOpacity(
          0.025,
        ),

        child: Container(
          width:
          double.infinity,

          padding:
          const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),

          decoration:
          BoxDecoration(
            borderRadius:
            BorderRadius.circular(
              16,
            ),

            border:
            Border.all(
              color:
              borderColor,
              width: 1,
            ),
          ),

          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.center,

            children: [
              // ==================================================
              // EVENT INFO
              // ==================================================

              Expanded(
                child: Padding(
                  padding:
                  const EdgeInsets.only(
                    right: 4,
                  ),

                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      // EVENT NAME
                      Text(
                        event.title,

                        maxLines: 2,

                        overflow:
                        TextOverflow.ellipsis,

                        style:
                        const TextStyle(
                          color:
                          textPrimary,

                          fontSize: 15,

                          fontWeight:
                          FontWeight.w800,

                          height: 1.25,
                        ),
                      ),

                      const SizedBox(
                        height: 7,
                      ),

                      // DATE
                      Text(
                        event.formattedDate,

                        maxLines: 1,

                        overflow:
                        TextOverflow.ellipsis,

                        style:
                        const TextStyle(
                          color:
                          textSecondary,

                          fontSize: 12,

                          fontWeight:
                          FontWeight.w500,
                        ),
                      ),

                      // VENUE
                      if (event.venue
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(
                          height: 4,
                        ),

                        Text(
                          event.venue,

                          maxLines: 1,

                          overflow:
                          TextOverflow.ellipsis,

                          style:
                          const TextStyle(
                            color:
                            textSecondary,

                            fontSize: 12,

                            fontWeight:
                            FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              // ==================================================
              // STATUS
              // ==================================================

              Container(
                constraints:
                const BoxConstraints(
                  minWidth: 76,
                ),

                padding:
                const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),

                decoration:
                BoxDecoration(
                  color:
                  statusColor.withOpacity(
                    0.09,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),

                child: FittedBox(
                  fit:
                  BoxFit.scaleDown,

                  child: Text(
                    _statusText(),

                    maxLines: 1,

                    softWrap: false,

                    style:
                    TextStyle(
                      color:
                      statusColor,

                      fontSize: 10.5,

                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// LOADING
// ============================================================================

class _LoadingView
    extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(
      BuildContext context,
      ) {
    return const Center(
      child:
      CircularProgressIndicator(
        strokeWidth: 2.5,
        color:
        Color(0xFF4A90E2),
      ),
    );
  }
}

// ============================================================================
// ERROR
// ============================================================================

class _ErrorView
    extends StatelessWidget {
  const _ErrorView();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(
          30,
        ),

        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [
            Container(
              width: 68,
              height: 68,

              decoration:
              BoxDecoration(
                color:
                const Color(
                  0xFFFFEEEE,
                ),

                borderRadius:
                BorderRadius.circular(
                  20,
                ),
              ),

              child:
              const Icon(
                Icons
                    .cloud_off_rounded,
                size: 30,
                color:
                Color(
                  0xFFE05252,
                ),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            const Text(
              'Unable to load events',

              textAlign:
              TextAlign.center,

              style:
              TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.w800,
                color:
                Color(
                  0xFF172033,
                ),
              ),
            ),

            const SizedBox(
              height: 7,
            ),

            const Text(
              'Please check your connection and try again.',

              textAlign:
              TextAlign.center,

              style:
              TextStyle(
                color:
                Color(
                  0xFF697386,
                ),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY STATE
// ============================================================================

class _EmptyState
    extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    this.onClear,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onClear;

  @override
  Widget build(
      BuildContext context,
      ) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 28,
        ),

        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [
            Container(
              width: 82,
              height: 82,

              decoration:
              BoxDecoration(
                color:
                const Color(
                  0xFFEAF3FF,
                ),

                borderRadius:
                BorderRadius.circular(
                  24,
                ),
              ),

              child:
              const Icon(
                Icons
                    .event_note_rounded,
                size: 38,
                color:
                Color(
                  0xFF4A90E2,
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            Text(
              title,

              textAlign:
              TextAlign.center,

              style:
              const TextStyle(
                color:
                Color(
                  0xFF172033,
                ),
                fontSize: 19,
                fontWeight:
                FontWeight.w800,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              subtitle,

              textAlign:
              TextAlign.center,

              style:
              const TextStyle(
                color:
                Color(
                  0xFF697386,
                ),
                fontSize: 12.5,
                height: 1.5,
              ),
            ),

            if (onClear !=
                null) ...[
              const SizedBox(
                height: 16,
              ),

              TextButton(
                onPressed:
                onClear,

                child:
                const Text(
                  'Clear filters',

                  style:
                  TextStyle(
                    fontWeight:
                    FontWeight
                        .w700,

                    color:
                    Color(
                      0xFF4A90E2,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}