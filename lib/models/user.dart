// lib/models/user.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String email;
  final String name;
  final String nim;
  final String role; // 'user' atau 'admin'
  final String? fcmToken; // Token untuk push notification
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.nim,
    required this.role,
    this.fcmToken,
    this.createdAt,
    this.updatedAt,
  });

  // Convert from Firestore Map
  factory AppUser.fromMap(Map<String, dynamic> map, String id) {
    return AppUser(
      id: id,
      email: map['email'] ?? '',
      name: map['name'] ?? map['displayName'] ?? '',
      nim: map['nim'] ?? '',
      role: map['role'] ?? 'user',
      fcmToken: map['fcmToken'],
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : null,
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  // Convert to Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'fcmToken': fcmToken,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Copy with method untuk update
  AppUser copyWith({
    String? email,
    String? name,
    String? role,
    String? fcmToken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      nim: this.nim,
      role: role ?? this.role,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper getters
  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isUser => role.toLowerCase() == 'user';
  bool get hasToken => fcmToken != null && fcmToken!.isNotEmpty;
}