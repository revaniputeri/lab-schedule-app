// lib/services/booking_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bookingSlot.dart';
import '../models/lab.dart';
import '../models/sesi.dart';
import '../models/date_availability.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _bookingsCollection => _firestore.collection('bookingSlots');
  CollectionReference get _labsCollection => _firestore.collection('laboratorium');
  CollectionReference get _sesiCollection => _firestore.collection('sesi');

  // ==================== LAB METHODS ====================

  /// Mendapatkan semua lab
  Future<List<Lab>> getAllLabs() async {
    try {
      final snapshot = await _labsCollection.get();
      return snapshot.docs
          .map((doc) => Lab.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Error getting labs: $e');
      return [];
    }
  }

  /// Mendapatkan lab berdasarkan ID
  Future<Lab?> getLabById(String id) async {
    try {
      final doc = await _labsCollection.doc(id).get();
      if (doc.exists) {
        return Lab.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting lab: $e');
      return null;
    }
  }

  // ==================== SESI METHODS ====================

  /// Mendapatkan semua sesi (diurutkan berdasarkan order)
  Future<List<Sesi>> getAllSesi() async {
    try {
      final snapshot = await _sesiCollection.get();
      final sesiList = snapshot.docs
          .map((doc) => Sesi.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      
      // Sort by order
      sesiList.sort((a, b) => a.order.compareTo(b.order));
      
      return sesiList;
    } catch (e) {
      print('Error getting sesi: $e');
      return [];
    }
  }

  /// Mendapatkan sesi berdasarkan ID
  Future<Sesi?> getSesiById(String id) async {
    try {
      final doc = await _sesiCollection.doc(id).get();
      if (doc.exists) {
        return Sesi.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting sesi: $e');
      return null;
    }
  }

  // ==================== AVAILABILITY METHODS ====================

  /// Helper function untuk cek apakah sesi sudah lewat
  bool _isSesiPast(Sesi sesi, DateTime date) {
    try {
      final now = DateTime.now();
      final sesiEndTime = sesi.endTime; // Format: "HH:mm" atau "HH.mm"
      
      // Parse dengan kedua format (colon dan dot)
      List<String> parts = sesiEndTime.contains(':') 
          ? sesiEndTime.split(':')
          : sesiEndTime.split('.');
      
      if (parts.length != 2) {
        print('Invalid sesi end time format: $sesiEndTime');
        return false;
      }
      
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      
      // Buat DateTime untuk akhir sesi
      final sesiEndDateTime = DateTime(date.year, date.month, date.day, hour, minute);
      
      final isPast = now.isAfter(sesiEndDateTime);
      print('Sesi: ${sesi.sesi}, End: $sesiEndTime, End DateTime: $sesiEndDateTime, Now: $now, isPast: $isPast');
      
      return isPast;
    } catch (e) {
      print('Error checking if sesi is past: $e');
      return false;
    }
  }

  /// Mendapatkan availability untuk seluruh bulan
  Future<Map<int, DateAvailability>> getMonthAvailability({
    required String labId,
    required int year,
    required int month,
  }) async {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final Map<int, DateAvailability> availability = {};

    try {
      // Batch process untuk efisiensi
      final allSesi = await getAllSesi();
      final monthlyBookings = await getBookingsByLabAndMonth(
        labId: labId,
        year: year,
        month: month,
      );

      // Group bookings by date
      final Map<String, List<BookingSlot>> bookingsByDate = {};
      for (var booking in monthlyBookings) {
        final dateKey = booking.dateOnly;
        bookingsByDate.putIfAbsent(dateKey, () => []);
        bookingsByDate[dateKey]!.add(booking);
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(year, month, day);
        final checkDate = DateTime(date.year, date.month, date.day);
        final dateKey = '${year}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

        // Cek apakah tanggal sudah lewat
        if (checkDate.isBefore(today)) {
          availability[day] = DateAvailability(
            date: date,
            status: DateStatus.past,
            totalSesi: allSesi.length,
            bookedSesi: 0,
            availableSesiIds: [],
            bookedSesiIds: [],
          );
          continue;
        }

        // Cek apakah hari ini dan semua sesi sudah lewat
        bool allSessionsPast = false;
        if (checkDate.isAtSameMomentAs(today)) {
          allSessionsPast = allSesi.every((sesi) => _isSesiPast(sesi, date));
        }

        final dayBookings = bookingsByDate[dateKey] ?? [];
        
        // Filter approved bookings (case-insensitive)
        final approvedBookings = dayBookings
            .where((b) => b.isApproved)
            .toList();
        
        // Untuk hari ini, abaikan sesi yang sudah lewat saat menghitung ketersediaan
        final List<Sesi> sesiConsidered = checkDate.isAtSameMomentAs(today)
          ? allSesi.where((s) => !_isSesiPast(s, date)).toList()
          : allSesi;

        final bookedSesiIds = approvedBookings.map((b) => b.idSesi).toList();
        final bookedSesiIdsConsidered = bookedSesiIds.where((id) =>
          sesiConsidered.any((s) => s.id == id)).toList();

        final availableSesiIds = sesiConsidered
          .where((s) => !bookedSesiIdsConsidered.contains(s.id))
          .map((s) => s.id)
          .toList();

        final totalSesi = sesiConsidered.length;
        final bookedSesi = bookedSesiIdsConsidered.length;

        DateStatus status;
        if (allSessionsPast) {
          status = DateStatus.past;
        } else if (bookedSesi == 0) {
          status = DateStatus.available;
        } else if (bookedSesi == totalSesi) {
          status = DateStatus.unavailable;
        } else {
          status = DateStatus.partial;
        }

        availability[day] = DateAvailability(
          date: date,
          status: status,
          totalSesi: totalSesi,
          bookedSesi: bookedSesi,
          availableSesiIds: availableSesiIds.toList(),
          bookedSesiIds: bookedSesiIds,
        );
      }

      return availability;
    } catch (e) {
      print('Error getting month availability: $e');
      return {};
    }
  }

  /// Menghitung ketersediaan untuk tanggal tertentu
  Future<DateAvailability> getDateAvailability({
    required String labId,
    required DateTime date,
  }) async {
    try {
      // Cek apakah tanggal sudah lewat
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final checkDate = DateTime(date.year, date.month, date.day);
      
      print('=== getDateAvailability ===');
      print('Date: $checkDate, Today: $today');
      
      if (checkDate.isBefore(today)) {
        print('Date is before today - returning past status');
        return DateAvailability(
          date: date,
          status: DateStatus.past,
          totalSesi: 0,
          bookedSesi: 0,
          availableSesiIds: [],
          bookedSesiIds: [],
        );
      }

      // Ambil semua sesi dan booking untuk tanggal tersebut
      final allSesi = await getAllSesi();
      final bookings = await getBookingsByLabAndDate(labId: labId, date: date);
      
        // Cek apakah hari ini dan semua sesi sudah lewat
        bool allSessionsPast = false;
        if (checkDate.isAtSameMomentAs(today)) {
        print('Date is today - checking if all sessions are past');
        allSessionsPast = allSesi.every((sesi) => _isSesiPast(sesi, date));
        print('All sessions past: $allSessionsPast');
        }

        // Filter hanya booking yang approved (case-insensitive)
        final approvedBookings = bookings
          .where((b) => b.isApproved)
          .toList();

        // Untuk hari ini, abaikan sesi yang sudah lewat saat menghitung ketersediaan
        final List<Sesi> sesiConsidered = checkDate.isAtSameMomentAs(today)
          ? allSesi.where((s) => !_isSesiPast(s, date)).toList()
          : allSesi;

        final bookedSesiIds = approvedBookings.map((b) => b.idSesi).toList();
        final bookedSesiIdsConsidered = bookedSesiIds.where((id) =>
          sesiConsidered.any((s) => s.id == id)).toList();

        final availableSesiIds = sesiConsidered
          .where((s) => !bookedSesiIdsConsidered.contains(s.id))
          .map((s) => s.id)
          .toList();

        final totalSesi = sesiConsidered.length;
        final bookedSesi = bookedSesiIdsConsidered.length;

      DateStatus status;
      if (allSessionsPast) {
        status = DateStatus.past;
      } else if (bookedSesi == 0) {
        status = DateStatus.available;
      } else if (bookedSesi == totalSesi) {
        status = DateStatus.unavailable;
      } else {
        status = DateStatus.partial;
      }

      print('Final status: $status');
      return DateAvailability(
        date: date,
        status: status,
        totalSesi: totalSesi,
        bookedSesi: bookedSesi,
        availableSesiIds: availableSesiIds,
        bookedSesiIds: bookedSesiIds,
      );
    } catch (e) {
      print('Error getting date availability: $e');
      return DateAvailability(
        date: date,
        status: DateStatus.unavailable,
        totalSesi: 0,
        bookedSesi: 0,
        availableSesiIds: [],
        bookedSesiIds: [],
      );
    }
  }

  // ==================== BOOKING QUERY METHODS ====================

  /// Mendapatkan booking berdasarkan lab dan tanggal
  Future<List<BookingSlot>> getBookingsByLabAndDate({
    required String labId,
    required DateTime date,
  }) async {
    try {
      // Format tanggal untuk query
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshot = await _bookingsCollection
          .where('idLab', isEqualTo: labId)
          .where('tanggalBooking', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('tanggalBooking', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      List<BookingSlot> bookings = [];
      for (var doc in snapshot.docs) {
        final booking = BookingSlot.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
        
        // Load relasi lab dan sesi
        booking.lab = await getLabById(booking.idLab);
        booking.sesi = await getSesiById(booking.idSesi);
        
        bookings.add(booking);
      }

      return bookings;
    } catch (e) {
      print('Error getting bookings by lab and date: $e');
      return [];
    }
  }

  /// Mendapatkan booking untuk lab dan bulan tertentu
  Future<List<BookingSlot>> getBookingsByLabAndMonth({
    required String labId,
    required int year,
    required int month,
  }) async {
    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

      final snapshot = await _bookingsCollection
          .where('idLab', isEqualTo: labId)
          .where('tanggalBooking', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('tanggalBooking', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      return snapshot.docs
          .map((doc) => BookingSlot.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList();
    } catch (e) {
      print('Error getting monthly bookings: $e');
      return [];
    }
  }

  // ==================== CREATE BOOKING ====================
  
  /// Membuat booking baru dengan user ID
  Future<String?> createBooking({
    required String labId,
    required String sesiId,
    required String keperluanKegiatan,
    required DateTime tanggalBooking,
    required String userId,
  }) async {
    try {
      // Validasi input
      if (userId.isEmpty) {
        throw Exception('User ID tidak boleh kosong');
      }

      // Buat booking object
      final booking = BookingSlot(
        id: '', // Akan di-generate oleh Firestore
        idLab: labId,
        idSesi: sesiId,
        keperluanKegiatan: keperluanKegiatan,
        status: 'Pending', // Default status
        tanggalBooking: tanggalBooking,
        idUser: userId,
        createdAt: DateTime.now(),
      );

      // Simpan ke Firestore
      final docRef = await _bookingsCollection.add(booking.toMap());
      print('Booking berhasil dibuat dengan ID: ${docRef.id} untuk user: $userId');
      return docRef.id;
    } catch (e) {
      print('Error creating booking: $e');
      return null;
    }
  }

  /// Membuat booking dari BookingSlot object
  Future<String?> createBookingFromSlot(BookingSlot booking) async {
    try {
      final docRef = await _bookingsCollection.add(booking.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating booking from slot: $e');
      return null;
    }
  }

  // ==================== GET BOOKINGS ====================

  /// Mendapatkan semua booking milik user tertentu
  Stream<List<BookingSlot>> getBookingsByUser(String userId) {
    return _bookingsCollection
        .where('idUser', isEqualTo: userId)
        .orderBy('tanggalBooking', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          List<BookingSlot> bookings = [];
          for (var doc in snapshot.docs) {
            final booking = BookingSlot.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
            
            // Load relasi lab dan sesi
            booking.lab = await getLabById(booking.idLab);
            booking.sesi = await getSesiById(booking.idSesi);
            
            bookings.add(booking);
          }
          return bookings;
        });
  }

  /// Mendapatkan booking by user dengan filter status
  Stream<List<BookingSlot>> getBookingsByUserAndStatus({
    required String userId,
    required String status,
  }) {
    return _bookingsCollection
        .where('idUser', isEqualTo: userId)
        .where('status', isEqualTo: status)
        .orderBy('tanggalBooking', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          List<BookingSlot> bookings = [];
          for (var doc in snapshot.docs) {
            final booking = BookingSlot.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
            
            booking.lab = await getLabById(booking.idLab);
            booking.sesi = await getSesiById(booking.idSesi);
            
            bookings.add(booking);
          }
          return bookings;
        });
  }

  /// Mendapatkan booking berdasarkan ID
  Future<BookingSlot?> getBookingById(String bookingId) async {
    try {
      final doc = await _bookingsCollection.doc(bookingId).get();
      if (doc.exists) {
        final booking = BookingSlot.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
        
        // Load relasi
        booking.lab = await getLabById(booking.idLab);
        booking.sesi = await getSesiById(booking.idSesi);
        
        return booking;
      }
      return null;
    } catch (e) {
      print('Error getting booking by ID: $e');
      return null;
    }
  }

  // ==================== UPDATE BOOKING ====================

  /// Update status booking
  Future<bool> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    try {
      await _bookingsCollection.doc(bookingId).update({
        'status': status,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      print('Error updating booking status: $e');
      return false;
    }
  }

  /// Update data booking
  Future<bool> updateBooking({
    required String bookingId,
    required String labId,
    required String sesiId,
    required String keperluanKegiatan,
    required DateTime tanggalBooking,
  }) async {
    try {
      await _bookingsCollection.doc(bookingId).update({
        'idLab': labId,
        'idSesi': sesiId,
        'keperluanKegiatan': keperluanKegiatan,
        'tanggalBooking': Timestamp.fromDate(tanggalBooking),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      print('Error updating booking: $e');
      return false;
    }
  }

  // ==================== DELETE BOOKING ====================

  /// Hapus booking (hanya untuk user yang bersangkutan)
  Future<bool> deleteBooking({
    required String bookingId,
    required String userId,
  }) async {
    try {
      // Cek apakah booking milik user
      final booking = await getBookingById(bookingId);
      if (booking?.idUser != userId) {
        throw Exception('Anda tidak memiliki izin untuk menghapus booking ini');
      }

      await _bookingsCollection.doc(bookingId).delete();
      return true;
    } catch (e) {
      print('Error deleting booking: $e');
      return false;
    }
  }

  // ==================== VALIDATION METHODS ====================

  /// Validasi apakah slot tersedia untuk booking
  Future<bool> isSlotAvailable({
    required String labId,
    required String sesiId,
    required DateTime tanggal,
  }) async {
    try {
      final startOfDay = DateTime(tanggal.year, tanggal.month, tanggal.day);
      final endOfDay = DateTime(tanggal.year, tanggal.month, tanggal.day, 23, 59, 59);

      final snapshot = await _bookingsCollection
          .where('idLab', isEqualTo: labId)
          .where('idSesi', isEqualTo: sesiId)
          .where('tanggalBooking', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('tanggalBooking', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .where('status', whereIn: ['Pending', 'Approved'])
          .get();

      return snapshot.docs.isEmpty;
    } catch (e) {
      print('Error checking slot availability: $e');
      return false;
    }
  }

  /// Validasi apakah user sudah memiliki booking di waktu yang sama
  Future<bool> hasUserBookingAtSameTime({
    required String userId,
    required DateTime tanggal,
  }) async {
    try {
      final startOfDay = DateTime(tanggal.year, tanggal.month, tanggal.day);
      final endOfDay = DateTime(tanggal.year, tanggal.month, tanggal.day, 23, 59, 59);

      final snapshot = await _bookingsCollection
          .where('idUser', isEqualTo: userId)
          .where('tanggalBooking', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('tanggalBooking', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .where('status', whereIn: ['Pending', 'Approved'])
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking user booking: $e');
      return false;
    }
  }

  // ==================== STATISTICS ====================

  /// Mendapatkan statistik booking user
  Future<Map<String, int>> getUserBookingStats(String userId) async {
    try {
      final snapshot = await _bookingsCollection
          .where('idUser', isEqualTo: userId)
          .get();

      final total = snapshot.docs.length;
      final pending = snapshot.docs
          .where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'Pending')
          .length;
      final approved = snapshot.docs
          .where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'Approved')
          .length;
      final rejected = snapshot.docs
          .where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'Rejected')
          .length;

      return {
        'total': total,
        'pending': pending,
        'approved': approved,
        'rejected': rejected,
      };
    } catch (e) {
      print('Error getting user booking stats: $e');
      return {'total': 0, 'pending': 0, 'approved': 0, 'rejected': 0};
    }
  }

  // ==================== STREAM METHODS ====================

  /// Stream untuk real-time updates booking by lab dan date
  Stream<List<BookingSlot>> streamBookingsByLabAndDate({
    required String labId,
    required DateTime date,
  }) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _bookingsCollection
        .where('idLab', isEqualTo: labId)
        .where('tanggalBooking', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('tanggalBooking', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingSlot.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ))
            .toList());
  }
}