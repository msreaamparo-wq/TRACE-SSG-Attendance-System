import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore path: participants/{id}
class ParticipantModel {
  final String id;
  final String name;
  final String idNumber;
  final String college;
  final String qrValue;

  ParticipantModel({
    required this.id,
    required this.name,
    required this.idNumber,
    required this.college,
    required this.qrValue,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'idNumber': idNumber,
      'college': college,
      'qrValue': qrValue,
    };
  }

  factory ParticipantModel.fromMap(String id, Map<String, dynamic> map) {
    return ParticipantModel(
      id: id,
      name: (map['name'] ?? '').toString(),
      idNumber: (map['idNumber'] ?? '').toString(),
      college: (map['college'] ?? '').toString(),
      qrValue: (map['qrValue'] ?? '').toString(),
    );
  }

  factory ParticipantModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ParticipantModel.fromMap(doc.id, data);
  }
}