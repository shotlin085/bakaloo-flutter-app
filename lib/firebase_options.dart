import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only configured for Android and iOS.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBp4byrUr8x6Rl66ANboNZfxnzUhlFMrI4',
    appId: '1:268417469016:android:487039928a41d18710582d',
    messagingSenderId: '268417469016',
    projectId: 'grocery-shotlin',
    storageBucket: 'grocery-shotlin.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBJJqvLI-10Smy4kp3OwPX0Ooi46PFhOR8',
    appId: '1:802646854363:ios:e903b3cfb80476f6665afe',
    messagingSenderId: '802646854363',
    projectId: 'bakaloo',
    storageBucket: 'bakaloo.firebasestorage.app',
    iosBundleId: 'com.bakaloo.bakalooFlutterApp',
  );
}
