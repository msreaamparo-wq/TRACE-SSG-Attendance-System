import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import 'package:attendance/services/firestore_service.dart';

/// Stores attendance scans locally when offline and automatically
/// synchronizes them to Firestore when the connection returns.
///
/// Offline flow:
///
///   Time In / Time Out
///          ↓
///     Hive queue
///          ↓
///   internet returns
///          ↓
///    Firestore sync
///
/// The queue also keeps track of pending Time In / Time Out records
/// so the app can make local decisions while offline.
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

  /// Emits the current number of unsynchronized attendance records.
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
    // Open the pending attendance queue.
    _box = await Hive.openBox(_boxName);

    _emitCount();

    // ----------------------------------------------------------
    // AUTO-SYNC WHEN INTERNET RETURNS
    // ----------------------------------------------------------

    _connSub =
        InternetConnection().onStatusChange.listen((status) {
          if (status == InternetStatus.connected) {
            syncPending();
          }
        });

    // ----------------------------------------------------------
    // TRY TO SYNC ANY LEFTOVER RECORDS
    // ----------------------------------------------------------

    await syncPending();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  Future<void> dispose() async {
    await _connSub?.cancel();

    if (!_pendingCountController.isClosed) {
      await _pendingCountController.close();
    }
  }

  // ============================================================
  // BASIC STATE
  // ============================================================

  int get pendingCount => _box?.length ?? 0;

  bool get hasPendingAttendance =>
      pendingCount > 0;

  void _emitCount() {
    if (_pendingCountController.isClosed) {
      return;
    }

    _pendingCountController.add(
      pendingCount,
    );
  }

  // ============================================================
  // INTERNET
  // ============================================================

  Future<bool> isOnline() async {
    return await InternetConnection()
        .hasInternetAccess;
  }

  // ============================================================
  // QUEUE TIME IN
  // ============================================================

  Future<void> queueTimeIn({
    required String eventId,
    required String userId,
    required String studentId,
    required String timeInStatus,
  }) async {
    final cleanEventId = eventId.trim();
    final cleanUserId = userId.trim();
    final cleanStudentId = studentId.trim();

    if (cleanEventId.isEmpty ||
        cleanStudentId.isEmpty) {
      throw ArgumentError(
        'eventId and studentId are required.',
      );
    }

    await _pendingBox.add({
      'type': 'timeIn',
      'eventId': cleanEventId,
      'userId': cleanUserId,
      'studentId': cleanStudentId,
      'timeInStatus':
      timeInStatus.trim().isEmpty
          ? 'on-time'
          : timeInStatus.trim(),
      'queuedAt':
      DateTime.now().toIso8601String(),
    });

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
  }) async {
    final cleanEventId = eventId.trim();
    final cleanUserId = userId.trim();
    final cleanStudentId = studentId.trim();

    if (cleanEventId.isEmpty ||
        cleanStudentId.isEmpty) {
      throw ArgumentError(
        'eventId and studentId are required.',
      );
    }

    await _pendingBox.add({
      'type': 'timeOut',
      'eventId': cleanEventId,
      'userId': cleanUserId,
      'studentId': cleanStudentId,
      'timeOutStatus':
      timeOutStatus.trim().isEmpty
          ? 'on-time'
          : timeOutStatus.trim(),
      'queuedAt':
      DateTime.now().toIso8601String(),
    });

    _emitCount();
  }

  // ============================================================
  // READ QUEUED RECORDS
  // ============================================================

  List<Map<String, dynamic>>
  getPendingRecords() {
    final records =
    <Map<String, dynamic>>[];

    for (final key
    in _pendingBox.keys) {
      final raw =
      _pendingBox.get(key);

      if (raw == null || raw is! Map) {
        continue;
      }

      records.add(
        {
          '_key': key,
          ...Map<String, dynamic>.from(
            raw,
          ),
        },
      );
    }

    // Keep records in queue order.
    records.sort((a, b) {
      final aTime =
      (a['queuedAt'] ?? '')
          .toString();

      final bTime =
      (b['queuedAt'] ?? '')
          .toString();

      return aTime.compareTo(
        bTime,
      );
    });

    return records;
  }

  // ============================================================
  // FIND PENDING RECORDS FOR STUDENT + EVENT
  // ============================================================

  List<Map<String, dynamic>>
  getPendingRecordsForStudent({
    required String eventId,
    required String studentId,
  }) {
    final cleanEventId =
    eventId.trim();

    final cleanStudentId =
    studentId.trim();

    if (cleanEventId.isEmpty ||
        cleanStudentId.isEmpty) {
      return [];
    }

    final records =
    <Map<String, dynamic>>[];

    for (final key
    in _pendingBox.keys) {
      final raw =
      _pendingBox.get(key);

      if (raw == null || raw is! Map) {
        continue;
      }

      final record =
      Map<String, dynamic>.from(
        raw,
      );

      final recordEventId =
      (record['eventId'] ?? '')
          .toString()
          .trim();

      final recordStudentId =
      (record['studentId'] ?? '')
          .toString()
          .trim();

      if (recordEventId ==
          cleanEventId &&
          recordStudentId ==
              cleanStudentId) {
        records.add({
          '_key': key,
          ...record,
        });
      }
    }

    records.sort((a, b) {
      final aTime =
      (a['queuedAt'] ?? '')
          .toString();

      final bTime =
      (b['queuedAt'] ?? '')
          .toString();

      return aTime.compareTo(
        bTime,
      );
    });

    return records;
  }

  // ============================================================
  // LOCAL ATTENDANCE STATE
  // ============================================================

  /// Returns the attendance state that can be determined from
  /// locally queued records.
  ///
  /// Example:
  ///
  /// queued Time In only:
  ///   hasTimeIn = true
  ///   hasTimeOut = false
  ///
  /// queued Time Out only:
  ///   hasTimeIn = false
  ///   hasTimeOut = true
  ///
  /// queued both:
  ///   hasTimeIn = true
  ///   hasTimeOut = true
  PendingAttendanceState
  getPendingAttendanceState({
    required String eventId,
    required String studentId,
  }) {
    final records =
    getPendingRecordsForStudent(
      eventId: eventId,
      studentId: studentId,
    );

    bool hasTimeIn = false;
    bool hasTimeOut = false;

    for (final record in records) {
      final type =
      (record['type'] ?? '')
          .toString();

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
    final records =
    getPendingRecordsForStudent(
      eventId: eventId,
      studentId: studentId,
    );

    return records.any(
          (record) =>
      (record['type'] ?? '')
          .toString() ==
          'timeIn',
    );
  }

  // ============================================================
  // CHECK PENDING TIME OUT
  // ============================================================

  bool hasPendingTimeOut({
    required String eventId,
    required String studentId,
  }) {
    final records =
    getPendingRecordsForStudent(
      eventId: eventId,
      studentId: studentId,
    );

    return records.any(
          (record) =>
      (record['type'] ?? '')
          .toString() ==
          'timeOut',
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
    final records =
    getPendingRecordsForStudent(
      eventId: eventId,
      studentId: studentId,
    );

    return records.any(
          (record) =>
      (record['type'] ?? '')
          .toString() ==
          type,
    );
  }

  // ============================================================
  // REMOVE ONE RECORD
  // ============================================================

  Future<void> removePendingRecord(
      dynamic key,
      ) async {
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
  // SYNCHRONIZE
  // ============================================================

  /// Pushes all pending attendance records to Firestore.
  ///
  /// Records are processed in queue order.
  ///
  /// Time In and Time Out records for the same student/event
  /// therefore remain ordered when the device reconnects.
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
      final keys =
      _pendingBox.keys.toList();

      for (final key in keys) {
        // Connection may have disappeared during sync.
        if (!await isOnline()) {
          break;
        }

        final raw =
        _pendingBox.get(key);

        if (raw == null ||
            raw is! Map) {
          await _pendingBox.delete(
            key,
          );
          continue;
        }

        final record =
        Map<String, dynamic>.from(
          raw,
        );

        try {
          final type =
          (record['type'] ?? '')
              .toString();

          final eventId =
          (record['eventId'] ?? '')
              .toString()
              .trim();

          final userId =
          (record['userId'] ?? '')
              .toString()
              .trim();

          final studentId =
          (record['studentId'] ?? '')
              .toString()
              .trim();

          // ----------------------------------------------------
          // TIME IN
          // ----------------------------------------------------

          if (type == 'timeIn') {
            await FirestoreService
                .instance
                .markAttendance(
              eventId: eventId,
              userId: userId,
              studentId: studentId,
              timeInStatus:
              (record['timeInStatus'] ??
                  'on-time')
                  .toString(),
            );
          }

          // ----------------------------------------------------
          // TIME OUT
          // ----------------------------------------------------

          else if (type == 'timeOut') {
            await FirestoreService
                .instance
                .markTimeOut(
              eventId: eventId,
              userId: userId,
              studentId: studentId,
              timeOutStatus:
              (record['timeOutStatus'] ??
                  'on-time')
                  .toString(),
            );
          }

          // ----------------------------------------------------
          // UNKNOWN RECORD
          // ----------------------------------------------------

          else {
            // Unknown queue item should not remain forever.
            await _pendingBox.delete(
              key,
            );

            continue;
          }

          // ----------------------------------------------------
          // SUCCESS
          // ----------------------------------------------------

          await _pendingBox.delete(
            key,
          );
        } catch (e) {
          final message =
          e.toString();

          // ----------------------------------------------------
          // DUPLICATE TIME IN
          // ----------------------------------------------------

          final duplicateTimeIn =
          message.contains(
            'already marked Present',
          );

          // ----------------------------------------------------
          // DUPLICATE TIME OUT
          // ----------------------------------------------------

          final duplicateTimeOut =
          message.contains(
            'already marked for time out',
          );

          // A duplicate means the record has already
          // reached Firestore, so it is safe to remove
          // this queued copy.
          if (duplicateTimeIn ||
              duplicateTimeOut) {
            await _pendingBox.delete(
              key,
            );

            continue;
          }

          // ----------------------------------------------------
          // TEMPORARY FAILURE
          // ----------------------------------------------------
          //
          // Any other failure leaves the record in the queue.
          //
          // Examples:
          // - internet dropped during sync
          // - Firebase unavailable
          // - deadline exceeded
          // - server temporarily unreachable
          //
          // It will retry on the next connectivity event.
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