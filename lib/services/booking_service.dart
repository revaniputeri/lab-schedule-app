// lib/services/booking_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lab.dart';
import '../models/sesi.dart';
import '../models/bookingSlot.dart';
import '../models/date_availability.dart';
import '../models/user.dart';
import '../services/notificaton_service.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Collection references - SESUAI DENGAN FIREBASE ANDA
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

  /// Mendapatkan multiple sesi berdasarkan list ID
  Future<List<Sesi>> getSesiByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    
    try {
      final List<Sesi> sesiList = [];
      
      // Firestore whereIn max 10 items, jadi batch jika lebih
      const int batchSize = 10;
      for (int i = 0; i < ids.length; i += batchSize) {
        final slice = ids.sublist(
          i, 
          i + batchSize > ids.length ? ids.length : i + batchSize
        );
        
        final snapshot = await _sesiCollection
            .where(FieldPath.documentId, whereIn: slice)
            .get();
            
        sesiList.addAll(
          snapshot.docs.map((doc) => 
            Sesi.fromMap(doc.data() as Map<String, dynamic>, doc.id)
          )
        );
      }
      
      // Sort by order
      sesiList.sort((a, b) => a.order.compareTo(b.order));
      
      return sesiList;
    } catch (e) {
      print('Error getting multiple sesi: $e');
      return [];
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

  /// Membuat booking baru dengan notifikasi
  Future<String?> createBooking(BookingSlot booking) async {
    try {
      // Simpan booking ke Firestore
      final docRef = await _bookingsCollection.add(booking.toMap());
      final bookingId = docRef.id;
      
      print('✅ Booking created with ID: $bookingId');
      
      // Kirim notifikasi ke admin (async, jangan block)
      _sendNewBookingNotification(
        bookingId: bookingId,
        booking: booking,
      ).catchError((e) {
        print('⚠️ Notification error (non-blocking): $e');
      });
      
      return bookingId;
    } catch (e) {
      print('❌ Error creating booking: $e');
      return null;
    }
  }

  /// Helper method untuk mengirim notifikasi booking baru
  Future<void> _sendNewBookingNotification({
    required String bookingId,
    required BookingSlot booking,
  }) async {
    try {
      // Get lab info
      final lab = await getLabById(booking.idLab);
      if (lab == null) {
        print('⚠️ Lab not found for notification');
        return;
      }

      // Get sesi info
      final sesi = await getSesiById(booking.idSesi);
      if (sesi == null) {
        print('⚠️ Sesi not found for notification');
        return;
      }

      // Get user info - SESUAI FIELD FIREBASE ANDA (idUser)
      final user = await getUserById(booking.idUser);
      final userName = user?.name ?? 'User';

      // Format date
      final date = booking.tanggalBooking;
      final formattedDate = '${date.day}/${date.month}/${date.year}';

      // Format time
      final time = '${sesi.startTime} - ${sesi.endTime}';

      // Get admin FCM tokens
      final adminTokens = await _notificationService.getAdminTokens();
      
      if (adminTokens.isEmpty) {
        print('⚠️ No admin tokens found for notification');
        return;
      }

      print('📤 Sending notification to ${adminTokens.length} admins');
      print('   User: $userName');
      print('   Lab: ${lab.namaLab}');
      print('   Date: $formattedDate');
      print('   Time: $time');

      // Send notification
      await _notificationService.sendBookingNotification(
        bookingId: bookingId,
        userName: userName,
        labName: lab.namaLab,
        time: time,
        date: formattedDate,
        adminTokens: adminTokens,
      );

      print('✅ Notification sent successfully');
    } catch (e) {
      print('❌ Error sending notification: $e');
      // Don't throw error, booking sudah berhasil dibuat
    }
  }

  /// Update status booking dengan notifikasi
  Future<bool> updateBookingStatus(String bookingId, String status) async {
    try {
      // Normalisasi status: "Approved", "Pending", "Rejected"
      final normalized = status.isEmpty
          ? status
          : status[0].toUpperCase() + status.substring(1).toLowerCase();
      
      // Get booking detail sebelum update untuk notifikasi
      final bookingDoc = await _bookingsCollection.doc(bookingId).get();
      if (!bookingDoc.exists) {
        print('⚠️ Booking not found');
        return false;
      }

      final bookingData = bookingDoc.data() as Map<String, dynamic>;
      final booking = BookingSlot.fromMap(bookingData, bookingId);
      
      // Update status
      await _bookingsCollection.doc(bookingId).update({'status': normalized});
      
      print('✅ Booking status updated to: $normalized');
      
      // Kirim notifikasi jika status berubah ke approved atau rejected
      if (normalized.toLowerCase() == 'approved' || 
          normalized.toLowerCase() == 'rejected') {
        _sendStatusChangeNotification(
          bookingId: bookingId,
          booking: booking,
          newStatus: normalized,
        ).catchError((e) {
          print('⚠️ Status notification error (non-blocking): $e');
        });
      }
      
      return true;
    } catch (e) {
      print('❌ Error updating booking status: $e');
      return false;
    }
  }

  /// Helper method untuk notifikasi perubahan status
  Future<void> _sendStatusChangeNotification({
    required String bookingId,
    required BookingSlot booking,
    required String newStatus,
  }) async {
    try {
      // Get user FCM token - SESUAI FIELD FIREBASE (idUser)
      final user = await getUserById(booking.idUser);
      if (user == null || user.fcmToken == null || user.fcmToken!.isEmpty) {
        print('⚠️ User FCM token not found for user: ${booking.idUser}');
        return;
      }

      // Get lab info
      final lab = await getLabById(booking.idLab);
      if (lab == null) return;

      // Get sesi info
      final sesi = await getSesiById(booking.idSesi);
      if (sesi == null) return;

      // Format data
      final date = booking.tanggalBooking;
      final formattedDate = '${date.day}/${date.month}/${date.year}';
      final time = '${sesi.startTime} - ${sesi.endTime}';

      String title;
      String body;
      
      if (newStatus.toLowerCase() == 'approved') {
        title = '✅ Booking Disetujui!';
        body = 'Booking Anda untuk ${lab.namaLab} pada $formattedDate ($time) telah disetujui';
      } else {
        title = '❌ Booking Ditolak';
        body = 'Booking Anda untuk ${lab.namaLab} pada $formattedDate ($time) ditolak';
      }

      print('📤 Sending status notification to: ${user.name}');

      // Create notification document untuk Cloud Function
      await _firestore.collection('notifications').add({
        'type': 'booking_status_update',
        'bookingId': bookingId,
        'userId': booking.idUser,
        'userToken': user.fcmToken,
        'labName': lab.namaLab,
        'time': time,
        'date': formattedDate,
        'status': newStatus,
        'title': title,
        'body': body,
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });

      print('✅ Status notification queued');
    } catch (e) {
      print('❌ Error sending status notification: $e');
    }
  }

  /// Ambil booking berdasarkan status (pending / approved / rejected)
  Future<List<BookingSlot>> getBookingsByStatus(String status) async {
    try {
      final normalizedRaw = status.isEmpty
          ? status
          : status[0].toUpperCase() + status.substring(1).toLowerCase();
      final normalized = normalizedRaw.trim();
      List<String> variants = [normalized, normalized.toLowerCase()];
      
      if (normalized.toLowerCase() == 'rejected') {
        variants.add('Ditolak');
      } else if (normalized.toLowerCase() == 'approved') {
        variants.add('Disetujui');
      } else if (normalized.toLowerCase() == 'pending') {
        variants.add('Menunggu');
      }
      
      variants = variants.where((e) => e.trim().isNotEmpty).toSet().toList();
      print('[getBookingsByStatus] Querying status variants = ${variants.join(', ')}');
      
      Query base = _bookingsCollection.where('status', whereIn: variants);
      final bool isPending = normalized.toLowerCase() == 'pending';
      Query ordered = base.orderBy('createdAt', descending: !isPending);
      
      QuerySnapshot snapshot;
      try {
        snapshot = await ordered.get();
      } on FirebaseException catch (e) {
        if (e.code == 'failed-precondition') {
          print('[getBookingsByStatus] Index missing, retry without orderBy');
          snapshot = await base.get();
        } else {
          rethrow;
        }
      }
      
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

      list.sort((a, b) {
        final da = a.createdAt ?? a.tanggalBooking;
        final db = b.createdAt ?? b.tanggalBooking;
        return (normalized.toLowerCase() == 'pending')
            ? da.compareTo(db) // oldest first
            : db.compareTo(da); // newest first
      });
      
      return list;
    } catch (e) {
      print('Error getBookingsByStatus($status): $e');
      return [];
    }
  }

  /// Ambil semua booking
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

  // ==================== USER METHODS ====================

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

  /// Ambil banyak user sekaligus (batch by 10 dokumen)
  Future<Map<String, AppUser>> getUsersByIds(List<String> ids) async {
    final Map<String, AppUser> result = {};
    final unique = ids.where((e) => e.isNotEmpty).toSet().toList();
    const int batchSize = 10;
    
    for (int i = 0; i < unique.length; i += batchSize) {
      final slice = unique.sublist(
        i, 
        i + batchSize > unique.length ? unique.length : i + batchSize
      );
      
      try {
        final snap = await _usersCollection
            .where(FieldPath.documentId, whereIn: slice)
            .get();
            
        for (var doc in snap.docs) {
          try {
            final user = AppUser.fromMap(
              doc.data() as Map<String, dynamic>, 
              doc.id
            );
            result[user.id] = user;
          } catch (e) {
            print('Error mapping user ${doc.id}: $e');
          }
        }
      } catch (e) {
        print('Error batch get users: $e');
      }
    }
    
    return result;
  }

  // ==================== AVAILABILITY METHODS ====================
  
  /// Helper function untuk cek apakah sesi sudah lewat
  bool _isSesiPast(Sesi sesi, DateTime date) {
    try {
      final now = DateTime.now();
      final sesiEndTime = sesi.endTime;
      final cleaned = sesiEndTime.contains(':') 
          ? sesiEndTime 
          : sesiEndTime.replaceAll('.', ':');
      final parts = cleaned.split(':');
      
      if (parts.length < 2) return false;
      
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      final sesiEndDateTime = DateTime(
        date.year, 
        date.month, 
        date.day, 
        hour, 
        minute
      );
      
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

    final allSesi = await getAllSesi();
    final bookings = await getBookingsByLabAndDate(labId: labId, date: date);
    final approvedBookings = bookings.where((b) => b.isApproved).toList();

    bool allSessionsPast = false;
    if (checkDate.isAtSameMomentAs(today)) {
      allSessionsPast = allSesi.every((sesi) => _isSesiPast(sesi, date));
    }

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

    final allSesi = await getAllSesi();
    final monthlyBookings = await getBookingsByLabAndMonth(
      labId: labId,
      year: year,
      month: month,
    );

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
      final approvedBookings = dayBookings.where((b) => b.isApproved).toList();

      bool allSessionsPast = false;
      if (checkDate.isAtSameMomentAs(today)) {
        allSessionsPast = allSesi.every((sesi) => _isSesiPast(sesi, date));
      }

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
    }

    return availability;
  }

  /// Stream untuk real-time updates
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