import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:attendance/models/attendance_model.dart';
import 'package:attendance/models/event_model.dart';
import 'package:attendance/services/attendance_queue_service.dart';
import 'package:attendance/services/local_storage_service.dart';

/// Result of an offline-aware attendance write.
enum AttendanceWriteResult {
  synced,
  queued,
}

class FirestoreService {
  FirestoreService._();

  static final FirestoreService instance =
  FirestoreService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ==========================================================
  // COLLECTIONS
  // ==========================================================

  CollectionReference get users =>
      _firestore.collection('users');

  CollectionReference get events =>
      _firestore.collection('events');

  CollectionReference get attendance =>
      _firestore.collection('attendance');

  // ==========================================================
  // USERS
  // ==========================================================

  Future<void> addUser(
      String id,
      Map<String, dynamic> data,
      ) async {
    await users.doc(id).set(data);

    final studentId =
    (data['studentId'] ?? '').toString().trim();

    if (studentId.isNotEmpty) {
      await LocalStorageService.saveStudent({
        'id': id,
        ...data,
      });
    }
  }

  Future<QuerySnapshot> getUsers() async {
    return await users.get();
  }

  Future<int> getUsersCount() async {
    final snapshot = await users.get();

    return snapshot.docs.length;
  }

  // ==========================================================
  // CACHE ALL STUDENTS
  // ==========================================================

  Future<int> cacheAllStudents() async {
    try {
      final snapshot = await users.get();

      final List<Map<String, dynamic>> students = [];

      for (final doc in snapshot.docs) {
        final raw = doc.data();

        if (raw is! Map) {
          continue;
        }

        final data =
        Map<String, dynamic>.from(raw);

        final studentId =
        (data['studentId'] ?? '')
            .toString()
            .trim();

        if (studentId.isEmpty) {
          continue;
        }

        students.add({
          'id': doc.id,
          ...data,
        });
      }

      await LocalStorageService.saveStudents(
        students,
      );

      debugPrint(
        'FirestoreService: cached '
            '${students.length} students locally.',
      );

      return students.length;
    } catch (e) {
      debugPrint(
        'FirestoreService: failed to cache '
            'students: $e',
      );

      return 0;
    }
  }

  // ==========================================================
  // FIND STUDENT — OFFLINE FIRST
  // ==========================================================

  Future<StudentRecord?> getStudentRecordById(
      String studentId,
      ) async {
    final id = studentId.trim();

    if (id.isEmpty) {
      return null;
    }

    final online =
    await AttendanceQueueService
        .instance
        .isOnline();

    // --------------------------------------------------------
    // ONLINE
    // --------------------------------------------------------

    if (online) {
      try {
        final snapshot = await users
            .where(
          'studentId',
          isEqualTo: id,
        )
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first;
          final raw = doc.data();

          if (raw is Map) {
            final data =
            Map<String, dynamic>.from(raw);

            await LocalStorageService.saveStudent({
              'id': doc.id,
              ...data,
            });

            return StudentRecord(
              id: doc.id,
              data: data,
              isOffline: false,
            );
          }
        }
      } on FirebaseException catch (e) {
        if (e.code != 'unavailable' &&
            e.code != 'deadline-exceeded') {
          rethrow;
        }

        debugPrint(
          'Firestore student lookup unavailable. '
              'Using local cache.',
        );
      } catch (e) {
        debugPrint(
          'Firestore student lookup failed. '
              'Using local cache: $e',
        );
      }
    }

    // --------------------------------------------------------
    // OFFLINE CACHE
    // --------------------------------------------------------

    final cached =
    LocalStorageService.getStudentOffline(id);

    if (cached != null) {
      return StudentRecord(
        id: (cached['id'] ?? '').toString(),
        data: cached,
        isOffline: true,
      );
    }

    return null;
  }

  /// Compatibility method for online DocumentSnapshot-based code.
  ///
  /// This method returns null when the device is offline.
  /// For offline-capable attendance processing, use
  /// [getStudentRecordById].
  Future<DocumentSnapshot?> getStudentById(
      String studentId,
      ) async {
    final id = studentId.trim();

    if (id.isEmpty) {
      return null;
    }

    final online =
    await AttendanceQueueService
        .instance
        .isOnline();

    if (!online) {
      return null;
    }

    try {
      final snapshot = await users
          .where(
        'studentId',
        isEqualTo: id,
      )
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;

      final raw = doc.data();

      if (raw is Map) {
        await LocalStorageService.saveStudent({
          'id': doc.id,
          ...Map<String, dynamic>.from(raw),
        });
      }

      return doc;
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' ||
          e.code == 'deadline-exceeded') {
        return null;
      }

      rethrow;
    } catch (e) {
      debugPrint(
        'getStudentById failed: $e',
      );

      return null;
    }
  }

  // ==========================================================
  // STUDENT DISPLAY INFO
  // ==========================================================

  Map<String, String> extractStudentDisplayInfo(
      Map<String, dynamic> data,
      ) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = data[key];

        if (value != null &&
            value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }

      return '';
    }

    return {
      'fullName': pick([
        'fullName',
        'name',
      ]),
      'course': pick([
        'course',
        'program',
        'degreeProgram',
      ]),
      'yearLevel': pick([
        'yearLevel',
        'year',
        'yrLevel',
        'gradeLevel',
      ]),
      'college': pick([
        'college',
        'department',
        'dept',
      ]),
    };
  }

  // ==========================================================
  // EVENTS
  // ==========================================================

  Future<void> addEvent(
      Map<String, dynamic> data,
      ) async {
    await events.add(data);
  }

  Future<QuerySnapshot> getEvents() async {
    return await events.get();
  }

  Future<void> updateEvent(
      String id,
      Map<String, dynamic> data,
      ) async {
    await events.doc(id).update(data);
  }

  Future<void> updateEventWithImage({
    required String eventId,
    required Map<String, dynamic> data,
    File? newImageFile,
    String? oldImagePath,
  }) async {
    var payload = data;

    if (newImageFile != null) {
      final result =
      await LocalStorageService.instance
          .replaceEventImage(
        eventId: eventId,
        newImageFile: newImageFile,
        oldImagePath: oldImagePath,
      );

      payload = {
        ...data,
        'eventImage': result['url'],
        'eventImagePath': result['path'],
      };
    }

    await updateEvent(
      eventId,
      payload,
    );
  }

  Future<void> deleteEvent(
      String id,
      ) async {
    await events.doc(id).delete();
  }

  Future<int> getEventsCount() async {
    final snapshot = await events.get();

    return snapshot.docs.length;
  }

  Stream<EventModel?> eventStream(
      String eventId,
      ) {
    return events
        .doc(eventId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return null;
      }

      return EventModel.fromFirestore(doc);
    });
  }

  // ==========================================================
  // ALL EVENTS
  // ==========================================================

  Future<List<EventModel>> getAllEvents() async {
    final snapshot = await events.get();

    final List<EventModel> allEvents = [];

    for (final doc in snapshot.docs) {
      try {
        final event =
        EventModel.fromFirestore(doc);

        allEvents.add(event);
      } catch (e) {
        debugPrint(
          'Error parsing event '
              '${doc.id}: $e',
        );
      }
    }

    allEvents.sort(
          (a, b) =>
          a.eventDate.compareTo(
            b.eventDate,
          ),
    );

    return allEvents;
  }

  // ==========================================================
  // UPCOMING EVENTS
  // ==========================================================

  Future<List<EventModel>> getUpcomingEvents({
    int limit = 5,
  }) async {
    final snapshot = await events.get();

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final List<EventModel> upcoming = [];

    for (final doc in snapshot.docs) {
      try {
        final event =
        EventModel.fromFirestore(doc);

        if (event.status.toLowerCase() ==
            'cancelled') {
          continue;
        }

        final eventDay = DateTime(
          event.eventDate.year,
          event.eventDate.month,
          event.eventDate.day,
        );

        if (eventDay.isAtSameMomentAs(today) ||
            eventDay.isAfter(today)) {
          upcoming.add(event);
        }
      } catch (e) {
        debugPrint(
          'Error parsing event '
              '${doc.id}: $e',
        );
      }
    }

    upcoming.sort(
          (a, b) =>
          a.eventDate.compareTo(
            b.eventDate,
          ),
    );

    if (upcoming.length > limit) {
      return upcoming.sublist(
        0,
        limit,
      );
    }

    return upcoming;
  }

  // ==========================================================
  // OFFLINE-AWARE TIME IN
  // ==========================================================

  Future<AttendanceWriteResult> recordTimeIn({
    required String eventId,
    required String userId,
    required String studentId,
    String timeInStatus = 'on-time',

    // GPS
    double? latitude,
    double? longitude,
    bool? locationVerified,
    double? locationAccuracy,

    // Used for preserving the real offline recording time.
    DateTime? recordedAt,
  }) async {
    // --------------------------------------------------------
    // OFFLINE
    // --------------------------------------------------------

    if (!await AttendanceQueueService
        .instance
        .isOnline()) {
      await AttendanceQueueService
          .instance
          .queueTimeIn(
        eventId: eventId,
        userId: userId,
        studentId: studentId,
        timeInStatus: timeInStatus,

        // Preserve GPS
        latitude: latitude,
        longitude: longitude,
        locationVerified:
        locationVerified,
        locationAccuracy:
        locationAccuracy,
      );

      return AttendanceWriteResult.queued;
    }

    // --------------------------------------------------------
    // ONLINE
    // --------------------------------------------------------

    try {
      await markAttendance(
        eventId: eventId,
        userId: userId,
        studentId: studentId,
        timeInStatus: timeInStatus,

        // GPS
        latitude: latitude,
        longitude: longitude,
        locationVerified:
        locationVerified,
        locationAccuracy:
        locationAccuracy,

        // Time
        recordedAt: recordedAt,
      );

      return AttendanceWriteResult.synced;
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' ||
          e.code == 'deadline-exceeded') {
        await AttendanceQueueService
            .instance
            .queueTimeIn(
          eventId: eventId,
          userId: userId,
          studentId: studentId,
          timeInStatus: timeInStatus,

          // Preserve GPS when queued.
          latitude: latitude,
          longitude: longitude,
          locationVerified:
          locationVerified,
          locationAccuracy:
          locationAccuracy,
        );

        return AttendanceWriteResult.queued;
      }

      rethrow;
    }
  }

  // ==========================================================
  // OFFLINE-AWARE TIME OUT
  // ==========================================================

  Future<AttendanceWriteResult> recordTimeOut({
    required String eventId,
    required String userId,
    required String studentId,
    String timeOutStatus = 'on-time',

    // GPS
    double? latitude,
    double? longitude,
    bool? locationVerified,
    double? locationAccuracy,

    // Used for preserving the real offline recording time.
    DateTime? recordedAt,
  }) async {
    // --------------------------------------------------------
    // OFFLINE
    // --------------------------------------------------------

    if (!await AttendanceQueueService
        .instance
        .isOnline()) {
      await AttendanceQueueService
          .instance
          .queueTimeOut(
        eventId: eventId,
        userId: userId,
        studentId: studentId,
        timeOutStatus: timeOutStatus,

        // Preserve GPS
        latitude: latitude,
        longitude: longitude,
        locationVerified:
        locationVerified,
        locationAccuracy:
        locationAccuracy,
      );

      return AttendanceWriteResult.queued;
    }

    // --------------------------------------------------------
    // ONLINE
    // --------------------------------------------------------

    try {
      await markTimeOut(
        eventId: eventId,
        userId: userId,
        studentId: studentId,
        timeOutStatus: timeOutStatus,

        // GPS
        latitude: latitude,
        longitude: longitude,
        locationVerified:
        locationVerified,
        locationAccuracy:
        locationAccuracy,

        // Time
        recordedAt: recordedAt,
      );

      return AttendanceWriteResult.synced;
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' ||
          e.code == 'deadline-exceeded') {
        await AttendanceQueueService
            .instance
            .queueTimeOut(
          eventId: eventId,
          userId: userId,
          studentId: studentId,
          timeOutStatus: timeOutStatus,

          // Preserve GPS when queued.
          latitude: latitude,
          longitude: longitude,
          locationVerified:
          locationVerified,
          locationAccuracy:
          locationAccuracy,
        );

        return AttendanceWriteResult.queued;
      }

      rethrow;
    }
  }

  // ==========================================================
  // MARK TIME IN
  // ==========================================================

  Future<void> markAttendance({
    required String eventId,
    required String userId,
    required String studentId,
    String timeInStatus = 'on-time',

    // GPS
    double? latitude,
    double? longitude,
    bool? locationVerified,
    double? locationAccuracy,

    // Original attendance recording time.
    DateTime? recordedAt,
  }) async {
    final existing = await attendance
        .where(
      'eventId',
      isEqualTo: eventId,
    )
        .where(
      'studentId',
      isEqualTo: studentId,
    )
        .limit(1)
        .get();

    // --------------------------------------------------------
    // LOCATION DATA
    // --------------------------------------------------------

    final Map<String, dynamic> locationData = {};

    if (latitude != null) {
      locationData['latitude'] = latitude;
    }

    if (longitude != null) {
      locationData['longitude'] = longitude;
    }

    if (locationVerified != null) {
      locationData['locationVerified'] =
          locationVerified;
    }

    if (locationAccuracy != null) {
      locationData['locationAccuracy'] =
          locationAccuracy;
    }

    // --------------------------------------------------------
    // TIME FIELD
    // --------------------------------------------------------

    final dynamic timeInValue =
        recordedAt ?? FieldValue.serverTimestamp();

    // --------------------------------------------------------
    // EXISTING ATTENDANCE RECORD
    // --------------------------------------------------------

    if (existing.docs.isNotEmpty) {
      final raw =
      existing.docs.first.data();

      final existingData =
      raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};

      final alreadyTimedIn =
          existingData['timeIn'] != null;

      final hasTimeOut =
          existingData['timeOut'] != null;

      if (alreadyTimedIn) {
        throw Exception(
          'Student already marked Present for this event.',
        );
      }

      final newStatus =
      AttendanceModel.computeStatus(
        hasTimeIn: true,
        hasTimeOut: hasTimeOut,
      );

      await attendance
          .doc(existing.docs.first.id)
          .update({
        'userId': userId,
        'timeIn': timeInValue,
        'attendanceStatus': newStatus,
        'timeInStatus': timeInStatus,

        // GPS
        ...locationData,
      });

      return;
    }

    // --------------------------------------------------------
    // NEW ATTENDANCE RECORD
    // --------------------------------------------------------

    await attendance.add({
      'eventId': eventId,
      'userId': userId,
      'studentId': studentId,
      'timeIn': timeInValue,
      'timeOut': null,
      'attendanceStatus':
      AttendanceModel.computeStatus(
        hasTimeIn: true,
        hasTimeOut: false,
      ),
      'timeInStatus': timeInStatus,
      'timeOutStatus': '',

      // GPS
      ...locationData,
    });
  }

  // ==========================================================
  // MARK TIME OUT
  // ==========================================================

  Future<void> markTimeOut({
    required String eventId,
    required String userId,
    required String studentId,
    String timeOutStatus = 'on-time',

    // GPS
    double? latitude,
    double? longitude,
    bool? locationVerified,
    double? locationAccuracy,

    // Original attendance recording time.
    DateTime? recordedAt,
  }) async {
    final existing = await attendance
        .where(
      'eventId',
      isEqualTo: eventId,
    )
        .where(
      'studentId',
      isEqualTo: studentId,
    )
        .limit(1)
        .get();

    // --------------------------------------------------------
    // LOCATION DATA
    // --------------------------------------------------------

    final Map<String, dynamic> locationData = {};

    if (latitude != null) {
      locationData['latitude'] = latitude;
    }

    if (longitude != null) {
      locationData['longitude'] = longitude;
    }

    if (locationVerified != null) {
      locationData['locationVerified'] =
          locationVerified;
    }

    if (locationAccuracy != null) {
      locationData['locationAccuracy'] =
          locationAccuracy;
    }

    // --------------------------------------------------------
    // TIME FIELD
    // --------------------------------------------------------

    final dynamic timeOutValue =
        recordedAt ?? FieldValue.serverTimestamp();

    // --------------------------------------------------------
    // NO PREVIOUS RECORD
    // --------------------------------------------------------

    if (existing.docs.isEmpty) {
      await attendance.add({
        'eventId': eventId,
        'userId': userId,
        'studentId': studentId,
        'timeIn': null,
        'timeOut': timeOutValue,
        'attendanceStatus':
        AttendanceModel.computeStatus(
          hasTimeIn: false,
          hasTimeOut: true,
        ),
        'timeInStatus': '',
        'timeOutStatus': timeOutStatus,

        // GPS
        ...locationData,
      });

      return;
    }

    // --------------------------------------------------------
    // EXISTING RECORD
    // --------------------------------------------------------

    final raw =
    existing.docs.first.data();

    final data =
    raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};

    final hasTimeIn =
        data['timeIn'] != null;

    final alreadyTimedOut =
        data['timeOut'] != null;

    if (alreadyTimedOut) {
      throw Exception(
        'Student already marked for time out for this event.',
      );
    }

    final newStatus =
    AttendanceModel.computeStatus(
      hasTimeIn: hasTimeIn,
      hasTimeOut: true,
    );

    await attendance
        .doc(existing.docs.first.id)
        .update({
      'userId': userId,
      'timeOut': timeOutValue,
      'attendanceStatus': newStatus,
      'timeOutStatus': timeOutStatus,

      // GPS
      ...locationData,
    });
  }

  // ==========================================================
  // TIME OUT LOOKUP
  // ==========================================================

  Future<TimeOutLookup> findTimeOutCandidate({
    required String eventId,
    required String studentId,
  }) async {
    // ========================================================
    // 1. LOCAL PENDING QUEUE
    // ========================================================

    final pending =
    AttendanceQueueService
        .instance
        .getPendingAttendanceState(
      eventId: eventId,
      studentId: studentId,
    );

    if (pending.hasTimeOut) {
      return TimeOutLookup.alreadyDone();
    }

    if (pending.hasTimeIn) {
      return TimeOutLookup.ready(
        hasTimeIn: true,
      );
    }

    // ========================================================
    // 2. FIRESTORE
    // ========================================================

    try {
      final snapshot = await attendance
          .where(
        'eventId',
        isEqualTo: eventId,
      )
          .where(
        'studentId',
        isEqualTo: studentId,
      )
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return TimeOutLookup.ready(
          hasTimeIn: false,
        );
      }

      final raw =
      snapshot.docs.first.data();

      final data =
      raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};

      if (data['timeOut'] != null) {
        return TimeOutLookup.alreadyDone();
      }

      return TimeOutLookup.ready(
        hasTimeIn: data['timeIn'] != null,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' ||
          e.code == 'deadline-exceeded') {
        return TimeOutLookup.ready(
          hasTimeIn: false,
        );
      }

      rethrow;
    } catch (e) {
      debugPrint(
        'findTimeOutCandidate failed: $e',
      );

      return TimeOutLookup.ready(
        hasTimeIn: false,
      );
    }
  }

  // ==========================================================
  // GET ATTENDANCE
  // ==========================================================

  Future<QuerySnapshot> getAttendance() async {
    return await attendance.get();
  }

  Future<int> getAttendanceCount() async {
    final snapshot =
    await attendance.get();

    return snapshot.docs.length;
  }

  Future<List<AttendanceModel>>
  getAttendanceForEvent(
      String eventId,
      ) async {
    final snapshot = await attendance
        .where(
      'eventId',
      isEqualTo: eventId,
    )
        .get();

    final List<AttendanceModel> records = [];

    for (final doc in snapshot.docs) {
      try {
        records.add(
          AttendanceModel.fromFirestore(doc),
        );
      } catch (e) {
        debugPrint(
          'Error parsing attendance '
              '${doc.id}: $e',
        );
      }
    }

    return records;
  }

  // ==========================================================
  // LIVE ATTENDANCE STATS
  // ==========================================================

  Stream<Map<String, int>>
  attendanceStatsStream(
      String eventId,
      ) {
    late final StreamController<
        Map<String, int>> controller;

    StreamSubscription? usersSub;
    StreamSubscription? attendanceSub;

    int totalUsers = 0;
    int presentCount = 0;
    int halfDayCount = 0;

    bool gotUsers = false;
    bool gotAttendance = false;

    void emit() {
      if (!gotUsers ||
          !gotAttendance ||
          controller.isClosed) {
        return;
      }

      final calculatedAbsent =
          totalUsers -
              presentCount -
              halfDayCount;

      final absent =
      calculatedAbsent < 0
          ? 0
          : calculatedAbsent;

      controller.add({
        'total': totalUsers,
        'present': presentCount,
        'halfDay': halfDayCount,
        'absent': absent,
      });
    }

    controller =
        StreamController<Map<String, int>>(
          onListen: () {
            usersSub = users.snapshots().listen(
                  (snap) {
                totalUsers =
                    snap.docs.length;

                gotUsers = true;

                emit();
              },
              onError: controller.addError,
            );

            attendanceSub = attendance
                .where(
              'eventId',
              isEqualTo: eventId,
            )
                .snapshots()
                .listen(
                  (snap) {
                int present = 0;
                int halfDay = 0;

                for (final doc in snap.docs) {
                  final raw = doc.data();

                  if (raw is! Map) {
                    continue;
                  }

                  final data =
                  Map<String, dynamic>.from(raw);

                  final status =
                  (data['attendanceStatus'] ?? '')
                      .toString()
                      .toLowerCase();

                  if (status ==
                      AttendanceModel.statusPresent) {
                    present++;
                  } else if (status ==
                      AttendanceModel.statusHalfDay) {
                    halfDay++;
                  }
                }

                presentCount = present;
                halfDayCount = halfDay;

                gotAttendance = true;

                emit();
              },
              onError: controller.addError,
            );
          },
          onCancel: () async {
            await usersSub?.cancel();
            await attendanceSub?.cancel();
          },
        );

    return controller.stream;
  }

  // ==========================================================
  // CURRENT MONTH ATTENDANCE
  // ==========================================================

  Future<Map<String, int>>
  getAttendanceStatsForCurrentMonth() async {
    final snapshot =
    await attendance.get();

    final now = DateTime.now();

    final startOfMonth = DateTime(
      now.year,
      now.month,
      1,
    );

    final startOfNextMonth = DateTime(
      now.year,
      now.month + 1,
      1,
    );

    int present = 0;
    int halfDay = 0;
    int absent = 0;
    int excused = 0;

    for (final doc in snapshot.docs) {
      AttendanceModel record;

      try {
        record =
            AttendanceModel.fromFirestore(doc);
      } catch (e) {
        debugPrint(
          'Error parsing attendance '
              '${doc.id}: $e',
        );

        continue;
      }

      final date =
          record.timeIn ?? record.timeOut;

      if (date != null) {
        if (date.isBefore(startOfMonth) ||
            !date.isBefore(
              startOfNextMonth,
            )) {
          continue;
        }
      }

      switch (
      record.attendanceStatus.toLowerCase()) {
        case AttendanceModel.statusPresent:
          present++;
          break;

        case AttendanceModel.statusHalfDay:
          halfDay++;
          break;

        case AttendanceModel.statusAbsent:
          absent++;
          break;

        case 'excused':
          excused++;
          break;
      }
    }

    return {
      'present': present,
      'halfDay': halfDay,
      'absent': absent,
      'excused': excused,
    };
  }
}

// ================================================================
// LOCAL STUDENT RECORD
// ================================================================

class StudentRecord {
  final String id;
  final Map<String, dynamic> data;
  final bool isOffline;

  StudentRecord({
    required this.id,
    required this.data,
    required this.isOffline,
  });
}

// ================================================================
// TIME OUT LOOKUP RESULT
// ================================================================

enum TimeOutLookupStatus {
  alreadyDone,
  ready,
}

class TimeOutLookup {
  final TimeOutLookupStatus status;
  final bool hasTimeIn;

  TimeOutLookup._(
      this.status,
      this.hasTimeIn,
      );

  factory TimeOutLookup.alreadyDone() {
    return TimeOutLookup._(
      TimeOutLookupStatus.alreadyDone,
      false,
    );
  }

  factory TimeOutLookup.ready({
    required bool hasTimeIn,
  }) {
    return TimeOutLookup._(
      TimeOutLookupStatus.ready,
      hasTimeIn,
    );
  }
}