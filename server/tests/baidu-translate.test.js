const test = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const {installBaiduTranslate} = require('../baidu-translate');

async function withServer(options, run) {
  const app = express();
  app.use(express.json());
  installBaiduTranslate(app, options);
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  const url = `http://127.0.0.1:${server.address().port}/api/translate`;
  const post = body => fetch(url, {method: 'POST',
    headers: {'Content-Type': 'application/json'}, body: JSON.stringify(body)});
  try { await run(post); }
  finally { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); }
}

test('使用服务端 Bearer 凭据与 llm 模型，保留换行并复用缓存', async () => {
  let calls = 0;
  await withServer({env: {BAIDU_TRANSLATE_APP_ID: 'example-app',
    BAIDU_TRANSLATE_API_KEY: 'example-key', BAIDU_TRANSLATE_KEY: 'unused'},
    async fetchImpl(url, options) {
      calls++;
      assert.equal(url, 'https://fanyi-api.baidu.com/ait/api/aiTextTranslate');
      assert.equal(options.headers.Authorization, 'Bearer example-key');
      assert.deepEqual(JSON.parse(options.body), {
        appid: 'example-app', q: 'hello\nworld', from: 'jp', to: 'zh', model_type: 'llm',
      });
      return {ok: true, async json() { return {trans_result: [{dst: '你好'}, {dst: '世界'}]}; }};
    }}, async post => {
      const body = {q: 'hello\nworld', from: 'ja', to: 'zh'};
      assert.deepEqual(await (await post(body)).json(), {translation: '你好\n世界'});
      assert.equal((await post(body)).status, 200);
      assert.equal(calls, 1);
    });
});

test('拒绝超长、错误语种与空内容；上游失败不会缓存或泄漏密钥', async () => {
  let calls = 0;
  await withServer({env: {BAIDU_TRANSLATE_APP_ID: 'example-app', BAIDU_TRANSLATE_API_KEY: 'example-key'},
    async fetchImpl() {
      calls++;
      return {ok: true, async json() { return {error_code: '54001', error_msg: 'example-key'}; }};
    }}, async post => {
      for (const body of [{q: ''}, {q: 'a'.repeat(6001)}, {q: 'hello', from: 'invalid'}, {q: 'hello', to: 'auto'}]) {
        assert.equal((await post(body)).status, 400);
      }
      for (let i = 0; i < 2; i++) {
        const response = await post({q: 'hello'});
        assert.equal(response.status, 502);
        assert.deepEqual(await response.json(), {error: 'translation_unavailable', code: '54001'});
      }
      assert.equal(calls, 2);
    });
});

test('未配置时返回 503；并发同文请求只调用一次上游', async () => {
  await withServer({env: {}}, async post => assert.equal((await post({q: 'hello'})).status, 503));
  let calls = 0;
  let finish;
  const gate = new Promise(resolve => { finish = resolve; });
  await withServer({env: {BAIDU_TRANSLATE_APP_ID: 'example-app', BAIDU_TRANSLATE_API_KEY: 'example-key'},
    async fetchImpl() {
      calls++;
      setTimeout(finish, 50);
      await gate;
      return {ok: true, async json() { return {trans_result: [{dst: '你好'}]}; }};
    }}, async post => {
      const results = await Promise.all([post({q: 'hello'}), post({q: 'hello'})]);
      assert.ok(results.every(result => result.status === 200));
      assert.equal(calls, 1);
    });
});
