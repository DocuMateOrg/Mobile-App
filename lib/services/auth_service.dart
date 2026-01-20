import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign Up [cite: 4, 219]
  Future<User?> signUp(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      return result.user;
    } catch (e) {
      print("Signup Error: $e");
      return null;
    }
  }

  // Login [cite: 4, 219]
  Future<User?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      return result.user;
    } catch (e) {
      print("Login Error: $e");
      return null;
    }
  }

  // Logout [cite: 219]
  Future<void> signOut() async {
    await _auth.signOut();
  }
}