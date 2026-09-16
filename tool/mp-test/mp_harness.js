// ===========================================================================
// 多人猜歌游戏 —— 本地测试服
//
// 用法：node tool/mp-test/mp_harness.js        （默认监听 3999）
//
// 为什么不是一份 server.js 的副本：
//   server/ 里那份 server.js 才是生产代码（且被 .gitignore 排除，含 client_secret
//   等敏感项）。如果把它的内容复制一份到这里，两边**一定会漂移** —— 修了
//   server.js 忘了同步副本，测试就会对着旧逻辑全绿，这种假绿比没测更糟。
//   所以这里改成**运行时派生**：读 server.js，就地打上「跳过 MySQL/Redis/
//   拟合定数缓存 + 换端口 + 敏感项改读环境变量」这几处测试专用改动，
//   写到 server/ 下的临时文件再启动。测试跑的一定是当前 server.js 的逻辑。
//
// 因此本脚本需要 server/server.js 存在（本来跑服务端也得有它）。
// ===========================================================================
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const serverDir = path.join(__dirname, '..', '..', 'server');
const sourcePath = path.join(serverDir, 'server.js');
const runtimePath = path.join(serverDir, '.mp_harness.runtime.js');

if (!fs.existsSync(sourcePath)) {
  console.error('[测试服] 找不到 ' + sourcePath);
  console.error('[测试服] 本脚本需要生产 server.js 才能派生测试服（它被 .gitignore 排除）。');
  console.error('[测试服] 请先在 server/ 下放好 server.js 再运行。');
  process.exit(1);
}

let code = fs.readFileSync(sourcePath, 'utf8');
const original = code;

// 1) 端口：避免和本地/线上服务撞车
code = code.replace("const PORT = 3000;", "const PORT = process.env.PORT || 3999;");

// 2) 跳过需要凭据/外网的三步启动流程
code = code.replace(
  "  await connectDB();",
  "  console.log('[TEST] 跳过 MySQL（本地无凭据）');"
);
code = code.replace(
  "  await connectRedis();",
  "  console.log('[TEST] 跳过 Redis');"
);
code = code.replace(
  "  await initializeChartStatsCache();",
  "  console.log('[TEST] 跳过拟合定数缓存（需要外网）');"
);

// 3) 敏感项兜底值脱敏：即使有人把派生文件误提交，也不含真实密钥
code = code.replace(
  /const DIVING_FISH_OAUTH_CLIENT_SECRET = '[^']*';/,
  "const DIVING_FISH_OAUTH_CLIENT_SECRET = process.env.DIVING_FISH_OAUTH_CLIENT_SECRET || '';"
);
code = code.replace(
  /const DIVING_FISH_OAUTH_CLIENT_ID = '[^']*';/,
  "const DIVING_FISH_OAUTH_CLIENT_ID = process.env.DIVING_FISH_OAUTH_CLIENT_ID || '';"
);
code = code.replace(
  /const GATEWAY_API_KEY = '[^']*';/,
  "const GATEWAY_API_KEY = process.env.GATEWAY_API_KEY || '';"
);
code = code.replace(
  /password: '[^']*',(\s*\/\/[^\n]*)?/g,
  "password: process.env.REDIS_PASSWORD || '',"
);

// 派生失败要在启动前就暴露，而不是让测试对着「没改过的 server.js」跑
const mustApply = [
  ["const PORT = process.env.PORT || 3999;", '端口替换'],
  ["[TEST] 跳过 MySQL（本地无凭据）", '跳过 MySQL'],
  ["[TEST] 跳过 Redis", '跳过 Redis'],
];
for (const [needle, label] of mustApply) {
  if (!code.includes(needle)) {
    console.error('[测试服] ' + label + ' 未生效 —— server.js 的对应代码可能已被改动。');
    console.error('[测试服] 请检查本脚本顶部的 replace 规则是否还匹配当前 server.js。');
    process.exit(1);
  }
}

fs.writeFileSync(runtimePath, code, 'utf8');
console.log('[测试服] 已从 server.js 派生测试服（端口 ' + (process.env.PORT || 3999) + '）');

const child = spawn(process.execPath, [runtimePath], { cwd: serverDir, stdio: 'inherit' });

function cleanup() {
  try { fs.unlinkSync(runtimePath); } catch (_) {}
}
child.on('exit', (code2) => { cleanup(); process.exit(code2 == null ? 0 : code2); });
process.on('SIGINT', () => { child.kill(); cleanup(); process.exit(0); });
process.on('SIGTERM', () => { child.kill(); cleanup(); process.exit(0); });