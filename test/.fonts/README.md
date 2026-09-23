# test/.fonts/README.md
把测试用的**真机字体**放这里，让「B50 卡片达成率对齐」这类**像素级**测试和真机同口径。

* `NotoSansSC-Bold.ttf` —— Google Fonts 的 **Noto Sans SC Bold**（v40），也就是
  App 里 `google_fonts` 在真机上加载的那份。字体**带 hinting**，字形墨迹在像素格上
  的吸附行为和真机一致；换成别的字体（比如微软雅黑）墨迹几何就对不上了。

  重新获取：`https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght@700`
  （旧 UA 会返回 ttf）→ 下下来的文件前面有 292 字节的包头，从 `00 01 00 00` 处截断即可。

  没有这个文件时 `test/support/real_fonts.dart` 会退回 Windows 自带的
  `NotoSansSC-VF.ttf` / 微软雅黑，测试仍然跑，但只是"近似"。
