// ignore_for_file: constant_identifier_names

class ApiUrls {
  static const String DiffMusicDataApi = 'https://www.diving-fish.com/api/maimaidxprober/chart_stats';
  static const String MusicDataApi = 'https://www.diving-fish.com/api/maimaidxprober/music_data';
  static const String TagDataApi = 'https://miruku.dxrating.net/api/v1/tags';
  static const String SongAliasApi = 'https://www.yuzuchan.moe/api/maimaidx/maimaidxalias';
  static const String DXRatingSongAliasApi = 'https://miruku.dxrating.net/api/v1/aliases';
  static const String UserBest50Api = 'https://www.diving-fish.com/api/maimaidxprober/query/player';
  static const String UserPlayDataApi = 'https://www.diving-fish.com/api/maimaidxprober/dev/player/records';
  static const String TrophiesCollectionApi = 'https://maimai.lxns.net/api/v0/maimai/trophy/list';
  static const String IconsCollectionApi = 'https://maimai.lxns.net/api/v0/maimai/icon/list';
  static const String PlatesCollectionApi = 'https://maimai.lxns.net/api/v0/maimai/plate/list';
  static const String FramesCollectionApi = 'https://maimai.lxns.net/api/v0/maimai/frame/list';
  static const String LuoXueSongsApi = 'https://maimai.lxns.net/api/v0/maimai/song/list';
  static const String ServerStatusApi = 'https://status.awmc.cc/api/status-page/heartbeat/maimai';
  static const String ServerStatusTitleApi = 'https://status.awmc.cc/api/status-page/maimai';
  static const String checkUpdateApi = 'http://47.93.46.104/app_version.json';
  static const String knowledgeApi = 'http://47.93.46.104:3000/api/knowledge';
  
  // 多人游戏服务器地址
  static const String MultiplayerServerUrl = 'ws://47.93.46.104:3000';
  static const String MultiplayerGameServerUrl = 'ws://47.93.46.104:3000';
  
  // Maidata 服务器地址
  static const String MaidataServerBaseUrl = 'http://47.93.46.104';
  static const String MaidataServerPortUrl = 'http://47.93.46.104:8888';
  
  // 落雪 OAuth 相关地址
  static const String LuoXueBaseUrl = 'https://maimai.lxns.net';
  static const String LuoXueApiBaseUrl = 'https://maimai.lxns.net/api/v0';
  static const String LuoXueOAuthTokenUrl = 'https://maimai.lxns.net/api/v0/oauth/token';
  static const String LuoXueOAuthAuthorizeUrl = 'https://maimai.lxns.net/oauth/authorize';
  
  // 落雪玩家数据 API
  static const String LuoXuePlayerApi = 'https://maimai.lxns.net/api/v0/user/maimai/player';
  static const String LuoXuePlayerScoresApi = 'https://maimai.lxns.net/api/v0/user/maimai/player/scores';
  
  // 排行榜 API 地址
  static const String RankingsBaseUrl = 'http://47.93.46.104:3000/api/rankings';
  static const String RankingsUpdateUrl = '$RankingsBaseUrl/update';

  // 歌曲评论 API 地址
  static const String CommentsBaseUrl = 'http://47.93.46.104:3000/api/comments';
  static const String CommentsBySongUrl = '$CommentsBaseUrl/song';
  static const String CommentsByUserUrl = '$CommentsBaseUrl/user';
  static const String CommentsCreateUrl = '$CommentsBaseUrl/create';
  static const String CommentsClearCacheUrl = '$CommentsBaseUrl/clear-cache';

  // 谱面评分 API 地址
  static const String RatingsBaseUrl = 'http://47.93.46.104:3000/api/ratings';
  static const String RatingsByChartUrl = '$RatingsBaseUrl/chart';
  static const String RatingsCreateUrl = '$RatingsBaseUrl/create';
  static const String RatingsDeleteUrl = '$RatingsBaseUrl';
}