import 'dart:convert';

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
        timeout = timeout ?? const Duration(seconds: 8);

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  /// Bearer token attached to requests when set. The signed-in
  /// [AuthProvider] keeps this up to date; repositories that only read
  /// public data (vendor browsing) never need it.
  String? authToken;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/api/v1$path').replace(queryParameters: query);

  Future<dynamic> get(String path, [Map<String, String>? query]) async {
    final response =
        await _client.get(_uri(path, query), headers: _headers()).timeout(timeout);
    return _handle(response);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final response = await _client
        .post(_uri(path), headers: _headers(), body: jsonEncode(body ?? {}))
        .timeout(timeout);
    return _handle(response);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    final response = await _client
        .patch(_uri(path), headers: _headers(), body: jsonEncode(body ?? {}))
        .timeout(timeout);
    return _handle(response);
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
