import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/booking_service.dart';
import '../models/lab.dart';
import '../models/date_availability.dart';
import '../widgets/month_selector.dart';
import '../widgets/room_selector.dart';
import '../widgets/calendar_grid.dart';
import '../widgets/navbar.dart';
import 'create_booking_page.dart';

class RoomBookingPage extends StatefulWidget {
  const RoomBookingPage({Key? key}) : super(key: key);

  @override
  State<RoomBookingPage> createState() => _RoomBookingPageState();
}

class _RoomBookingPageState extends State<RoomBookingPage>
    with TickerProviderStateMixin {
  final BookingService _bookingService = BookingService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Lab> _labs = [];
  String? _selectedLabId;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _selectedDay = DateTime.now().day;

  Map<int, DateAvailability> _monthAvailability = {};
  bool _isLoading = true;
  String? _currentUserId;
  String? _userName; // Tambahkan variable untuk nama user

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    
    // Setup animation controllers
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _getCurrentUser();
    _loadInitialData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Method untuk mendapatkan current user
  void _getCurrentUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      // Coba ambil nama dari Firestore jika displayName kosong
      String? userName;
      if (currentUser.displayName == null || currentUser.displayName!.isEmpty) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
          if (userDoc.exists) {
            userName = userDoc['name'];
          }
        } catch (e) {
          print('Error fetching user data: $e');
        }
      }
      
      setState(() {
        _currentUserId = currentUser.uid;
        _userName = userName ?? currentUser.displayName ?? currentUser.email?.split('@').first ?? "Mahasiswa";
      });
      print('Current User: $_userName');
    } else {
      print('No user logged in');
      setState(() {
        _userName = "Mahasiswa";
      });
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    _labs = await _bookingService.getAllLabs();

    if (_labs.isNotEmpty) {
      _selectedLabId = _labs[0].id;
      await _loadMonthAvailability();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadMonthAvailability() async {
    if (_selectedLabId == null) return;

    setState(() => _isLoading = true);

    _monthAvailability = await _bookingService.getMonthAvailability(
      labId: _selectedLabId!,
      year: _selectedMonth.year,
      month: _selectedMonth.month,
    );

    setState(() => _isLoading = false);
  }

  void _showNotificationModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Notifikasi',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.blue),
              title: const Text('Booking Anda Disetujui'),
              subtitle: const Text('Lab BA - 15 Nov 2025'),
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber, color: Colors.orange),
              title: const Text('Pengingat Booking'),
              subtitle: const Text('Lab DT - Besok 09:00'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.logout, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text(
          'Anda akan keluar dari akun anda. Lanjutkan?',
          style: TextStyle(fontSize: 15),
          textAlign: TextAlign.left,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseAuth.instance.signOut();
                // Navigasi ke halaman login
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              } catch (e) {
                print('Error signing out: $e');
              }
            },
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeMonth(int delta) async {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
    await _loadMonthAvailability();
  }

  Future<void> _selectLab(String labId) async {
    if (_selectedLabId == labId) return;

    setState(() {
      _selectedLabId = labId;
    });
    await _loadMonthAvailability();
  }

  void _onDaySelected(int day) {
    setState(() {
      _selectedDay = day;
    });
    _showDayDetail(day);
  }

  void _showDayDetail(int day) async {
    final availability = _monthAvailability[day];
    if (availability == null) return;

    final result = await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detail Ketersediaan - $day ${_getMonthName(_selectedMonth.month)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.event_available,
                color: Colors.green.shade600,
              ),
              title: const Text('Sesi Tersedia'),
              trailing: Text(
                '${availability.availableSesiIds.length}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.event_busy, color: Colors.red.shade600),
              title: const Text('Sesi Terisi'),
              trailing: Text(
                '${availability.bookedSesiIds.length}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (availability.isAvailable)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Booking Ruangan',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              )
            else if (availability.isPast)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Tanggal Sudah Lewat',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Tidak Tersedia',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (result == true && _selectedLabId != null) {
      await _navigateToBookingForm(day);
    }
  }

  Future<void> _navigateToBookingForm(int day) async {
    if (_currentUserId == null) {
      _showLoginRequiredDialog();
      return;
    }

    final selectedLab = _labs.firstWhere((lab) => lab.id == _selectedLabId);
    final selectedDate = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      day,
    );

    final bookingResult = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingFormPage(
          lab: selectedLab, 
          selectedDate: selectedDate, 
          currentUserId: _currentUserId!,
        ),
      ),
    );

    if (bookingResult == true) {
      await _loadMonthAvailability();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking berhasil dibuat!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Diperlukan'),
        content: const Text('Anda harus login terlebih dahulu untuk melakukan booking.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxWidth = size.width > 600 ? 600.0 : size.width;

    return Scaffold(
      body: Stack(
        children: [
          // Background utama
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
                      child: Container(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            
                            // Month Selector dengan animasi
                            SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.3), 
                                end: Offset.zero
                              ).animate(
                                CurvedAnimation(
                                  parent: _slideController, 
                                  curve: Curves.easeOut
                                ),
                              ),
                              child: FadeTransition(
                                opacity: _fadeController,
                                child: MonthSelector(
                                  selectedMonth: _selectedMonth,
                                  onMonthChanged: _changeMonth,
                                  isLoading: _isLoading,
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Room Selector dengan animasi
                            SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.5), 
                                end: Offset.zero
                              ).animate(
                                CurvedAnimation(
                                  parent: _slideController,
                                  curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
                                ),
                              ),
                              child: FadeTransition(
                                opacity: _fadeController,
                                child: RoomSelector(
                                  labs: _labs,
                                  selectedLabId: _selectedLabId,
                                  onLabSelected: _selectLab,
                                  isLoading: _isLoading,
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Calendar dengan animasi
                            SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.7), 
                                end: Offset.zero
                              ).animate(
                                CurvedAnimation(
                                  parent: _slideController,
                                  curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
                                ),
                              ),
                              child: FadeTransition(
                                opacity: _fadeController,
                                child: _isLoading && _labs.isEmpty
                                    ? Container(
                                        height: 300,
                                        child: const Center(child: CircularProgressIndicator()),
                                      )
                                    : CalendarGrid(
                                        selectedMonth: _selectedMonth,
                                        selectedDay: _selectedDay,
                                        monthAvailability: _monthAvailability,
                                        onDaySelected: _onDaySelected,
                                      ),
                              ),
                            ),

                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Navbar di bawah
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Navbar(userRole: 'user', currentIndex: 1),
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
              offset: const Offset(0, 8),
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
                  'Halo, ${_userName ?? "Mahasiswa"}! 👋',
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
                  // Notification Icon dengan animasi pulse
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_pulseController.value * 0.1),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _showNotificationModal,
                            borderRadius: BorderRadius.circular(15),
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
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  // Logout Icon
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showLogoutDialog,
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.logout,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}