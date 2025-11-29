import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // LOGIN
  Future<Map<String, dynamic>?> loginUser(String nim, String password) async {
    try {
      // Cari user berdasarkan NIM di Firestore
      var querySnapshot = await _firestore
          .collection('users')
          .where('nim', isEqualTo: nim)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('NIM tidak ditemukan');
      }

      var userData = querySnapshot.docs.first.data();
      String email = userData['email'];

      // Login dengan email yang ditemukan
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userData;
    } catch (e) {
      if (e is FirebaseAuthException) {
        if (e.code == 'wrong-password') {
          throw Exception('Password salah');
        } else if (e.code == 'user-not-found') {
          throw Exception('NIM tidak ditemukan');
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
}
