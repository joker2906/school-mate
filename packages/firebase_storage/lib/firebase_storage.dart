import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

class FirebaseException implements Exception {
  final String code;
  final String? message;

  FirebaseException({required this.code, this.message});

  @override
  String toString() => message ?? code;
}

class TaskSnapshot {
  final Reference ref;

  TaskSnapshot(this.ref);
}

typedef UploadTask = Future<TaskSnapshot>;

class FirebaseStorage {
  FirebaseStorage._();

  static final FirebaseStorage instance = FirebaseStorage._();

  Reference ref([String? path = '']) => Reference(path);
}

class Reference {
  final String _path;

  Reference(String? path) : _path = _normalize(path ?? '');

  Reference child(String childPath) {
    if (_path.isEmpty) {
      return Reference(childPath);
    }
    return Reference('$_path/$childPath');
  }

  UploadTask putFile(File file) async {
    await _uploadBytes(await file.readAsBytes());
    return TaskSnapshot(this);
  }

  UploadTask putData(Uint8List data) async {
    await _uploadBytes(data);
    return TaskSnapshot(this);
  }

  Future<String> getDownloadURL() async {
    final client = HttpClient();
    client.connectionTimeout = _requestTimeout;
    try {
      final uri = Uri.parse(
        '${_defaultBaseUrl()}/storage/url?destination=${Uri.encodeComponent(_path)}',
      );
      final req = await client.getUrl(uri).timeout(_requestTimeout);
      final res = await req.close().timeout(_requestTimeout);
      final text = await utf8.decodeStream(res).timeout(_requestTimeout);
      final json = (jsonDecode(text) as Map).cast<String, dynamic>();
      if (res.statusCode >= 400) {
        throw FirebaseException(
          code: (json['detail'] ?? 'storage-error').toString(),
          message: (json['detail'] ?? 'storage-error').toString(),
        );
      }
      final url = json['url']?.toString() ?? '';
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return url;
      }
      return '${_defaultBaseUrl()}$url';
    } on TimeoutException {
      throw FirebaseException(
        code: 'network-timeout',
        message: _networkErrorMessage(),
      );
    } on SocketException {
      throw FirebaseException(
        code: 'network-error',
        message: _networkErrorMessage(),
      );
    } catch (e) {
      if (e is FirebaseException) rethrow;
      throw FirebaseException(code: 'network-error', message: e.toString());
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _uploadBytes(List<int> bytes) async {
    final boundary = '----schoolmate-${DateTime.now().microsecondsSinceEpoch}';
    final crlf = '\r\n';

    final client = HttpClient();
    client.connectionTimeout = _requestTimeout;
    try {
      final uri = Uri.parse('${_defaultBaseUrl()}/storage/upload?destination=${Uri.encodeComponent(_path)}');
      final req = await client.postUrl(uri).timeout(_requestTimeout);
      req.headers.set(HttpHeaders.contentTypeHeader, 'multipart/form-data; boundary=$boundary');

      final header = StringBuffer()
        ..write('--$boundary$crlf')
        ..write('Content-Disposition: form-data; name="file"; filename="upload.bin"$crlf')
        ..write('Content-Type: application/octet-stream$crlf$crlf');

      req.add(utf8.encode(header.toString()));
      req.add(bytes);
      req.add(utf8.encode('$crlf--$boundary--$crlf'));

      final res = await req.close().timeout(_requestTimeout);
      final text = await utf8.decodeStream(res).timeout(_requestTimeout);
      if (res.statusCode >= 400) {
        String msg = 'storage-upload-failed';
        try {
          final json = (jsonDecode(text) as Map).cast<String, dynamic>();
          msg = (json['detail'] ?? msg).toString();
        } catch (_) {}
        throw FirebaseException(code: 'upload-error', message: msg);
      }
    } on TimeoutException {
      throw FirebaseException(
        code: 'network-timeout',
        message: _networkErrorMessage(),
      );
    } on SocketException {
      throw FirebaseException(
        code: 'network-error',
        message: _networkErrorMessage(),
      );
    } catch (e) {
      if (e is FirebaseException) rethrow;
      throw FirebaseException(code: 'network-error', message: e.toString());
    } finally {
      client.close(force: true);
    }
  }

  static String _normalize(String path) {
    return path.trim().replaceAll('\\\\', '/').replaceAll(RegExp(r'^/+|/+$'), '');
  }
}
