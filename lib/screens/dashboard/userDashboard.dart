import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../widgets/navbar.dart';
import '../../models/bookingSlot.dart';
import '../../models/lab.dart';
import '../../models/sesi.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({Key? key}) : super(key: key);

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

String? userName;

class _UserDashboardState extends State<UserDashboard>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;

  // Data dari Firebase
  List<BookingSlot> upcomingBookings = [];
  List<BookingSlot> currentBookings = [];
  List<BookingSlot> pastBookings = [];
  
  bool isLoadingBookings = true;
  int totalBookings = 0;
  int pendingCount = 0;
  int approvedCount = 0;
  
  // Filter state
  String? selectedStatusFilter; // null = semua, 'Pending', 'Approved'

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserName();
      _loadBookings();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists) {
        setState(() {
          userName = doc['name'];
        });
      }
    } catch (e) {
      print("Error mengambil nama user: $e");
    }
  }

  Future<void> _loadBookings() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final now = DateTime.now();

      // Ambil semua booking user dari Firebase
      final querySnapshot = await FirebaseFirestore.instance
          .collection('bookingSlots')
          .where('idUser', isEqualTo: uid)
          .orderBy('tanggalBooking', descending: false)
          .get();

      List<BookingSlot> upcoming = [];
      List<BookingSlot> current = [];
      List<BookingSlot> past = [];
      int pending = 0;
      int approved = 0;

      for (var doc in querySnapshot.docs) {
        // Parse BookingSlot dari Firestore
        BookingSlot booking = BookingSlot.fromMap(doc.data(), doc.id);

        // Fetch data Lab
        if (booking.idLab.isNotEmpty) {
          try {
            final labDoc = await FirebaseFirestore.instance
                .collection('laboratorium')
                .doc(booking.idLab)
                .get();
            
            if (labDoc.exists) {
              booking = booking.copyWith(
                lab: Lab.fromMap(labDoc.data()!, labDoc.id),
              );
            }
          } catch (e) {
            print('Error fetching lab: $e');
          }
        }

        // Fetch data Sesi
        if (booking.idSesi.isNotEmpty) {
          try {
            final sesiDoc = await FirebaseFirestore.instance
                .collection('sesi')
                .doc(booking.idSesi)
                .get();
            
            if (sesiDoc.exists) {
              booking = booking.copyWith(
                sesi: Sesi.fromMap(sesiDoc.data()!, sesiDoc.id),
              );
            }
          } catch (e) {
            print('Error fetching sesi: $e');
          }
        }

        // Hitung statistik
        if (booking.isPending) pending++;
        if (booking.isApproved) approved++;

        // Kategorikan booking berdasarkan tanggal dan waktu
        final bookingDate = DateTime(
          booking.tanggalBooking.year,
          booking.tanggalBooking.month,
          booking.tanggalBooking.day,
        );
        
        final today = DateTime(now.year, now.month, now.day);

        if (bookingDate.isAfter(today)) {
          // Booking yang akan datang
          upcoming.add(booking);
        } else if (bookingDate.isAtSameMomentAs(today)) {
          // Booking hari ini - cek jam berdasarkan sesi
          if (booking.sesi != null) {
            final startHour = _parseTimeToHour(booking.sesi!.startTime);
            final endHour = _parseTimeToHour(booking.sesi!.endTime);
            final currentHour = now.hour + (now.minute / 60);

            if (currentHour >= startHour && currentHour <= endHour) {
              // Sedang berlangsung
              // Jika booking ditolak, jangan masukkan ke 'current' — biarkan muncul di list "Booking yang Anda Buat"
              if (booking.isRejected) {
                // Treat rejected current-session bookings as upcoming so they remain visible
                upcoming.add(booking);
              } else {
                current.add(booking);
              }
            } else if (currentHour < startHour) {
              // Belum dimulai
              upcoming.add(booking);
            } else {
              // Sudah selesai
              past.add(booking);
            }
          } else {
            // Jika tidak ada data sesi, masukkan ke upcoming
            upcoming.add(booking);
          }
        } else {
          // Booking yang sudah lewat
          past.add(booking);
        }
      }

      setState(() {
        // Sort setiap list berdasarkan tanggal dan waktu sesi
        upcomingBookings = upcoming;
        _sortBookingsByDateAndTime(upcomingBookings);
        
        currentBookings = current;
        _sortBookingsByDateAndTime(currentBookings);
        
        pastBookings = past;
        _sortBookingsByDateAndTime(pastBookings);
        
        totalBookings = querySnapshot.docs.length;
        pendingCount = pending;
        approvedCount = approved;
        isLoadingBookings = false;
      });
    } catch (e) {
      print("Error loading bookings: $e");
      setState(() {
        isLoadingBookings = false;
      });
      
      // Tampilkan error ke user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data booking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper function untuk format tanggal
  String _formatDate(DateTime date) {
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    
    return '${days[date.weekday % 7]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // Helper function untuk mendapatkan icon lab
  IconData _getLabIcon(String labName) {
    final name = labName.toLowerCase();
    if (name.contains('komputer')) return Icons.computer;
    if (name.contains('jaringan')) return Icons.router;
    if (name.contains('multimedia')) return Icons.photo_library;
    if (name.contains('database') || name.contains('bisnis')) return Icons.storage;
    if (name.contains('hardware') || name.contains('perakitan')) return Icons.memory;
    if (name.contains('software')) return Icons.code;
    return Icons.science;
  }

  // Helper function untuk mendapatkan warna status
  Color _getStatusColor(String status) {
    if (status.toLowerCase() == 'approved') return Color(0xFF10B981);
    if (status.toLowerCase() == 'pending') return Color(0xFFFF9F43);
    if (status.toLowerCase() == 'rejected') return Color(0xFFEF4444);
    return Color(0xFF6B7280);
  }

  // Helper function untuk parse waktu ke jam (desimal)
  double _parseTimeToHour(String time) {
    try {
      // Parse format "08.00" atau "08:00"
      final cleaned = time.replaceAll('.', ':');
      final parts = cleaned.split(':');
      if (parts.length >= 2) {
        return double.parse(parts[0]) + (double.parse(parts[1]) / 60);
      }
      return 0;
    } catch (e) {
      print('Error parsing time: $e');
      return 0;
    }
  }

  // Helper function untuk mengurutkan booking berdasarkan tanggal dan waktu sesi
  void _sortBookingsByDateAndTime(List<BookingSlot> bookings) {
    bookings.sort((a, b) {
      // Urutkan berdasarkan tanggal terlebih dahulu
      final dateComparison = a.tanggalBooking.compareTo(b.tanggalBooking);
      if (dateComparison != 0) {
        return dateComparison;
      }

      // Jika tanggal sama, urutkan berdasarkan waktu sesi
      if (a.sesi != null && b.sesi != null) {
        final aStartHour = _parseTimeToHour(a.sesi!.startTime);
        final bStartHour = _parseTimeToHour(b.sesi!.startTime);
        return aStartHour.compareTo(bStartHour);
      }

      // Jika salah satu tidak memiliki sesi, asumsikan urutan tetap
      return 0;
    });
  }

  // Helper untuk mendapatkan nama status dengan huruf kapital
  String _getStatusDisplay(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Disetujui';
      case 'pending':
        return 'Menunggu';
      case 'rejected':
        return 'Ditolak';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // BACKGROUND UTAMA
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF0F4FF),
                  Color(0xFFE8F1FF),
                  Color(0xFFF5F9FF),
                ],
              ),
            ),
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeController,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildAppBar(),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildQuickStats(),
                            const SizedBox(height: 30),
                            
                            // Tampilkan booking yang sedang berlangsung
                            if (currentBookings.isNotEmpty) ...[
                              _buildSectionTitle(
                                'Sedang Berlangsung',
                                Icons.play_circle_outline,
                              ),
                              const SizedBox(height: 15),
                              _buildBookingsList(currentBookings, 'Current'),
                              const SizedBox(height: 30),
                            ],
                            
                            // Tampilkan booking yang akan datang
                            _buildSectionTitle(
                              'Booking yang Anda Buat',
                              Icons.calendar_today,
                            ),
                            const SizedBox(height: 15),
                            isLoadingBookings
                                ? _buildLoadingIndicator()
                                : _filterBookingsByStatus(upcomingBookings).isEmpty
                                    ? _buildEmptyState(
                                        selectedStatusFilter == null
                                            ? 'Tidak ada booking mendatang'
                                            : 'Tidak ada booking dengan status $selectedStatusFilter')
                                    : _buildBookingsList(
                                        _filterBookingsByStatus(upcomingBookings), 'Upcoming'),
                            const SizedBox(height: 30),
                            
                            // Tampilkan booking yang sudah lewat
                            if (_filterBookingsByStatus(pastBookings).isNotEmpty) ...[
                              _buildSectionTitle(
                                'Riwayat Booking',
                                Icons.history,
                              ),
                              const SizedBox(height: 15),
                              _buildBookingsList(
                                  _filterBookingsByStatus(pastBookings), 'Past'),
                            ],
                            
                            const SizedBox(height: 100), // Extra space untuk navbar
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // NAVBAR DI BAWAH
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: const Navbar(userRole: 'user', currentIndex: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4A90E2), Color(0xFF5B9FEE), Color(0xFF6BADFF)],
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF4A90E2).withOpacity(0.3),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: FlexibleSpaceBar(
          titlePadding: const EdgeInsets.only(left: 20, bottom: 20),
          title: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-0.5, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _slideController,
                curve: Curves.easeOut,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, ${userName ?? "Mahasiswa"}! 👋',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const Text(
                  'Lab Scheduler',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          background: Padding(
            padding: const EdgeInsets.only(right: 20, top: 40),
            child: Align(
              alignment: Alignment.topRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_pulseController.value * 0.1),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper function untuk filter booking berdasarkan status
  List<BookingSlot> _filterBookingsByStatus(List<BookingSlot> bookings) {
    if (selectedStatusFilter == null) {
      return bookings;
    }
    return bookings.where((booking) {
      return booking.status.toLowerCase() == selectedStatusFilter!.toLowerCase();
    }).toList();
  }

  // Helper function untuk toggle filter
  void _toggleStatusFilter(String? status) {
    setState(() {
      if (selectedStatusFilter == status) {
        selectedStatusFilter = null; // Reset filter jika diklik lagi
      } else {
        selectedStatusFilter = status;
      }
    });
  }

  Widget _buildQuickStats() {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
          .animate(
            CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
          ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Booking',
              totalBookings.toString(),
              Icons.event_note,
              Color(0xFF4A90E2),
              Color(0xFFE8F1FF),
              onTap: () => _toggleStatusFilter(null), // Reset filter
              isActive: selectedStatusFilter == null,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: _buildStatCard(
              'Menunggu',
              pendingCount.toString(),
              Icons.pending_actions,
              Color(0xFFFF9F43),
              Color(0xFFFFF4E6),
              onTap: () => _toggleStatusFilter('Pending'),
              isActive: selectedStatusFilter == 'Pending',
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: _buildStatCard(
              'Disetujui',
              approvedCount.toString(),
              Icons.check_circle,
              Color(0xFF10B981),
              Color(0xFFECFDF5),
              onTap: () => _toggleStatusFilter('Approved'),
              isActive: selectedStatusFilter == 'Approved',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color iconColor,
    Color bgColor, {
    VoidCallback? onTap,
    bool isActive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isActive ? Border.all(color: iconColor, width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: isActive
                    ? iconColor.withOpacity(0.2)
                    : Colors.black.withOpacity(0.05),
                blurRadius: isActive ? 15 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A90E2), Color(0xFF5B9FEE)],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF4A90E2).withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildBookingsList(List<BookingSlot> bookings, String type) {
    return Column(
      children: bookings.asMap().entries.map((entry) {
        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 400 + (entry.key * 100)),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: _buildBookingCard(entry.value, type),
        );
      }).toList(),
    );
  }

  Widget _buildBookingCard(BookingSlot booking, String type) {
    // Tambahkan badge "Sedang Berlangsung" untuk current bookings
    bool isCurrent = type == 'Current';
    
    // Get data untuk display
    String labName = booking.lab?.namaLab ?? 'Lab';
    String sesiInfo = booking.sesi?.waktu ?? 'Sesi tidak tersedia';
    Color statusColor = _getStatusColor(booking.status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isCurrent 
            ? Border.all(color: Color(0xFF4A90E2), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // TODO: Navigate to booking detail
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Badge "Sedang Berlangsung"
                  if (isCurrent)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Color(0xFF4A90E2).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_circle_filled,
                            color: Color(0xFF4A90E2),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'SEDANG BERLANGSUNG',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A90E2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          _getLabIcon(labName),
                          color: statusColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              labName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              booking.keperluanKegiatan,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _formatDate(booking.tanggalBooking),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  sesiInfo,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: booking.isApproved
                              ? Color(0xFFECFDF5)
                              : booking.isPending
                                  ? Color(0xFFFFF4E6)
                                  : Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _getStatusDisplay(booking.status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
        ),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}