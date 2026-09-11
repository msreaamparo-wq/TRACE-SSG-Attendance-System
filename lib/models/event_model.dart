import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// The two attendance checkpoints an event can have. The Firestore schema
/// only stores one "time in" window and one "time out" window per event
/// (`timeInStart/End`, `timeOutStart/End`) — in the UI these map to the
/// "Morning" (arrival) and "Afternoon" (departure) checkpoints.
enum AttendanceSession { timeIn, timeOut }

extension AttendanceSessionX on AttendanceSession {
  String get actionLabel => this == AttendanceSession.timeIn ? 'Time In' : 'Time Out';

  String get periodLabel => this == AttendanceSession.timeIn ? 'Morning' : 'Afternoon';

  String get fullLabel => '$periodLabel ($actionLabel)';

  IconData get icon => this == AttendanceSession.timeIn ? Icons.login_rounded : Icons.logout_rounded;
}

/// Firestore path:
/// events/{eventId}
///
/// Actual Firestore fields:
/// - eventName
/// - description
/// - eventDate
/// - venue
/// - eventImage
/// - eventImagePath   (NEW — Storage object path, see local_storage_service.dart fix)
/// - timeInStart
/// - timeInEnd
/// - timeOutStart
/// - timeOutEnd
/// - status
/// - createdAt
class EventModel {
  final String id;
  final String eventName;
  final String description;
  final DateTime eventDate;
  final String venue;
  final String eventImage;
  final String eventImagePath;
  final String timeInStart;
  final String timeInEnd;
  final String timeOutStart;
  final String timeOutEnd;
  final String status;
  final DateTime? createdAt;

  EventModel({
    required this.id,
    required this.eventName,
    required this.description,
    required this.eventDate,
    required this.venue,
    required this.eventImage,
    this.eventImagePath = '',
    required this.timeInStart,
    required this.timeInEnd,
    required this.timeOutStart,
    required this.timeOutEnd,
    required this.status,
    this.createdAt,
  });

  // ==========================================================
  // FIRESTORE MAPPING
  // ==========================================================

  Map<String, dynamic> toMap() {
    return {
      'eventName': eventName,
      'description': description,
      'eventDate': Timestamp.fromDate(eventDate),
      'venue': venue,
      'eventImage': eventImage,
      'eventImagePath': eventImagePath,
      'timeInStart': timeInStart,
      'timeInEnd': timeInEnd,
      'timeOutStart': timeOutStart,
      'timeOutEnd': timeOutEnd,
      'status': status,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  // ==========================================================
  // FROM FIRESTORE
  // ==========================================================

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return EventModel.fromMap(doc.id, data);
  }

  // ==========================================================
  // FROM MAP
  // ==========================================================

  factory EventModel.fromMap(String id, Map<String, dynamic> data) {
    return EventModel(
      id: id,
      eventName: (data['eventName'] ?? 'Untitled Event').toString(),
      description: (data['description'] ?? '').toString(),
      eventDate: _parseDate(data['eventDate']),
      venue: (data['venue'] ?? '').toString(),
      eventImage: (data['eventImage'] ?? '').toString(),
      eventImagePath: (data['eventImagePath'] ?? '').toString(),
      timeInStart: (data['timeInStart'] ?? '').toString(),
      timeInEnd: (data['timeInEnd'] ?? '').toString(),
      timeOutStart: (data['timeOutStart'] ?? '').toString(),
      timeOutEnd: (data['timeOutEnd'] ?? '').toString(),
      status: (data['status'] ?? 'upcoming').toString(),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  // ==========================================================
  // DATE PARSER
  // ==========================================================

  static DateTime _parseDate(dynamic value) {
    final now = DateTime.now();

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String && value.trim().isNotEmpty) {
      final direct = DateTime.tryParse(value.trim());
      if (direct != null) {
        return direct;
      }
    }

    return DateTime(now.year, now.month, now.day);
  }

  // ==========================================================
  // STATUS — ALWAYS COMPUTED LIVE FROM THE CLOCK
  // (unchanged from your last fix — this part was already correct)
  // ==========================================================

  String get statusLabel {
    if (status.toLowerCase() == 'cancelled') return 'Cancelled';

    final now = _nowManila();
    final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final today = DateTime(now.year, now.month, now.day);

    if (eventDay.isAfter(today)) return 'Upcoming';
    if (eventDay.isBefore(today)) return 'Ended';
    return 'Active';
  }

  /// Color-coded status used for badges: green = happening now,
  /// blue = still to come, gray = finished/cancelled.
  Color get statusColor {
    final normalized = statusLabel.toLowerCase();
    if (normalized == 'active') return const Color(0xFF20A96B);
    if (normalized == 'upcoming') return const Color(0xFF4A90E2);
    if (normalized == 'cancelled') return const Color(0xFFE0473C);
    return const Color(0xFF6B7280); // ended
  }

  String get statusDisplayLabel => statusLabel.toLowerCase() == 'active' ? 'Ongoing' : statusLabel;

  // ==========================================================
  // ICON
  // ==========================================================

  IconData get icon {
    final name = eventName.toLowerCase();

    if (name.contains('sport') ||
        name.contains('game') ||
        name.contains('intramural')) {
      return Icons.sports_basketball_rounded;
    }

    if (name.contains('party') || name.contains('celebration')) {
      return Icons.celebration_rounded;
    }

    if (name.contains('meeting') || name.contains('assembly')) {
      return Icons.groups_rounded;
    }

    if (name.contains('school') ||
        name.contains('academic') ||
        name.contains('graduation') ||
        name.contains('seminar')) {
      return Icons.school_rounded;
    }

    if (name.contains('wika') || name.contains('language')) {
      return Icons.menu_book_rounded;
    }

    return Icons.event_rounded;
  }

  // ==========================================================
  // FORMATTED DATE
  // ==========================================================

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get formattedDate {
    return '${_months[eventDate.month - 1]} ${eventDate.day}, ${eventDate.year}';
  }

  // ==========================================================
  // FORMATTED TIME WINDOWS
  // ==========================================================

  String? get formattedCheckInWindow {
    if (timeInStart.trim().isEmpty && timeInEnd.trim().isEmpty) return null;
    if (timeInStart.trim().isEmpty) return timeInEnd;
    if (timeInEnd.trim().isEmpty) return timeInStart;
    return '$timeInStart - $timeInEnd';
  }

  String? get formattedCheckOutWindow {
    if (timeOutStart.trim().isEmpty && timeOutEnd.trim().isEmpty) return null;
    if (timeOutStart.trim().isEmpty) return timeOutEnd;
    if (timeOutEnd.trim().isEmpty) return timeOutStart;
    return '$timeOutStart - $timeOutEnd';
  }

  // ==========================================================
  // SESSION WINDOWS — cutoff enforcement for Time In / Time Out
  //
  // FIX (this pass) — THE ACTUAL BUG:
  //
  // `_nowManila()` builds "now" as:
  //     DateTime.now().toUtc().add(Duration(hours: 8))
  // This is a UTC-*flagged* DateTime whose .hour/.minute/.day FIELDS
  // correctly read as Manila wall-clock time — but its underlying EPOCH
  // (what isBefore/isAfter actually compare) is the true current UTC
  // instant shifted 8 hours further into the future. That's fine as
  // long as you only ever read its *fields* off it.
  //
  // The old `_combine()` then built session start/end times using plain
  // `DateTime(y, m, d, h, min)` — a *local* (device-timezone) DateTime.
  // If the device's timezone is already set to Manila (+8), THAT
  // DateTime's epoch is the correct real-world epoch for that Manila
  // wall-clock moment.
  //
  // Comparing those two directly (`now.isBefore(start)` /
  // `now.isAfter(end)`) mixes two different epoch "domains": one that's
  // artificially 8 hours ahead of real time, one that's correct. On a
  // phone actually set to Manila time, that made "now" appear ~8 hours
  // further along than it really was — so at an actual 3:35 PM, the
  // comparison was effectively happening against ~11:35 PM, which is
  // why the 2:57–3:57 PM afternoon window showed as *already closed*
  // while it should still have been open.
  //
  // THE FIX: build start/end with `DateTime.utc(...)` instead of
  // `DateTime(...)`. That keeps start/end in the SAME "+8h shifted"
  // epoch domain as `_nowManila()`, so the comparison is internally
  // consistent — and it's also now independent of whatever timezone
  // the device itself happens to be set to (phone, emulator, or web),
  // since neither side ever touches the device's local offset again.
  // ==========================================================

  static TimeOfDay? _parseTimeOfDay(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;

    // Meridiem is mandatory.
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$').firstMatch(raw);
    if (match == null) return null;

    int hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final meridiem = match.group(3)!.toUpperCase();

    if (hour < 1 || hour > 12 || minute > 59) return null;

    if (meridiem == 'PM' && hour != 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;

    return TimeOfDay(hour: hour, minute: minute);
  }

  static const Duration _manilaOffset = Duration(hours: 8);

  static DateTime _nowManila() => DateTime.now().toUtc().add(_manilaOffset);

  DateTime? _combine(String timeStr) {
    final tod = _parseTimeOfDay(timeStr);
    if (tod == null) return null;
    final now = _nowManila();
    // FIX: .utc(...) instead of the old (...) — keeps this in the same
    // epoch domain as _nowManila() so direct isBefore/isAfter compares
    // are correct regardless of device timezone.
    return DateTime.utc(now.year, now.month, now.day, tod.hour, tod.minute);
  }

  DateTime? get timeInStartAt => _combine(timeInStart);
  DateTime? get timeInEndAt => _combine(timeInEnd);
  DateTime? get timeOutStartAt => _combine(timeOutStart);
  DateTime? get timeOutEndAt => _combine(timeOutEnd);

  bool get hasTimeInWindow => timeInStartAt != null && timeInEndAt != null;
  bool get hasTimeOutWindow => timeOutStartAt != null && timeOutEndAt != null;

  DateTime? _sessionStartAt(AttendanceSession session) =>
      session == AttendanceSession.timeIn ? timeInStartAt : timeOutStartAt;

  DateTime? _sessionEndAt(AttendanceSession session) =>
      session == AttendanceSession.timeIn ? timeInEndAt : timeOutEndAt;

  bool hasSessionWindow(AttendanceSession session) =>
      _sessionStartAt(session) != null && _sessionEndAt(session) != null;

  /// True if [session] has no configured schedule, or `now` falls inside it.
  bool isSessionOpen(AttendanceSession session) {
    final start = _sessionStartAt(session);
    final end = _sessionEndAt(session);
    if (start == null || end == null) return true;
    final now = _nowManila();
    return !now.isBefore(start) && !now.isAfter(end);
  }

  bool hasSessionEnded(AttendanceSession session) {
    final end = _sessionEndAt(session);
    if (end == null) return false;
    return _nowManila().isAfter(end);
  }

  bool hasSessionNotStarted(AttendanceSession session) {
    final start = _sessionStartAt(session);
    if (start == null) return false;
    return _nowManila().isBefore(start);
  }

  String sessionWindowLabel(AttendanceSession session) {
    final label = session == AttendanceSession.timeIn ? formattedCheckInWindow : formattedCheckOutWindow;
    return label ?? 'No schedule set';
  }

  String sessionStartLabel(AttendanceSession session) {
    final raw = session == AttendanceSession.timeIn ? timeInStart : timeOutStart;
    return raw.trim();
  }

  String sessionEndLabel(AttendanceSession session) {
    final raw = session == AttendanceSession.timeIn ? timeInEnd : timeOutEnd;
    return raw.trim();
  }

  // ==========================================================
  // COMPATIBILITY GETTERS
  // ==========================================================

  String get title => eventName;

  String get displayTitle => eventName;

  String get displayType => statusLabel;
}