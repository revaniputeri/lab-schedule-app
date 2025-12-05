import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // LOGIN
  Future<Map<String, dynamic>?> loginUser(String username, String password) async {
    try {
      String email;
      Map<String, dynamic>? userData;

      // Cek apakah input adalah email (untuk admin)
      if (username.contains('@')) {
        // Login langsung dengan email
        email = username;
        
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Ambil data user dari Firestore
        var currentUser = _auth.currentUser;
        if (currentUser != null) {
          var userDoc = await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .get();
          
          if (userDoc.exists) {
            userData = userDoc.data();
          }
        }
      } else {
        // Input adalah NIM (untuk mahasiswa)
        // Cari user berdasarkan NIM di Firestore
        var querySnapshot = await _firestore
            .collection('users')
            .where('nim', isEqualTo: username)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          throw Exception('Username tidak ditemukan');
        }

        userData = querySnapshot.docs.first.data();
        email = userData['email'];

        // Login dengan email yang ditemukan
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      return userData;
    } catch (e) {
      if (e is FirebaseAuthException) {
        if (e.code == 'wrong-password') {
          throw Exception('Password salah');
        } else if (e.code == 'user-not-found') {
          throw Exception('Username tidak ditemukan');
        } else if (e.code == 'invalid-email') {
          throw Exception('Format email tidak valid');
        }
        throw Exception('Login gagal: ${e.message}');
      }
      throw Exception('Login gagal: $e');
    }
  }

  // REGISTER
  Future<void> registerUser(
    String name,
    String nim,
    String email,
    String password,
    String role,
  ) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'nim': nim,
        'email': email,
        'role': role, // "admin" atau "user"
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Registrasi gagal: $e');
    }
  }

  // RESET PASSWORD / LUPA PASSWORD
Future<bool> resetPassword(String email) async {
    try {
      // Kirim email reset password langsung via Firebase Auth
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('Email tidak terdaftar');
      } else if (e.code == 'invalid-email') {
        throw Exception('Format email tidak valid');
      } else if (e.code == 'missing-android-pkg-name' || 
                 e.code == 'missing-ios-bundle-id') {
        throw Exception('Aplikasi belum dikonfigurasi dengan benar');
      } else if (e.code == 'unauthorized-continue-uri') {
        throw Exception('URL redirect tidak diizinkan');
      } else if (e.code == 'invalid-continue-uri') {
        throw Exception('URL redirect tidak valid');
      } else if (e.code == 'missing-continue-uri') {
        throw Exception('URL redirect belum dikonfigurasi');
      }
      throw Exception('Reset password gagal: ${e.message}');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }
}