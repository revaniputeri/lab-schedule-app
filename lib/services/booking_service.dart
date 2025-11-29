// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lab.dart';
import '../models/sesi.dart';
import '../models/bookingSlot.dart';
import '../models/date_availability.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _labsCollection => _firestore.collection('laboratorium');
  CollectionReference get _sesiCollection => _firestore.collection('sesi');
  CollectionReference get _bookingsCollection => _firestore.collection('bookingSlots');

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
  
  /// Mendapatkan semua sesi (diurutkan berdasarkan nama sesi)
  Future<List<Sesi>> getAllSesi() async {
    try {
      final snapshot = await _sesiCollection.get();
      final sesiList = snapshot.docs
          .map((doc) => Sesi.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      
      // Sort by order (extracted from sesi name)
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

  // ==================== BOOKING METHODS ====================
  
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
        
        // Fetch relasi Lab dan Sesi
        booking.lab = await getLabById(booking.idLab);
        booking.sesi = await getSesiById(booking.idSesi);
        
        bookings.add(booking);
      }

      return bookings;
    } catch (e) {
      print('Error getting bookings: $e');
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

  /// Membuat booking baru
  Future<String?> createBooking(BookingSlot booking) async {
    try {
      final docRef = await _bookingsCollection.add(booking.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating booking: $e');
      return null;
    }
  }

  /// Update status booking
  Future<bool> updateBookingStatus(String bookingId, String status) async {
    try {
      await _bookingsCollection.doc(bookingId).update({'status': status});
      return true;
    } catch (e) {
      print('Error updating booking status: $e');
      return false;
    }
  }

  // ==================== AVAILABILITY METHODS ====================
  /// Helper function untuk cek apakah sesi sudah lewat (menggunakan tanggal yang diberikan)
  bool _isSesiPast(Sesi sesi, DateTime date) {
    try {
      final now = DateTime.now();
      final sesiEndTime = sesi.endTime; // ex: "08:00" or "08.00"
      final cleaned = sesiEndTime.contains(':') ? sesiEndTime : sesiEndTime.replaceAll('.', ':');
      final parts = cleaned.split(':');
      if (parts.length < 2) return false;
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      final sesiEndDateTime = DateTime(date.year, date.month, date.day, hour, minute);
      return now.isAfter(sesiEndDateTime);
    } catch (e) {
      print('Error in _isSesiPast: $e');
      return false;
    }
  }
  
  /// Menghitung ketersediaan untuk tanggal tertentu
  Future<DateAvailability> getDateAvailability({
    required String labId,
    required DateTime date,
  }) async {
    // Cek apakah tanggal sudah lewat
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final checkDate = DateTime(date.year, date.month, date.day);
    
    if (checkDate.isBefore(today)) {
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

    // Filter hanya booking yang approved (case-insensitive)
    final approvedBookings = bookings.where((b) => b.isApproved).toList();

    // Cek apakah hari ini dan semua sesi sudah lewat
    bool allSessionsPast = false;
    if (checkDate.isAtSameMomentAs(today)) {
      allSessionsPast = allSesi.every((sesi) => _isSesiPast(sesi, date));
    }

    // Untuk hari ini, abaikan sesi yang sudah lewat saat menghitung ketersediaan
    final List<Sesi> sesiConsidered = checkDate.isAtSameMomentAs(today)
        ? allSesi.where((s) => !_isSesiPast(s, date)).toList()
        : allSesi;

    final bookedSesiIds = approvedBookings.map((b) => b.idSesi).toList();
    final bookedSesiIdsConsidered = bookedSesiIds
        .where((id) => sesiConsidered.any((s) => s.id == id))
        .toList();

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

    // Debug logging for today to help verify availability
    if (checkDate.isAtSameMomentAs(today)) {
      print('getDateAvailability - date: $checkDate, totalSesiConsidered: $totalSesi, bookedSesi: $bookedSesi, availableSesiIds: $availableSesiIds, bookedSesiIds: $bookedSesiIds');
    }

    return DateAvailability(
      date: date,
      status: status,
      totalSesi: totalSesi,
      bookedSesi: bookedSesi,
      availableSesiIds: availableSesiIds,
      bookedSesiIds: bookedSesiIdsConsidered,
    );
  }

  /// Mendapatkan availability untuk seluruh bulan
  Future<Map<int, DateAvailability>> getMonthAvailability({
    required String labId,
    required int year,
    required int month,
  }) async {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final Map<int, DateAvailability> availability = {};

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

      final dayBookings = bookingsByDate[dateKey] ?? [];

      // Filter approved bookings (case-insensitive)
      final approvedBookings = dayBookings.where((b) => b.isApproved).toList();

      // Cek apakah hari ini dan semua sesi sudah lewat
      bool allSessionsPast = false;
      if (checkDate.isAtSameMomentAs(today)) {
        allSessionsPast = allSesi.every((sesi) => _isSesiPast(sesi, date));
      }

      // Untuk hari ini, abaikan sesi yang sudah lewat saat menghitung ketersediaan
      final List<Sesi> sesiConsidered = checkDate.isAtSameMomentAs(today)
          ? allSesi.where((s) => !_isSesiPast(s, date)).toList()
          : allSesi;

      final bookedSesiIds = approvedBookings.map((b) => b.idSesi).toList();
      final bookedSesiIdsConsidered = bookedSesiIds
          .where((id) => sesiConsidered.any((s) => s.id == id))
          .toList();

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
        bookedSesiIds: bookedSesiIdsConsidered,
      );

      // Debug logging for today
      if (checkDate.isAtSameMomentAs(today)) {
        print('getMonthAvailability - day: $day, totalSesiConsidered: $totalSesi, bookedSesi: $bookedSesi, availableSesiIds: ${availableSesiIds.toList()}, bookedSesiIds: ${bookedSesiIdsConsidered}');
      }
    }

    return availability;
  }

  /// Stream untuk real-time updates (opsional)
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