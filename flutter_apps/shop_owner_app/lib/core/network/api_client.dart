import 'dart:convert';
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
    print('DEBUG API_URL: $url');
    final headers = await _getHeaders();
    return await http.get(url, headers: headers);
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    final headers = await _getHeaders();
    return await http.post(url, headers: headers, body: jsonEncode(body));
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    final headers = await _getHeaders();
    return await http.put(url, headers: headers, body: jsonEncode(body));
  }

  Future<http.Response> delete(String endpoint) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    final headers = await _getHeaders();
    return await http.delete(url, headers: headers);
  }

  Future<http.Response> postMultipart(
      String endpoint, Map<String, String> fields, String filePath) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    final headers = await _getHeaders();
    headers.remove('Content-Type'); // Let http handle the boundary

    var request = http.MultipartRequest('POST', url);
    request.headers.addAll(headers);
    request.fields.addAll(fields);

    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send();
    return await http.Response.fromStream(streamedResponse);
  }
}
