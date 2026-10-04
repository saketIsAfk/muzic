// songs_list_repository.dart
import 'dart:convert';
import 'package:muzic/core/base_dio_client/api_client.dart';
import 'package:muzic/features/resources/repositories/song_list_info.dart';

class SongsListRepository {
  final _apiClient = ApiClient();

  Future<SongsListInfo> fetchLibrary() async {
    final response = await _apiClient.get('/library');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return SongsListInfo.fromJson(json);
    } else {
      throw Exception('Failed to load library: ${response.statusCode}');
    }
  }
}
