import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lab.dart';
import '../models/sesi.dart';
import '../services/firebase_service.dart';

class BookingFormPage extends StatefulWidget {
  final Lab lab;
  final DateTime selectedDate;

  const BookingFormPage({
    Key? key,
    required this.lab,
    required this.selectedDate,
  }) : super(key: key);

  @override
  State<BookingFormPage> createState() => _BookingFormPageState();
}

class _BookingFormPageState extends State<BookingFormPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _keperluanController = TextEditingController();

  List<Sesi> _allSesi = [];
  List<String> _bookedSesiIds = [];
  List<String> _selectedSesiIds = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  static const int _maxSesiSelection = 3;

  @override
  void initState() {
    super.initState();
    _loadSesiData();
  }

  Future<void> _loadSesiData() async {
    setState(() => _isLoading = true);

    try {
      _allSesi = await _firebaseService.getAllSesi();

      final bookings = await _firebaseService.getBookingsByLabAndDate(
        labId: widget.lab.id,
        date: widget.selectedDate,
      );

      _bookedSesiIds = bookings
          .where((b) => b.isApproved)
          .map((b) => b.idSesi)
          .toList();

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading sesi: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data sesi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isSesiBooked(String sesiId) {
    return _bookedSesiIds.contains(sesiId);
  }

  bool _isSesiPast(Sesi sesi) {
    final now = DateTime.now();
    final selectedDate = widget.selectedDate;

    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    if (selected.isBefore(today)) {
      return true;
    }

    if (selected.isAfter(today)) {
      return false;
    }

    final endTimeStr = sesi.endTime;
    final cleaned = endTimeStr.replaceAll('.', ':');
    final parts = cleaned.split(':');

    int hour = 0;
    int minute = 0;

    if (parts.isNotEmpty) {
      hour = int.tryParse(parts[0]) ?? 0;
    }
    if (parts.length > 1) {
      minute = int.tryParse(parts[1]) ?? 0;
    }

    final sesiEndTime = DateTime(
      selected.year,
      selected.month,
      selected.day,
      hour,
      minute,
    );

    return now.isAfter(sesiEndTime);
  }

  Future<void> _submitBooking() async {
    if (_selectedSesiIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal 1 sesi'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_keperluanController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deskripsi keperluan tidak boleh kosong'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      for (String sesiId in _selectedSesiIds) {
        final bookingData = {
          'idLab': widget.lab.id,
          'idSesi': sesiId,
          'keperluanKegiatan': _keperluanController.text.trim(),
          'status': 'Pending',
          'tanggalBooking': Timestamp.fromDate(widget.selectedDate),
          'createdAt': Timestamp.fromDate(DateTime.now()),
        };

        await FirebaseFirestore.instance
            .collection('bookingSlots')
            .add(bookingData);
      }

      setState(() => _isSubmitting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedSesiIds.length} booking berhasil dibuat!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat booking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'BUAT BOOKING',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateCard(),
                  const SizedBox(height: 16),
                  _buildLabCard(),
                  const SizedBox(height: 20),
                  _buildLabInfo(),
                  const SizedBox(height: 24),
                  _buildTimeSection(),
                  const SizedBox(height: 24),
                  _buildDescriptionSection(),
                  const SizedBox(height: 32),
                  _buildSubmitButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildDateCard() {
    final formattedDate = _formatDate(widget.selectedDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_today,
              color: Colors.blue.shade600,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tanggal Booking',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                formattedDate,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.computer, color: Colors.green.shade600, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nama Ruangan',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.lab.namaLab,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabInfo() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.lab.fotoUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Image.network(
                widget.lab.fotoUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholderImage();
                },
              ),
            )
          else
            _buildPlaceholderImage(),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fasilitas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildFasilitasList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            'Foto tidak tersedia',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildFasilitasList() {
    if (widget.lab.fasilitas == null || widget.lab.fasilitas!.isEmpty) {
      return Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            'Belum ada informasi fasilitas',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      );
    }

    return Column(
      children: [
        ...widget.lab.fasilitas!.map((fasilitas) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    fasilitas,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          );
        }).toList(),

        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.lab.kapasitasText,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeSection() {
    final selectedCount = _selectedSesiIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Waktu',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selectedCount >= _maxSesiSelection
                    ? Colors.red.shade50
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$selectedCount/$_maxSesiSelection dipilih',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: selectedCount >= _maxSesiSelection
                      ? Colors.red.shade700
                      : Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _allSesi.map((sesi) {
            final isBooked = _isSesiBooked(sesi.id);
            final isSelected = _selectedSesiIds.contains(sesi.id);
            final isPast = _isSesiPast(sesi);

            final canSelect =
                (!isPast && !isBooked) &&
                (selectedCount < _maxSesiSelection || isSelected);
            return GestureDetector(
              onTap: (!canSelect)
                  ? null
                  : () {
                      setState(() {
                        if (isSelected) {
                          _selectedSesiIds.remove(sesi.id);
                        } else if (_selectedSesiIds.length <
                            _maxSesiSelection) {
                          _selectedSesiIds.add(sesi.id);
                        }
                      });
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isBooked
                      ? Colors.grey.shade200
                      : isPast
                      ? Colors.grey.shade100
                      : isSelected
                      ? Colors.blue.shade600
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isBooked
                        ? Colors.grey.shade300
                        : isPast
                        ? Colors.grey.shade300
                        : isSelected
                        ? Colors.blue.shade600
                        : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),

                    Text(
                      sesi.waktu,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isBooked
                            ? Colors.grey.shade500
                            : isPast
                            ? Colors.grey.shade500
                            : isSelected
                            ? Colors.white
                            : Colors.grey.shade800,
                        decoration: isBooked || isPast
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Informasi Pemilihan Sesi',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '• Pilih minimal 1 sesi, maksimal $_maxSesiSelection sesi',
                style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
              ),
              Text(
                '• Sesi dicoret = sudah di-booking atau sudah lewat waktu',
                style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
              ),
              Text(
                '• Klik sesi untuk memilih atau membatalkan',
                style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Deskripsi Keperluan',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: _keperluanController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Deskripsikan Keperluan Anda',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final selectedCount = _selectedSesiIds.length;

    return Column(
      children: [
        if (selectedCount > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sesi yang Dipilih',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._selectedSesiIds.map((sesiId) {
                  final sesi = _allSesi.firstWhere((s) => s.id == sesiId);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${sesi.sesi}: ${sesi.waktu}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitBooking,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade400,
              disabledBackgroundColor: Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        selectedCount > 0
                            ? 'BUAT $selectedCount BOOKING'
                            : 'BUAT BOOKING',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final days = [
      'Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu',
    ];
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];

    final dayName = days[date.weekday % 7];
    final day = date.day;
    final monthName = months[date.month - 1];
    final year = date.year;

    return '$dayName, $day $monthName $year';
  }

  @override
  void dispose() {
    _keperluanController.dispose();
    super.dispose();
  }
}