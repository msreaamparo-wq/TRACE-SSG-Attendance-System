import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  // ============================================================
  // SINGLETON
  // ============================================================

  LocalStorageService._();

  static final LocalStorageService instance =
  LocalStorageService._();

  // ============================================================
  // HIVE BOXES
  // ============================================================

  static const String attendanceBox = 'attendanceBox';
  static const String studentsBox = 'studentsBox';
  static const String eventsBox = 'eventsBox';
  static const String userBox = 'userBox';

  // ============================================================
  // INITIALIZE HIVE
  // ============================================================

  static Future<void> init() async {
    await Hive.initFlutter();

    await Hive.openBox(attendanceBox);
    await Hive.openBox(studentsBox);
    await Hive.openBox(eventsBox);
    await Hive.openBox(userBox);
  }

  // ============================================================
  // OFFLINE ATTENDANCE
  // ============================================================

  static Future<void> saveOfflineAttendance(
      Map<String, dynamic> attendance,
      ) async {
    final box = Hive.box(attendanceBox);
    await box.add(attendance);
  }

  static List getOfflineAttendance() {
    final box = Hive.box(attendanceBox);
    return box.values.toList();
  }

  static Future<void> clearOfflineAttendance() async {
    final box = Hive.box(attendanceBox);
    await box.clear();
  }

  // ============================================================
  // STUDENT CACHE
  // ============================================================

  static Future<void> saveStudent(
      Map<String, dynamic> student,
      ) async {
    final studentId =
    (student['studentId'] ?? '').toString().trim();

    if (studentId.isEmpty) return;

    final box = Hive.box(studentsBox);

    await box.put(
      studentId,
      {
        'id': (student['id'] ?? '').toString(),
        'fullName': (student['fullName'] ?? '').toString(),
        'email': (student['email'] ?? '').toString(),
        'studentId': studentId,
        'course': (student['course'] ?? '').toString(),
        'college': (student['college'] ?? '').toString(),
        'yearLevel': (student['yearLevel'] ?? '').toString(),
        'role': (student['role'] ?? 'student').toString(),
      },
    );
  }

  static Future<void> saveStudents(
      List<Map<String, dynamic>> students,
      ) async {
    final box = Hive.box(studentsBox);

    for (final student in students) {
      final studentId =
      (student['studentId'] ?? '').toString().trim();

      if (studentId.isEmpty) continue;

      await box.put(
        studentId,
        {
          'id': (student['id'] ?? '').toString(),
          'fullName': (student['fullName'] ?? '').toString(),
          'email': (student['email'] ?? '').toString(),
          'studentId': studentId,
          'course': (student['course'] ?? '').toString(),
          'college': (student['college'] ?? '').toString(),
          'yearLevel': (student['yearLevel'] ?? '').toString(),
          'role': (student['role'] ?? 'student').toString(),
        },
      );
    }
  }

  static Map<String, dynamic>? getStudentOffline(
      String studentId,
      ) {
    final id = studentId.trim();

    if (id.isEmpty) return null;

    final box = Hive.box(studentsBox);
    final raw = box.get(id);

    if (raw == null || raw is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(raw);
  }

  static List<Map<String, dynamic>> getCachedStudents() {
    final box = Hive.box(studentsBox);

    return box.values
        .where((value) => value is Map)
        .map(
          (value) =>
      Map<String, dynamic>.from(value as Map),
    )
        .toList();
  }

  static Future<void> deleteStudentOffline(
      String studentId,
      ) async {
    final id = studentId.trim();

    if (id.isEmpty) return;

    final box = Hive.box(studentsBox);
    await box.delete(id);
  }

  static Future<void> clearStudentCache() async {
    final box = Hive.box(studentsBox);
    await box.clear();
  }

  static int get cachedStudentCount {
    final box = Hive.box(studentsBox);
    return box.length;
  }

  // ============================================================
  // EVENT CACHE
  // ============================================================

  static Future<void> saveEvent(
      Map<String, dynamic> event,
      ) async {
    final eventId =
    (event['id'] ?? '').toString().trim();

    if (eventId.isEmpty) return;

    final box = Hive.box(eventsBox);

    await box.put(
      eventId,
      Map<String, dynamic>.from(event),
    );
  }

  static Future<void> saveEvents(
      List<Map<String, dynamic>> events,
      ) async {
    final box = Hive.box(eventsBox);

    for (final event in events) {
      final eventId =
      (event['id'] ?? '').toString().trim();

      if (eventId.isEmpty) continue;

      await box.put(
        eventId,
        Map<String, dynamic>.from(event),
      );
    }
  }

  static Map<String, dynamic>? getEventOffline(
      String eventId,
      ) {
    final id = eventId.trim();

    if (id.isEmpty) return null;

    final box = Hive.box(eventsBox);
    final raw = box.get(id);

    if (raw == null || raw is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(raw);
  }

  static List<Map<String, dynamic>> getCachedEvents() {
    final box = Hive.box(eventsBox);

    return box.values
        .where((value) => value is Map)
        .map(
          (value) =>
      Map<String, dynamic>.from(value as Map),
    )
        .toList();
  }

  static Future<void> deleteEventOffline(
      String eventId,
      ) async {
    final id = eventId.trim();

    if (id.isEmpty) return;

    final box = Hive.box(eventsBox);
    await box.delete(id);
  }

  static Future<void> clearEventCache() async {
    final box = Hive.box(eventsBox);
    await box.clear();
  }

  static int get cachedEventCount {
    final box = Hive.box(eventsBox);
    return box.length;
  }

  // ============================================================
  // USER SESSION CACHE
  // ============================================================

  static Future<void> saveUserSession(
      Map<String, dynamic> user,
      ) async {
    final box = Hive.box(userBox);

    await box.put(
      'currentUser',
      {
        'uid': (user['uid'] ?? '').toString(),
        'email': (user['email'] ?? '').toString(),
        'fullName': (user['fullName'] ?? '').toString(),
        'role': (user['role'] ?? '').toString(),
        'studentId': (user['studentId'] ?? '').toString(),
        'course': (user['course'] ?? '').toString(),
        'college': (user['college'] ?? '').toString(),
        'yearLevel': (user['yearLevel'] ?? '').toString(),
      },
    );
  }

  static Map<String, dynamic>? getUserSession() {
    final box = Hive.box(userBox);
    final raw = box.get('currentUser');

    if (raw == null || raw is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(raw);
  }

  static bool get hasUserSession {
    final box = Hive.box(userBox);
    return box.get('currentUser') != null;
  }

  static Future<void> clearUserSession() async {
    final box = Hive.box(userBox);
    await box.delete('currentUser');
  }

  // ============================================================
  // FIREBASE STORAGE — EVENT IMAGES
  // ============================================================

  final FirebaseStorage _storage =
      FirebaseStorage.instance;

  Future<Map<String, String>> uploadEventImage({
    required String eventId,
    required File imageFile,
  }) async {
    final ext = imageFile.path.contains('.')
        ? imageFile.path.split('.').last
        : 'jpg';

    final path =
        'event_images/${eventId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    final ref = _storage.ref().child(path);

    final task = await ref.putFile(imageFile);

    final url = await task.ref.getDownloadURL();

    return {
      'url': url,
      'path': path,
    };
  }

  Future<void> deleteEventImageByPath(
      String? path,
      ) async {
    if (path == null || path.trim().isEmpty) {
      return;
    }

    try {
      await _storage.ref().child(path).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        debugPrint(
          'LocalStorageService: old image already gone.',
        );
      } else {
        debugPrint(
          'LocalStorageService: failed to delete old image: $e',
        );
      }
    } catch (e) {
      debugPrint(
        'LocalStorageService: unexpected image delete error: $e',
      );
    }
  }

  Future<Map<String, String>> replaceEventImage({
    required String eventId,
    required File newImageFile,
    String? oldImagePath,
  }) async {
    final result = await uploadEventImage(
      eventId: eventId,
      imageFile: newImageFile,
    );

    unawaited(
      deleteEventImageByPath(oldImagePath),
    );

    return result;
  }
}