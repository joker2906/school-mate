import 'dart:async';
import 'dart:convert';
import 'dart:io';

const Duration _requestTimeout = Duration(seconds: 12);

String _defaultBaseUrl() {
  const env = String.fromEnvironment('FASTAPI_BASE_URL', defaultValue: '');
  if (env.isNotEmpty) {
    return env;
  }
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://127.0.0.1:8000';
}

String _networkErrorMessage() {
  return 'Could not reach the SchoolMate server at ${_defaultBaseUrl()}. '
      'Make sure the backend is running and your device can access it.';
}

class FirebaseAuthException implements Exception {
  final String code;
  final String? message;

  FirebaseAuthException({required this.code, this.message});

  @override
  String toString() => message ?? code;
}

class User {
  final String uid;
  final String? email;

  User({required this.uid, this.email});
}

class UserCredential {
  final User? user;

  UserCredential({required this.user});
}

class AuthCredential {}

class FirebaseAuth {
  FirebaseAuth._();

  static final FirebaseAuth instance = FirebaseAuth._();

  User? _currentUser;
  String? _accessToken;

  User? get currentUser => _currentUser;
  String? get accessToken => _accessToken;

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final data = await _post('/auth/register', {
      'email': email,
      'password': password,
    });
    final user = User(uid: data['uid'] as String, email: data['email'] as String?);
    _currentUser = user;
    _accessToken = data['access_token']?.toString();
    return UserCredential(user: user);
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final data = await _post('/login', {
      'email': email,
      'password': password,
    });
    final user = User(uid: data['uid'] as String, email: data['email'] as String?);
    _currentUser = user;
    _accessToken = data['access_token']?.toString();
    return UserCredential(user: user);
  }

  Future<void> signOut() async {
    _currentUser = null;
    _accessToken = null;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final client = HttpClient();
    client.connectionTimeout = _requestTimeout;
    try {
      final uri = Uri.parse('${_defaultBaseUrl()}$path');
      final req = await client.postUrl(uri).timeout(_requestTimeout);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.write(jsonEncode(body));
      final res = await req.close().timeout(_requestTimeout);
      final text = await utf8.decodeStream(res).timeout(_requestTimeout);
      Map<String, dynamic> json = {};
      if (text.isNotEmpty) {
        json = (jsonDecode(text) as Map).cast<String, dynamic>();
      }
      if (res.statusCode >= 400) {
        throw FirebaseAuthException(
          code: (json['detail'] ?? 'auth-error').toString(),
          message: (json['detail'] ?? 'Authentication failed').toString(),
        );
      }
      return json;
    } on TimeoutException {
      throw FirebaseAuthException(
        code: 'network-timeout',
        message: _networkErrorMessage(),
      );
    } on SocketException {
      throw FirebaseAuthException(
        code: 'network-error',
        message: _networkErrorMessage(),
      );
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'network-error',
        message: e.toString(),
      );
    } finally {
      client.close(force: true);
    }
  }
}
