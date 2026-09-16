enum GameType {
  info,       // 无提示猜歌
  cover,      // 根据部分曲绘猜歌
  blurred,    // 根据模糊曲绘猜歌
  audio,      // 根据歌曲片段猜歌
  alia,       // 根据别名猜歌
  letters,    // 舞萌开字母
  flash,      // 曲绘快闪
  tileReveal, // 曲绘拼图
  chartPeek,  // 谱面片段
}

extension GameTypeExtension on GameType {
  /// 用于 API 通信的英文字段名
  /// (info, cover, blurred, audio, alia, letters, flash, tileReveal, chartPeek)
  ///
  /// 注意 flash / tileReveal / chartPeek 用的是 camelCase：服务端只做透传，
  /// 客户端 RoomEntity._parseGameType 同时认 camelCase 与中文显示名。
  String get apiKey {
    switch (this) {
      case GameType.info:
        return 'info';
      case GameType.cover:
        return 'cover';
      case GameType.blurred:
        return 'blurred';
      case GameType.audio:
        return 'audio';
      case GameType.alia:
        return 'alia';
      case GameType.letters:
        return 'letters';
      case GameType.flash:
        return 'flash';
      case GameType.tileReveal:
        return 'tileReveal';
      case GameType.chartPeek:
        return 'chartPeek';
    }
  }

  /// 用于 UI 显示的中文名
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
      case GameType.flash:
        return '曲绘快闪';
      case GameType.tileReveal:
        return '曲绘拼图';
      case GameType.chartPeek:
        return '谱面片段';
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
      case GameType.flash:
        return '曲绘一闪而过，凭记忆猜歌名';
      case GameType.tileReveal:
        return '曲绘被切成小块逐批揭示';
      case GameType.chartPeek:
        return '看无声的谱面片段猜歌名';
    }
  }
}
