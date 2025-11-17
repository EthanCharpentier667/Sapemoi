import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAs_sabDrdbUosK_6LLDYqDLaezWMJmKTw',
    appId: '1:136016577830:android:d6497b65842386c1566de7',
    messagingSenderId: '136016577830',
    projectId: 'sapemoi-f5c9e',
    storageBucket: 'sapemoi-f5c9e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAfsd9sq3-5LPp4jMtikGxQGZYa9O5CYMg',
    appId: '1:136016577830:ios:d77250c6ad8db297566de7',
    messagingSenderId: '136016577830',
    projectId: 'sapemoi-f5c9e',
    storageBucket: 'sapemoi-f5c9e.firebasestorage.app',
    iosBundleId: 'com.example.sapemoi',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAotY7vHUzjNZqPrbp0Ft-DFJMbqJLgL2U',
    appId: '1:136016577830:web:5087230207d7d9e2566de7',
    messagingSenderId: '136016577830',
    projectId: 'sapemoi-f5c9e',
    authDomain: 'sapemoi-f5c9e.firebaseapp.com',
    storageBucket: 'sapemoi-f5c9e.firebasestorage.app',
  );

}