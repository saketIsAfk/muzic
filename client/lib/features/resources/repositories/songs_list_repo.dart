// songs_list_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:muzic/core/base_dio_client/api_config.dart';
import 'package:muzic/features/resources/repositories/song_list_info.dart';

class SongsListRepository {

  Future<SongsListInfo> fetchLibrary() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/library'));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return SongsListInfo.fromJson(json);
    } else {
      throw Exception('Failed to load library: ${response.statusCode}');
    }
  }
}
