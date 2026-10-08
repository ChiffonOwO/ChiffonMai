const fs = require('fs');
const path = require('path');

const defaultFile = path.join(__dirname, 'data', 'loading-tips.json');

function readTipsFromFile() {
  const file = process.env.LOADING_TIPS_FILE || defaultFile;
  const parsed = JSON.parse(fs.readFileSync(file, 'utf8'));
  const list = Array.isArray(parsed) ? parsed : parsed.tips;
  if (!Array.isArray(list)) throw new Error('tips must be an array');
  const tips = [];
  const ids = new Set();
  for (const item of list) {
    const id = String(item?.id || '').trim();
    const text = String(item?.text || '').trim();
    if (!id || !text || ids.has(id)) continue;
    ids.add(id);
    tips.push({ id, text });
  }
  if (!tips.length) throw new Error('empty tips catalogue');
  return tips;
}

async function readTips(getDb) {
  const db = typeof getDb === 'function' ? getDb() : null;
  if (db) {
    const [rows] = await db.execute(
      'SELECT tip_id AS id, tip_text AS text FROM loading_tips WHERE enabled = 1 ORDER BY sort_order ASC, id ASC',
    );
    // 全部停用时返回空目录，不能把 JSON 中已停用的语录重新展示出来。
    return rows;
  }
  return readTipsFromFile();
}

function installLoadingTips(app, getDb) {
  app.get('/api/loading-tips', async (_req, res) => {
    try {
      // 兼容未执行启动初始化的旧生产进程，先确保数据库表存在。
      await ensureLoadingTipsTable(getDb);
      res.set('Cache-Control', 'no-cache').json({ version: 1, tips: await readTips(getDb) });
    } catch (error) {
      console.error('loading tips catalogue unavailable:', error.message);
      res.status(503).json({ error: 'loading_tips_unavailable' });
    }
  });
  app.post('/api/loading-tips', async (req, res) => {
    const text = String(req.body?.text || '').trim();
    if (!text || text.length > 500) return res.status(400).json({ error: 'invalid_tip_text' });
    const db = typeof getDb === 'function' ? getDb() : null;
    if (!db) return res.status(503).json({ error: 'loading_tips_unavailable' });
    try {
      // 兼容未执行启动初始化的旧生产进程，避免上传因缺表直接返回 500。
      await ensureLoadingTipsTable(getDb);
      const [[row]] = await db.execute(
        "SELECT COALESCE(MAX(CAST(SUBSTRING(tip_id, 8) AS UNSIGNED)), 0) AS n, COALESCE(MAX(sort_order), 0) AS sort_order FROM loading_tips WHERE tip_id LIKE 'normal_%'",
      );
      const n = Number(row.n || 0) + 1;
      const tipId = `normal_${String(n).padStart(3, '0')}`;
      const sortOrder = Number(row.sort_order || 0) + 1;
      await db.execute(
        'INSERT INTO loading_tips (tip_id, tip_text, enabled, sort_order) VALUES (?, ?, 0, ?)',
        [tipId, text, sortOrder],
      );
      return res.status(201).json({ tip_id: tipId, sort_order: sortOrder, enabled: 0 });
    } catch (error) {
      console.error('loading tip submission failed:', error.message);
      return res.status(500).json({ error: 'loading_tip_submission_failed' });
    }
  });
}

async function ensureLoadingTipsTable(getDb) {
  const db = typeof getDb === 'function' ? getDb() : null;
  if (!db) return;
  await db.execute(`
    CREATE TABLE IF NOT EXISTS loading_tips (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
      tip_id VARCHAR(96) NOT NULL UNIQUE,
      tip_text TEXT NOT NULL,
      enabled TINYINT(1) NOT NULL DEFAULT 1,
      sort_order INT NOT NULL DEFAULT 0,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);
}

module.exports = { installLoadingTips, ensureLoadingTipsTable };
