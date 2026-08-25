import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  Future<Map<String, dynamic>> analyzeRegion(List<double> bbox) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/analyze-deforestation');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'bbox': bbox}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      String detail = 'Unknown error';
      try {
        final errorBody = jsonDecode(response.body);
        detail = errorBody['detail'] ?? detail;
      } catch (_) {}
      throw Exception('Analysis failed (${response.statusCode}): $detail');
    }
  }
}

class AppConfig {
  // Use 'http://10.0.2.2:3000' for Android emulators
  static const String baseUrl = 'http://127.0.0.1:3000';
}