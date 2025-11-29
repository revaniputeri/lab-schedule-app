import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // LOGIN
  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      var userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        return userDoc.data();
      } else {
        throw Exception('Data user tidak ditemukan di Firestore');
      }
    } catch (e) {
      if (e is FirebaseAuthException) {
        throw Exception('Login gagal: ${e.code} | ${e.message}');
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
