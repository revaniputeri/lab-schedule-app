import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Tambahkan import ini
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
  final FirebaseAuth _auth = FirebaseAuth.instance; // Tambahkan FirebaseAuth

  List<Lab> _labs = [];
  String? _selectedLabId;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _selectedDay = DateTime.now().day;
  
  Map<int, DateAvailability> _monthAvailability = {};
  bool _isLoading = true;
  String? _currentUserId; // Simpan current user ID

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;

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

    _getCurrentUser();
    _loadInitialData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Method untuk mendapatkan current user
  void _getCurrentUser() {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      setState(() {
        _currentUserId = currentUser.uid;
      });
      print('Current User ID: $_currentUserId'); // Debug
    } else {
      print('No user logged in'); // Debug
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

  Future<void> _changeMonth(int delta) async {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
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
              leading: Icon(Icons.event_available, color: Colors.green.shade600),
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
    // Cek apakah user sudah login
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

    print('Navigating to BookingForm with:'); // Debug
    print('User ID: $_currentUserId'); // Debug
    print('Lab: ${selectedLab.namaLab}'); // Debug
    print('Date: $selectedDate'); // Debug

    final bookingResult = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingFormPage(
          lab: selectedLab, 
          selectedDate: selectedDate, 
          currentUserId: _currentUserId!, // Gunakan currentUserId yang sudah disimpan
        ),
      ),
    );

    if (bookingResult == true) {
      // Refresh data setelah booking berhasil
      await _loadMonthAvailability();
      
      // Show success message
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

    if (_isLoading && _labs.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0F4FF), Color(0xFFE8F1FF), Color(0xFFF5F9FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                children: [
                  // Header dengan icon notifikasi (dengan fade animation)
                  FadeTransition(
                    opacity: _fadeController,
                    child: _buildHeader(),
                  ),
                  const SizedBox(height: 8),

                  // Month Selector (dengan slide up animation)
                  SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
                        .animate(
                          CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
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

                  // Room Selector (dengan slide up animation)
                  SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
                        .animate(
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

                  // Calendar (dengan slide up animation)
                  Expanded(
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.7), end: Offset.zero)
                          .animate(
                            CurvedAnimation(
                              parent: _slideController,
                              curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
                            ),
                          ),
                      child: FadeTransition(
                        opacity: _fadeController,
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : CalendarGrid(
                                selectedMonth: _selectedMonth,
                                selectedDay: _selectedDay,
                                monthAvailability: _monthAvailability,
                                onDaySelected: _onDaySelected,
                              ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const Navbar(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Notification icon
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _showNotificationModal,
              icon: const Icon(
                Icons.notifications_outlined,
                size: 24,
              ),
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}