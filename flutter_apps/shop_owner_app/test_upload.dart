import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIyIiwicm9sZSI6ImZpZWxkX2V4ZWN1dGl2ZSIsIm5hbWUiOiJTdXJlc2ggQmFidSIsImV4cCI6MTc5MTk5Mjg1Mn0.5ry-qGvXyvJobvepEJ1zOEwe7sWVO-DFj3DXIIZe3qc';
  
  // write fake image
  final file = File('test.jpg');
  await file.writeAsBytes([1,2,3,4,5]);

  final endpoint = '/api/v1/visits/6/upload-photo';
  final apiBaseUrl = 'http://127.0.0.1:8000';
  final url = Uri.parse('$apiBaseUrl$endpoint');
  
  final headers = {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

  var request = http.MultipartRequest('POST', url);
  request.headers.addAll(headers);
  request.fields.addAll({
    'photo_lat': '12.34',
    'photo_lng': '56.78',
    'notes': 'Dart test',
  });

  request.files.add(await http.MultipartFile.fromPath('file', file.path));

  print('Sending request to $url...');
  final streamedResponse = await request.send();
  final response = await http.Response.fromStream(streamedResponse);
  
  print('Status: ${response.statusCode}');
  print('Body: ${response.body}');
}
