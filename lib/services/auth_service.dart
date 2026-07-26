import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;

  Stream<User?> get authStateChanges => _auth.userChanges();
  User? get currentUser => _auth.currentUser;

  // 🚨 YENİ: main.dart'tan bir kez çağrılır, hem web hem mobilde
  // giriş tamamlandığında bu dinleyici Firebase'e bağlar.
  void listenGoogleAuthEvents() {
    _authSub ??= GoogleSignIn.instance.authenticationEvents.listen(
      (event) async {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          final idToken = event.user.authentication.idToken;
          final credential = GoogleAuthProvider.credential(idToken: idToken);
          await _auth.signInWithCredential(credential);
        }
      },
      onError: (Object e) {
        // İstersen buraya ErrorHandlerService çağrısı ekleyebilirsin
      },
    );
  }

  // Mobil/desktop'ta doğrudan popup açar.
  // Web'de bu metod çağrılmaz — orada kullanıcı renderButton()'a tıklar.
  Future<void> signInWithGoogle() async {
    if (GoogleSignIn.instance.supportsAuthenticate()) {
      await GoogleSignIn.instance.authenticate();
      // Sonuç yukarıdaki authenticationEvents dinleyicisi tarafından işlenir.
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}
