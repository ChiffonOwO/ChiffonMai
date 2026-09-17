// ===========================================================================
// 生成「dxrating 曲绘兜底」的基线索引（assets/dxrating_cover_index.json）
//
// 为什么要有这个文件：dxdata 有 4MB，实测从 miruku.dxrating.net 下载要 **200s+**
// （≈20KB/s），App 运行时根本等不起 —— 所以随包带一份基线索引，
// 曲绘兜底立刻可用、且不产生任何服务器压力；运行时只会「有机会时」尝试更新。
//
// 索引结构（与 lib/service/DxRatingCoverService.dart 的 cacheVersion 对应）：
//   { "v": 1, "generatedAt": "<ISO>", "source": "dxdata|<url>", "count": N,
//     "images": { "<基础 songId>": "<imageName>", ... } }
//
// 基础 songId 的归一化规则：dxdata 里 DX 谱面的 internalId = 10000 + 基础 id
// （实测：君の知らない物語 std=181 / dx=10181），水鱼的 DX 条目 id 同理，
// 所以 10000~19999 一律减 10000；6 位（宴会场，100000+）原样。
//
// 用法（改完记得跑一次，索引会随包发布）：
//   node tool/gen_dxrating_cover_index.cjs                 # 在线拉 dxdata
//   node tool/gen_dxrating_cover_index.cjs <本地dxdata.json>  # 用本地文件（离线）
// ===========================================================================
const fs = require('fs');
const path = require('path');
const https = require('https');

const DX_DATA_URL = 'https://miruku.dxrating.net/api/v1/dxdata';
const OUT = path.join(__dirname, '..', 'assets', 'dxrating_cover_index.json');
const CACHE_VERSION = 1;

function normalizeSongId(raw) {
  const n = Number(raw);
  if (!Number.isFinite(n)) return String(raw);
  if (n >= 10000 && n < 20000) return String(n - 10000);
  return String(n);
}

function download(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, (res) => {
        if (res.statusCode !== 200) {
          reject(new Error(`HTTP ${res.statusCode}`));
          res.resume();
          return;
        }
        const chunks = [];
        res.on('data', (c) => {
          chunks.push(c);
          process.stdout.write(
            `\r  已下载 ${(chunks.reduce((a, b) => a + b.length, 0) / 1024 / 1024).toFixed(2)} MB`
          );
        });
        res.on('end', () => {
          process.stdout.write('\n');
          resolve(Buffer.concat(chunks).toString('utf8'));
        });
      })
      .on('error', reject);
  });
}

(async () => {
  const local = process.argv[2];
  const t0 = Date.now();
  let raw;
  let source;
  if (local) {
    console.log(`读取本地 dxdata: ${local}`);
    raw = fs.readFileSync(local, 'utf8');
    source = `local:${path.basename(local)}`;
  } else {
    console.log(`拉取 ${DX_DATA_URL}（实测要 200s+，耐心等）…`);
    raw = await download(DX_DATA_URL);
    source = DX_DATA_URL;
  }
  const dx = JSON.parse(raw);
  console.log(`dxdata: ${dx.songs.length} 首歌，updatedAt=${dx.updatedAt}`);

  const images = {};
  let skipped = 0;
  for (const song of dx.songs) {
    const imageName = song.imageName;
    if (!imageName) {
      skipped++;
      continue;
    }
    for (const sheet of song.sheets) {
      const id = sheet.internalId;
      if (id == null || id <= 0) continue;
      const key = normalizeSongId(id);
      if (!(key in images)) images[key] = imageName;
    }
  }

  const payload = {
    v: CACHE_VERSION,
    generatedAt: new Date().toISOString(),
    source,
    dxdataUpdatedAt: dx.updatedAt,
    count: Object.keys(images).length,
    images,
  };
  fs.writeFileSync(OUT, JSON.stringify(payload));
  const kb = (fs.statSync(OUT).size / 1024).toFixed(0);
  console.log(
    `已写出 ${OUT}\n  ${payload.count} 条 / ${kb} KB / 跳过无 imageName 的歌 ${skipped} 首 / 耗时 ${(
      (Date.now() - t0) / 1000
    ).toFixed(1)}s`
  );
})();
