/** 百度大模型文本翻译代理；所有百度凭据仅从服务端环境变量读取。 */
const crypto = require('node:crypto');
const {isIP} = require('node:net');
const BAIDU_TRANSLATE_URL = 'https://fanyi-api.baidu.com/ait/api/aiTextTranslate';

function installBaiduTranslate(app, options = {}) {
  const fetchImpl = options.fetchImpl || globalThis.fetch;
  const env = options.env || process.env;
  const appId = env.BAIDU_TRANSLATE_APP_ID || '';
  const apiKey = env.BAIDU_TRANSLATE_API_KEY || '';
  const signKey = env.BAIDU_TRANSLATE_KEY || '';
  const cache = new Map();
  const pending = new Map();
  const clients = new Map();
  const cacheTtl = 30 * 24 * 60 * 60 * 1000;

  async function translate(q, from, to) {
    if (!appId || (!apiKey && !signKey)) {
      const error = new Error('translation_not_configured');
      error.status = 503;
      throw error;
    }
    const payload = {appid: appId, q, from, to, model_type: 'llm'};
    const headers = {'Content-Type': 'application/json;charset=utf-8'};
    if (apiKey) {
      headers.Authorization = `Bearer ${apiKey}`;
    } else {
      // 官方接口也兼容 APP ID + 密钥签名，优先使用 API Key 鉴权。
      payload.salt = crypto.randomBytes(16).toString('hex');
      payload.sign = crypto.createHash('md5')
          .update(appId + q + payload.salt + signKey, 'utf8').digest('hex');
    }
    const response = await fetchImpl(BAIDU_TRANSLATE_URL, {
      method: 'POST', headers, body: JSON.stringify(payload),
      signal: AbortSignal.timeout(25000),
    });
    const data = await response.json();
    const code = String(data?.error_code || '');
    if (!response.ok || (code && code !== '52000')) {
      // 只保留错误码，避免日志或响应包含上游请求中的凭据。
      const error = new Error('translation_upstream_error');
      error.code = /^\d{1,10}$/.test(code) ? code : 'upstream_http_error';
      throw error;
    }
    const parts = Array.isArray(data?.trans_result) ? data.trans_result : [];
    const translation = parts.filter(part => typeof part?.dst === 'string')
        .map(part => part.dst).join('\n');
    if (!translation) throw new Error('translation_empty_result');
    return translation;
  }

  app.post('/api/translate', async (req, res) => {
    const q = typeof req.body?.q === 'string' ? req.body.q.trim() : '';
    let from = typeof req.body?.from === 'string' ? req.body.from : 'auto';
    const to = typeof req.body?.to === 'string' ? req.body.to : 'zh';
    from = from === 'ja' ? 'jp' : from;
    // 当前功能只需要英语、日语及自动检测到中文，限制代理用途与文本长度。
    if (!q || [...q].length > 6000 || !['auto', 'en', 'jp'].includes(from) || to !== 'zh') {
      return res.status(400).json({error: 'invalid_translation_request'});
    }
    const now = Date.now();
    const remote = req.socket?.remoteAddress || 'unknown';
    // 只信任本机 Nginx 覆写的 X-Real-IP；公网直连不能伪造限流身份。
    const realIp = req.headers?.['x-real-ip'];
    const isLoopback = ['127.0.0.1', '::1', '::ffff:127.0.0.1'].includes(remote);
    const clientId = isLoopback && typeof realIp === 'string' && isIP(realIp)
        ? realIp : remote;
    for (const [id, usage] of clients) {
      if (now - usage.start >= 60000) clients.delete(id);
    }
    const usage = clients.get(clientId) || {start: now, count: 0};
    if (usage.count >= 30 || (!clients.has(clientId) && clients.size >= 10000)) {
      return res.status(429).json({error: 'translation_rate_limited'});
    }
    usage.count++;
    clients.set(clientId, usage);
    const cacheKey = JSON.stringify([from, to, q]);
    const cached = cache.get(cacheKey);
    if (cached && now - cached.time < cacheTtl) {
      return res.json({translation: cached.translation});
    }
    try {
      let request = pending.get(cacheKey);
      if (!request) {
        if (pending.size >= 8) {
          return res.status(429).json({error: 'translation_busy'});
        }
        request = translate(q, from, to);
        pending.set(cacheKey, request);
      }
      let translation;
      try {
        translation = await request;
      } finally {
        if (pending.get(cacheKey) === request) pending.delete(cacheKey);
      }
      // 有界缓存，避免反复翻译同一收藏品导致重复计费。
      if (cache.size >= 2000) cache.delete(cache.keys().next().value);
      cache.set(cacheKey, {translation, time: Date.now()});
      return res.json({translation});
    } catch (error) {
      console.warn('百度翻译失败:', error.code || error.name);
      return res.status(error.status || 502).json({
        error: error.status === 503 ? 'translation_not_configured' : 'translation_unavailable',
        ...(error.code ? {code: error.code} : {}),
      });
    }
  });
}

module.exports = {installBaiduTranslate};
