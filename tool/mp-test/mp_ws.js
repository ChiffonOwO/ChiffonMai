// 解析 ws 依赖。
//
// 测试脚本放在 tool/mp-test/，而 ws 装在 server/node_modules（本地测试服的依赖）。
// Node 的模块解析是**按脚本所在目录**向上找 node_modules，不是按 cwd，
// 所以直接从 tool/ 里 require('ws') 会 MODULE_NOT_FOUND。
// 这里先走常规解析（便于在装了 ws 的环境里直接用），失败再回退到 server/。
const path = require('path');

let WebSocket;
try {
  WebSocket = require('ws');
} catch (_) {
  WebSocket = require(path.join(__dirname, '..', '..', 'server', 'node_modules', 'ws'));
}

module.exports = WebSocket;