class Sesi {
  final String id;
  final String sesi;              // "Sesi 1", "Sesi 2", dll
  final String waktu;             // "08.00 - 10.00" atau "11.30 - 13.00"

  Sesi({
    required this.id,
    required this.sesi,
    required this.waktu,
  });

  factory Sesi.fromMap(Map<String, dynamic> map, String id) {
    return Sesi(
      id: id,
      sesi: map['sesi'] ?? '',
      waktu: map['waktu'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sesi': sesi,
      'waktu': waktu,
    };
  }

  // Helper untuk parsing waktu
  List<String> get waktuParts {
    // Parse "08.00 - 10.00" menjadi ["08.00", "10.00"]
    try {
      return waktu.split(' - ').map((e) => e.trim()).toList();
    } catch (e) {
      return ['', ''];
    }
  }

  String get startTime {
    try {
      return waktuParts.first;
    } catch (e) {
      return '';
    }
  }

  String get endTime {
    try {
      return waktuParts.last;
    } catch (e) {
      return '';
    }
  }

  // Helper untuk mendapatkan order dari nama sesi
  int get order {
    try {
      final match = RegExp(r'\d+').firstMatch(sesi);
      return match != null ? int.tryParse(match.group(0) ?? '0') ?? 0 : 0;
    } catch (e) {
      return 0;
    }
  }

  // Display name
  String get displayName => '$sesi ($waktu)';
}