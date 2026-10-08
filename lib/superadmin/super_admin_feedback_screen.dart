import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'super_admin_common.dart' as common;

class SuperAdminFeedbackScreen extends StatelessWidget {
  const SuperAdminFeedbackScreen({super.key});

  // ============================================================
  // HELPERS
  // ============================================================

  int _ratingValue(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();

    return int.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }

  DateTime? _timestampValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }

  String _formatDate(dynamic value) {
    final date = _timestampValue(value);

    if (date == null) {
      return 'Date unavailable';
    }

    final monthNames = [
      '',
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

    final hour =
    date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);

    final minute =
    date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${monthNames[date.month]} ${date.day}, '
        '${date.year} • $hour:$minute $period';
  }

  // ============================================================
  // GROUP FEEDBACK BY EVENT
  // ============================================================

  Map<String, List<Map<String, dynamic>>> _groupByEvent(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final grouped =
    <String, List<Map<String, dynamic>>>{};

    for (final doc in docs) {
      final data = doc.data();

      final eventId =
      (data['eventId'] ?? '').toString().trim();

      final eventName =
      (data['eventName'] ?? 'Unknown Event')
          .toString()
          .trim();

      final key = eventId.isNotEmpty
          ? eventId
          : eventName;

      grouped.putIfAbsent(key, () => []);

      grouped[key]!.add(data);
    }

    // Latest feedback first within each event.
    for (final list in grouped.values) {
      list.sort((a, b) {
        final aDate =
        _timestampValue(a['submittedAt']);
        final bDate =
        _timestampValue(b['submittedAt']);

        if (aDate == null && bDate == null) {
          return 0;
        }

        if (aDate == null) return 1;
        if (bDate == null) return -1;

        return bDate.compareTo(aDate);
      });
    }

    return grouped;
  }

  double _averageRating(
      List<Map<String, dynamic>> feedback,
      ) {
    if (feedback.isEmpty) return 0;

    var total = 0;

    for (final item in feedback) {
      total += _ratingValue(item['rating']);
    }

    return total / feedback.length;
  }

  int _countRating(
      List<Map<String, dynamic>> feedback,
      int rating,
      ) {
    return feedback.where(
          (item) =>
      _ratingValue(item['rating']) == rating,
    ).length;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('feedback')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorState();
        }

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs =
            snapshot.data?.docs ?? [];

        final grouped =
        _groupByEvent(docs);

        return Container(
          color: common.TraceColors.canvas,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                28,
                28,
                28,
                40,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  // ==================================================
                  // HEADER
                  // ==================================================

                  const Text(
                    'Event Feedback',
                    style: TextStyle(
                      color:
                      common.TraceColors.ink,
                      fontSize: 25,
                      fontWeight:
                      FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Review participant feedback grouped by event.',
                    style: TextStyle(
                      color: common.TraceColors
                          .textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // EMPTY
                  // ==================================================

                  if (grouped.isEmpty)
                    _emptyState(),

                  // ==================================================
                  // EVENTS
                  // ==================================================

                  ...grouped.entries.map(
                        (entry) {
                      return _eventFeedbackSection(
                        eventId: entry.key,
                        feedback: entry.value,
                      );
                    },
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
  // EVENT SECTION
  // ============================================================

  Widget _eventFeedbackSection({
    required String eventId,
    required List<Map<String, dynamic>> feedback,
  }) {
    final eventName =
    (feedback.first['eventName'] ??
        'Unknown Event')
        .toString()
        .trim();

    final average =
    _averageRating(feedback);

    final fiveStars =
    _countRating(feedback, 5);
    final fourStars =
    _countRating(feedback, 4);
    final threeStars =
    _countRating(feedback, 3);
    final twoStars =
    _countRating(feedback, 2);
    final oneStar =
    _countRating(feedback, 1);

    final comments = feedback
        .where(
          (item) =>
      (item['comment'] ?? '')
          .toString()
          .trim()
          .isNotEmpty,
    )
        .toList();

    final suggestions = feedback
        .where(
          (item) =>
      (item['suggestions'] ?? '')
          .toString()
          .trim()
          .isNotEmpty,
    )
        .toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 24,
      ),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: common.TraceColors.surface,
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          // ========================================================
          // EVENT HEADER
          // ========================================================

          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: common.TraceColors.accent
                      .withValues(alpha: 0.12),
                  borderRadius:
                  BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_rounded,
                  color:
                  common.TraceColors.accent,
                  size: 23,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      eventName.isEmpty
                          ? 'Unknown Event'
                          : eventName,
                      style: const TextStyle(
                        color:
                        common.TraceColors.ink,
                        fontSize: 18,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${feedback.length} '
                          '${feedback.length == 1 ? 'response' : 'responses'}',
                      style: const TextStyle(
                        color: common.TraceColors
                            .textSecondary,
                        fontSize: 12,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // ========================================================
          // OVERALL RATING
          // ========================================================

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color:
              common.TraceColors.canvas,
              borderRadius:
              BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                // BIG RATING
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overall Rating',
                      style: TextStyle(
                        color:
                        common.TraceColors
                            .textSecondary,
                        fontSize: 11.5,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Text(
                          average.toStringAsFixed(1),
                          style:
                          const TextStyle(
                            color:
                            common.TraceColors
                                .ink,
                            fontSize: 28,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          '/ 5',
                          style:
                          TextStyle(
                            color:
                            common.TraceColors
                                .textSecondary,
                            fontSize: 13,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 2),

                    Row(
                      children: List.generate(
                        5,
                            (index) {
                          final filled =
                              index < average;

                          return Icon(
                            filled
                                ? Icons
                                .star_rounded
                                : Icons
                                .star_border_rounded,
                            color:
                            common.TraceColors
                                .accent,
                            size: 19,
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 28),

                Expanded(
                  child:
                  _ratingDistribution(
                    fiveStars: fiveStars,
                    fourStars: fourStars,
                    threeStars: threeStars,
                    twoStars: twoStars,
                    oneStar: oneStar,
                    total:
                    feedback.length,
                  ),
                ),
              ],
            ),
          ),

          // ========================================================
          // COMMENTS
          // ========================================================

          if (comments.isNotEmpty) ...[
            const SizedBox(height: 24),

            _sectionTitle(
              icon:
              Icons.favorite_border_rounded,
              title:
              'Experiences & Comments',
              count:
              comments.length,
            ),

            const SizedBox(height: 12),

            ...comments.map(
                  (item) => _responseCard(
                text:
                item['comment']
                    .toString()
                    .trim(),
                submittedAt:
                item['submittedAt'],
                icon:
                Icons.format_quote_rounded,
              ),
            ),
          ],

          // ========================================================
          // SUGGESTIONS
          // ========================================================

          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 24),

            _sectionTitle(
              icon:
              Icons.lightbulb_outline_rounded,
              title: 'Suggestions',
              count:
              suggestions.length,
            ),

            const SizedBox(height: 12),

            ...suggestions.map(
                  (item) => _responseCard(
                text:
                item['suggestions']
                    .toString()
                    .trim(),
                submittedAt:
                item['submittedAt'],
                icon:
                Icons.lightbulb_outline_rounded,
              ),
            ),
          ],

          // ========================================================
          // EVENT ID
          // ========================================================

          const SizedBox(height: 18),

          Text(
            'Event ID: $eventId',
            style: const TextStyle(
              color: common.TraceColors
                  .textSecondary,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RATING DISTRIBUTION
  // ============================================================

  Widget _ratingDistribution({
    required int fiveStars,
    required int fourStars,
    required int threeStars,
    required int twoStars,
    required int oneStar,
    required int total,
  }) {
    final ratings = [
      (5, fiveStars),
      (4, fourStars),
      (3, threeStars),
      (2, twoStars),
      (1, oneStar),
    ];

    return Column(
      children: ratings.map(
            (item) {
          final rating = item.$1;
          final count = item.$2;

          final progress = total == 0
              ? 0.0
              : count / total;

          return Padding(
            padding:
            const EdgeInsets.only(
              bottom: 5,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 25,
                  child: Text(
                    '$rating★',
                    style: const TextStyle(
                      color: common.TraceColors
                          .textSecondary,
                      fontSize: 10.5,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                Expanded(
                  child: ClipRRect(
                    borderRadius:
                    BorderRadius.circular(
                      20,
                    ),
                    child:
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor:
                      const Color(
                        0xFFE2E8F0,
                      ),
                      valueColor:
                      const AlwaysStoppedAnimation(
                        common.TraceColors
                            .accent,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 7),

                SizedBox(
                  width: 20,
                  child: Text(
                    '$count',
                    textAlign:
                    TextAlign.right,
                    style:
                    const TextStyle(
                      color: common.TraceColors
                          .textSecondary,
                      fontSize: 10,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ).toList(),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    required int count,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color:
          common.TraceColors.ink,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color:
            common.TraceColors.ink,
            fontSize: 14,
            fontWeight:
            FontWeight.w800,
          ),
        ),
        const SizedBox(width: 7),
        Container(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF2F6),
            borderRadius:
            BorderRadius.circular(
              20,
            ),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: common.TraceColors
                  .textSecondary,
              fontSize: 10,
              fontWeight:
              FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // RESPONSE CARD
  // ============================================================

  Widget _responseCard({
    required String text,
    required dynamic submittedAt,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 9,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius:
        BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE8EDF3),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color:
            common.TraceColors.accent,
            size: 19,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style:
                  const TextStyle(
                    color: common.TraceColors
                        .ink,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  _formatDate(submittedAt),
                  style:
                  const TextStyle(
                    color: common.TraceColors
                        .textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.symmetric(
        vertical: 60,
        horizontal: 24,
      ),
      decoration: BoxDecoration(
        color:
        common.TraceColors.surface,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color:
          const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 46,
            color: common.TraceColors
                .textSecondary,
          ),
          const SizedBox(height: 14),
          const Text(
            'No feedback yet',
            style: TextStyle(
              color:
              common.TraceColors.ink,
              fontSize: 16,
              fontWeight:
              FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Student feedback will appear here after submission.',
            textAlign:
            TextAlign.center,
            style: TextStyle(
              color: common.TraceColors
                  .textSecondary,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _errorState() {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 46,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load event feedback.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color: common.TraceColors
                    .textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}