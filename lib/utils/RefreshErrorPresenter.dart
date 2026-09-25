import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';

import '../manager/DivingFish/DivingFishOAuthManager.dart';
import '../manager/DivingFish/ProberException.dart';

/// 刷新水鱼成绩失败时，统一给用户的交代。
///
/// 为什么要有这个函数：首页（`HomePage._openRefreshData`）和「系统」Tab
/// （`SystemHubPage`）各有一套刷新入口与进度显示，但**错误处理必须一致**。
/// 原来只有「系统」Tab 处理了 `CONSENT_REQUIRED`（直接拉起水鱼授权页），
/// 首页只弹一句「刷新数据失败：该用户尚未授权本应用，请先完成绑定后再试」——
/// 用户被告知「请先完成绑定」，却没有任何绑定入口，只能自己猜去哪里绑。
///
/// 水鱼 OAuth 文档 §4.3 要求 `consent_required` 时「引导用户完成一次绑定」，
/// 这个函数就是那一步。
///
/// [qq] 是本次要刷新的 QQ；为空时无法发起绑定，只给文案提示。
Future<void> presentRefreshError(Object error, {String qq = ''}) async {
  if (error is ProberException && error.code == 'CONSENT_REQUIRED') {
    // 好友对比路径会带上现成的授权链接；没有就现发起一次设备码绑定。
    var url = error.bindingUrl ?? '';
    if (url.isEmpty && qq.isNotEmpty) {
      url = await DivingFishOAuthManager().startBinding(qq);
    }

    if (url.isEmpty) {
      Fluttertoast.showToast(
        msg: qq.isEmpty
            ? error.message
            : 'QQ $qq 尚未授权本应用，请稍后在「账号与同步」中完成授权',
      );
      return;
    }

    // 只打开，不重查授权状态：用户此刻还没点「同意」，
    // 立刻回查必然仍是未授权（真正的重查入口在刷新对话框里）。
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('打开水鱼授权页失败: $e');
    }
    Fluttertoast.showToast(
      msg: opened
          ? '该 QQ 尚未授权本应用，已打开授权页；授权完成后请重新刷新'
          : '该 QQ 尚未授权本应用，请在浏览器中打开授权页完成绑定',
    );
    return;
  }

  Fluttertoast.showToast(msg: '刷新数据失败：$error');
}
