// 一次性回填脚本：为 song_rankings 历史 dx_score 行补上 max_dx_score。
//
// 背景：在 max_dx_score 列加入之前写入的历史成绩，该列均为 NULL，
// 导致「平均DX得分达成率」恒为 0。App 端增量上传只会在玩家重新同步时
// 补回自己那份 max_dx_score，历史数据需要一次性回填。
//
// 计算逻辑与 flutter 端 SongRankingService._maxDxScoreOf 完全一致：
//   - UTAGE 双谱面（songId.length==6 && charts.length==2）：两张谱面 notes 之和 × 3
//   - 其它：charts[difficulty_index].notes 之和 × 3
//
// 用法：在服务器上执行  node backfill_max_dx_score.js
const mysql = require('mysql2/promise');
const https = require('https');

const dbConfig = {
  host: 'localhost',
  port: 3306,
  user: 'root',
  password: process.env.DB_PASSWORD || 'Maozedong001',
  database: 'user_maimai_rankings',
  waitForConnections: true,
  connectionLimit: 5,
  queueLimit: 0,
};

const MUSIC_DATA_API =
  'https://www.diving-fish.com/api/maimaidxprober/music_data';

function fetchMusicData() {
  return new Promise((resolve, reject) => {
    https
      .get(MUSIC_DATA_API, (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            reject(new Error('解析音乐数据失败: ' + e.message));
          }
        });
      })
      .on('error', (e) => reject(new Error('请求音乐数据失败: ' + e.message)));
  });
}

// 与客户端 _maxDxScoreOf 一致：返回 DX 满分（note 总数 × 3），无法计算返回 0
function maxDxScoreOf(song, difficultyIndex) {
  if (!song || !song.id || !Array.isArray(song.charts)) return 0;
  const isUtageDouble = song.id.length === 6 && song.charts.length === 2;
  if (isUtageDouble) {
    let total = 0;
    for (const chart of song.charts) {
      total += sumNotes(chart.notes);
    }
    return total * 3;
  }
  if (
    difficultyIndex < 0 ||
    difficultyIndex >= song.charts.length
  ) {
    return 0;
  }
  return sumNotes(song.charts[difficultyIndex].notes) * 3;
}

function sumNotes(notes) {
  if (!Array.isArray(notes)) return 0;
  return notes.reduce((acc, n) => acc + (Number(n) || 0), 0);
}

async function main() {
  const songs = await fetchMusicData();
  console.log(`[Backfill] 已获取歌曲数据: ${songs.length} 首`);

  const songById = new Map();
  for (const s of songs) {
    if (s.id) songById.set(s.id, s);
  }

  const db = mysql.createPool(dbConfig);

  const [rows] = await db.query(
    `SELECT DISTINCT song_id, difficulty_index
     FROM song_rankings
     WHERE ranking_type = 'dx_score'
       AND (max_dx_score IS NULL OR max_dx_score <= 0)`
  );
  console.log(`[Backfill] 缺少 max_dx_score 的 dx_score 谱面记录: ${rows.length} 条`);

  let updated = 0;
  let skipped = 0;
  for (const row of rows) {
    const song = songById.get(row.song_id);
    const maxDx = maxDxScoreOf(song, row.difficulty_index);
    if (maxDx <= 0) {
      skipped++;
      continue;
    }
    const [result] = await db.execute(
      `UPDATE song_rankings
       SET max_dx_score = ?
       WHERE song_id = ? AND difficulty_index = ?
         AND ranking_type = 'dx_score'
         AND (max_dx_score IS NULL OR max_dx_score <= 0)`,
      [maxDx, row.song_id, row.difficulty_index]
    );
    updated += result.affectedRows;
  }

  console.log(`[Backfill] 回填完成: 更新 ${updated} 行, 跳过(无谱面数据/无法计算) ${skipped} 行`);

  // 清除平均值排行榜缓存，避免读到旧值
  try {
    const redis = require('redis');
    const client = redis.createClient({
      url: 'redis://localhost:6379',
      password: process.env.REDIS_PASSWORD || 'Maozedong001',
    });
    client.on('error', () => {});
    await client.connect();
    await client.del('song_rankings:averages');
    await client.quit();
    console.log('[Backfill] 已清除 Redis 缓存 song_rankings:averages');
  } catch (e) {
    console.log('[Backfill] 清除 Redis 缓存失败(可忽略): ' + e.message);
  }

  await db.end();
}

main().catch((e) => {
  console.error('[Backfill] 失败:', e);
  process.exit(1);
});
