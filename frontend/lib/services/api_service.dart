import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Replace with your backend URL
  static const String baseUrl = 'http://localhost:8000';

  static Future<Map<String, dynamic>> startDownload(String url) async {
    final response = await http.post(
      Uri.parse('$baseUrl/download'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': url}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to start download');
    }
  }

  static Future<Map<String, dynamic>> getStatus(String jobId) async {
    final response = await http.get(Uri.parse('$baseUrl/status/$jobId'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get status');
    }
  }

  static Future<void> openFolder(String jobId) async {
    await http.get(Uri.parse('$baseUrl/open-folder/$jobId'));
  }

  static Future<Map<String, dynamic>> getSettings() async {
    final response = await http.get(Uri.parse('$baseUrl/settings'));
    return json.decode(response.body);
  }

  static Future<void> updateSettings(String outputsDir) async {
    await http.post(
      Uri.parse('$baseUrl/settings'),
      body: {'outputs_dir': outputsDir},
    );
  }
}
