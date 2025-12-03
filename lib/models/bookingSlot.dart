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
  final String idUser; // Wajib: ID user yang booking
  final DateTime? createdAt;
  final String? rejectReason;

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
    required this.idUser, // Diubah menjadi required
    this.createdAt,
    this.rejectReason,
    this.lab,
    this.sesi,
  });

  // Constructor untuk membuat booking baru dengan user ID
  factory BookingSlot.createNew({
    required String idLab,
    required String idSesi,
    required String keperluanKegiatan,
    required DateTime tanggalBooking,
    required String idUser, // Parameter baru untuk user ID
  }) {
    return BookingSlot(
      id: '', // ID akan di-generate oleh Firestore
      idLab: idLab,
      idSesi: idSesi,
      keperluanKegiatan: keperluanKegiatan,
      status: 'Pending', // Default status
      tanggalBooking: tanggalBooking,
      idUser: idUser, // Set user ID
      createdAt: DateTime.now(),
      rejectReason: null,
    );
  }

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
      idUser: map['idUser'] ?? '', // Default empty string jika tidak ada
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] is Timestamp 
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.parse(map['createdAt']))
          : null,
        rejectReason: map['rejectReason'] as String?,
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
      if (rejectReason != null) 'rejectReason': rejectReason,
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

  // Copy with method untuk update data
  BookingSlot copyWith({
    String? idLab,
    String? idSesi,
    String? keperluanKegiatan,
    String? status,
    DateTime? tanggalBooking,
    String? idUser,
    DateTime? createdAt,
    String? rejectReason,
    Lab? lab,
    Sesi? sesi,
  }) {
    return BookingSlot(
      id: id,
      idLab: idLab ?? this.idLab,
      idSesi: idSesi ?? this.idSesi,
      keperluanKegiatan: keperluanKegiatan ?? this.keperluanKegiatan,
      status: status ?? this.status,
      tanggalBooking: tanggalBooking ?? this.tanggalBooking,
      idUser: idUser ?? this.idUser,
      createdAt: createdAt ?? this.createdAt,
      rejectReason: rejectReason ?? this.rejectReason,
      lab: lab ?? this.lab,
      sesi: sesi ?? this.sesi,
    );
  }
}