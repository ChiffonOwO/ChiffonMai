const express = require('express');
const http = require('http');
const https = require('https');
const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');
const mysql = require('mysql2/promise');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

const PORT = process.env.PORT || 3000;

// MySQL 数据库配置
const dbConfig = {
  host: '替换为你的数据库主机地址',
  port: 3306,
  user: '替换为你的数据库用户名',
  password: '替换为你的数据库密码',
  database: '替换为你的数据库名称',
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
  
  server.listen(PORT, () => {
    console.log(`服务器运行在 http://localhost:${PORT}`);
    console.log('WebSocket 服务器已启动');
  });
}

startServer();