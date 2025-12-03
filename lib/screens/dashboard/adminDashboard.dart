import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jadwal_lab/services/booking_service.dart';
import 'package:jadwal_lab/models/user.dart';
import 'package:jadwal_lab/models/bookingSlot.dart';
import 'package:intl/intl.dart';
import 'package:jadwal_lab/widgets/navbar.dart';

// File: adminDashboard.dart
// Dashboard untuk Admin/Dosen untuk validasi booking

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late TabController _tabController;

  final _service = BookingService(); 
  bool _isLoading = false;
  String? _error;

  List<BookingSlot> _pending = [];
  List<BookingSlot> _approved = [];
  List<BookingSlot> _rejected = [];
  Map<String, AppUser> _userCache = {};

  Map<String, int> stats = {
    'pending': 0,
    'approved': 0,
    'rejected': 0,
    'total': 0,
  };

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

    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Ambil lab yang dikelola admin login saat ini
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw 'User belum login';
      }

      final labsSnap = await FirebaseFirestore.instance
          .collection('laboratorium')
          .where('userId', isEqualTo: uid)
          .get();
      final ownedLabIds = labsSnap.docs.map((d) => d.id).toList();

      // Jika admin tidak memiliki lab, kosongkan hasil
      if (ownedLabIds.isEmpty) {
        setState(() {
          _pending = [];
          _approved = [];
          _rejected = [];
          _userCache = {};
          stats = {
            'pending': 0,
            'approved': 0,
            'rejected': 0,
            'total': 0,
          };
        });
        return;
      }

      // Ambil booking per status lalu filter hanya milik lab admin
      final pendingAll = await _service.getBookingsByStatus('pending');
      final approvedAll = await _service.getBookingsByStatus('approved');
      final rejectedAll = await _service.getBookingsByStatus('rejected');

      final pending = pendingAll.where((b) => ownedLabIds.contains(b.idLab)).toList();
      final approved = approvedAll.where((b) => ownedLabIds.contains(b.idLab)).toList();
      final rejected = rejectedAll.where((b) => ownedLabIds.contains(b.idLab)).toList();

      final allIds = <String>{};
      for (var b in pending) allIds.add(b.idUser);
      for (var b in approved) allIds.add(b.idUser);
      for (var b in rejected) allIds.add(b.idUser);

      Map<String, AppUser> userMap = {};
      if (allIds.isNotEmpty) {
        userMap = await _service.getUsersByIds(allIds.toList());
      }

      setState(() {
        _pending = pending;
        _approved = approved;
        _rejected = rejected;
        _userCache = userMap;
        stats = {
          'pending': _pending.length,
          'approved': _approved.length,
          'rejected': _rejected.length,
          'total': _pending.length + _approved.length + _rejected.length,
        };
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: FadeTransition(
            opacity: _fadeController,
            child: Column(
              children: [
                _buildAppBar(),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: LinearProgressIndicator(),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(_error!, style: TextStyle(color: Colors.red)),
                  )
                else
                  _buildStatsCards(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPendingList(),     // pakai _pending
                      _buildApprovedList(),    // pakai _approved
                      _buildRejectedList(),    // pakai _rejected
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Navbar(userRole: 'admin', currentIndex: 0),
    );
  }

  Widget _buildAppBar() {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
          .animate(
            CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
          ),
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A90E2), Color(0xFF5B9FEE), Color(0xFF6BADFF)],
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade50,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kelola & Validasi Booking Lab',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                    Icons.notifications_active,
                    color: Colors.white,
                    size: 20,
                  ),
                      SizedBox(width: 5),
                      Text(
                        '3',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showLogoutDialog,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.logout,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Pending',
              stats['pending'].toString(),
              Icons.pending_actions,
              Colors.orange.shade400,
              Colors.orange.shade50,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Approved',
              stats['approved'].toString(),
              Icons.check_circle,
              Colors.green.shade400,
              Colors.green.shade50,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Rejected',
              stats['rejected'].toString(),
              Icons.cancel,
              Colors.red.shade400,
              Colors.red.shade50,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Total',
              stats['total'].toString(),
              Icons.analytics,
              Colors.blue.shade400,
              Colors.blue.shade50,
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
    Color bgColor,
  ) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 600),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double val, child) {
        return Transform.scale(scale: val, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade400, Colors.blue.shade300],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        tabs: const [
          Tab(
            child: SizedBox(width: 100, child: Center(child: Text('Pending'))),
          ),
          Tab(
            child: SizedBox(width: 100, child: Center(child: Text('Approved'))),
          ),
          Tab(
            child: SizedBox(width: 100, child: Center(child: Text('Rejected'))),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingList() {
    if (_pending.isEmpty && !_isLoading) {
      return _emptyState('Belum ada booking pending');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      itemCount: _pending.length,
      itemBuilder: (context, index) {
        final b = _pending[index];
        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 400 + (index * 80)),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (c, val, child) => Transform.translate(
            offset: Offset(50 * (1 - val), 0),
            child: Opacity(opacity: val, child: child),
          ),
          child: _buildPendingBookingCard(b),
        );
      },
    );
  }

  Widget _buildApprovedList() {
    if (_approved.isEmpty && !_isLoading) {
      return _emptyState('Belum ada booking disetujui');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _approved.length,
      itemBuilder: (context, i) => _buildApprovedCard(_approved[i]),
    );
  }

  Widget _buildRejectedList() {
    if (_rejected.isEmpty && !_isLoading) {
      return _emptyState('Belum ada booking ditolak');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _rejected.length,
      itemBuilder: (context, i) => _buildRejectedCard(_rejected[i]),
    );
  }

  Widget _emptyState(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 15),
            Text(msg, style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
          TextButton(onPressed: _loadAll, child: const Text('Refresh')),
        ],
      ),
    );
  }

// ADAPT: ubah card agar menerima BookingSlot bukan Map
  Widget _buildPendingBookingCard(BookingSlot b) {
    final labName = b.lab?.namaLab ?? 'Lab';
    final sesiName = b.sesi?.sesi ?? '';
    final dateStr = _formatDateIndo(b.tanggalBooking, full: true);
    final timeStr = b.sesi?.waktu.isNotEmpty == true ? b.sesi!.waktu : sesiName;
    final color = Colors.blue; // bisa dipilih berdasarkan lab / random
    final createdAt = b.createdAt ?? b.tanggalBooking;
    final diff = DateTime.now().difference(createdAt);
    final submittedAt = _relative(diff);
    final user = _userCache[b.idUser]; // idUser is non-nullable
    final userName = (user?.name.isNotEmpty == true) ? user!.name : '-';
    final nim = (user?.nim.isNotEmpty == true) ? user!.nim : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: color.withOpacity(0.15),
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text(userName,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800)),
                          const SizedBox(height: 4),
                            Text('NIM: $nim',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        b.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.computer, 'Lab', labName, Colors.blue),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.calendar_today, 'Tanggal', dateStr, Colors.green),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.access_time, 'Sesi', timeStr, Colors.orange),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.description,
                        'Keperluan',
                        b.keperluanKegiatan.isEmpty ? '-' : _truncate(b.keperluanKegiatan),
                        Colors.purple,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 5),
                    Text(
                      'Diajukan $submittedAt',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _showDetail(b),
                      child: const Text('Detail'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tombol aksi
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showRejectDialog(b),
                    child: _actionBtn(Icons.close, 'Tolak', Colors.red.shade600),
                  ),
                ),
                Container(width: 1, height: 50, color: Colors.grey.shade300),
                Expanded(
                  child: InkWell(
                    onTap: () => _showApproveDialog(b),
                    child: _actionBtn(Icons.check, 'Setujui', Colors.green.shade600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color iconColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800)),
            ],
          ),
        ),
      ],
    );
  }

  String _truncate(String text, {int max = 120}) {
    if (text.length <= max) return text;
    return text.substring(0, max).trim() + '…';
  }

  void _showDetail(BookingSlot b) {
    final user = _userCache[b.idUser];
    final userName = (user?.name.isNotEmpty == true) ? user!.name : '-';
    final nim = (user?.nim.isNotEmpty == true) ? user!.nim : '-';
    final labName = b.lab?.namaLab ?? '-';
    final sesiName = b.sesi?.sesi ?? '-';
    final waktu = b.sesi?.waktu ?? sesiName;
    final dateStr = _formatDateIndo(b.tanggalBooking, full: true);
    final createdAt = b.createdAt ?? b.tanggalBooking;
    final submittedAt = _relative(DateTime.now().difference(createdAt));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(ctx).padding.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    const Text(
                      'Detail Booking',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      b.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: b.isApproved
                            ? Colors.green.shade700
                            : b.isRejected
                                ? Colors.red.shade700
                                : Colors.orange.shade700,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.person, 'Nama', userName, Colors.blue),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.badge, 'NIM', nim, Colors.indigo),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.computer, 'Lab', labName, Colors.blue),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.calendar_today, 'Tanggal', dateStr, Colors.green),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.access_time, 'Sesi', waktu, Colors.orange),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.description, 'Keperluan', b.keperluanKegiatan.isEmpty ? '-' : b.keperluanKegiatan, Colors.purple),
                const SizedBox(height: 8),
                if (b.isRejected)
                  _buildInfoRow(
                    Icons.report,
                    'Alasan Penolakan',
                    (b.rejectReason != null && b.rejectReason!.trim().isNotEmpty)
                        ? b.rejectReason!
                        : '-',
                    Colors.red,
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 5),
                    Text(
                      'Diajukan $submittedAt',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  String _relative(Duration d) {
    if (d.inMinutes < 1) return 'baru saja';
    if (d.inMinutes < 60) return '${d.inMinutes} menit yang lalu';
    if (d.inHours < 24) return '${d.inHours} jam yang lalu';
    return '${d.inDays} hari yang lalu';
  }

  // Safe Indonesian date formatter with fallback if locale not initialized
  String _formatDateIndo(DateTime dt, {bool full = false}) {
    try {
      final pattern = full ? 'd MMMM yyyy' : 'd MMM yyyy';
      // Use intl DateFormat only if available
      return DateFormat(pattern, 'id_ID').format(dt);
    } catch (e) {
      // Fallback: manual mapping month
      const monthsFull = [
        'Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember'
      ];
      const monthsShort = [
        'Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'
      ];
      final mIndex = dt.month - 1;
      final monthStr = full ? monthsFull[mIndex] : monthsShort[mIndex];
      return '${dt.day} $monthStr ${dt.year}';
    }
  }

// Approved & Rejected card adaptasi
  Widget _buildApprovedCard(BookingSlot b) {
    // Samakan tampilan dengan card Pending, tanpa tombol aksi
    final labName = b.lab?.namaLab ?? 'Lab';
    final sesiName = b.sesi?.sesi ?? '';
    final dateStr = _formatDateIndo(b.tanggalBooking, full: true);
    final timeStr = b.sesi?.waktu.isNotEmpty == true ? b.sesi!.waktu : sesiName;
    final color = Colors.green; // warna aksen untuk approved
    final createdAt = b.createdAt ?? b.tanggalBooking;
    final diff = DateTime.now().difference(createdAt);
    final submittedAt = _relative(diff);
    final user = _userCache[b.idUser];
    final userName = (user?.name.isNotEmpty == true) ? user!.name : '-';
    final nim = (user?.nim.isNotEmpty == true) ? user!.nim : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(Icons.check_circle, color: color, size: 26),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800)),
                      const SizedBox(height: 4),
                      Text('NIM: $nim',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Approved',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.computer, 'Lab', labName, Colors.blue),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.calendar_today, 'Tanggal', dateStr, Colors.green),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.access_time, 'Sesi', timeStr, Colors.orange),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.description,
                        'Keperluan',
                        b.keperluanKegiatan.isEmpty ? '-' : _truncate(b.keperluanKegiatan),
                        Colors.purple,
                      ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 5),
                Text(
                  'Diajukan $submittedAt',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _showDetail(b),
                      child: const Text('Detail'),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedCard(BookingSlot b) {
    // Samakan tampilan dengan card Pending, tanpa tombol aksi
    final labName = b.lab?.namaLab ?? 'Lab';
    final sesiName = b.sesi?.sesi ?? '';
    final dateStr = _formatDateIndo(b.tanggalBooking, full: true);
    final timeStr = b.sesi?.waktu.isNotEmpty == true ? b.sesi!.waktu : sesiName;
    final color = Colors.red; // warna aksen untuk rejected
    final createdAt = b.createdAt ?? b.tanggalBooking;
    final diff = DateTime.now().difference(createdAt);
    final submittedAt = _relative(diff);
    final user = _userCache[b.idUser];
    final userName = (user?.name.isNotEmpty == true) ? user!.name : '-';
    final nim = (user?.nim.isNotEmpty == true) ? user!.nim : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(Icons.cancel, color: color, size: 26),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800)),
                      const SizedBox(height: 4),
                      Text('NIM: $nim',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Rejected',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.computer, 'Lab', labName, Colors.blue),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.calendar_today, 'Tanggal', dateStr, Colors.green),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.access_time, 'Sesi', timeStr, Colors.orange),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.description,
                        'Keperluan',
                        b.keperluanKegiatan.isEmpty ? '-' : _truncate(b.keperluanKegiatan),
                        Colors.purple,
                      ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 5),
                Text(
                  'Diajukan $submittedAt',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _showDetail(b),
                      child: const Text('Detail'),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

// Dialog approve / reject modifikasi
  void _showApproveDialog(BookingSlot b) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.check_circle, color: Colors.green.shade600),
            ),
            const SizedBox(width: 12),
            const Text('Setujui Booking?'),
          ],
        ),
        content: Builder(builder: (context) {
          final user = _userCache[b.idUser];
          final userName = (user?.name.isNotEmpty == true) ? user!.name : '-';
          final nim = (user?.nim.isNotEmpty == true) ? user!.nim : '-';
          return Text('$userName\nNIM: $nim\n${b.lab?.namaLab} • ${b.sesi?.waktu} • ${_formatDateIndo(b.tanggalBooking)}');
        }),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await _service.updateBookingStatus(b.id, 'approved');
              if (ok) {
                _showSuccessSnackbar('Booking disetujui');
                _loadAll();
              } else {
                _showErrorSnackbar('Gagal update status');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BookingSlot b) {
    final controller = TextEditingController();
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
              child: Icon(Icons.cancel, color: Colors.red.shade600),
            ),
            const SizedBox(width: 12),
            const Text('Tolak Booking?'),
          ],
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Alasan penolakan (opsional)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await _service.updateBookingStatus(b.id, 'rejected');
              // (opsional) simpan alasan ke field 'rejectReason'
              if (ok) {
                if (controller.text.trim().isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('bookingSlots')
                      .doc(b.id)
                      .update({'rejectReason': controller.text.trim()});
                }
                _showSuccessSnackbar('Booking ditolak');
                _loadAll();
              } else {
                _showErrorSnackbar('Gagal update status');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('Tolak'),
          ),
        ],
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

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 10),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.logout, color: Colors.orange.shade600),
            ),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari dashboard admin?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/');
              _showSuccessSnackbar('Berhasil logout');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
