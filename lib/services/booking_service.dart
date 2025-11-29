// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lab.dart';
import '../models/sesi.dart';
import '../models/bookingSlot.dart';
import '../models/date_availability.dart';
import '../models/user.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _labsCollection => _firestore.collection('laboratorium');
  CollectionReference get _sesiCollection => _firestore.collection('sesi');
  CollectionReference get _bookingsCollection => _firestore.collection('bookingSlots');
  CollectionReference get _usersCollection => _firestore.collection('users');

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
      // Normalisasi status: kapital huruf pertama lainnya lowercase agar konsisten dengan data Firestore ("Approved", "Pending", "Rejected")
      final normalized = status.isEmpty
          ? status
          : status[0].toUpperCase() + status.substring(1).toLowerCase();
      await _bookingsCollection.doc(bookingId).update({'status': normalized});
      return true;
    } catch (e) {
      print('Error updating booking status: $e');
      return false;
    }
  }

  /// Ambil booking berdasarkan status (pending / approved / rejected)
  Future<List<BookingSlot>> getBookingsByStatus(String status) async {
    try {
        final normalizedRaw = status.isEmpty
            ? status
            : status[0].toUpperCase() + status.substring(1).toLowerCase();
        final normalized = normalizedRaw.trim();
        // Build case-insensitive variants
        List<String> variants = [normalized, normalized.toLowerCase()];
        if (normalized.toLowerCase() == 'rejected') {
          variants.add('Ditolak');
        } else if (normalized.toLowerCase() == 'approved') {
          variants.add('Disetujui');
        } else if (normalized.toLowerCase() == 'pending') {
          variants.add('Menunggu');
        }
        // Remove duplicates and empty
        variants = variants.where((e) => e.trim().isNotEmpty).toSet().toList();
        print('[getBookingsByStatus] Querying status variants = ${variants.join(', ')}');
        Query base = _bookingsCollection.where('status', whereIn: variants);
        Query ordered = base.orderBy('tanggalBooking', descending: false);
      QuerySnapshot snapshot;
      try {
        snapshot = await ordered.get();
      } on FirebaseException catch (e) {
        // Jika index belum dibuat untuk kombinasi where + orderBy
        if (e.code == 'failed-precondition') {
          print('[getBookingsByStatus] Index missing, retry without orderBy. Firestore message: ${e.message}');
          snapshot = await base.get();
        } else {
          rethrow;
        }
      }
      // Kumpulkan dokumen (sudah mencakup variasi dengan whereIn)
      final docs = <QueryDocumentSnapshot>[];
      docs.addAll(snapshot.docs);
      print('[getBookingsByStatus] Found ${docs.length} docs');
      final List<BookingSlot> list = [];
      for (var doc in docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final b = BookingSlot.fromMap(data, doc.id);
          if (b.idLab.isNotEmpty) {
            b.lab = await getLabById(b.idLab);
          }
            if (b.idSesi.isNotEmpty) {
            b.sesi = await getSesiById(b.idSesi);
          }
          list.add(b);
        } catch (inner) {
          print('[getBookingsByStatus] Error mapping doc ${doc.id}: $inner');
        }
      }
      return list;
    } catch (e) {
      print('Error getBookingsByStatus($status): $e');
      return [];
    }
  }

  /// Ambil semua booking sekaligus lalu kelompokkan di client (opsional)
  Future<List<BookingSlot>> getAllBookings() async {
    try {
      final snapshot = await _bookingsCollection.get();
      final List<BookingSlot> list = [];
      for (var doc in snapshot.docs) {
        final b = BookingSlot.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        b.lab = await getLabById(b.idLab);
        b.sesi = await getSesiById(b.idSesi);
        list.add(b);
      }
      return list;
    } catch (e) {
      print('Error getAllBookings: $e');
      return [];
    }
  }

  /// Ambil user tunggal
  Future<AppUser?> getUserById(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (!doc.exists) return null;
      return AppUser.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    } catch (e) {
      print('Error getUserById($userId): $e');
      return null;
    }
  }

  /// Ambil banyak user sekaligus (batch by 10 dokumen karena batas whereIn)
  Future<Map<String, AppUser>> getUsersByIds(List<String> ids) async {
    final Map<String, AppUser> result = {};
    final unique = ids.where((e) => e.isNotEmpty).toSet().toList();
    const int batchSize = 10; // Firestore whereIn maksimum 10
    for (int i = 0; i < unique.length; i += batchSize) {
      final slice = unique.sublist(i, i + batchSize > unique.length ? unique.length : i + batchSize);
      try {
        final snap = await _usersCollection.where(FieldPath.documentId, whereIn: slice).get();
        for (var doc in snap.docs) {
          try {
            final user = AppUser.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            result[user.id] = user;
          } catch (e) {
            print('Error mapping user ${doc.id}: $e');
          }
        }
      } catch (e) {
        print('Error batch get users (${slice.join(',')}): $e');
      }
    }
    return result;
  }

  // ==================== AVAILABILITY METHODS ====================
  
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
    final approvedBookings = bookings
        .where((b) => b.isApproved)
        .toList();
    
    final bookedSesiIds = approvedBookings.map((b) => b.idSesi).toList();
    final availableSesiIds = allSesi
        .where((s) => !bookedSesiIds.contains(s.id))
        .map((s) => s.id)
        .toList();

    final totalSesi = allSesi.length;
    final bookedSesi = bookedSesiIds.length;

    DateStatus status;
    if (bookedSesi == 0) {
      status = DateStatus.available;
    } else if (bookedSesi == totalSesi) {
      status = DateStatus.unavailable;
    } else {
      status = DateStatus.partial;
    }

    return DateAvailability(
      date: date,
      status: status,
      totalSesi: totalSesi,
      bookedSesi: bookedSesi,
      availableSesiIds: availableSesiIds,
      bookedSesiIds: bookedSesiIds,
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
      final approvedBookings = dayBookings
          .where((b) => b.isApproved)
          .toList();
      
      final bookedSesiIds = approvedBookings.map((b) => b.idSesi).toList();
      final availableSesiIds = allSesi
          .where((s) => !bookedSesiIds.contains(s.id))
          .map((s) => s.id)
          .toList();

      final totalSesi = allSesi.length;
      final bookedSesi = bookedSesiIds.length;

      DateStatus status;
      if (bookedSesi == 0) {
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