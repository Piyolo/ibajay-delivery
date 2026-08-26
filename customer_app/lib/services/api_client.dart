import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'app_config.dart';

/// Thin HTTP wrapper around the FastAPI backend.
///
/// Adds the JSON headers, base-URL handling, and converts non-2xx
/// responses into [ApiException] so repositories only deal with
/// decoded data or a single error type.
///
/// Every request is capped at [timeout] — without it, a connection to an
/// unreachable host (wrong IP, server asleep, blocked firewall port) can
/// hang for the OS's full TCP timeout (~2 minutes) before failing, which
/// freezes whatever screen is awaiting the call.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl, Duration? timeout})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
        // Generous enough for free-tier server cold starts (~20-50s wake).
        // Requests to an unreachable host would otherwise hang for the OS's
        // full TCP timeout before failing.
        timeout = timeout ?? const Duration(seconds: 25);

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  /// Bearer token attached to requests when set. The signed-in
  /// [AuthProvider] keeps this up to date; repositories that only read
  /// public data (vendor browsing) never need it.
  String? authToken;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/api/v1$path').replace(queryParameters: query);

  /// Sends a request, converting transport-level failures (timeouts, no
  /// route, no internet) into [ApiException] so callers always receive a
  /// typed error and the UI can show a message instead of hanging.
  Future<http.Response> _send(Future<http.Response> future) async {
    try {
      return await future.timeout(timeout);
    } on TimeoutException {
      throw ApiException(
        'Could not reach the server. Check your internet connection and try again.',
      );
    } on SocketException {
      throw ApiException(
        'No network connection. Please check your internet and try again.',
      );
    }
  }

  Future<dynamic> get(String path, [Map<String, String>? query]) async {
    final response = await _send(_client.get(_uri(path, query), headers: _headers()));
    return _handle(response);
  }

  Future<dynamic> post(String path, {Object? body, Map<String, String>? query}) async {
    final response = await _send(
      _client.post(_uri(path, query), headers: _headers(), body: jsonEncode(body ?? {})),
    );
    return _handle(response);
  }

  Future<dynamic> patch(String path, {Object? body, Map<String, String>? query}) async {
    final response = await _send(
      _client.patch(_uri(path, query), headers: _headers(), body: jsonEncode(body ?? {})),
    );
    return _handle(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await _send(_client.delete(_uri(path), headers: _headers()));
    return _handle(response);
  }

  /// Uploads a local file as a multipart POST (e.g. chat photos to
  /// /uploads). Returns the decoded response, e.g. {"url": "https://..."}.
  Future<dynamic> postMultipart(String path, {required String filePath}) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(_headers())
      ..files.add(await http.MultipartFile.fromPath('file', filePath));
    try {
      final streamed = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      return _handle(response);
    } on TimeoutException {
      throw ApiException('Upload timed out. Check your connection and try again.');
    } on SocketException {
      throw ApiException('No network connection. Please check your internet and try again.');
    }
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  dynamic _handle(http.Response response) {
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic> && decoded['detail'] != null
          ? decoded['detail'].toString()
          : 'Request failed (${response.statusCode})';
      throw ApiException(message, statusCode: response.statusCode);
    }
    return decoded;
  }

  void dispose() => _client.close();
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
