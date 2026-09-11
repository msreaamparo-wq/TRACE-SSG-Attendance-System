import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore path:
/// attendance/{attendanceId}
///
/// Actual Firestore fields:
/// - eventId
/// - userId
/// - studentId
/// - timeIn
/// - timeOut
/// - attendanceStatus   -> 'present' | 'half-day' | 'absent'
/// - timeInStatus
/// - timeOutStatus
class AttendanceModel {
  final String id;
  final String eventId;
  final String userId;
  final String studentId;
  final DateTime? timeIn;
  final DateTime? timeOut;
  final String attendanceStatus;
  final String timeInStatus;
  final String timeOutStatus;

  AttendanceModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.studentId,
    this.timeIn,
    this.timeOut,
    required this.attendanceStatus,
    required this.timeInStatus,
    required this.timeOutStatus,
  });

  // ==========================================================
  // STATUS RULES
  // ==========================================================
  //
  // present   -> has BOTH timeIn and timeOut
  // half-day  -> has ONLY ONE of timeIn / timeOut
  // absent    -> has NEITHER
  //
  // This is the single source of truth for attendance status — every
  // place that writes `attendanceStatus` (FirestoreService) should call
  // this instead of hardcoding a string, so the rule never drifts.
  static const String statusPresent = 'present';
  static const String statusHalfDay = 'half-day';
  static const String statusAbsent = 'absent';

  static String computeStatus({
    required bool hasTimeIn,
    required bool hasTimeOut,
  }) {
    if (hasTimeIn && hasTimeOut) return statusPresent;
    if (hasTimeIn || hasTimeOut) return statusHalfDay;
    return statusAbsent;
  }

  // ==========================================================
  // FIRESTORE MAPPING
  // ==========================================================

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'userId': userId,
      'studentId': studentId,
      'timeIn': timeIn != null ? Timestamp.fromDate(timeIn!) : null,
      'timeOut': timeOut != null ? Timestamp.fromDate(timeOut!) : null,
      'attendanceStatus': attendanceStatus,
      'timeInStatus': timeInStatus,
      'timeOutStatus': timeOutStatus,
    };
  }

  // ==========================================================
  // FROM FIRESTORE
  // ==========================================================

  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AttendanceModel.fromMap(doc.id, data);
  }

  // ==========================================================
  // FROM MAP
  // ==========================================================

  factory AttendanceModel.fromMap(String id, Map<String, dynamic> map) {
    return AttendanceModel(
      id: id,
      eventId: (map['eventId'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      studentId: (map['studentId'] ?? '').toString(),
      timeIn: _parseTimestamp(map['timeIn']),
      timeOut: _parseTimestamp(map['timeOut']),
      attendanceStatus: (map['attendanceStatus'] ?? statusAbsent).toString(),
      timeInStatus: (map['timeInStatus'] ?? '').toString(),
      timeOutStatus: (map['timeOutStatus'] ?? '').toString(),
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  // ==========================================================
  // CONVENIENCE
  // ==========================================================

  bool get hasTimedIn => timeIn != null;

  bool get hasTimedOut => timeOut != null;

  bool get isPresent => attendanceStatus.toLowerCase() == statusPresent;

  bool get isHalfDay => attendanceStatus.toLowerCase() == statusHalfDay;

  bool get isAbsent => attendanceStatus.toLowerCase() == statusAbsent;

  AttendanceModel copyWith({
    DateTime? timeIn,
    DateTime? timeOut,
    String? attendanceStatus,
    String? timeInStatus,
    String? timeOutStatus,
  }) {
    return AttendanceModel(
      id: id,
      eventId: eventId,
      userId: userId,
      studentId: studentId,
      timeIn: timeIn ?? this.timeIn,
      timeOut: timeOut ?? this.timeOut,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      timeInStatus: timeInStatus ?? this.timeInStatus,
      timeOutStatus: timeOutStatus ?? this.timeOutStatus,
    );
  }
}