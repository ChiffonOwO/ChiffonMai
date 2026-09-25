import 'package:flutter/material.dart';
import '../entity/FeatureModels.dart';
import 'FeatureFlags.dart';

/// 集中管理所有功能分类和功能项定义
///
/// 各个功能项的 [ButtonItem.subtitle] 与对应 Hub 页（LibraryHubPage /
/// Best50HubPage / GuessHubPage / ToolsHubPage / SystemHubPage）中
/// HubActionTile 的 subtitle 保持一致，保证首页"全部功能"与 Hub 页显示一致。
class FeatureRegistry {
  FeatureRegistry._();

  static List<ButtonCategory> allCategories(bool isDivingFishLoggedIn) => [
    ButtonCategory(name: '曲库与数据', items: [
      const ButtonItem(icon: Icons.music_note, title: '乐曲查询', subtitle: '按歌名、别名、谱师和标签搜索'),
      const ButtonItem(icon: Icons.score, title: '成绩查询', subtitle: '浏览全部游玩记录与筛选结果'),
      const ButtonItem(icon: Icons.wysiwyg_rounded, title: '牌子进度', subtitle: '查看各版本与目标牌子'),
      const ButtonItem(icon: Icons.grading_rounded, title: '个性化成绩查询', subtitle: '按等级或谱师查看成绩'),
      const ButtonItem(icon: Icons.collections_bookmark, title: '收藏品查询', subtitle: '查看头像、姓名框等收藏品'),
    ]),
    ButtonCategory(name: 'Best50与排行榜', items: [
      const ButtonItem(icon: Icons.leaderboard, title: 'Best50', subtitle: '查看当前 Best35 与 Best15'),
      const ButtonItem(icon: Icons.analytics, title: '拟合 Best50', subtitle: '分析潜在 Rating 上限'),
      const ButtonItem(icon: Icons.timeline_rounded, title: 'Rating 历史', subtitle: '看 Rating 随时间的变化'),
      const ButtonItem(icon: Icons.person_search_outlined, title: '个性化 Best50', subtitle: '按标签筛选 Best50'),
      const ButtonItem(icon: Icons.analytics_outlined, title: '个性化拟合 Best50', subtitle: '按标签查看拟合 Rating 上限'),
      const ButtonItem(icon: Icons.leaderboard, title: 'Rating 排行榜', subtitle: '查看玩家 Rating 排行'),
      const ButtonItem(icon: Icons.auto_graph_rounded, title: '拟合总Rating排行榜', subtitle: '查看拟合总 Rating 与官方 Best50 差值'),
      const ButtonItem(icon: Icons.percent, title: '平均达成率排行榜', subtitle: '按全量成绩的平均达成率排名'),
      const ButtonItem(icon: Icons.score_outlined, title: '平均DX分数达成率排行榜', subtitle: '按全量成绩的平均DX得分达成率排名'),
      const ButtonItem(icon: Icons.leaderboard_outlined, title: '特殊排行榜', subtitle: '发现有趣的玩家数据'),
    ]),
    ButtonCategory(name: '猜歌游戏', items: [
      const ButtonItem(icon: Icons.gamepad, title: '无提示猜歌', subtitle: '凭记忆挑战曲库'),
      const ButtonItem(icon: Icons.gamepad, title: '根据部分曲绘猜歌', subtitle: '看一小块曲绘猜出歌曲'),
      const ButtonItem(icon: Icons.gamepad, title: '根据模糊曲绘猜歌', subtitle: '根据模糊化处理后的曲绘猜歌'),
      const ButtonItem(icon: Icons.gamepad, title: '根据歌曲片段猜歌', subtitle: '截取音源片段猜歌'),
      const ButtonItem(icon: Icons.gamepad, title: '根据别名猜歌', subtitle: '用别名挑战你的熟悉度'),
      const ButtonItem(icon: Icons.gamepad, title: '舞萌开字母', subtitle: '看首字母猜歌'),
      const ButtonItem(icon: Icons.gamepad, title: '多人猜歌游戏', subtitle: '和朋友一起猜舞萌曲库'),
    ]),
    ButtonCategory(name: '实用工具', icon: Icons.work, items: [
      const ButtonItem(icon: Icons.headphones, title: '随身听', subtitle: '后台播放舞萌曲库，带通知栏播放器'),
      const ButtonItem(icon: Icons.arrow_circle_up, title: '段位表', subtitle: '挑战你的下一段位'),
      const ButtonItem(icon: Icons.label, title: '基于标签推荐', subtitle: '基于你的游玩谱面标签推荐曲目'),
      const ButtonItem(icon: Icons.trending_up, title: '基于目标 Rating 推荐', subtitle: '寻找适合上分的谱面'),
      const ButtonItem(icon: Icons.tune, title: '基于定数区间推荐', subtitle: '按定数范围挑选谱面'),
      const ButtonItem(icon: Icons.shuffle, title: '随机乐曲', subtitle: '随机抽取 1-4 首歌曲'),
      const ButtonItem(icon: Icons.calculate, title: '单曲 Rating 计算', subtitle: '根据达成率计算单首 rating'),
      const ButtonItem(icon: Icons.percent, title: '达成率计算', subtitle: '根据判定详情算出达成率'),
      const ButtonItem(icon: Icons.compare_arrows, title: '版本对照', subtitle: '按版本整理可游玩曲目'),
      const ButtonItem(icon: Icons.replay, title: '达成率反推', subtitle: '根据判定详情推出绝赞详情'),
      const ButtonItem(icon: Icons.door_back_door, title: 'KALEIDXSCOPE', subtitle: '探索独特的舞萌玩法'),
      const ButtonItem(icon: Icons.image_search, title: '曲绘识别', subtitle: '用相机或图片快速找歌'),
      const ButtonItem(icon: Icons.document_scanner, title: '结算画面识别', subtitle: '拍摄机台结算画面，自动识别成绩'),
      const ButtonItem(icon: Icons.bar_chart, title: '定数分布', subtitle: '查看谱面定数分布'),
      const ButtonItem(icon: Icons.favorite, title: '收藏夹', subtitle: '管理你收藏的谱面'),
      const ButtonItem(icon: Icons.play_arrow, title: '自定义谱面播放', subtitle: '播放本地自定义谱面'),
      const ButtonItem(icon: Icons.today, title: '每日推荐', subtitle: '今天打什么？交给推荐'),
      const ButtonItem(icon: Icons.people, title: '好友对比', subtitle: '看看你和好友的成绩差异'),
      const ButtonItem(icon: Icons.map, title: '全国音游地图', subtitle: '看看哪里有你想玩的机台'),
      const ButtonItem(icon: Icons.public, title: '全球音游街机地图', subtitle: '查看 NearCade 全球街机店铺'),
    ]),
    ButtonCategory(name: '友情链接', icon: Icons.handshake_outlined, items: [
      const ButtonItem(
        icon: Icons.link,
        title: '查看友情链接',
        subtitle: '发现同好项目',
      ),
    ]),
    ButtonCategory(name: '系统', icon: Icons.settings, items: [
      const ButtonItem(icon: Icons.file_upload_sharp, title: '刷新数据', subtitle: '重新拉取并初始化所有本地缓存'),
      const ButtonItem(icon: Icons.cleaning_services, title: '刷新 maidata', subtitle: '手动刷新所有 maidata 缓存'),
      const ButtonItem(icon: Icons.qr_code_scanner, title: '同步成绩到水鱼', subtitle: '扫码抓取并同步最新成绩'),
      const ButtonItem(icon: Icons.cloud_sync, title: '同步成绩到落雪', subtitle: '将本地成绩同步到落雪咖啡屋'),
      const ButtonItem(icon: Icons.cloud_upload_outlined, title: '同步成绩到 AWMC NET', subtitle: '用机台二维码导入成绩到 AWMC NET'),
      if (isDivingFishLoggedIn)
        const ButtonItem(icon: Icons.logout, title: '登出水鱼账号', subtitle: '清除水鱼登录状态')
      else
        const ButtonItem(icon: Icons.login, title: '登录水鱼', subtitle: '获取 ImportToken 以使用同步功能'),
      const ButtonItem(icon: Icons.network_check, title: '服务器状态', subtitle: '查看舞萌服务状态'),
      const ButtonItem(icon: Icons.update, title: '检查更新', subtitle: '检查应用是否有新版本'),
      const ButtonItem(icon: Icons.info_outline, title: '关于 APP', subtitle: '了解项目与版本信息'),
      const ButtonItem(icon: Icons.poll_outlined, title: '问卷调查', subtitle: '助力 ChiffonMai 更上一层楼'),
      const ButtonItem(icon: Icons.public, title: '访问官方网站', subtitle: '前往 chiffonmai.cloud 查看项目主页'),
      const ButtonItem(icon: Icons.groups_outlined, title: '加入 QQ 群', subtitle: '一键跳转官方交流群'),
      const ButtonItem(icon: Icons.volunteer_activism, title: '支持开发者', subtitle: '支持项目持续更新'),
      const ButtonItem(icon: Icons.manage_accounts, title: '账号管理', subtitle: '查看已绑定的水鱼账号信息'),
      const ButtonItem(icon: Icons.backup, title: '数据备份', subtitle: '导入或导出本地数据'),
      const ButtonItem(icon: Icons.comment, title: '最近评论', subtitle: '查看社区最近评论'),
      const ButtonItem(icon: Icons.star, title: '最近评分', subtitle: '查看社区最近评分'),
      // 「AWMC 网关」入口：默认隐藏（FeatureFlags.awmcGateway），代码一行没删。
      // 关掉时首页搜索 / 收藏 / 全部功能里也一起看不到。
      if (FeatureFlags.awmcGateway)
        const ButtonItem(icon: Icons.shield_outlined, title: 'AWMC 网关', subtitle: '查询/写入机台账号数据（敏感操作）'),
      const ButtonItem(icon: Icons.dark_mode, title: '主题与背景', subtitle: '调整主题色、模式和背景图'),
    ]),
  ];
}
