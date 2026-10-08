// 同步统计只经 HTTP 代理读写固定槽位，不向客户端暴露 Redis 凭据或命令。
const SLOTS = ['scorehub:fish', 'scorehub:lx', 'awmc:fish', 'awmc:lx', 'direct:awmc'];
const PREFIX = 'chiffonmai:sync_stats';

function installSyncStats(app, getRedis) {
  // 匿名统计仅供参考。限流由 HTTPS 入口执行，写入还需限制耗时及槽位。
  app.get('/api/sync-stats', async (req, res) => {
    const slots = req.query.slots === undefined
      ? SLOTS : String(req.query.slots).split(',');
    if (!slots.length || slots.length > SLOTS.length || slots.some(s => !SLOTS.includes(s))) {
      return res.status(400).json({ success: false, error: 'invalid_slots' });
    }
    const client = getRedis();
    if (!client?.isReady) {
      return res.status(503).json({ success: false, error: 'stats_unavailable' });
    }
    try {
      const data = {};
      for (const slot of new Set(slots)) {
        data[slot] = await client.lRange(`${PREFIX}:${slot}`, 0, 99);
      }
      return res.json({ success: true, data });
    } catch (_) {
      return res.status(503).json({ success: false, error: 'stats_unavailable' });
    }
  });

  app.post('/api/sync-stats', async (req, res) => {
    const { line, platform, durationMs, ok } = req.body || {};
    const slot = `${line}:${platform}`;
    if (!SLOTS.includes(slot) || !Number.isInteger(durationMs) ||
        durationMs <= 0 || durationMs > 30 * 60 * 1000 || typeof ok !== 'boolean') {
      return res.status(400).json({ success: false, error: 'invalid_sample' });
    }
    const client = getRedis();
    if (!client?.isReady) {
      return res.status(503).json({ success: false, error: 'stats_unavailable' });
    }
    try {
      const key = `${PREFIX}:${slot}`;
      const entry = JSON.stringify({ t: Date.now(), d: durationMs, ok: ok ? 1 : 0 });
      await client.multi().lPush(key, entry).lTrim(key, 0, 99)
        .expire(key, 30 * 24 * 3600).exec();
      return res.status(201).json({ success: true });
    } catch (_) {
      return res.status(503).json({ success: false, error: 'stats_unavailable' });
    }
  });
}

module.exports = { installSyncStats };
