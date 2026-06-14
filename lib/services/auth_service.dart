import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Giriş durumunu dinleyen stream
  Stream<User?> get authStateChanges => _auth.userChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithGoogle() async {
    // 1. Google hesap seçiciyi aç
    final GoogleSignInAccount googleUser = await GoogleSignIn.instance
        .authenticate();

    // 2. Firebase için gerekli token
    final idToken = googleUser.authentication.idToken;

    // 3. Firebase kimlik bilgisi oluştur
    final credential = GoogleAuthProvider.credential(idToken: idToken);

    // 4. Firebase'e giriş yap
    return await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}
