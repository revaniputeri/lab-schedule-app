# SIBOJI - Sistem Booking Lab JTI

![Siboji](https://i.imghippo.com/files/fb5933vc.png)

## 📖 Deskripsi Aplikasi

**SIBOJI (Sistem Booking Lab JTI)** merupakan proyek Project Based Learning (PBL) yang dikembangkan untuk membantu pengelolaan pemesanan dan penjadwalan laboratorium di Jurusan Teknologi Informasi secara terpusat dan real-time. 

Aplikasi ini dibuat berbasis mobile menggunakan **Flutter** dengan **Firebase** sebagai backend untuk mengatasi permasalahan penjadwalan manual, seperti:
- Double booking
- Kurangnya transparansi ketersediaan laboratorium
- Proses administrasi yang tidak efisien

### 👥 Peran Pengguna

SIBOJI mendukung beberapa peran pengguna:
- **Mahasiswa/Dosen**: Pengguna yang melakukan booking laboratorium
- **Admin/Ketua Lab**: Pengelola jadwal dan validasi pemesanan

### ✨ Fitur Utama

- ✅ Autentikasi berbasis role (mahasiswa, dosen, admin, asisten lab)
- 📅 Tampilan kalender interaktif untuk melihat ketersediaan lab
- 🔖 Pemesanan slot laboratorium dengan mudah
- ⚠️ Validasi bentrokan jadwal secara otomatis
- 🔔 Notifikasi status booking real-time
- 📊 Dashboard pengelolaan untuk admin

Dengan adanya sistem ini, diharapkan proses pemanfaatan laboratorium menjadi lebih tertib, efisien, dan transparan, serta mampu meningkatkan optimalisasi penggunaan fasilitas laboratorium di lingkungan kampus.

---

## 🚀 Instalasi Flutter

### 1. Download Flutter SDK

Unduh Flutter SDK sesuai sistem operasi Anda:

**Windows:**
```bash
# Download dari: https://docs.flutter.dev/get-started/install/windows
# Atau gunakan Git
git clone https://github.com/flutter/flutter.git -b stable
```

**macOS:**
```bash
# Download dari: https://docs.flutter.dev/get-started/install/macos
# Atau gunakan Git
git clone https://github.com/flutter/flutter.git -b stable
```

**Linux:**
```bash
# Download dari: https://docs.flutter.dev/get-started/install/linux
# Atau gunakan Git
git clone https://github.com/flutter/flutter.git -b stable
```

### 2. Tambahkan Flutter ke PATH

**Windows:**
- Cari "Environment Variables" di Start Menu
- Edit PATH dan tambahkan lokasi folder `flutter\bin`

**macOS/Linux:**
```bash
# Tambahkan ke ~/.bashrc atau ~/.zshrc
export PATH="$PATH:`pwd`/flutter/bin"

# Reload terminal
source ~/.bashrc  # atau source ~/.zshrc
```

### 3. Verifikasi Instalasi

```bash
flutter --version
flutter doctor
```

Perintah `flutter doctor` akan menampilkan status instalasi dan dependensi yang diperlukan.

### 4. Install Dependensi Tambahan

**Android Development:**
- Install [Android Studio](https://developer.android.com/studio)
- Install Android SDK dan emulator melalui Android Studio

**iOS Development (hanya macOS):**
- Install [Xcode](https://apps.apple.com/us/app/xcode/id497799835) dari App Store
- Jalankan: `sudo xcodebuild -license accept`

### 5. Setup Editor

**Visual Studio Code:**
```bash
# Install extension Flutter dan Dart
code --install-extension Dart-Code.flutter
code --install-extension Dart-Code.dart-code
```

**Android Studio:**
- Install plugin Flutter dan Dart dari Settings > Plugins

---

## 📱 Cara Menjalankan Aplikasi SIBOJI

### 1. Clone Repository

```bash
git clone https://github.com/revaniputeri/lab-schedule-app
cd lab-schedule-app
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Konfigurasi Firebase

1. Buat project baru di [Firebase Console](https://console.firebase.google.com/)
2. Download file konfigurasi:
   - **Android**: `google-services.json` → letakkan di `android/app/`
   - **iOS**: `GoogleService-Info.plist` → letakkan di `ios/Runner/`
3. Aktifkan Firebase Authentication dan Firestore di console

### 4. Jalankan Aplikasi

**Menggunakan Emulator/Simulator:**
```bash
# Cek device yang tersedia
flutter devices

# Jalankan aplikasi
flutter run
```

**Menggunakan Device Fisik:**
1. Aktifkan USB Debugging (Android) atau Trust Computer (iOS)
2. Hubungkan device ke komputer
3. Jalankan `flutter run`

**Mode Release (untuk testing performa):**
```bash
flutter run --release
```

### 5. Build APK/IPA

**Android (APK):**
```bash
# Build APK
flutter build apk --release

# Build App Bundle (untuk Google Play Store)
flutter build appbundle --release
```

**iOS (hanya macOS):**
```bash
flutter build ios --release
```

File hasil build akan tersimpan di:
- APK: `build/app/outputs/flutter-apk/`
- App Bundle: `build/app/outputs/bundle/release/`
- iOS: `build/ios/iphoneos/`

---

## 🛠️ Troubleshooting

### Error: "Unable to locate Android SDK"
```bash
flutter config --android-sdk /path/to/android/sdk
```

### Error: "CocoaPods not installed" (macOS)
```bash
sudo gem install cocoapods
pod setup
```

### Error: "Gradle build failed"
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### Hot Reload tidak berfungsi
```bash
# Restart aplikasi dengan
r  # hot reload
R  # hot restart
```

---

## 📚 Dokumentasi

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)

---

## 👨‍💻 Tim Pengembang

Proyek ini dikembangkan sebagai bagian dari Project Based Learning (PBL) Jurusan Teknologi Informasi dan dikerjakan oleh Kelompok 5 Kelas SIB - 3D.
