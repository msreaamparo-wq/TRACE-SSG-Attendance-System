import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import 'package:attendance/services/firestore_service.dart';

/// Stores attendance records locally when offline and automatically
/// synchronizes them to Firestore when the connection returns.
///
/// Offline flow:
///
///   Time In / Time Out
///          ↓
///   Campus GPS Verification
///          ↓
///      Hive Queue
///          ↓
///   Internet returns
///          ↓
///     Firestore Sync
///
/// GPS verification data is preserved while offline and restored
/// when the queued attendance record is synchronized.
class AttendanceQueueService {
  AttendanceQueueService._();

  static final AttendanceQueueService instance =
  AttendanceQueueService._();

  // ============================================================
  // HIVE
  // ============================================================

  static const String _boxName = 'pending_attendance';

  Box? _box;

  // ============================================================
  // CONNECTION
  // ============================================================

  StreamSubscription<InternetStatus>? _connSub;

  bool _isSyncing = false;

  // ============================================================
  // PENDING COUNT STREAM
  // ============================================================

  final StreamController<int> _pendingCountController =
  StreamController<int>.broadcast();

  Stream<int> get pendingCountStream =>
      _pendingCountController.stream;

  // ============================================================
  // INTERNAL BOX ACCESS
  // ============================================================

  Box get _pendingBox {
    final box = _box;

    if (box == null) {
      throw StateError(
        'AttendanceQueueService.init() must be called before use.',
      );
    }

    return box;
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);

    _emitCount();

    // ----------------------------------------------------------
    // AUTO SYNC WHEN INTERNET RETURNS
    // ----------------------------------------------------------

    await _connSub?.cancel();

    _connSub = InternetConnection().onStatusChange.listen(
          (status) {
        if (status == InternetStatus.connected) {
          syncPending();
        }
      },
    );

    // ----------------------------------------------------------
    // TRY TO SYNC EXISTING QUEUE
    // ----------------------------------------------------------

    await syncPending();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  Future<void> dispose() async {
    await _connSub?.cancel();
    _connSub = null;

    if (!_pendingCountController.isClosed) {
      await _pendingCountController.close();
    }
  }

  // ============================================================
  // BASIC STATE
  // ============================================================

  int get pendingCount => _box?.length ?? 0;

  bool get hasPendingAttendance => pendingCount > 0;

  void _emitCount() {
    if (_pendingCountController.isClosed) {
      return;
    }

    _pendingCountController.add(pendingCount);
  }

  // ============================================================
  // INTERNET
  // ============================================================

  Future<bool> isOnline() async {
    return await InternetConnection().hasInternetAccess;
  }

  // ============================================================
  // QUEUE TIME IN
  // ============================================================

  Future<void> queueTimeIn({
    required String eventId,
    required String userId,
    required String studentId,
    required String timeInStatus,

    // GPS verification
    double? latitude,
    double? longitude,
    bool? locationVerified,
    double? locationAccuracy,
  }) async {
    final cleanEventId = eventId.trim();
    final cleanUserId = userId.trim();
    final cleanStudentId = studentId.trim();

    if (cleanEventId.isEmpty || cleanStudentId.isEmpty) {
      throw ArgumentError(
        'eventId and studentId are required.',
      );
    }

    final record = <String, dynamic>{
      'type': 'timeIn',
      'eventId': cleanEventId,
      'userId': cleanUserId,
      'studentId': cleanStudentId,
      'timeInStatus': timeInStatus.trim().isEmpty
          ? 'on-time'
          : timeInStatus.trim(),

      // Actual time when the SSG officer recorded the attendance
      // while offline.
      'recordedAt': DateTime.now().toIso8601String(),

      // Time when the record was placed into Hive.
      'queuedAt': DateTime.now().toIso8601String(),
    };

    // ----------------------------------------------------------
    // GPS DATA
    // ----------------------------------------------------------

    if (latitude != null) {
      record['latitude'] = latitude;
    }

    if (longitude != null) {
      record['longitude'] = longitude;
    }

    if (locationVerified != null) {
      record['locationVerified'] = locationVerified;
    }

    if (locationAccuracy != null) {
      record['locationAccuracy'] = locationAccuracy;
    }

    await _pendingBox.add(record);

    _emitCount();
  }

  // ============================================================
  // QUEUE TIME OUT
  // ============================================================

  Future<void> queueTimeOut({
    required String eventId,
    required String userId,
    required String studentId,
    required String timeOutStatus,

    // GPS verification
    double? latitude,
    double? longitude,
    bool? locationVerified,
    double? locationAccuracy,
  }) async {
    final cleanEventId = eventId.trim();
    final cleanUserId = userId.trim();
    final cleanStudentId = studentId.trim();

    if (cleanEventId.isEmpty || cleanStudentId.isEmpty) {
      throw ArgumentError(
        'eventId and studentId are required.',
      );
    }

    final record = <String, dynamic>{
      'type': 'timeOut',
      'eventId': cleanEventId,
      'userId': cleanUserId,
      'studentId': cleanStudentId,
      'timeOutStatus': timeOutStatus.trim().isEmpty
          ? 'on-time'
          : timeOutStatus.trim(),

      // Actual time when the SSG officer recorded the attendance.
      'recordedAt': DateTime.now().toIso8601String(),

      // Time when the record was placed into Hive.
      'queuedAt': DateTime.now().toIso8601String(),
    };

    // ----------------------------------------------------------
    // GPS DATA
    // ----------------------------------------------------------

    if (latitude != null) {
      record['latitude'] = latitude;
    }

    if (longitude != null) {
      record['longitude'] = longitude;
    }

    if (locationVerified != null) {
      record['locationVerified'] = locationVerified;
    }

    if (locationAccuracy != null) {
      record['locationAccuracy'] = locationAccuracy;
    }

    await _pendingBox.add(record);

    _emitCount();
  }

  // ============================================================
  // READ QUEUED RECORDS
  // ============================================================

  List<Map<String, dynamic>> getPendingRecords() {
    final records = <Map<String, dynamic>>[];

    for (final key in _pendingBox.keys) {
      final raw = _pendingBox.get(key);

      if (raw == null || raw is! Map) {
        continue;
      }

      records.add({
        '_key': key,
        ...Map<String, dynamic>.from(raw),
      });
    }

    records.sort((a, b) {
      final aTime = (a['queuedAt'] ?? '').toString();
      final bTime = (b['queuedAt'] ?? '').toString();

      return aTime.compareTo(bTime);
    });

    return records;
  }

  // ============================================================
  // FIND PENDING RECORDS FOR STUDENT + EVENT
  // ============================================================

  List<Map<String, dynamic>> getPendingRecordsForStudent({
    required String eventId,
    required String studentId,
  }) {
    final cleanEventId = eventId.trim();
    final cleanStudentId = studentId.trim();

    if (cleanEventId.isEmpty || cleanStudentId.isEmpty) {
      return [];
    }

    final records = <Map<String, dynamic>>[];

    for (final key in _pendingBox.keys) {
      final raw = _pendingBox.get(key);

      if (raw == null || raw is! Map) {
        continue;
      }

      final record = Map<String, dynamic>.from(raw);

      final recordEventId =
      (record['eventId'] ?? '').toString().trim();

      final recordStudentId =
      (record['studentId'] ?? '').toString().trim();

      if (recordEventId == cleanEventId &&
          recordStudentId == cleanStudentId) {
        records.add({
          '_key': key,
          ...record,
        });
      }
    }

    records.sort((a, b) {
      final aTime = (a['queuedAt'] ?? '').toString();
      final bTime = (b['queuedAt'] ?? '').toString();

      return aTime.compareTo(bTime);
    });

    return records;
  }

  // ============================================================
  // LOCAL ATTENDANCE STATE
  // ============================================================

  PendingAttendanceState getPendingAttendanceState({
    required String eventId,
    required String studentId,
  }) {
    final records = getPendingRecordsForStudent(
      eventId: eventId,
      studentId: studentId,
    );

    bool hasTimeIn = false;
    bool hasTimeOut = false;

    for (final record in records) {
      final type = (record['type'] ?? '').toString();

      if (type == 'timeIn') {
        hasTimeIn = true;
      }

      if (type == 'timeOut') {
        hasTimeOut = true;
      }
    }

    return PendingAttendanceState(
      hasTimeIn: hasTimeIn,
      hasTimeOut: hasTimeOut,
    );
  }

  // ============================================================
  // CHECK PENDING TIME IN
  // ============================================================

  bool hasPendingTimeIn({
    required String eventId,
    required String studentId,
  }) {
    final records = getPendingRecordsForStudent(
      eventId: eventId,
      studentId: studentId,
    );

    return records.any(
          (record) =>
      (record['type'] ?? '').toString() == 'timeIn',
    );
  }

  // ============================================================
  // CHECK PENDING TIME OUT
  // ============================================================

  bool hasPendingTimeOut({
    required String eventId,
    required String studentId,
  }) {
    final records = getPendingRecordsForStudent(
      eventId: eventId,
      studentId: studentId,
    );

    return records.any(
          (record) =>
      (record['type'] ?? '').toString() == 'timeOut',
    );
  }

  // ============================================================
  // CHECK IF ALREADY QUEUED
  // ============================================================

  bool hasPendingSameAction({
    required String eventId,
    required String studentId,
    required String type,
  }) {
    final records = getPendingRecordsForStudent(
      eventId: eventId,
      studentId: studentId,
    );

    return records.any(
          (record) =>
      (record['type'] ?? '').toString() == type,
    );
  }

  // ============================================================
  // REMOVE ONE RECORD
  // ============================================================

  Future<void> removePendingRecord(dynamic key) async {
    await _pendingBox.delete(key);

    _emitCount();
  }

  // ============================================================
  // CLEAR QUEUE
  // ============================================================

  Future<void> clearPending() async {
    await _pendingBox.clear();

    _emitCount();
  }

  // ============================================================
  // CONVERTERS
  // ============================================================

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  bool? _toBool(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is bool) {
      return value;
    }

    final text = value.toString().trim().toLowerCase();

    if (text == 'true') {
      return true;
    }

    if (text == 'false') {
      return false;
    }

    return null;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }

  // ============================================================
  // SYNCHRONIZE
  // ============================================================

  /// Pushes all pending attendance records to Firestore.
  ///
  /// Records are processed in queue order.
  ///
  /// GPS data collected while offline is preserved.
  ///
  /// The original offline recording time is also preserved.
  Future<void> syncPending() async {
    if (_isSyncing) {
      return;
    }

    if (_box == null) {
      return;
    }

    if (_pendingBox.isEmpty) {
      return;
    }

    if (!await isOnline()) {
      return;
    }

    _isSyncing = true;

    try {
      final records = getPendingRecords();

      for (final record in records) {
        if (!await isOnline()) {
          break;
        }

        final key = record['_key'];

        try {
          final type =
          (record['type'] ?? '').toString();

          final eventId =
          (record['eventId'] ?? '').toString().trim();

          final userId =
          (record['userId'] ?? '').toString().trim();

          final studentId =
          (record['studentId'] ?? '').toString().trim();

          final latitude =
          _toDouble(record['latitude']);

          final longitude =
          _toDouble(record['longitude']);

          final locationVerified =
          _toBool(record['locationVerified']);

          final locationAccuracy =
          _toDouble(record['locationAccuracy']);

          final recordedAt =
          _toDateTime(record['recordedAt']);

          // ----------------------------------------------------
          // TIME IN
          // ----------------------------------------------------

          if (type == 'timeIn') {
            await FirestoreService.instance.markAttendance(
              eventId: eventId,
              userId: userId,
              studentId: studentId,
              timeInStatus:
              (record['timeInStatus'] ?? 'on-time')
                  .toString(),

              // Original recording time
              recordedAt: recordedAt,

              // Restore GPS data
              latitude: latitude,
              longitude: longitude,
              locationVerified: locationVerified,
              locationAccuracy: locationAccuracy,
            );
          }

          // ----------------------------------------------------
          // TIME OUT
          // ----------------------------------------------------

          else if (type == 'timeOut') {
            await FirestoreService.instance.markTimeOut(
              eventId: eventId,
              userId: userId,
              studentId: studentId,
              timeOutStatus:
              (record['timeOutStatus'] ?? 'on-time')
                  .toString(),

              // Original recording time
              recordedAt: recordedAt,

              // Restore GPS data
              latitude: latitude,
              longitude: longitude,
              locationVerified: locationVerified,
              locationAccuracy: locationAccuracy,
            );
          }

          // ----------------------------------------------------
          // UNKNOWN RECORD
          // ----------------------------------------------------

          else {
            await _pendingBox.delete(key);
            continue;
          }

          // ----------------------------------------------------
          // SUCCESS
          // ----------------------------------------------------

          await _pendingBox.delete(key);
        } catch (e) {
          final message = e.toString();

          final duplicateTimeIn =
          message.contains(
            'already marked Present',
          );

          final duplicateTimeOut =
          message.contains(
            'already marked for time out',
          );

          // Already recorded in Firestore,
          // so the queued duplicate can be removed.
          if (duplicateTimeIn || duplicateTimeOut) {
            await _pendingBox.delete(key);
            continue;
          }

          // Any other error leaves the record
          // inside the queue for another retry.
        }
      }
    } finally {
      _isSyncing = false;

      _emitCount();
    }
  }
}

// ================================================================
// LOCAL PENDING ATTENDANCE STATE
// ================================================================

class PendingAttendanceState {
  final bool hasTimeIn;
  final bool hasTimeOut;

  const PendingAttendanceState({
    required this.hasTimeIn,
    required this.hasTimeOut,
  });

  bool get isEmpty =>
      !hasTimeIn && !hasTimeOut;

  bool get isHalfDay =>
      hasTimeIn != hasTimeOut;

  bool get isPresent =>
      hasTimeIn && hasTimeOut;
}