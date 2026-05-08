enum GameType {
  info,      // 无提示猜歌
  cover,     // 根据部分曲绘猜歌
  blurred,   // 根据模糊曲绘猜歌
  audio,     // 根据歌曲片段猜歌
  alia,      // 根据别名猜歌
  letters,   // 舞萌开字母
}

extension GameTypeExtension on GameType {
  String get name {
    switch (this) {
      case GameType.info:
        return '无提示猜歌';
      case GameType.cover:
        return '曲绘猜歌';
      case GameType.blurred:
        return '模糊曲绘';
      case GameType.audio:
        return '歌曲片段';
      case GameType.alia:
        return '别名猜歌';
      case GameType.letters:
        return '开字母';
    }
  }

  String get description {
    switch (this) {
      case GameType.info:
        return '根据歌曲信息猜歌名';
      case GameType.cover:
        return '根据部分曲绘猜歌名';
      case GameType.blurred:
        return '根据模糊曲绘猜歌名';
      case GameType.audio:
        return '根据歌曲片段猜歌名';
      case GameType.alia:
        return '根据别名猜歌名';
      case GameType.letters:
        return '根据首字母猜歌名';
    }
  }
}