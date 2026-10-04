import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:muzic/core/base_dio_client/api_config.dart';

/// The one place that knows the base URL and attaches the Firebase ID token.
/// Every repository calls through this instead of `http` directly, so
/// authenticated requests work the same way everywhere without each repo
/// re-implementing it.
class ApiClient {
  Future<http.Response> get(String path) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return http.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
  }
}
