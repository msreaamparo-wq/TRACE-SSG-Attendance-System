import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore path:
/// users/{userId}
///
/// Actual Firestore fields:
/// - fullName
/// - email
/// - studentId
/// - course
/// - college
/// - yearLevel
/// - role
class UserModel {
  // ============================================================
  // ROLE CONSTANTS
  // ------------------------------------------------------------
  // Centralizing the raw role strings avoids typos like
  // 'admin' vs 'Admin' scattered across the codebase, and gives
  // every screen a single source of truth to check against.
  // ============================================================
  static const String roleSuperAdmin = 'superadmin';
  static const String roleAdmin = 'admin';
  static const String roleOrganizer = 'organizer';
  static const String roleStudent = 'student';

  final String id;
  final String fullName;
  final String email;
  final String studentId;
  final String course;
  final String college;
  final String yearLevel;
  final String role;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.studentId,
    required this.course,
    required this.college,
    required this.yearLevel,
    required this.role,
  });

  // ==========================================================
  // FIRESTORE MAPPING
  // ==========================================================

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'studentId': studentId,
      'course': course,
      'college': college,
      'yearLevel': yearLevel,
      'role': role,
    };
  }

  // ==========================================================
  // FROM FIRESTORE
  // ==========================================================

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromMap(doc.id, data);
  }

  // ==========================================================
  // FROM MAP
  // ==========================================================

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      fullName: (map['fullName'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      studentId: (map['studentId'] ?? '').toString(),
      course: (map['course'] ?? '').toString(),
      college: (map['college'] ?? '').toString(),
      yearLevel: (map['yearLevel'] ?? '').toString(),
      role: (map['role'] ?? UserModel.roleStudent).toString(),
    );
  }

  // ==========================================================
  // NORMALIZED ROLE
  // ------------------------------------------------------------
  // Bug fix: the previous role getters did `role.toLowerCase() ==
  // 'admin'`, which breaks the moment Firestore stores the role
  // as "Admin ", "Super Admin", or "super_admin" — any stray
  // casing/spacing/punctuation made every role check silently
  // fail (and fail *closed*, so a super admin could get treated
  // as a plain student). This strips everything but letters
  // before comparing, so all of those variants normalize to the
  // same constant.
  // ==========================================================

  String get _normalizedRole =>
      role.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  // ==========================================================
  // CONVENIENCE
  // ==========================================================

  bool get isSuperAdmin => _normalizedRole == roleSuperAdmin;

  bool get isAdmin => _normalizedRole == roleAdmin;

  bool get isOrganizer => _normalizedRole == roleOrganizer;

  bool get isStudent => _normalizedRole == roleStudent;

  /// True for anyone who should see admin-level screens
  /// (super admin included).
  bool get hasAdminAccess => isSuperAdmin || isAdmin;

  UserModel copyWith({
    String? fullName,
    String? email,
    String? studentId,
    String? course,
    String? college,
    String? yearLevel,
    String? role,
  }) {
    return UserModel(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      studentId: studentId ?? this.studentId,
      course: course ?? this.course,
      college: college ?? this.college,
      yearLevel: yearLevel ?? this.yearLevel,
      role: role ?? this.role,
    );
  }
}