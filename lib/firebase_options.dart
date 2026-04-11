import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web is not supported.');
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        ),
    };
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDI1d8rVZcT7VF6hTKcTHo6B3Mh7CA4gtM',
    appId: '1:751857864758:android:1b6e3d9819ffd71815c897',
    messagingSenderId: '751857864758',
    projectId: 'gfmapp',
    storageBucket: 'gfmapp.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCo90oTe9M7epgLatpmXocug9KetttKErc',
    appId: '1:751857864758:ios:9d303acdaadb578615c897',
    messagingSenderId: '751857864758',
    projectId: 'gfmapp',
    storageBucket: 'gfmapp.firebasestorage.app',
    iosClientId: '751857864758-cp1hfid31ngifhtq9lk38utpjlmr22s3.apps.googleusercontent.com',
    iosBundleId: 'com.app.gfm',
  );
}
