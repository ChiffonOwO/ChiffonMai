/**
 * 友情链接目录。
 *
 * 友链只读接口，数据库凭据留在服务端，不下发到客户端。
 */
async function ensureFriendLinksTable(getDb) {
  const db = typeof getDb === 'function' ? getDb() : null;
  if (!db) throw new Error('database_unavailable');
  await db.execute(`
    CREATE TABLE IF NOT EXISTS friend_links (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(128) NOT NULL,
      description VARCHAR(500) NOT NULL,
      url VARCHAR(2048) NOT NULL,
      icon_type VARCHAR(32) NOT NULL DEFAULT 'web',
      icon_color CHAR(7) NOT NULL DEFAULT '#5C6BC0',
      sort_order INT NOT NULL DEFAULT 0,
      enabled TINYINT(1) NOT NULL DEFAULT 1,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      KEY idx_friend_links_enabled_order (enabled, sort_order, id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);
}

async function readFriendLinks(getDb) {
  const db = typeof getDb === 'function' ? getDb() : null;
  if (!db) throw new Error('database_unavailable');
  const [rows] = await db.execute(`
    SELECT id, name, description, url, icon_type, icon_color
    FROM friend_links
    WHERE enabled = 1
    ORDER BY sort_order ASC, id ASC
  `);
  return rows;
}

function installFriendLinks(app, getDb) {
  app.get('/api/friend-links', async (_req, res) => {
    try {
      await ensureFriendLinksTable(getDb);
      res.set('Cache-Control', 'no-cache').json({
        version: 1,
        links: await readFriendLinks(getDb),
      });
    } catch (error) {
      console.error('friend links catalogue unavailable:', error.message);
      res.status(503).json({ error: 'friend_links_unavailable' });
    }
  });
}

module.exports = { ensureFriendLinksTable, readFriendLinks, installFriendLinks };
