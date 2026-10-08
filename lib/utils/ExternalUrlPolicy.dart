/// 外部跳转的最低限度校验，避免服务端返回的任意 URL 被直接交给系统浏览器。
class ExternalUrlPolicy {
  ExternalUrlPolicy._();

  static const _allowedHosts = <String>{
    'chiffonmai.cloud',
    'diving-fish.com',
    'www.diving-fish.com',
    'maimai.lxns.net',
    'lxns.net',
    'wmc.pub',
    'net.wmc.pub',
    'api.wmc.pub',
    'maimai.bakapiano.com',
    'wward.lanzouw.com',
  };

  static bool isAllowed(Uri uri) {
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty) return false;
    final host = uri.host.toLowerCase();
    return _allowedHosts
        .any((allowed) => host == allowed || host.endsWith('.$allowed'));
  }
}
