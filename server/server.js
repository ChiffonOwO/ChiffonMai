const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

const PORT = process.env.PORT || 80;

// 全局房间存储
const rooms = new Map();
// 全局玩家存储
const players = new Map();

// 玩家类
class Player {
  constructor(id, nickname) {
    this.id = id;
    this.nickname = nickname;
    this.ready = false;
    this.score = 0;
    this.surrendered = false;
    this.socket = null;
    this.currentRoomId = null;
  }
}

// 生成6位数字房间码
function generateRoomCode() {
  let code;
  do {
    code = Math.floor(Math.random() * 1000000).toString().padStart(6, '0');
  } while (Array.from(rooms.values()).some(room => room.code === code));
  return code;
}

// 房间类
class Room {
  constructor(id, gameType, maxPlayers, timeLimit, maxGuesses, totalRounds, hostId) {
    this.id = id;
    this.code = generateRoomCode(); // 6位房间码
    this.gameType = gameType;
    this.maxPlayers = maxPlayers;
    this.timeLimit = timeLimit;
    this.maxGuesses = maxGuesses;
    this.totalRounds = totalRounds;
    this.players = [];
    this.hostId = hostId; // 房主ID
    this.status = 'waiting'; // waiting, playing, ended
    this.currentRound = 0;
    this.currentSong = null;
    this.gameState = null;
    this.guesses = [];
    this.roundTimer = null;
    this.createdAt = Date.now();
    this.lastActivityAt = Date.now();
    this.isRoundOver = false; // 回合是否结束
  }

  // 更新最后活动时间
  updateActivity() {
    this.lastActivityAt = Date.now();
  }

  // 添加玩家
  addPlayer(player) {
    if (this.players.length >= this.maxPlayers) return false;
    if (this.players.find(p => p.id === player.id)) return false;
    
    player.currentRoomId = this.id;
    player.ready = false;
    player.surrendered = false;
    this.players.push(player);
    this.updateActivity();
    return true;
  }

  // 移除玩家
  removePlayer(playerId) {
    const index = this.players.findIndex(p => p.id === playerId);
    if (index === -1) return null;
    
    const removedPlayer = this.players.splice(index, 1)[0];
    removedPlayer.currentRoomId = null;
    this.updateActivity();
    
    // 如果移除的是房主，转移房主身份
    if (this.hostId === playerId && this.players.length > 0) {
      this.hostId = this.players[0].id;
    }
    
    return removedPlayer;
  }

  // 更新玩家准备状态
  updatePlayerReady(playerId, ready) {
    const player = this.players.find(p => p.id === playerId);
    if (!player) return false;
    player.ready = ready;
    this.updateActivity();
    return true;
  }

  // 设置玩家投降
  setPlayerSurrendered(playerId) {
    const player = this.players.find(p => p.id === playerId);
    if (!player) return false;
    player.surrendered = true;
    this.updateActivity();
    return true;
  }

  // 检查是否所有玩家都准备好了
  allPlayersReady() {
    return this.players.every(p => p.ready);
  }

  // 检查是否所有玩家都投降了
  allPlayersSurrendered() {
    return this.players.every(p => p.surrendered);
  }

  // 开始游戏
  startGame() {
    if (this.status !== 'waiting') return false;
    if (this.players.length < 2) return false;
    
    this.status = 'playing';
    this.currentRound = 0;
    this.updateActivity();
    return true;
  }

  // 开始回合
  startRound() {
    if (this.currentRound >= this.totalRounds) {
      this.endGame();
      return null;
    }
    
    this.currentRound++;
    this.currentSong = generateRandomSong();
    this.guesses = [];
    this.isRoundOver = false; // 重置回合结束状态
    this.updateActivity();
    
    // 重置玩家状态
    this.players.forEach(p => {
      p.ready = false;
      p.surrendered = false;
    });
    
    return this.currentSong;
  }

  // 结束回合
  endRound() {
    this.isRoundOver = true; // 标记回合结束
    // 计算得分
    this.guesses.forEach(guess => {
      const player = this.players.find(p => p.id === guess.playerId);
      if (player && !player.surrendered && guess.correct) {
        player.score += Math.max(100 - guess.timeSpent, 10);
      }
    });
    
    this.updateActivity();
  }

  // 结束游戏
  endGame() {
    this.status = 'ended';
    if (this.roundTimer) {
      clearTimeout(this.roundTimer);
      this.roundTimer = null;
    }
    this.updateActivity();
  }

  // 添加猜测
  addGuess(playerId, songId, songName, timeSpent) {
    const correct = songId === this.currentSong.id || 
      songName.toLowerCase().includes(this.currentSong.name.toLowerCase()) ||
      this.currentSong.name.toLowerCase().includes(songName.toLowerCase());
    
    const guess = {
      playerId,
      playerNickname: this.players.find(p => p.id === playerId)?.nickname || '',
      songId,
      songName,
      correct,
      timeSpent: Math.max(0, timeSpent)
    };
    
    this.guesses.push(guess);
    this.updateActivity();
    return guess;
  }

  // 获取房间状态（用于发送给客户端）
  getState() {
    return {
      id: this.id,
      code: this.code,
      gameType: this.gameType,
      maxPlayers: this.maxPlayers,
      timeLimit: this.timeLimit,
      maxGuesses: this.maxGuesses,
      totalRounds: this.totalRounds,
      players: this.players.map(p => ({
        id: p.id,
        nickname: p.nickname,
        ready: p.ready,
        score: p.score,
        surrendered: p.surrendered,
        host: p.id === this.hostId
      })),
      hostId: this.hostId,
      status: this.status,
      currentRound: this.currentRound,
      createdAt: this.createdAt,
      lastActivityAt: this.lastActivityAt
    };
  }

  // 获取游戏状态（用于游戏中）
  getGameState() {
    return {
      roomId: this.id,
      currentRound: this.currentRound,
      totalRounds: this.totalRounds,
      timeLimit: this.timeLimit,
      maxGuesses: this.maxGuesses,
      currentGuesses: this.guesses.length,
      currentSong: this.currentSong,
      guesses: this.guesses,
      players: this.players.map(p => ({
        id: p.id,
        nickname: p.nickname,
        score: p.score,
        ready: p.ready,
        surrendered: p.surrendered
      })),
      status: this.status,
      isRoundOver: this.isRoundOver || this.allPlayersSurrendered(),
      isGameOver: this.status === 'ended'
    };
  }
}

// 全局歌曲缓存
let songCache = [
  { id: '1', name: 'ヒバナ', artist: 'DECO*27' },
  { id: '2', name: 'メリーゴーランド', artist: 'DECO*27' },
  { id: '3', name: 'ゴーストルール', artist: 'DECO*27' },
  { id: '4', name: 'アンハッピーリフレイン', artist: 'DECO*27' },
  { id: '5', name: 'モザイクロール', artist: 'DECO*27' },
  { id: '6', name: 'パンダヒーロー', artist: 'DECO*27' },
  { id: '7', name: 'ライアーダンス', artist: 'DECO*27' },
  { id: '8', name: 'ローリンガール', artist: 'DECO*27' },
  { id: '9', name: 'ワールドイズマイン', artist: 'ryo' },
  { id: '10', name: 'ブラック★ロックシューター', artist: 'ryo' },
  { id: '11', name: 'メルト', artist: 'ryo' },
  { id: '12', name: 'ココロ', artist: 'トラボルタP' },
  { id: '13', name: 'ファインダー', artist: 'kz' },
  { id: '14', name: 'レンズ', artist: 'kz' },
  { id: '15', name: 'SPiCa', artist: 'kz' }
];

// 更新歌曲缓存
function updateSongCache(songs) {
  if (!Array.isArray(songs)) return;
  
  songs.forEach(song => {
    if (song.id && song.name) {
      const existingIndex = songCache.findIndex(s => s.id === song.id);
      if (existingIndex >= 0) {
        // 更新现有歌曲
        songCache[existingIndex] = {
          id: song.id,
          name: song.name,
          artist: song.artist || '',
          level: song.level || '',
          genre: song.genre || ''
        };
      } else {
        // 添加新歌曲
        songCache.push({
          id: song.id,
          name: song.name,
          artist: song.artist || '',
          level: song.level || '',
          genre: song.genre || ''
        });
      }
    }
  });
  
  console.log(`歌曲缓存已更新，当前共 ${songCache.length} 首歌曲`);
}

// 获取歌曲缓存数量
function getSongCacheCount() {
  return songCache.length;
}

// 生成随机歌曲
function generateRandomSong() {
  if (songCache.length === 0) {
    // 如果缓存为空，返回默认歌曲
    return { id: '1', name: 'ヒバナ', artist: 'DECO*27' };
  }
  return songCache[Math.floor(Math.random() * songCache.length)];
}

// 广播消息到房间内所有玩家
function broadcast(roomId, message, excludePlayerId = null) {
  const room = rooms.get(roomId);
  if (!room) return;
  
  room.players.forEach(player => {
    if (player.id !== excludePlayerId && player.socket && player.socket.readyState === WebSocket.OPEN) {
      try {
        player.socket.send(JSON.stringify(message));
      } catch (error) {
        console.error('Broadcast error:', error);
      }
    }
  });
}

// 发送消息给单个玩家
function sendToPlayer(playerId, message) {
  const player = players.get(playerId);
  if (player && player.socket && player.socket.readyState === WebSocket.OPEN) {
    try {
      player.socket.send(JSON.stringify(message));
    } catch (error) {
      console.error('Send to player error:', error);
    }
  }
}

// WebSocket连接处理
wss.on('connection', (ws) => {
  const playerId = uuidv4();
  const player = new Player(playerId, null);
  player.socket = ws;
  players.set(playerId, player);
  
  console.log(`Player connected: ${playerId}`);

  ws.on('message', (data) => {
    try {
      const message = JSON.parse(data);
      const { action, payload } = message;
      
      console.log(`Received action: ${action} from player: ${playerId}`);
      
      switch (action) {
        // 初始化连接
        case 'initialize': {
          player.nickname = payload?.nickname || `Player_${playerId.slice(0, 8)}`;
          sendToPlayer(playerId, {
            action: 'initialized',
            payload: { playerId, nickname: player.nickname }
          });
          break;
        }

        // 创建房间
        case 'create_room': {
          const { gameType, maxPlayers = 4, timeLimit = 60, maxGuesses = 10, totalRounds = 5 } = payload || {};
          const roomId = uuidv4();
          const room = new Room(roomId, gameType, maxPlayers, timeLimit, maxGuesses, totalRounds, playerId);
          
          room.addPlayer(player);
          rooms.set(roomId, room);
          
          // 发送房间创建成功消息
          sendToPlayer(playerId, {
            action: 'room_created',
            payload: { room: room.getState() }
          });
          
          console.log(`Room created: ${roomId} by player: ${playerId}`);
          break;
        }

        // 通过房间ID加入房间
        case 'join_room': {
          const { roomId } = payload || {};
          const room = rooms.get(roomId);
          
          if (!room) {
            sendToPlayer(playerId, {
              action: 'join_failed',
              payload: { reason: '房间不存在' }
            });
            return;
          }
          
          if (room.status !== 'waiting') {
            sendToPlayer(playerId, {
              action: 'join_failed',
              payload: { reason: '游戏已开始' }
            });
            return;
          }
          
          if (!room.addPlayer(player)) {
            sendToPlayer(playerId, {
              action: 'join_failed',
              payload: { reason: '房间已满或您已在房间中' }
            });
            return;
          }
          
          // 通知房间内其他玩家有新玩家加入
          broadcast(roomId, {
            action: 'player_joined',
            payload: { 
              player: { 
                id: player.id, 
                nickname: player.nickname, 
                ready: player.ready, 
                score: player.score,
                surrendered: player.surrendered,
                host: false
              } 
            }
          }, playerId);
          
          // 发送房间状态给新加入的玩家
          sendToPlayer(playerId, {
            action: 'room_joined',
            payload: {
              room: room.getState(),
              player: { 
                id: player.id, 
                nickname: player.nickname, 
                ready: player.ready, 
                score: player.score,
                surrendered: player.surrendered
              }
            }
          });
          
          // 广播房间更新给所有人
          broadcast(roomId, {
            action: 'room_updated',
            payload: { room: room.getState() }
          });
          
          console.log(`Player ${playerId} joined room: ${roomId}`);
          break;
        }

        // 通过房间码加入房间
        case 'join_room_by_code': {
          const { code } = payload || {};
          
          // 查找房间
          let targetRoom = null;
          let targetRoomId = null;
          for (const [roomId, room] of rooms) {
            if (room.code === code) {
              targetRoom = room;
              targetRoomId = roomId;
              break;
            }
          }
          
          if (!targetRoom) {
            sendToPlayer(playerId, {
              action: 'join_failed',
              payload: { reason: '房间不存在' }
            });
            return;
          }
          
          if (targetRoom.status !== 'waiting') {
            sendToPlayer(playerId, {
              action: 'join_failed',
              payload: { reason: '游戏已开始' }
            });
            return;
          }
          
          if (!targetRoom.addPlayer(player)) {
            sendToPlayer(playerId, {
              action: 'join_failed',
              payload: { reason: '房间已满或您已在房间中' }
            });
            return;
          }
          
          // 通知房间内其他玩家
          broadcast(targetRoomId, {
            action: 'player_joined',
            payload: { 
              player: { 
                id: player.id, 
                nickname: player.nickname, 
                ready: player.ready, 
                score: player.score,
                surrendered: player.surrendered,
                host: false
              } 
            }
          }, playerId);
          
          // 发送房间状态给新加入的玩家
          sendToPlayer(playerId, {
            action: 'room_joined',
            payload: {
              room: targetRoom.getState(),
              player: { 
                id: player.id, 
                nickname: player.nickname, 
                ready: player.ready, 
                score: player.score,
                surrendered: player.surrendered
              }
            }
          });
          
          // 广播房间更新
          broadcast(targetRoomId, {
            action: 'room_updated',
            payload: { room: targetRoom.getState() }
          });
          
          console.log(`Player ${playerId} joined room: ${targetRoomId} via code: ${code}`);
          break;
        }

        // 离开房间
        case 'leave_room': {
          const roomId = player.currentRoomId;
          if (!roomId) {
            sendToPlayer(playerId, {
              action: 'error',
              payload: { message: '您不在任何房间中' }
            });
            return;
          }
          
          const room = rooms.get(roomId);
          if (!room) {
            player.currentRoomId = null;
            sendToPlayer(playerId, { action: 'left_room' });
            return;
          }
          
          const wasHost = room.hostId === playerId;
          room.removePlayer(playerId);
          
          // 通知其他玩家
          broadcast(roomId, {
            action: 'player_left',
            payload: { playerId }
          });
          
          // 如果房主离开，广播房主变更
          if (wasHost && room.players.length > 0) {
            broadcast(roomId, {
              action: 'host_changed',
              payload: { newHostNickname: room.players[0].nickname }
            });
          }
          
          // 如果房间为空，删除房间
          if (room.players.length === 0) {
            if (room.roundTimer) {
              clearTimeout(room.roundTimer);
            }
            rooms.delete(roomId);
            console.log(`Room ${roomId} deleted (empty)`);
          } else {
            // 广播房间更新
            broadcast(roomId, {
              action: 'room_updated',
              payload: { room: room.getState() }
            });
          }
          
          player.currentRoomId = null;
          sendToPlayer(playerId, { action: 'left_room' });
          
          console.log(`Player ${playerId} left room: ${roomId}`);
          break;
        }

        // 更新准备状态
        case 'update_ready': {
          const roomId = player.currentRoomId;
          if (!roomId) {
            sendToPlayer(playerId, {
              action: 'error',
              payload: { message: '您不在任何房间中' }
            });
            return;
          }
          
          const room = rooms.get(roomId);
          if (!room) {
            player.currentRoomId = null;
            sendToPlayer(playerId, {
              action: 'error',
              payload: { message: '房间不存在' }
            });
            return;
          }
          
          if (room.status !== 'waiting') {
            sendToPlayer(playerId, {
              action: 'error',
              payload: { message: '游戏已开始，无法修改准备状态' }
            });
            return;
          }
          
          const { ready } = payload || {};
          room.updatePlayerReady(playerId, ready);
          
          // 广播玩家准备状态变更
          broadcast(roomId, {
            action: 'player_ready',
            payload: { playerId, ready }
          });
          
          // 广播房间更新
          broadcast(roomId, {
            action: 'room_updated',
            payload: { room: room.getState() }
          });
          
          // 通知发起者成功
          sendToPlayer(playerId, {
            action: 'ready_updated',
            payload: { success: true, ready }
          });
          
          console.log(`Player ${playerId} set ready: ${ready} in room: ${roomId}`);
          break;
        }

        // 开始游戏
        case 'start_game': {
          const roomId = player.currentRoomId;
          if (!roomId) {
            sendToPlayer(playerId, {
              action: 'error',
              payload: { message: '您不在任何房间中' }
            });
            return;
          }
          
          const room = rooms.get(roomId);
          if (!room) {
            player.currentRoomId = null;
            sendToPlayer(playerId, {
              action: 'error',
              payload: { message: '房间不存在' }
            });
            return;
          }
          
          // 检查是否是房主
          if (room.hostId !== playerId) {
            sendToPlayer(playerId, {
              action: 'error',
              payload: { message: '只有房主可以开始游戏' }
            });
            return;
          }
          
          // 检查房间状态
          if (room.status !== 'waiting') {
            sendToPlayer(playerId, {
              action: 'error',
              payload: { message: '游戏已开始' }
            });
            return;
          }
          
          // 检查玩家数量
          if (room.players.length < 2) {
            sendToPlayer(playerId, {
              action: 'error',
              payload: { message: '至少需要2名玩家才能开始游戏' }
            });
            return;
          }
          
          // 检查是否所有玩家都准备好
          if (!room.allPlayersReady()) {
            sendToPlayer(playerId, {
              action: 'error',
              payload: { message: '并非所有玩家都已准备' }
            });
            return;
          }
          
          // 开始游戏
          if (!room.startGame()) {
            sendToPlayer(playerId, {
              action: 'error',
              payload: { message: '无法开始游戏' }
            });
            return;
          }
          
          // 开始第一回合
          const song = room.startRound();
          if (!song) {
            sendToPlayer(playerId, {
              action: 'error',
              payload: { message: '无法开始回合' }
            });
            return;
          }
          
          // 设置回合计时器
          room.roundTimer = setTimeout(() => {
            endRoundHandler(roomId);
          }, room.timeLimit * 1000);
          
          // 广播回合开始
          broadcast(roomId, {
            action: 'round_start',
            payload: { gameState: room.getGameState() }
          });
          
          console.log(`Game started in room: ${roomId}`);
          break;
        }

        // 提交猜测
        case 'submit_guess': {
          const roomId = player.currentRoomId;
          if (!roomId) {
            sendToPlayer(playerId, {
              action: 'error',
              payload: { message: '您不在任何房间中' }
            });
            return;
          }
          
          const room = rooms.get(roomId);
          if (!room) {
            player.currentRoomId = null;
            sendToPlayer(playerId, {
              action: 'error',
              payload: { message: '房间不存在' }
            });
            return;
          }
          
          if (room.status !== 'playing') {
            sendToPlayer(playerId, {
              action: 'error',
              payload: { message: '游戏未在进行中' }
            });
            return;
          }
          
          const { songId, songName } = payload || {};
          const timeSpent = room.timeLimit - Math.floor((room.roundTimer?._idleStart ? (Date.now() - room.roundTimer._idleStart) / 1000 : 0));
          
          const guess = room.addGuess(playerId, songId, songName, timeSpent);
          
          // 广播猜测
          broadcast(roomId, {
            action: 'guess_received',
            payload: { guess }
          });
          
          // 检查是否达到最大正确猜测数
          if (guess.correct && room.guesses.filter(g => g.correct).length >= room.maxGuesses) {
            clearTimeout(room.roundTimer);
            endRoundHandler(roomId);
          }
          
          console.log(`Guess submitted by ${playerId} in room ${roomId}: ${songName} (correct: ${guess.correct})`);
          break;
        }

        // 投降
        case 'surrender': {
          const roomId = player.currentRoomId;
          if (!roomId) {
            sendToPlayer(playerId, {
              action: 'error',
              payload: { message: '您不在任何房间中' }
            });
            return;
          }
          
          const room = rooms.get(roomId);
          if (!room) {
            player.currentRoomId = null;
            sendToPlayer(playerId, {
              action: 'error',
              payload: { message: '房间不存在' }
            });
            return;
          }
          
          if (room.status !== 'playing') {
            sendToPlayer(playerId, {
              action: 'error',
              payload: { message: '游戏未在进行中' }
            });
            return;
          }
          
          room.setPlayerSurrendered(playerId);
          
          // 广播投降
          broadcast(roomId, {
            action: 'player_surrendered',
            payload: { playerId, surrendered: true }
          });
          
          // 广播房间更新
          broadcast(roomId, {
            action: 'room_updated',
            payload: { room: room.getState() }
          });
          
          // 检查是否所有玩家都投降了
          if (room.allPlayersSurrendered()) {
            clearTimeout(room.roundTimer);
            endRoundHandler(roomId);
          }
          
          console.log(`Player ${playerId} surrendered in room: ${roomId}`);
          break;
        }

        // 获取房间列表
        case 'get_rooms': {
          const waitingRooms = [];
          for (const [roomId, room] of rooms) {
            if (room.status === 'waiting') {
              waitingRooms.push(room.getState());
            }
          }
          
          sendToPlayer(playerId, {
            action: 'rooms_list',
            payload: { rooms: waitingRooms }
          });
          break;
        }

        // 上传歌曲数据到服务器缓存
        case 'upload_songs': {
          const { songs } = payload || {};
          if (!songs || !Array.isArray(songs)) {
            sendToPlayer(playerId, {
              action: 'upload_songs_response',
              payload: { success: false, message: '歌曲数据格式错误' }
            });
            return;
          }
          
          updateSongCache(songs);
          
          sendToPlayer(playerId, {
            action: 'upload_songs_response',
            payload: { 
              success: true, 
              message: `成功上传 ${songs.length} 首歌曲`,
              totalSongs: getSongCacheCount()
            }
          });
          
          console.log(`Player ${playerId} uploaded ${songs.length} songs`);
          break;
        }

        // 获取服务器歌曲数量
        case 'get_song_count': {
          sendToPlayer(playerId, {
            action: 'song_count_response',
            payload: { count: getSongCacheCount() }
          });
          break;
        }

        // 获取当前房间信息
        case 'get_room_info': {
          const roomId = player.currentRoomId;
          if (!roomId) {
            sendToPlayer(playerId, {
              action: 'error',
              payload: { message: '您不在任何房间中' }
            });
            return;
          }
          
          const room = rooms.get(roomId);
          if (!room) {
            player.currentRoomId = null;
            sendToPlayer(playerId, {
              action: 'error',
              payload: { message: '房间不存在' }
            });
            return;
          }
          
          sendToPlayer(playerId, {
            action: 'room_info',
            payload: { room: room.getState() }
          });
          break;
        }

        // 心跳
        case 'heartbeat': {
          sendToPlayer(playerId, {
            action: 'heartbeat',
            payload: {}
          });
          break;
        }

        default:
          console.log('Unknown action:', action);
      }
    } catch (error) {
      console.error('Message parsing error:', error);
    }
  });

  // 连接关闭处理
  ws.on('close', () => {
    console.log(`Player disconnected: ${playerId}`);
    
    // 从玩家列表移除
    players.delete(playerId);
    
    // 如果玩家在房间中，处理离开逻辑
    const roomId = player.currentRoomId;
    if (roomId) {
      const room = rooms.get(roomId);
      if (room) {
        const wasHost = room.hostId === playerId;
        room.removePlayer(playerId);
        
        // 通知其他玩家
        broadcast(roomId, {
          action: 'player_left',
          payload: { playerId }
        });
        
        // 如果房主离开，广播房主变更
        if (wasHost && room.players.length > 0) {
          broadcast(roomId, {
            action: 'host_changed',
            payload: { newHostNickname: room.players[0].nickname }
          });
        }
        
        // 如果房间为空，删除房间
        if (room.players.length === 0) {
          if (room.roundTimer) {
            clearTimeout(room.roundTimer);
          }
          rooms.delete(roomId);
          console.log(`Room ${roomId} deleted (empty)`);
        } else {
          // 广播房间更新
          broadcast(roomId, {
            action: 'room_updated',
            payload: { room: room.getState() }
          });
        }
      }
    }
  });

  // 错误处理
  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
  });
});

// 回合结束处理函数
function endRoundHandler(roomId) {
  const room = rooms.get(roomId);
  if (!room) return;
  
  // 结束当前回合
  room.endRound();
  
  // 广播回合结束
  broadcast(roomId, {
    action: 'round_over',
    payload: { gameState: room.getGameState() }
  });
  
  // 延迟后开始下一回合或结束游戏
  setTimeout(() => {
    if (!rooms.has(roomId)) return;
    
    const currentRoom = rooms.get(roomId);
    if (currentRoom.status !== 'playing') return;
    
    const song = currentRoom.startRound();
    if (!song) {
      // 游戏结束
      broadcast(roomId, {
        action: 'game_over',
        payload: { gameState: currentRoom.getGameState() }
      });
      console.log(`Game ended in room: ${roomId}`);
      return;
    }
    
    // 开始下一回合
    currentRoom.roundTimer = setTimeout(() => {
      endRoundHandler(roomId);
    }, currentRoom.timeLimit * 1000);
    
    broadcast(roomId, {
      action: 'round_start',
      payload: { gameState: currentRoom.getGameState() }
    });
  }, 3000);
}

server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});