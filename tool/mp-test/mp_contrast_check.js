// 对比度校验：验证 AppTheme 新增的语义色对在浅色/暗色主题下都可读。
//
// 起因：多人房间页原先用 Colors.green[100] / Colors.yellow[50] 这类硬编码浅色，
// 暗色主题下是亮斑。改用 successSurface/successForeground 等成对颜色后，
// 这里用 WCAG 的相对亮度公式算实际对比度，避免"看着还行"这种主观判断。
function srgbToLin(c) {
  const s = c / 255;
  return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
}
function lum(hex) {
  const h = hex.replace('#', '');
  const r = parseInt(h.slice(0, 2), 16);
  const g = parseInt(h.slice(2, 4), 16);
  const b = parseInt(h.slice(4, 6), 16);
  return 0.2126 * srgbToLin(r) + 0.7152 * srgbToLin(g) + 0.0722 * srgbToLin(b);
}
function contrast(a, b) {
  const la = lum(a), lb = lum(b);
  const hi = Math.max(la, lb), lo = Math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

// 从 lib/utils/AppTheme.dart 里抠出来的实际取值
const pairs = [
  // [名称, 前景, 背景, 是否正文级(需 >=4.5)]
  ['成功：答对横幅（浅色）',   '2E7D32', 'E7F6E9', true],
  ['成功：答对横幅（暗色）',   '8BD48F', '1B3A22', true],
  ['信息：房主提示（浅色）',   '1565C0', 'E3F2FD', true],
  ['信息：房主提示（暗色）',   '9CC7F0', '1B2E3F', true],
  ['排行榜前三名底色 vs 正文（浅色）', '546161', 'FFF7E0', true],
  ['排行榜前三名底色 vs 正文（暗色）', 'B0C4C4', '37301C', true],
];

// 对照：改动之前的硬编码颜色
const legacy = [
  ['旧-答对横幅（暗色）Colors.green on green[100]', '4CAF50', 'C8E6C9', true],
  ['旧-排行榜前三名（暗色）正文 on yellow[50]',      'B0C4C4', 'FFFDE7', true],
  ['旧-房主变更（暗色）blue[800] on blue[100]',      '1565C0', 'BBDEFB', true],
];

let fail = 0;
// 只在检查「新配色」时计入失败；对照组的旧配色本来就是拿来证明问题的
function report(title, rows, countFailure = true) {
  console.log(title);
  for (const [name, fg, bg, needBody] of rows) {
    const c = contrast(fg, bg);
    const min = needBody ? 4.5 : 3.0;
    const ok = c >= min;
    if (!ok && countFailure) fail++;
    console.log(`  ${ok ? '[PASS]' : '[FAIL]'} ${name}  对比度=${c.toFixed(2)} (需 >= ${min})`);
  }
}

report('=== 新配色（应全部通过）===', pairs);
console.log('');
report('=== 改动前的硬编码配色（对照，不计入失败）===', legacy, false);

console.log('');
console.log(fail === 0
  ? '================ 汇总: 新配色全部达标 ================'
  : '================ 汇总: 有 ' + fail + ' 项不达标 ================');
process.exit(fail === 0 ? 0 : 1);
