import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../errors/exceptions.dart';

/// HTTP Client abstraction for MapLess AI
class ApiClient {
  final http.Client _client;
  final String baseUrl;

  ApiClient({http.Client? client, this.baseUrl = ApiConstants.localhostBaseUrl})
      : _client = client ?? http.Client();

  Future<Map<String, dynamic>> get(String url) async {
    try {
      final response = await _client
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(ApiConstants.defaultTimeout);
      return _handleResponse(response);
    } on SocketException catch (e) {
      throw NetworkException('Unable to reach server: ${e.message}', code: 'SOCKET_ERROR');
    } on TimeoutException {
      throw const NetworkException('Request timed out', code: 'TIMEOUT');
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException('Unexpected network error: $e', code: 'UNKNOWN_NETWORK');
    }
  }

  Future<Map<String, dynamic>> post(String url, Map<String, dynamic> body) async {
    try {
      final response = await _client
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(ApiConstants.defaultTimeout);
      return _handleResponse(response);
    } on SocketException catch (e) {
      throw NetworkException('Unable to reach server: ${e.message}', code: 'SOCKET_ERROR');
    } on TimeoutException {
      throw const NetworkException('Request timed out', code: 'TIMEOUT');
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException('Unexpected network error: $e', code: 'UNKNOWN_NETWORK');
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      String message = 'HTTP Error ${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] != null) {
          message = decoded['error']['message'] ?? message;
        }
      } catch (_) {}
      throw NetworkException(message, statusCode: response.statusCode);
    }
  }

  void close() {
    _client.close();
  }
}
