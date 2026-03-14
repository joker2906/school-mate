class FirebaseOptions {
  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String? storageBucket;

  const FirebaseOptions({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    this.storageBucket,
  });
}

class Firebase {
  static Future<void> initializeApp({FirebaseOptions? options}) async {
    // No-op for FastAPI backend mode.
  }
}
