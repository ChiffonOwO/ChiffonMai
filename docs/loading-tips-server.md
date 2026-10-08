# 加载语录服务端管理

加载语录由 MySQL 的 `loading_tips` 表管理。2026-10-04 已在现有业务数据库建表并导入原客户端全部 51 条语录。

- `tip_id`：稳定标识（原目录为 `legacy-001` 至 `legacy-051`），客户端按此保存勾选偏好。修改文案时保持 ID 不变。
- `tip_text`：语录文本，表使用 `utf8mb4`，支持中文和 emoji。
- `enabled`：`1` 为可展示，`0` 为服务端停用。
- `sort_order`：升序排列。
- `created_at` / `updated_at`：创建、修改时间。

接口：`GET https://chiffonmai.cloud/api/loading-tips`。

服务器在注册路由时传入现有数据库连接池：

```js
require('./loading-tips').installLoadingTips(app, () => db);
```

每次请求直接查询表，数据库修改后无需重启服务。客户端可以在「加载语录管理」手动刷新，也会按缓存策略自动获取目录。用户的显示勾选保存在本机，与服务器的 `enabled` 分开管理。

重新部署时可使用 `server/data/loading-tips-migration.sql` 建表并导入原始目录；重复执行不会覆盖已编辑的语录和停用状态。服务器配置和数据库口令不应放入迁移文件。

## HTTPS 续期

2026-10-04 已续期 `chiffonmai.cloud` 证书，并激活服务器发行版提供的 `certbot-renew.timer`。新证书截止时间为 2027-01-02 06:21:29 UTC。

成功续期后的 Nginx 重载钩子：`/etc/letsencrypt/renewal-hooks/deploy/chiffonmai-reload-nginx`。

可用以下只读命令检查后续续期状态：

```sh
systemctl status certbot-renew.timer
systemctl list-timers certbot-renew.timer --all
openssl x509 -in /etc/letsencrypt/live/chiffonmai.cloud/fullchain.pem -noout -dates
```

客户端投稿使用 POST /api/loading-tips，请求体为 { text: ... }。服务端会查询当前最大的 normal_N，分配下一个三位补零的编号（如 `normal_002`），sort_order 接在当前最大值之后，enabled 固定为 0；审核时将对应记录改为 1 即可展示。旧的 legacy-* 编号不会参与新编号。
