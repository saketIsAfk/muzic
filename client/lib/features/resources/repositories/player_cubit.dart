import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart' hide PlayerState;
import 'package:muzic/features/resources/repositories/album_info.dart';
import 'package:muzic/features/resources/repositories/player_repo.dart';
import 'package:muzic/features/resources/repositories/player_state.dart';

import 'package:rxdart/rxdart.dart';

class PositionData {
  const PositionData(this.position, this.duration);
  final Duration position;
  final Duration duration;
}

class PlayerCubit extends Cubit<PlayerState> {
  final AudioPlayer _player = AudioPlayer();

  PlayerCubit() : super(PlayerState());

  AudioPlayer get player => _player;

  Stream<PositionData> positionDataStream() {
    return Rx.combineLatest2<Duration, Duration?, PositionData>(
      _player.positionStream,
      _player.durationStream,
      (position, duration) => PositionData(position, duration ?? Duration.zero),
    );
  }

  Future<void> playSong(SongModel song) async {
    try {
      final streamInfo = await PlayerRepository().getStreamUrl(song.audioPublicId);

      await _player.setUrl(streamInfo.streamUrl);
      _player.play();

      emit(state.copyWith(currentSong: song, isPlaying: true, streamUrl: streamInfo.streamUrl));
    } catch (e, s) {
      debugPrint("Failed to play song: $e");
      debugPrint(s.toString());
    }
  }

  void togglePlay() {
    if (_player.playing) {
      _player.pause();
      emit(state.copyWith(isPlaying: false));
    } else {
      _player.play();
      emit(state.copyWith(isPlaying: true));
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Stops playback and clears the now-playing song (e.g. on logout).
  /// Emits a fresh PlayerState rather than copyWith — copyWith's `??`
  /// fallback pattern can't null out currentSong/streamUrl once set.
  Future<void> stop() async {
    await _player.stop();
    emit(PlayerState());
  }

  @override
  Future<void> close() {
    _player.dispose();
    return super.close();
  }
}
