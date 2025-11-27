enum DateStatus {
  available,      // Semua sesi tersedia (hijau)
  partial,        // Beberapa sesi terisi (kuning)
  unavailable,    // Semua sesi terisi (merah)
  past,           // Tanggal sudah lewat (abu-abu)
}

class DateAvailability {
  final DateTime date;
  final DateStatus status;
  final int totalSesi;
  final int bookedSesi;
  final List<String> availableSesiIds;
  final List<String> bookedSesiIds;

  DateAvailability({
    required this.date,
    required this.status,
    required this.totalSesi,
    required this.bookedSesi,
    required this.availableSesiIds,
    required this.bookedSesiIds,
  });

  int get availableSesi => totalSesi - bookedSesi;
  
  bool get isAvailable => status == DateStatus.available || status == DateStatus.partial;
  
  bool get isPast => status == DateStatus.past;
}