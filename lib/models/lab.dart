class Lab {
  final String id;
  final String namaLab;           // Sesuai dengan field di Firebase
  final String lokasiLab;         // Lokasi lab
  final int kapasitasLab;         // Kapasitas lab
  final String? fotoUrl;          // URL foto lab (opsional)
  final List<String>? fasilitas;  // List fasilitas lab

  Lab({
    required this.id,
    required this.namaLab,
    required this.lokasiLab,
    required this.kapasitasLab,
    this.fotoUrl,
    this.fasilitas,
  });

  factory Lab.fromMap(Map<String, dynamic> map, String id) {
    return Lab(
      id: id,
      namaLab: map['namaLab'] ?? '',
      lokasiLab: map['lokasiLab'] ?? '',
      kapasitasLab: int.tryParse(map['kapasitasLab']?.toString() ?? '0') ?? 0,
      fotoUrl: map['fotoUrl'],
      fasilitas: map['fasilitas'] != null 
          ? List<String>.from(map['fasilitas'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'namaLab': namaLab,
      'lokasiLab': lokasiLab,
      'kapasitasLab': kapasitasLab.toString(),
      'fotoUrl': fotoUrl,
      'fasilitas': fasilitas,
    };
  }

  // Helper untuk display name
  String get displayName => namaLab;
  
  // Helper untuk display kapasitas
  String get kapasitasText => 'Kapasitas $kapasitasLab Orang';
}