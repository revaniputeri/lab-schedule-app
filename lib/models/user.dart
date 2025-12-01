import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String name;
  final String nim; // may be empty
  final String email;
  final String role; // e.g. 'user', 'admin'
  final DateTime? createdAt;

  AppUser({
    required this.id,
    required this.name,
    required this.nim,
    required this.email,
    required this.role,
    this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String id) {
    DateTime? created;
    final raw = map['createdAt'];
    if (raw is Timestamp) {
      created = raw.toDate();
    }
    return AppUser(
      id: id,
      name: map['name'] ?? '',
      nim: map['nim'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'user',
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'nim': nim,
      'email': email,
      'role': role,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
