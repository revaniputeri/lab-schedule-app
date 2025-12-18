import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jadwal_lab/widgets/navbar.dart';

class LabManagementPage extends StatefulWidget {
  const LabManagementPage({Key? key}) : super(key: key);

  @override
  State<LabManagementPage> createState() => _LabManagementPageState();
}

class _LabManagementPageState extends State<LabManagementPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  
  Map<String, dynamic>? _myLab;
  bool _isLoading = false;
  String? _error;
  String? _debugInfo; // Untuk debugging

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

    _loadMyLab();
  }

  Future<void> _loadMyLab() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _debugInfo = null;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _error = 'User tidak terautentikasi';
        });
        return;
      }

      print('🔍 Current User ID: ${currentUser.uid}');

      // Ambil data user untuk mendapatkan labId
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      
      if (!userDoc.exists) {
        setState(() {
          _error = 'Data user tidak ditemukan';
          _debugInfo = 'User ID: ${currentUser.uid} tidak ada di collection users';
        });
        return;
      }

      final userData = userDoc.data();
      print('📄 User Data: $userData');
      
      final labId = userData?['labId'];
      print('🏢 Lab ID from user: $labId (Type: ${labId.runtimeType})');

      if (labId == null || labId.toString().trim().isEmpty) {
        setState(() {
          _error = 'Admin belum memiliki lab yang ditugaskan';
          _debugInfo = 'Field labId kosong atau null pada user ${currentUser.uid}';
        });
        return;
      }

      // Konversi labId ke string dan trim whitespace
      final labIdString = labId.toString().trim();
      print('🔑 Mencari lab dengan ID: "$labIdString"');

      // Ambil data lab berdasarkan labId
      final labDoc = await _firestore
          .collection('laboratorium')
          .doc(labIdString)
          .get();
      
      print('📋 Lab Doc exists: ${labDoc.exists}');
      
      if (!labDoc.exists) {
        // Coba cari dengan query jika document ID tidak cocok
        print('⚠️ Document tidak ditemukan, mencoba dengan query...');
        
        final querySnapshot = await _firestore
            .collection('laboratorium')
            .where(FieldPath.documentId, isEqualTo: labIdString)
            .get();
            
        if (querySnapshot.docs.isEmpty) {
          setState(() {
            _error = 'Lab tidak ditemukan';
            _debugInfo = 'Lab ID "$labIdString" tidak ada di collection laboratorium';
          });
          return;
        }
        
        // Gunakan hasil query
        final labDocFromQuery = querySnapshot.docs.first;
        setState(() {
          _myLab = {
            'id': labDocFromQuery.id,
            ...labDocFromQuery.data(),
          };
        });
        print('✅ Lab ditemukan via query: ${_myLab!['namaLab']}');
        return;
      }

      final labData = labDoc.data();
      print('📊 Lab Data: $labData');

      setState(() {
        _myLab = {
          'id': labDoc.id,
          ...labData!,
        };
      });
      print('✅ Lab berhasil dimuat: ${_myLab!['namaLab']}');
      
    } catch (e, stackTrace) {
      print('❌ Error loading lab: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _error = 'Gagal memuat data lab';
        _debugInfo = 'Error: $e';
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
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_error != null)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 80,
                              color: Colors.red.shade300,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_debugInfo != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  'Debug Info:\n$_debugInfo',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _loadMyLab,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Coba Lagi'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (_myLab == null)
                  Expanded(
                    child: _buildEmptyState(),
                  )
                else
                  Expanded(
                    child: _buildLabDetail(),
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
                Icons.computer,
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
                    'Kelola Lab Saya',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _myLab != null 
                        ? 'Edit ${_myLab!['namaLab'] ?? 'Lab'}' 
                        : 'Memuat data...',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            if (_myLab != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Lab Aktif',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.computer_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          Text(
            'Belum ada lab',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _loadMyLab,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildLabDetail() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: TweenAnimationBuilder(
        duration: Duration(milliseconds: 400),
        tween: Tween<double>(begin: 0, end: 1),
        builder: (c, val, child) => Transform.translate(
          offset: Offset(50 * (1 - val), 0),
          child: Opacity(opacity: val, child: child),
        ),
        child: _buildLabCard(_myLab!),
      ),
    );
  }

  Widget _buildLabCard(Map<String, dynamic> lab) {
    final labName = lab['namaLab'] ?? 'Lab';
    final facilities = List<String>.from(lab['fasilitas'] ?? []);
    final kapasitas = lab['kapasitasLab']?.toString() ?? '-';
    final lokasi = lab['lokasiLab'] ?? '-';
    final color = Colors.blue;

    return Container(
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.computer,
                        color: color,
                        size: 32,
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
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.location_on, 
                                size: 16, 
                                color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  lokasi,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 20),
                // Info Kapasitas
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people, 
                        size: 24, 
                        color: Colors.blue.shade600),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kapasitas Lab',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$kapasitas Orang',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Fasilitas Section
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 20,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Fasilitas Tersedia',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${facilities.length} Item',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (facilities.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined, 
                            size: 40, 
                            color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'Belum ada fasilitas',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: facilities.map((facility) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: color.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: color.shade700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                facility,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: color.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: InkWell(
              onTap: () => _showEditLabDialog(lab),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit, color: Colors.blue.shade600, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Edit Informasi Lab',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditLabDialog(Map<String, dynamic> lab) {
    final nameController = TextEditingController(text: lab['namaLab']);
    final kapasitasController = TextEditingController(
      text: lab['kapasitasLab']?.toString() ?? ''
    );
    final lokasiController = TextEditingController(text: lab['lokasiLab']);
    final facilityController = TextEditingController();
    List<String> facilities = List<String>.from(lab['fasilitas'] ?? []);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.edit, color: Colors.blue.shade600),
              ),
              const SizedBox(width: 12),
              const Text('Edit Lab'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Lab',
                    prefixIcon: const Icon(Icons.computer),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lokasiController,
                  decoration: InputDecoration(
                    labelText: 'Lokasi Lab',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: kapasitasController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Kapasitas Lab',
                    prefixIcon: const Icon(Icons.people),
                    suffixText: 'orang',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text(
                  'Fasilitas:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                if (facilities.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: facilities.map((f) {
                        return Chip(
                          label: Text(f, style: TextStyle(fontSize: 12)),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            setDialogState(() {
                              facilities.remove(f);
                            });
                          },
                          backgroundColor: Colors.blue.shade50,
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: facilityController,
                        decoration: InputDecoration(
                          labelText: 'Tambah Fasilitas',
                          prefixIcon: const Icon(Icons.add_circle_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            setDialogState(() {
                              facilities.add(value.trim());
                              facilityController.clear();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        onPressed: () {
                          if (facilityController.text.trim().isNotEmpty) {
                            setDialogState(() {
                              facilities.add(facilityController.text.trim());
                              facilityController.clear();
                            });
                          }
                        },
                        icon: Icon(Icons.add, color: Colors.blue.shade600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tekan Enter atau tombol + untuk menambah fasilitas',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal', style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  _showErrorSnackbar('Nama lab tidak boleh kosong');
                  return;
                }
                
                Navigator.pop(context);
                
                try {
                  final updateData = {
                    'namaLab': nameController.text.trim(),
                    'lokasiLab': lokasiController.text.trim(),
                    'fasilitas': facilities,
                    'updatedAt': DateTime.now(),
                  };
                  
                  // Only update kapasitasLab if valid number
                  final kapasitasStr = kapasitasController.text.trim();
                  if (kapasitasStr.isNotEmpty) {
                    final kapasitas = int.tryParse(kapasitasStr);
                    if (kapasitas != null) {
                      updateData['kapasitasLab'] = kapasitas;
                    }
                  }
                  
                  await _firestore.collection('laboratorium').doc(lab['id']).update(updateData);
                  _showSuccessSnackbar('Lab berhasil diperbarui');
                  _loadMyLab();
                } catch (e) {
                  _showErrorSnackbar('Gagal memperbarui lab: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Simpan Perubahan'),
            ),
          ],
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
}