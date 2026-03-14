import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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

const Duration _requestTimeout = Duration(seconds: 12);

String _networkErrorMessage() {
  return 'Could not reach the SchoolMate server at ${_defaultBaseUrl()}. '
      'Make sure the backend is running and your device can access it.';
}

class FirestoreException implements Exception {
  final String code;
  final String? message;

  FirestoreException({required this.code, this.message});

  @override
  String toString() => message ?? code;
}

class Timestamp {
  final DateTime _value;

  Timestamp._(this._value);

  static Timestamp now() => Timestamp._(DateTime.now());

  static Timestamp fromDate(DateTime dt) => Timestamp._(dt);

  DateTime toDate() => _value;
}

class SetOptions {
  final bool merge;

  const SetOptions({this.merge = false});
}

class SnapshotOptions {
  const SnapshotOptions();
}

class FieldValue {
  static _FieldValueOp arrayUnion(List<dynamic> values) =>
      _FieldValueOp(op: 'arrayUnion', values: values);
}

class _FieldValueOp {
  final String op;
  final List<dynamic> values;

  _FieldValueOp({required this.op, required this.values});
}

class FirebaseFirestore {
  FirebaseFirestore._();

  static final FirebaseFirestore instance = FirebaseFirestore._();

  CollectionReference<Map<String, dynamic>> collection(String path) {
    return CollectionReference<Map<String, dynamic>>(_normalizePath(path));
  }

  CollectionReference<Map<String, dynamic>> collectionGroup(String path) {
    return CollectionReference<Map<String, dynamic>>(_normalizePath(path));
  }

  DocumentReference<Map<String, dynamic>> doc(String path) {
    final normalized = _normalizePath(path);
    final segments = normalized.split('/');
    if (segments.length < 2) {
      throw FirestoreException(
        code: 'invalid-document-path',
        message: 'Document path must include collection and id',
      );
    }
    final id = segments.removeLast();
    final collectionPath = segments.join('/');
    return DocumentReference<Map<String, dynamic>>(collectionPath, id);
  }
}

class Query<T extends Map<String, dynamic>> {
  final String collectionPath;
  final List<_Filter> _filters;
  final List<_OrderBy> _orderBy;
  final int? _limit;

  Query(
    this.collectionPath, {
    List<_Filter>? filters,
    List<_OrderBy>? orderBy,
    int? limit,
  })  : _filters = filters ?? [],
        _orderBy = orderBy ?? [],
        _limit = limit;

  Query<T> where(
    String field, {
    dynamic isEqualTo,
    List<dynamic>? whereIn,
    dynamic arrayContains,
    dynamic isNotEqualTo,
  }) {
    final next = List<_Filter>.from(_filters);
    if (isEqualTo != null) {
      next.add(_Filter(field: field, op: '==', value: isEqualTo));
    }
    if (whereIn != null) {
      next.add(_Filter(field: field, op: 'in', value: whereIn));
    }
    if (arrayContains != null) {
      next.add(_Filter(field: field, op: 'array_contains', value: arrayContains));
    }
    if (isNotEqualTo != null) {
      next.add(_Filter(field: field, op: '!=', value: isNotEqualTo));
    }
    return Query<T>(
      collectionPath,
      filters: next,
      orderBy: List<_OrderBy>.from(_orderBy),
      limit: _limit,
    );
  }

  Query<T> orderBy(String field, {bool descending = false}) {
    final next = List<_OrderBy>.from(_orderBy)
      ..add(_OrderBy(field: field, descending: descending));
    return Query<T>(
      collectionPath,
      filters: List<_Filter>.from(_filters),
      orderBy: next,
      limit: _limit,
    );
  }

  Query<T> limit(int count) {
    return Query<T>(
      collectionPath,
      filters: List<_Filter>.from(_filters),
      orderBy: List<_OrderBy>.from(_orderBy),
      limit: count,
    );
  }

  Future<QuerySnapshot<T>> get() async {
    final payload = {
      'collection': collectionPath,
      'filters': _filters
          .map((f) => {'field': f.field, 'op': f.op, 'value': _encodeValue(f.value)})
          .toList(),
      'order_by': _orderBy
          .map((o) => {'field': o.field, 'descending': o.descending})
          .toList(),
      'limit': _limit,
    };

    final data = await _post('/firestore/query', payload);
    final docs = (data['docs'] as List<dynamic>? ?? [])
        .map((e) => QueryDocumentSnapshot<T>._(
              id: (e as Map<String, dynamic>)['id'].toString(),
              data: _decodeMap((e)['data'] as Map<String, dynamic>) as T,
            ))
        .toList();
    return QuerySnapshot<T>._(docs);
  }

  Stream<QuerySnapshot<T>> snapshots() async* {
    while (true) {
      yield await get();
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }
}

class CollectionReference<T extends Map<String, dynamic>> extends Query<T> {
  CollectionReference(String collectionPath)
      : super(collectionPath);

  DocumentReference<T> doc([String? path]) {
    if (path == null || path.trim().isEmpty) {
      return DocumentReference<T>(collectionPath, _randomId());
    }
    final normalized = _normalizePath(path);
    if (normalized.contains('/')) {
      final segments = normalized.split('/');
      final id = segments.removeLast();
      final col = segments.join('/');
      return DocumentReference<T>(col, id);
    }
    return DocumentReference<T>(collectionPath, normalized);
  }

  Future<DocumentReference<T>> add(Map<String, dynamic> data) async {
    final response = await _post('/firestore/add_doc', {
      'collection': collectionPath,
      'data': _encodeMap(data),
    });
    final id = response['id'].toString();
    return DocumentReference<T>(collectionPath, id);
  }
}

class DocumentReference<T extends Map<String, dynamic>> {
  final String collectionPath;
  final String id;

  DocumentReference(this.collectionPath, this.id);

  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    await _post('/firestore/set_doc', {
      'collection': collectionPath,
      'doc_id': id,
      'data': _encodeMap(data),
      'merge': options?.merge ?? false,
    });
  }

  Future<void> update(Map<String, dynamic> data) async {
    await _post('/firestore/update_doc', {
      'collection': collectionPath,
      'doc_id': id,
      'data': _encodeMap(data),
    });
  }

  Future<void> delete() async {
    await _post('/firestore/delete_doc', {
      'collection': collectionPath,
      'doc_id': id,
    });
  }

  Future<DocumentSnapshot<T>> get() async {
    final resp = await _post('/firestore/get_doc', {
      'collection': collectionPath,
      'doc_id': id,
    });
    return DocumentSnapshot<T>._(
      id: id,
      exists: resp['exists'] == true,
      data: resp['data'] == null
          ? null
          : _decodeMap((resp['data'] as Map<String, dynamic>) ) as T,
    );
  }
}

class QuerySnapshot<T extends Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<T>> docs;

  QuerySnapshot._(this.docs);
}

class DocumentSnapshot<T extends Map<String, dynamic>> {
  final String id;
  final bool exists;
  final T? _data;

  DocumentSnapshot._({required this.id, required this.exists, required T? data})
      : _data = data;

  T? data() => _data;

  dynamic operator [](String key) => _data?[key];
}

class QueryDocumentSnapshot<T extends Map<String, dynamic>>
    extends DocumentSnapshot<T> {
  QueryDocumentSnapshot._({required String id, required T data})
      : super._(id: id, exists: true, data: data);

  @override
  T data() => super.data() as T;
}

class _Filter {
  final String field;
  final String op;
  final dynamic value;

  _Filter({required this.field, required this.op, required this.value});
}

class _OrderBy {
  final String field;
  final bool descending;

  _OrderBy({required this.field, required this.descending});
}

String _normalizePath(String path) {
  return path.trim().replaceAll('\\\\', '/').replaceAll(RegExp(r'^/+|/+$'), '');
}

String _randomId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final r = Random();
  return List.generate(20, (_) => chars[r.nextInt(chars.length)]).join();
}

Map<String, dynamic> _encodeMap(Map<String, dynamic> input) {
  final out = <String, dynamic>{};
  input.forEach((key, value) {
    out[key] = _encodeValue(value);
  });
  return out;
}

dynamic _encodeValue(dynamic value) {
  if (value is Timestamp) {
    return {'__timestamp__': value.toDate().toUtc().toIso8601String()};
  }
  if (value is DateTime) {
    return {'__timestamp__': value.toUtc().toIso8601String()};
  }
  if (value is _FieldValueOp) {
    return {'__op': value.op, 'values': value.values.map(_encodeValue).toList()};
  }
  if (value is Map<String, dynamic>) {
    return _encodeMap(value);
  }
  if (value is List) {
    return value.map(_encodeValue).toList();
  }
  return value;
}

Map<String, dynamic> _decodeMap(Map<String, dynamic> input) {
  final out = <String, dynamic>{};
  input.forEach((key, value) {
    out[key] = _decodeValue(value);
  });
  return out;
}

dynamic _decodeValue(dynamic value) {
  if (value is Map) {
    final map = value.cast<String, dynamic>();
    if (map.containsKey('__timestamp__')) {
      return Timestamp.fromDate(DateTime.parse(map['__timestamp__'].toString()));
    }
    return _decodeMap(map);
  }
  if (value is List) {
    return value.map(_decodeValue).toList();
  }
  return value;
}

Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> payload) async {
  final client = HttpClient();
  client.connectionTimeout = _requestTimeout;
  try {
    final uri = Uri.parse('${_defaultBaseUrl()}$path');
    final req = await client.postUrl(uri).timeout(_requestTimeout);
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    req.write(jsonEncode(payload));
    final res = await req.close().timeout(_requestTimeout);
    final text = await utf8.decodeStream(res).timeout(_requestTimeout);
    final json = text.isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(text) as Map).cast<String, dynamic>();
    if (res.statusCode >= 400) {
      throw FirestoreException(
        code: (json['detail'] ?? 'firestore-error').toString(),
        message: (json['detail'] ?? 'firestore-error').toString(),
      );
    }
    return json;
  } on TimeoutException {
    throw FirestoreException(
      code: 'network-timeout',
      message: _networkErrorMessage(),
    );
  } on SocketException {
    throw FirestoreException(
      code: 'network-error',
      message: _networkErrorMessage(),
    );
  } finally {
    client.close(force: true);
  }
}
