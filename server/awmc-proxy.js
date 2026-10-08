// AWMC 网关开发者令牌只保存在服务端；客户端通过本代理提交自己的二维码和目标平台凭据。
const https = require('https');

const UPSTREAM = 'https://api.wmc.pub';
const GATEWAY_TOKEN_ENV = 'AWMC_GATEWAY_TOKEN';

const ROUTES = new Map([
  ['/v1/health', new Set(['GET'])],
  ['/v1/user/music', new Set(['POST'])],
  ['/v1/update-lx', new Set(['POST'])],
  ['/v1/update-fish', new Set(['POST'])],
]);

function forward(path, method, body, token) {
  return new Promise((resolve, reject) => {
    const target = new URL(`${UPSTREAM}${path}`);
    const payload = body == null ? null : JSON.stringify(body);
    const request = https.request(target, {
      method,
      headers: {
        Accept: 'application/json',
        Authorization: `Bearer ${token}`,
        ...(payload ? {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
        } : {}),
      },
    }, response => {
      const chunks = [];
      response.on('data', chunk => chunks.push(chunk));
      response.on('end', () => resolve({
        statusCode: response.statusCode || 502,
        contentType: response.headers['content-type'],
        body: Buffer.concat(chunks),
      }));
    });
    request.setTimeout(195000, () => request.destroy(new Error('upstream timeout')));
    request.on('error', reject);
    if (payload) request.write(payload);
    request.end();
  });
}

function installAwmcProxy(app) {
  app.all('/api/awmc/*', async (req, res) => {
    const path = `/${req.params[0]}`;
    const methods = ROUTES.get(path);
    if (!methods || !methods.has(req.method)) {
      return res.status(404).json({ success: false, error: 'awmc_route_not_allowed' });
    }
    // 共享开发者权限仅用于同步；不开放密钥管理、用量记录或机台写入。
    if (req.method === 'POST') {
      const body = req.body || {};
      const qr = body.qrcode;
      const credential = path === '/v1/update-fish' ? body.token : body.key;
      if (typeof qr !== 'string' || !qr.startsWith('SGWCMAID') ||
          qr.length <= 20 || qr.length > 4096 ||
          (path !== '/v1/user/music' && (typeof credential !== 'string' ||
            !credential.trim() || credential.length > 4096))) {
        return res.status(400).json({ success: false, error: 'invalid_sync_request' });
      }
    }
    const token = process.env[GATEWAY_TOKEN_ENV] || '';
    if (!token) {
      return res.status(503).json({ success: false, error: 'awmc_gateway_not_configured' });
    }
    const body = req.method === 'GET' ? null : {
      qrcode: req.body.qrcode,
      ...(path === '/v1/update-fish' ? { token: req.body.token } : {}),
      ...(path === '/v1/update-lx' ? { key: req.body.key } : {}),
    };
    try {
      const result = await forward(path, req.method, body, token);
      res.status(result.statusCode);
      if (result.contentType) res.set('Content-Type', result.contentType);
      return res.send(result.body);
    } catch (error) {
      console.error('[awmc] proxy failed:', error.message);
      return res.status(502).json({ success: false, error: 'awmc_upstream_unavailable' });
    }
  });
}

module.exports = { installAwmcProxy };
