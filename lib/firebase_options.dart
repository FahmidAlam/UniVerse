// File generated to mirror `flutterfire configure` output.
// Values sourced from android/app/google-services.json (project universe-e1a60).
// UniVerse is Android-only, so only the Android platform is configured.
// ignore_for_file: type=lint
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
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'this app targets Android only.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only configured for Android - '
          'received: $defaultTargetPlatform',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBcEk63pMGNEVCZ8O7Ftc6KfuYe0Q_tFac',
    appId: '1:336302188092:android:2ec9294ce4175fbecc8539',
    messagingSenderId: '336302188092',
    projectId: 'universe-e1a60',
    storageBucket: 'universe-e1a60.firebasestorage.app',
  );
}
