import 'dart:convert';

import 'package:muzic/core/base_dio_client/api_client.dart';
import 'package:muzic/features/resources/repositories/song_list_info.dart';

class PlayerRepository {
  final _apiClient = ApiClient();

  Future<StreamInfo> getStreamUrl(String publicId) async {
    final response = await _apiClient.get('/stream/$publicId');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return StreamInfo.fromJson(json);
    } else {
      throw Exception('Failed to load stream URL: ${response.statusCode}');
    }
  }
}
