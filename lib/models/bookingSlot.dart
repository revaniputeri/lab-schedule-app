import 'package:cloud_firestore/cloud_firestore.dart';
import 'lab.dart';
import 'sesi.dart';

class BookingSlot {
  final String id;
  final String idLab;
  final String idSesi;
  final String keperluanKegiatan;
  final String status; // 'Pending', 'Approved', 'Rejected' (case-sensitive)
  final DateTime tanggalBooking;
  final String? idUser; // Opsional: ID user yang booking
  final DateTime? createdAt;

  // Relasi (akan diisi saat fetch data)
  Lab? lab;
  Sesi? sesi;

  BookingSlot({
    required this.id,
    required this.idLab,
    required this.idSesi,
    required this.keperluanKegiatan,
    required this.status,
    required this.tanggalBooking,
    this.idUser,
    this.createdAt,
    this.lab,
    this.sesi,
  });

  factory BookingSlot.fromMap(Map<String, dynamic> map, String id) {
    // Parse tanggalBooking - bisa berupa Timestamp atau String
    DateTime parsedDate;
    try {
      if (map['tanggalBooking'] is Timestamp) {
        parsedDate = (map['tanggalBooking'] as Timestamp).toDate();
      } else if (map['tanggalBooking'] is String) {
        parsedDate = DateTime.parse(map['tanggalBooking']);
      } else {
        parsedDate = DateTime.now();
      }
    } catch (e) {
      print('Error parsing tanggalBooking: $e');
      parsedDate = DateTime.now();
    }

    return BookingSlot(
      id: id,
      idLab: map['idLab'] ?? '',
      idSesi: map['idSesi'] ?? '',
      keperluanKegiatan: map['keperluanKegiatan'] ?? '',
      status: map['status'] ?? 'Pending',
      tanggalBooking: parsedDate,
      idUser: map['idUser'],
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] is Timestamp 
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.parse(map['createdAt']))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idLab': idLab,
      'idSesi': idSesi,
      'keperluanKegiatan': keperluanKegiatan,
      'status': status,
      'tanggalBooking': Timestamp.fromDate(tanggalBooking),
      'idUser': idUser,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
    };
  }

  // Helper method untuk mendapatkan tanggal tanpa waktu
  String get dateOnly {
    return '${tanggalBooking.year}-${tanggalBooking.month.toString().padLeft(2, '0')}-${tanggalBooking.day.toString().padLeft(2, '0')}';
  }

  // Helper untuk check status (case-insensitive)
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isRejected => status.toLowerCase() == 'rejected';
}