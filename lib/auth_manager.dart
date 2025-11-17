import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_model.dart';

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
      print('🔵 Starting Google Sign In...');
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('❌ Google sign in cancelled');
        return null;
      }

      print('✅ Google user: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      print('✅ Firebase sign in successful: ${userCredential.user?.email}');
      
      await _saveUserLocally(userCredential.user!);
      return userCredential;
    } catch (e) {
      print('❌ Google sign in error: $e');
      rethrow;
    }
  }

  // MARK: - Apple Sign In
  Future<UserCredential?> signInWithApple() async {
    try {
      print('🍎 Starting Apple Sign In...');
      
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
      print('✅ Apple sign in successful: ${userCredential.user?.email}');
      
      await _saveUserLocally(userCredential.user!);
      return userCredential;
    } catch (e) {
      print('❌ Apple sign in error: $e');
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
      await _saveUserLocally(userCredential.user!);
      return userCredential;
    } catch (e) {
      print('❌ Email sign in error: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _saveUserLocally(userCredential.user!);
      return userCredential;
    } catch (e) {
      print('❌ Email sign up error: $e');
      rethrow;
    }
  }

  // MARK: - Sign Out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      await _clearUserLocally();
      print('✅ Sign out successful');
    } catch (e) {
      print('❌ Sign out error: $e');
      rethrow;
    }
  }

  // MARK: - Local Storage
  Future<void> _saveUserLocally(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('uid', user.uid);
    await prefs.setString('email', user.email ?? '');
    await prefs.setString('displayName', user.displayName ?? '');
    await prefs.setString('photoURL', user.photoURL ?? '');
  }

  Future<void> _clearUserLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('uid');
    await prefs.remove('email');
    await prefs.remove('displayName');
    await prefs.remove('photoURL');
  }

  Future<UserModel?> getLocalUser() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid');
    
    if (uid == null) return null;

    return UserModel(
      uid: uid,
      email: prefs.getString('email') ?? '',
      displayName: prefs.getString('displayName'),
      photoURL: prefs.getString('photoURL'),
      createdAt: DateTime.now(),
    );
  }
}
