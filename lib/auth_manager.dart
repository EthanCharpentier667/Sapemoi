import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'user_model.dart';
import 'network_manager.dart';

class AuthManager {
  static final AuthManager _instance = AuthManager._internal();
  factory AuthManager() => _instance;
  AuthManager._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // MARK: - Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      await _saveUserToRemote(userCredential.user!);
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // MARK: - Apple Sign In
  Future<UserCredential?> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      await _saveUserToRemote(userCredential.user!);
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // MARK: - Email/Password Sign In
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _saveUserToRemote(userCredential.user!);
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _saveUserToRemote(userCredential.user!);
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // MARK: - Sign Out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // MARK: - Remote-only user storage
  Future<void> _saveUserToRemote(User user) async {
    try {
      final userMap = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
        photoURL: user.photoURL,
        createdAt: DateTime.now(),
      ).toMap();
      await NetworkManager().upsertUser(userMap);
    } catch (e) {}
  }

  /// Returns the user model fetched from the remote API (no local cache).
  Future<UserModel?> getLocalUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    try {
      var remote = await NetworkManager().getUserRemote(firebaseUser.uid);
      if (remote == null) {
        await _saveUserToRemote(firebaseUser);
        remote = await NetworkManager().getUserRemote(firebaseUser.uid);
        if (remote == null) return null;
      }
      return UserModel.fromMap(remote);
    } catch (e) {
      return null;
    }
  }
}
