import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase is not configured for web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'Firebase is not configured for $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDfyJlfSYpx6CKbXyzdSATKyN_RRsg0wuw',
    appId: '1:517356630866:android:96224e5cfaf247d8c1c08b',
    messagingSenderId: '517356630866',
    projectId: 'sk-live-1f547',
    storageBucket: 'sk-live-1f547.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDfyJlfSYpx6CKbXyzdSATKyN_RRsg0wuw',
    appId: '1:517356630866:ios:96224e5cfaf247d8c1c08b',
    messagingSenderId: '517356630866',
    projectId: 'sk-live-1f547',
    storageBucket: 'sk-live-1f547.firebasestorage.app',
    iosBundleId: 'com.sklive.app',
  );
}
