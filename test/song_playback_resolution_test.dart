import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_flutter_app/service/Portable/PortableSongLibrary.dart';

void main() {
  test('目录未收录时仍按原始 songId 生成 AWMC 播放兜底', () {
    final song = PortableSongLibrary().resolveForPlayback(
      songId: '11968',
      title: '测试歌曲',
      type: 'DX',
      artist: '测试艺术家',
    );

    expect(song, isNotNull);
    expect(song!.divingFishId, '11968');
    expect(song.audioId, 1968);
    expect(song.artist, '测试艺术家');
    expect(song.isAwmcExtra, isTrue);
    expect(song.audioUrls.first, 'https://download.wmc.pub/s/11968/track.mp3');
  });

  test('无法解析的 songId 不会伪造音源条目', () {
    expect(
      PortableSongLibrary().resolveForPlayback(
        songId: 'not-a-song-id',
        title: '测试歌曲',
        type: 'DX',
      ),
      isNull,
    );
  });
}
