import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../storage/local_storage.dart';

class ApiClient {
  Future<Map<String, String>> _getHeaders() async {
    final token = await LocalStorage.getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> get(String endpoint) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    debugPrint('[ApiClient] GET $url');
    final headers = await _getHeaders();
    final response = await http.get(url, headers: headers);
    _checkUnauthorized(response);
    return response;
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    debugPrint('[ApiClient] POST $url');
    final headers = await _getHeaders();
    final response = await http.post(url, headers: headers, body: jsonEncode(body));
    _checkUnauthorized(response);
    return response;
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    debugPrint('[ApiClient] PUT $url');
    final headers = await _getHeaders();
    final response = await http.put(url, headers: headers, body: jsonEncode(body));
    _checkUnauthorized(response);
    return response;
  }

  Future<http.Response> delete(String endpoint) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    debugPrint('[ApiClient] DELETE $url');
    final headers = await _getHeaders();
    final response = await http.delete(url, headers: headers);
    _checkUnauthorized(response);
    return response;
  }

  Future<http.Response> postMultipart(
      String endpoint, Map<String, String> fields, String filePath) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    debugPrint('[ApiClient] POST Multipart $url');
    final headers = await _getHeaders();
    headers.remove('Content-Type');

    final request = http.MultipartRequest('POST', url);
    request.headers.addAll(headers);
    request.fields.addAll(fields);
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    _checkUnauthorized(response);
    return response;
  }

  Future<http.Response> postMultipartBytes(
      String endpoint, List<int> bytes, String filename) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    debugPrint('[ApiClient] POST Multipart Bytes $url');
    final headers = await _getHeaders();
    headers.remove('Content-Type');

    final request = http.MultipartRequest('POST', url);
    request.headers.addAll(headers);
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    _checkUnauthorized(response);
    return response;
  }

  void _checkUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      debugPrint('[ApiClient] 401 Unauthorized encountered');
    }
  }
}
