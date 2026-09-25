/// AWMC NET 查询异常。
///
/// [message] 是**可以直接展示给用户的中文文案**，所以刷新流程里
/// 直接用 `e.toString()` 弹 toast 就是人话，不需要再翻译一层。
///
/// 刻意只带一句文案、不做错误分类：目前没有任何调用方需要
/// 「按错误类型分支」（重试按钮、引导跳转都还没做），
/// 加了枚举也只会是没人读的死信息。等真有消费者时再加。
class AwmcNetException implements Exception {
  final String message;

  const AwmcNetException(this.message);

  @override
  String toString() => message;
}
