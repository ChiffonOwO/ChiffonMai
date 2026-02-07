# ChiffonMai

<div align="center">
  <img src="https://img.shields.io/badge/Platform-Android/iOS-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/Language-Dart/Flutter-blue.svg" alt="Language">
  <img src="https://img.shields.io/badge/Purpose-Maimai%20DX%20Tool-green.svg" alt="Purpose">
</div>

<br>

ChiffonMai 是一款专为 **舞萌DX (Maimai DX)** 玩家打造的一站式移动端工具类应用，聚合了曲库查询、成绩统计、Rating计算、曲目推荐等多种实用功能，助力玩家提升游玩体验。

## ✨ 核心功能

| 功能模块 | 功能描述 |
|---------|---------|
| 🎵 乐曲查询 | 完整查询舞萌DX曲库的所有乐曲信息 |
| 📊 成绩查询 | 查看个人游玩数据、成绩记录 |
| 🏆 Best50查询 | 计算并展示个人Best50成绩（龙币！） |
| 📈 拟合Best50查询 | 分析Best50拟合情况，解决"w55拟合才w52"的问题 |
| 🎯 基于Best50推荐 | 根据你的Best50成绩智能推荐适合的曲目 |
| 🎼 基于流派推荐 | 按你常玩的曲目流派个性化推荐 |
| 🏷️ 基于标签推荐 | 基于谱面标签（如难度、风格）精准推荐曲目 |
| 🔀 随机乐曲 | 随机生成1-4首曲目，解决选曲困难症 |
| 🧮 单曲Rating计算 | 计算单曲Rating，判断"鸟加有没有分吃" |
| 📉 达成率计算 | 根据判定详情（Perfect/Great等）精准算出达成率 |
| 🆚 版本对照 | 查询各版本必打曲目（舞神必备） |
| 🔍 达成率反推 | 根据达成率反推绝赞/良判等判定详情 |
| 📱 绑定二维码 | 关联你的舞萌DX账号，同步游戏数据 |

## 📱 适配说明

- 支持Android/iOS双平台
- 适配主流移动端分辨率
- 无性能门槛，低配设备流畅运行

## 🛠️ 技术栈

- 开发框架：Flutter
- 编程语言：Dart
- 状态管理：根据实际使用框架填写（如Provider/Bloc/GetX）
- 网络请求：Dio
- 本地存储：Hive/SQLite

## 📥 安装方式

### 安卓端
1. 下载最新版APK文件（Releases页面）
2. 允许安装未知来源应用
3. 安装并打开应用

### iOS端
1. 通过TestFlight测试版安装 或
2. App Store上架后直接搜索"ChiffonMai"下载

## 📄 隐私说明

- 应用仅在本地存储你的游戏数据，不会上传至第三方服务器
- 账号绑定仅用于同步官方数据，不会收集敏感信息
- 所有计算逻辑均在本地完成，保障数据安全

## 🤝 贡献指南

1. Fork本仓库
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交修改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开Pull Request

## 📝 许可证

本项目采用 [MIT License](LICENSE) 开源许可证，详细条款请查看LICENSE文件。

## 💡 免责声明

- ChiffonMai 是第三方工具，非SEGA官方出品
- 本应用仅用于学习和娱乐，请勿用于商业用途
- 数据来源均为公开信息，如有侵权请联系删除

## 📞 反馈与建议

- GitHub Issues：提交Bug反馈/功能建议
- 交流群：[可选] 填写QQ/微信群号
- 邮箱：[可选] 填写联系邮箱

## 🎉 致谢

- 感谢所有舞萌DX玩家的测试和反馈
- 感谢MaimaiDX相关数据开源社区的支持
- 致敬SEGA开发的优秀音游作品