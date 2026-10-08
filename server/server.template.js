// ===========================================================================
// 说明：完整的生产 server.js 内联了「水鱼 OAuth 代理 /api/prober/*」
// （后端持有 client_secret 换票并代理查分器成绩读取）。本模板为精简骨架，未包含该段。
//
// 敏感项优先读环境变量，其次用 server.js 内默认值（server.js 已被 .gitignore 排除）：
//   DIVING_FISH_OAUTH_CLIENT_ID     水鱼账号 OAuth 应用 client_id
//   DIVING_FISH_OAUTH_CLIENT_SECRET 水鱼账号 OAuth 应用 client_secret
//   GATEWAY_API_KEY                 App↔后端 OAuth 代理的 API key
//   LUOXUE_OAUTH_CLIENT_ID          落雪 OAuth 应用 client_id
//   LUOXUE_OAUTH_CLIENT_SECRET      落雪 OAuth 应用 client_secret（只在服务端）
//   LUOXUE_OAUTH_REDIRECT_URI       落雪 OAuth 回调地址，默认 OOB
//   PROBER_SUBJECT_MODE             可选 'ref'(默认、长期) / 'qq'(仅过渡期)
//   AWMC_GATEWAY_TOKEN               AWMC 网关开发者令牌（只在服务端）
//   AWMC_NET_DEVELOPER_KEY           AWMC NET 开发者令牌（只在服务端）
// ===========================================================================
const express = require('express');
const http = require('http');
const https = require('https');
const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');
const mysql = require('mysql2/promise');
const redis = require('redis');

const app = express();
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: false }));
// Redis 凭据仅从环境变量读取；原统计 LIST 键名不变，历史样本继续可读。
const statsRedis = redis.createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379',
  password: process.env.REDIS_PASSWORD || undefined,
});
statsRedis.on('error', () => console.warn('同步统计 Redis 暂不可用'));
statsRedis.connect().catch(() => console.warn('同步统计 Redis 连接失败'));
require('./sync-stats').installSyncStats(app, () => statsRedis);
require('./awmc-proxy').installAwmcProxy(app);
require('./awmc-net-proxy').installAwmcNetProxy(app);
const loadingTips = require('./loading-tips');
loadingTips.installLoadingTips(app, () => db);
require('./special-rankings').installSpecialRankings(app, () => db, () => statsRedis);
// 生产环境应由 HTTPS 反向代理终止 TLS；应用本身只监听内网端口。
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

const PORT = process.env.PORT || 3000;
const GATEWAY_API_KEY = process.env.GATEWAY_API_KEY || '';
const LUOXUE_OAUTH_CLIENT_ID = process.env.LUOXUE_OAUTH_CLIENT_ID || '56a76019-2e7b-4650-abeb-082b8d5dede6';
const LUOXUE_OAUTH_CLIENT_SECRET = process.env.LUOXUE_OAUTH_CLIENT_SECRET || '';
const LUOXUE_OAUTH_REDIRECT_URI = process.env.LUOXUE_OAUTH_REDIRECT_URI || 'urn:ietf:wg:oauth:2.0:oob';

// 落雪 OAuth 换票代理：client_secret 只在服务端环境变量中保存，绝不下发到 App。
app.post('/api/luoxue/oauth/token', async (req, res) => {
  if (!LUOXUE_OAUTH_CLIENT_SECRET) {
    return res.status(503).json({ error: 'luoxue_oauth_not_configured' });
  }
  const grantType = String(req.body?.grant_type || '');
  const code = String(req.body?.code || '');
  const refreshToken = String(req.body?.refresh_token || '');
  if (grantType !== 'authorization_code' && grantType !== 'refresh_token') {
    return res.status(400).json({ error: 'unsupported_grant_type' });
  }
  if ((grantType === 'authorization_code' && !code) ||
      (grantType === 'refresh_token' && !refreshToken)) {
    return res.status(400).json({ error: 'invalid_request' });
  }
  const form = new URLSearchParams({
    grant_type: grantType,
    code,
    refresh_token: refreshToken,
    client_id: LUOXUE_OAUTH_CLIENT_ID,
    client_secret: LUOXUE_OAUTH_CLIENT_SECRET,
    redirect_uri: LUOXUE_OAUTH_REDIRECT_URI,
  }).toString();
  const upstream = https.request('https://maimai.lxns.net/api/v0/oauth/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Content-Length': Buffer.byteLength(form),
    },
  }, (upstreamResponse) => {
    const chunks = [];
    upstreamResponse.on('data', (chunk) => chunks.push(chunk));
    upstreamResponse.on('end', () => {
      let body;
      try { body = JSON.parse(Buffer.concat(chunks).toString('utf8')); }
      catch (_) { body = { error: 'invalid_upstream_response' }; }
      res.status(upstreamResponse.statusCode || 502).json(body);
    });
  });
  upstream.on('error', () => res.status(502).json({ error: 'upstream_unavailable' }));
  upstream.end(form);
});

// MySQL 数据库配置（生产环境必须通过环境变量注入）
const dbConfig = {
  host: process.env.DB_HOST || '替换为你的数据库主机地址',
  port: 3306,
  user: process.env.DB_USER || '替换为你的数据库用户名',
  password: process.env.DB_PASSWORD || '替换为你的数据库密码',
  database: process.env.DB_NAME || '替换为你的数据库名称',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

// 创建数据库连接池
let db;

async function connectDB() {
  try {
    db = mysql.createPool(dbConfig);
    
    // 验证连接池是否正常工作
    const connection = await db.getConnection();
    await connection.execute('SELECT 1');
    connection.release();
    
    console.log('MySQL 数据库连接成功');
    await initializeRankingsTable();
  } catch (err) {
    console.error('数据库连接失败:', err.message);
    process.exit(1);
  }
}

// 初始化排行榜表
async function initializeRankingsTable() {
  const createTableSQL = `
    CREATE TABLE IF NOT EXISTS user_maimai_rankings (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id VARCHAR(64) NOT NULL UNIQUE,
      username VARCHAR(128) NOT NULL,
      player_id VARCHAR(64),
      total_rating DECIMAL(10,2) DEFAULT 0,
      best35_rating DECIMAL(10,2) DEFAULT 0,
      rank INT DEFAULT 0,
      rank_change INT DEFAULT 0,
      data_source VARCHAR(32) DEFAULT 'unknown',
      last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
  `;

  const createIndexSQL = `
    CREATE INDEX IF NOT EXISTS idx_user_id ON user_maimai_rankings(user_id);
    CREATE INDEX IF NOT EXISTS idx_rank ON user_maimai_rankings(rank);
    CREATE INDEX IF NOT EXISTS idx_total_rating ON user_maimai_rankings(total_rating);
  `;

  try {
    await db.execute(createTableSQL);
    await db.execute(createIndexSQL);
    console.log('排行榜表初始化完成');
  } catch (err) {
    console.error('初始化排行榜表失败:', err.message);
  }
}

// 计算排名
async function calculateRankings() {
  try {
    // 获取所有用户的 rating 并排序
    const [rows] = await db.execute('SELECT user_id, total_rating FROM user_maimai_rankings ORDER BY total_rating DESC');
    
    let currentRank = 1;
    let prevRating = null;
    let sameRatingCount = 0;
    
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      
      if (prevRating === null || row.total_rating !== prevRating) {
        currentRank = i + 1;
        sameRatingCount = 1;
      } else {
        sameRatingCount++;
      }
      
      prevRating = row.total_rating;
      
      await db.execute(
        'UPDATE user_maimai_rankings SET rank = ? WHERE user_id = ?',
        [currentRank, row.user_id]
      );
    }
    
    console.log('排名计算完成');
  } catch (err) {
    console.error('计算排名失败:', err.message);
  }
}

// WebSocket 连接处理
wss.on('connection', (ws) => {
  console.log('新客户端连接');
  
  ws.on('message', async (message) => {
    try {
      const data = JSON.parse(message);
      
      switch (data.type) {
        case 'update_ranking':
          await handleRankingUpdate(data);
          break;
        case 'get_ranking':
          await handleGetRanking(ws);
          break;
        case 'get_user_rank':
          await handleGetUserRank(ws, data);
          break;
        default:
          console.log('未知消息类型:', data.type);
      }
    } catch (err) {
      console.error('处理消息失败:', err.message);
    }
  });
  
  ws.on('close', () => {
    console.log('客户端断开连接');
  });
  
  ws.on('error', (err) => {
    console.error('WebSocket 错误:', err.message);
  });
});

// 处理排名更新
async function handleRankingUpdate(data) {
  try {
    const { userId, username, playerId, totalRating, best35Rating } = data;
    
    const [existingRows] = await db.execute(
      'SELECT total_rating FROM user_maimai_rankings WHERE user_id = ?',
      [userId]
    );
    
    let rankChange = 0;
    
    if (existingRows.length > 0) {
      const oldRating = existingRows[0].total_rating;
      rankChange = totalRating > oldRating ? 1 : (totalRating < oldRating ? -1 : 0);
      
      await db.execute(
        `UPDATE user_maimai_rankings SET 
          username = ?, 
          player_id = ?, 
          total_rating = ?, 
          best35_rating = ?,
          rank_change = ?
        WHERE user_id = ?`,
        [username, playerId, totalRating, best35Rating, rankChange, userId]
      );
    } else {
      await db.execute(
        `INSERT INTO user_maimai_rankings (user_id, username, player_id, total_rating, best35_rating, rank_change)
        VALUES (?, ?, ?, ?, ?, 0)`,
        [userId, username, playerId, totalRating, best35Rating]
      );
    }
    
    await calculateRankings();
    
    console.log(`用户 ${username} 的排名已更新`);
  } catch (err) {
    console.error('更新排名失败:', err.message);
  }
}

// 处理获取排名列表
async function handleGetRanking(ws) {
  try {
    const [rows] = await db.execute(
      'SELECT user_id, username, player_id, total_rating, best35_rating, rank, rank_change, data_source, last_updated FROM user_maimai_rankings ORDER BY rank ASC LIMIT 100'
    );
    
    ws.send(JSON.stringify({
      type: 'ranking_list',
      data: rows
    }));
  } catch (err) {
    console.error('获取排名列表失败:', err.message);
  }
}

// 处理获取用户排名
async function handleGetUserRank(ws, data) {
  try {
    const { userId } = data;
    
    const [rows] = await db.execute(
      'SELECT user_id, username, player_id, total_rating, best35_rating, rank, rank_change, data_source, last_updated FROM user_maimai_rankings WHERE user_id = ?',
      [userId]
    );
    
    if (rows.length > 0) {
      ws.send(JSON.stringify({
        type: 'user_rank',
        data: rows[0]
      }));
    } else {
      ws.send(JSON.stringify({
        type: 'user_rank',
        data: null
      }));
    }
  } catch (err) {
    console.error('获取用户排名失败:', err.message);
  }
}

// 启动服务器
async function startServer() {
  await connectDB();
  await loadingTips.ensureLoadingTipsTable(() => db);
  
  server.listen(PORT, () => {
    console.log(`服务器运行在 http://localhost:${PORT}`);
    console.log('WebSocket 服务器已启动');
  });
}

startServer();
