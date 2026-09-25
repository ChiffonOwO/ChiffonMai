// ignore_for_file: constant_identifier_names

// 开发者token，Clone本项目时请改成自己的token，类名改为DeveloperToken
class DeveloperTokenShow {
  static const String TencentSecretId = '你的腾讯云SecretId';
  static const String TencentSecretKey = '你的腾讯云SecretKey';
  
  // 落雪 OAuth Client Secret
  static const String LuoXueClientSecret = '你的落雪OAuth Client Secret';

  // AWMC NET.（https://net.wmc.pub）查分器开发者密钥。
  //
  // 用途：App 直连 `GET /dev/player/records?qq=<QQ>` 查成绩，请求头 `Developer-Token`。
  // 申请：登录 net.wmc.pub 后在开发者页面申请，密钥形如 `awmc_sk_...`，
  //       需要 `bot + developer` 权限（只读查分；不限频率最好）。
  // 留空 / 用占位符会导致「刷新数据 → AWMC NET」提示密钥无效（HTTP 401）。
  static const String AwmcNetDeveloperKey = '你的AWMC NET开发者密钥（awmc_sk_...）';
  
  // MySQL数据库配置
  static const String MySQLHost = '你的MySQL主机地址';
  static const int MySQLPort = 3306;
  static const String MySQLDatabase = 'user_maimai_rankings';
  static const String MySQLUsername = '你的MySQL用户名';
  static const String MySQLPassword = '你的MySQL密码';
  
  // Redis配置
  static const String RedisHost = '你的Redis主机地址';
  static const int RedisPort = 6379;
  static const String RedisPassword = '你的Redis密码';
  static const int RedisDatabase = 0;
}