// File generated by FlutterFire CLI.
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
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB2ru_CZlwuE09EZOhlpocbS1VTZwaEK44',
    appId: '1:110328579030:web:47fd520d7a7578ff21da77',
    messagingSenderId: '110328579030',
    projectId: 'flutter-acf51',
    authDomain: 'flutter-acf51.firebaseapp.com',
    storageBucket: 'flutter-acf51.firebasestorage.app',
    measurementId: 'G-X8HNXGL8RN',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCbMLbui-fqI9k9d_KsgAcdNANCkb5FHaA',
    appId: '1:110328579030:android:ff1b057bd92c865521da77',
    messagingSenderId: '110328579030',
    projectId: 'flutter-acf51',
    storageBucket: 'flutter-acf51.firebasestorage.app',
  );
}
