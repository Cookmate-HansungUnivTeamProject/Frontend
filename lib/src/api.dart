import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 서버 주소 기본값.
/// - 빌드할 때 `--dart-define=API_BASE=http://192.168.0.10:8000`처럼 바꿀 수 있다.
/// - 안드로이드 에뮬레이터는 PC를 10.0.2.2로 본다. 실제 폰은 설정 화면에서 PC의 IP를 넣는다.
String defaultApiBase() {
  const fromBuild = String.fromEnvironment('API_BASE');
  if (fromBuild.isNotEmpty) return fromBuild;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://127.0.0.1:8000';
}

/// 서버가 요청을 거절했거나(404·409·422) 서버에 연결하지 못했을 때(statusCode 0).
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

/// 주방 허브 백엔드 API. 응답 모양은 백엔드 저장소의 docs/openapi.json과 같다.
class KitchenApi {
  KitchenApi({String? baseUrl, http.Client? client})
    : baseUrl = normalizeBase(baseUrl ?? defaultApiBase()),
      _client = client ?? http.Client();

  String baseUrl;
  final http.Client _client;

  static const timeout = Duration(seconds: 3);

  /// 'http://' 없이 넣거나 끝에 '/'를 붙여도 되게 정리한다.
  static String normalizeBase(String value) {
    var v = value.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    if (!v.startsWith('http://') && !v.startsWith('https://')) {
      v = 'http://$v';
    }
    return v;
  }

  /// 기기·타이머·주문·온도·알림 전부.
  Future<Map<String, dynamic>> state() => _send('GET', '/api/state');

  Future<Map<String, dynamic>> devicePower(String id, bool on) =>
      _send('POST', '/api/devices/$id/power', {'on': on});

  /// 화력은 정수로 보낸다(2.0처럼 소수로 보내면 서버가 422로 거절).
  Future<Map<String, dynamic>> deviceLevel(String id, int level) =>
      _send('POST', '/api/devices/$id/level', {'level': level});

  /// 30~300초, 30초 단위만 된다(그 밖은 422).
  Future<Map<String, dynamic>> timerStart(String id, int sec) =>
      _send('POST', '/api/timers/$id/start', {'sec': sec});

  Future<Map<String, dynamic>> timerStop(String id) =>
      _send('POST', '/api/timers/$id/stop');

  /// action: accept · reject · complete.
  /// 주문 버튼은 화면 번호(slot)가 아니라 주문 고유 번호(id)로 부른다.
  Future<Map<String, dynamic>> orderAction(int id, String action) =>
      _send('POST', '/api/orders/$id/$action');

  Future<Map<String, dynamic>> _send(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final res = await _request(method, Uri.parse('$baseUrl$path'), body);
    final text = utf8.decode(res.bodyBytes, allowMalformed: true);
    Object? json;
    try {
      json = text.isEmpty ? null : jsonDecode(text);
    } on FormatException {
      json = null;
    }
    if (res.statusCode != 200) {
      throw ApiException(
        res.statusCode,
        _detail(json) ?? '서버 오류 (${res.statusCode})',
      );
    }
    if (json is! Map<String, dynamic>) {
      throw ApiException(res.statusCode, '서버 응답 모양이 달라요');
    }
    return json;
  }

  Future<http.Response> _request(
    String method,
    Uri uri,
    Map<String, Object?>? body,
  ) async {
    try {
      if (method == 'GET') {
        return await _client.get(uri).timeout(timeout);
      }
      return await _client
          .post(
            uri,
            // 이 헤더가 없으면 http 패키지가 text/plain으로 보내서 서버가 422로 거절한다.
            headers: body == null
                ? null
                : const {'Content-Type': 'application/json'},
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(timeout);
    } catch (_) {
      throw ApiException(0, '서버에 연결할 수 없어요 ($baseUrl)');
    }
  }

  /// 오류 응답의 detail을 사람이 읽을 문장으로 꺼낸다.
  /// 404·409는 {"detail": "문장"}, 422는 {"detail": [{"msg": "문장"}, ...]} 모양이다.
  static String? _detail(Object? json) {
    if (json is! Map) return null;
    final detail = json['detail'];
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] is String) return first['msg'] as String;
    }
    return null;
  }

  void close() => _client.close();
}
