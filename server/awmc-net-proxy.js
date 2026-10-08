// AWMC NET 的 Developer-Token 只保存在服务端，客户端仅提交 QQ 查询。
const https = require('https');

function installAwmcNetProxy(app) {
  app.get('/api/awmc-net/records', (req, res) => {
    const qq = String(req.query.qq || '').trim();
    if (!/^\d{5,12}$/.test(qq)) {
      return res.status(400).json({ success: false, error: 'invalid_qq' });
    }
    const token = process.env.AWMC_NET_DEVELOPER_KEY || '';
    if (!token) {
      return res.status(503).json({ success: false, error: 'awmc_net_not_configured' });
    }
    const upstream = new URL('https://net.wmc.pub/dev/player/records');
    upstream.searchParams.set('qq', qq);
    const request = https.request(upstream, {
      method: 'GET',
      headers: {
        Accept: 'application/json',
        'Developer-Token': token,
        Authorization: `Bearer ${token}`,
      },
    }, response => {
      const chunks = [];
      response.on('data', chunk => chunks.push(chunk));
      response.on('end', () => {
        res.status(response.statusCode || 502);
        if (response.headers['content-type']) res.set('Content-Type', response.headers['content-type']);
        res.send(Buffer.concat(chunks));
      });
    });
    request.setTimeout(45000, () => request.destroy(new Error('upstream timeout')));
    request.on('error', error => {
      console.error('[awmc-net] proxy failed:', error.message);
      if (!res.headersSent) res.status(502).json({ success: false, error: 'awmc_net_upstream_unavailable' });
    });
    request.end();
  });
}

module.exports = { installAwmcNetProxy };
