'use strict';

const https = require('node:https');
const TYPES = ['breakCount', 'difficultyDiff', 'masterDiff', 'expertDiff', 'sampleCount',
  'noteCount', 'avgAchievement', 'masterAvgAchievement', 'expertAvgAchievement', 'bpmRanking'];
const SNAPSHOT_AGE = 6 * 60 * 60 * 1000;
const CACHE_TTL = 300;

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    const request = https.get(url, { headers: { 'Accept': 'application/json' } }, response => {
      if (response.statusCode !== 200) { response.resume(); return reject(new Error(`upstream_${response.statusCode}`)); }
      let raw = '';
      response.setEncoding('utf8');
      response.on('data', chunk => {
        raw += chunk;
        if (raw.length > 20 * 1024 * 1024) request.destroy(new Error('upstream_too_large'));
      });
      response.on('error', reject);
      response.on('end', () => { try { resolve(JSON.parse(raw)); } catch (error) { reject(error); } });
    });
    request.setTimeout(20000, () => request.destroy(new Error('upstream_timeout')));
    request.on('error', reject);
  });
}

function buildRankings(songs, stats, now = Date.now()) {
  if (!Array.isArray(songs) || !songs.length || !stats?.charts || !Object.keys(stats.charts).length) {
    throw new Error('invalid_upstream_data');
  }
  const result = Object.fromEntries(TYPES.map(type => [type, []]));
  const labels = ['BASIC', 'ADVANCED', 'EXPERT', 'MASTER', 'Re:MASTER'];
  const add = (type, entry, metric) => {
    if (Number.isFinite(metric)) result[type].push({ ...entry, metric, breakCount: Math.trunc(metric) });
  };
  for (const song of songs) {
    const id = String(song.id);
    if (!Array.isArray(song.ds) || !Array.isArray(song.charts)) continue;
    for (let index = 0; index < song.ds.length; index++) {
      // 宴会双谱面的旧榜单只统计首个谱面，保持客户端原有行为。
      if (id.length === 6 && index > 0) continue;
      const chart = song.charts[index];
      if (!chart) continue;
      const entry = { songId: id, songTitle: song.title, songType: song.type,
        difficultyIndex: index, difficultyLabel: id.length === 6 ? 'UTAGE' : labels[index],
        ds: Number(song.ds[index]), updateTime: now };
      const notes = chart.notes;
      if (Array.isArray(notes) && notes.length >= 4 && notes.every(Number.isFinite)) {
        add('breakCount', entry, notes[notes.length - 1]);
        add('noteCount', entry, notes.reduce((sum, count) => sum + count, 0));
      }
      // BPM 每首歌只收录一次。
      if (index === 0) add('bpmRanking', { ...entry, difficultyLabel: 'BPM', ds: 0 }, Number(song.basic_info?.bpm));
      const data = stats.charts[id]?.[index];
      if (!data) continue;
      const fitted = Number(data.fit_diff);
      if (fitted > 0 && entry.ds > 0) {
        const diff = (fitted - entry.ds) * 100;
        add('difficultyDiff', entry, diff);
        if (index >= 3) add('masterDiff', entry, diff);
        if (index === 2) add('expertDiff', entry, diff);
      }
      const samples = Array.isArray(data.dist) ? data.dist.reduce((sum, value) => sum + Number(value || 0), 0) : Number(data.cnt);
      if (samples > 0) add('sampleCount', entry, samples);
      const avg = Number(data.avg);
      if (avg > 0) {
        add('avgAchievement', entry, avg * 100);
        if (index >= 3) add('masterAvgAchievement', entry, avg * 100);
        if (index === 2) add('expertAvgAchievement', entry, avg * 100);
      }
    }
  }
  for (const entries of Object.values(result)) {
    entries.sort((a, b) => b.metric - a.metric || Number(a.songId) - Number(b.songId) || a.difficultyIndex - b.difficultyIndex);
    // 度量单独保留用于排序，避免小数转整数导致正反榜次序不准确。
  }
  if (TYPES.some(type => result[type].length === 0)) throw new Error('incomplete_upstream_rankings');
  return result;
}

function installSpecialRankings(app, getDb, getRedis, options = {}) {
  let schema;
  let rebuilding;
  let retryAfter = 0;
  const upstream = options.fetchJson || fetchJson;
  const ensureSchema = async () => {
    if (!schema) {
      schema = getDb().query(`CREATE TABLE IF NOT EXISTS special_ranking_snapshots (
        ranking_type VARCHAR(40) NOT NULL PRIMARY KEY,
        payload JSON NOT NULL,
        updated_at BIGINT NOT NULL
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`).catch(error => { schema = null; throw error; });
    }
    await schema;
  };
  const rebuild = async () => {
    if (rebuilding) return rebuilding;
    rebuilding = (async () => {
      await ensureSchema();
      const [songs, stats] = await Promise.all([
        upstream('https://www.diving-fish.com/api/maimaidxprober/music_data'),
        upstream('https://www.diving-fish.com/api/maimaidxprober/chart_stats'),
      ]);
      const now = Date.now();
      const rankings = buildRankings(songs, stats, now);
      const connection = await getDb().getConnection();
      try {
        await connection.beginTransaction();
        for (const type of TYPES) await connection.execute(
          `INSERT INTO special_ranking_snapshots (ranking_type, payload, updated_at) VALUES (?, ?, ?)
           ON DUPLICATE KEY UPDATE payload = VALUES(payload), updated_at = VALUES(updated_at)`,
          [type, JSON.stringify(rankings[type]), now]);
        await connection.commit();
      } catch (error) { await connection.rollback(); throw error; }
      finally { connection.release(); }
      retryAfter = 0;
      return rankings;
    })().catch(error => { retryAfter = Date.now() + 60000; throw error; }).finally(() => { rebuilding = null; });
    return rebuilding;
  };
  app.get('/api/special-rankings', async (req, res) => {
    const type = String(req.query.type || 'breakCount');
    if (!TYPES.includes(type)) return res.status(400).json({ success: false, error: 'invalid_ranking_type' });
    const requestedLimit = Number(req.query.limit || 100);
    if (!Number.isInteger(requestedLimit) || requestedLimit < 1 || requestedLimit > 1000) {
      return res.status(400).json({ success: false, error: 'invalid_limit' });
    }
    const reverse = req.query.reverse === 'true';
    const forceRefresh = req.query.refresh === 'true';
    const cacheKey = `special:http:v1:${type}:${reverse}:${requestedLimit}`;
    // 缓存只保存短期、已分页的 HTTP 响应，不再让手机写 Redis 大列表。
    const cache = getRedis?.();
    if (!forceRefresh && cache?.isReady) {
      try { const cached = await cache.get(cacheKey); if (cached) return res.json(JSON.parse(cached)); } catch (_) {}
    }
    try {
      await ensureSchema();
      const [rows] = await getDb().execute('SELECT payload, updated_at FROM special_ranking_snapshots WHERE ranking_type = ?', [type]);
      let data;
      let updatedAt;
      if (!rows.length) {
        if (Date.now() < retryAfter) throw new Error('upstream_retry_later');
        data = (await rebuild())[type];
        updatedAt = data[0].updateTime;
      } else {
        data = typeof rows[0].payload === 'string' ? JSON.parse(rows[0].payload) : rows[0].payload;
        updatedAt = Number(rows[0].updated_at);
        // 上游暂不可用时仍返回最后一次完整快照，更新在后台执行。
        if (Date.now() - updatedAt > SNAPSHOT_AGE && Date.now() >= retryAfter) {
          rebuild().catch(() => console.warn('特殊排行榜更新失败，继续使用 MySQL 快照'));
        }
      }
      const sorted = reverse ? data.slice().reverse() : data;
      const response = { success: true, type, total: data.length, updatedAt,
        stale: Date.now() - updatedAt > SNAPSHOT_AGE,
        data: sorted.slice(0, requestedLimit).map((entry, index) => ({ ...entry, rank: index + 1 })) };
      if (cache?.isReady) { try { await cache.set(cacheKey, JSON.stringify(response), { EX: CACHE_TTL }); } catch (_) {} }
      return res.json(response);
    } catch (error) {
      console.warn('特殊排行榜读取失败:', error.code || error.message);
      return res.status(503).json({ success: false, error: 'special_rankings_unavailable' });
    }
  });
  return { rebuild };
}

module.exports = { TYPES, buildRankings, installSpecialRankings };
