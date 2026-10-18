# 我的世界服务器目录 · `minecraft-server-directory`

Discourse 插件：允许用户提交自己的 Minecraft Java Edition 服务器，由论坛后台定时执行 Minecraft Server List Ping，公开展示在线状态、版本、在线人数和 MOTD。

UI 结构参考了 CloudRail BBS 的 `Resource-Center-Plugin`：独立页面、卡片列表、筛选、自动刷新、双语 locale、管理端入口。

## 功能

- 独立页面 `/minecraft-servers`
- 用户提交、编辑、删除自己的服务器
- 管理员审核、通过、拒绝、隐藏、删除
- 服务端定时探测 Minecraft Java Edition 状态
- 显示在线人数、版本、延迟、MOTD
- 公开列表只显示已审核通过的服务器
- 中英文界面
- 响应式卡片布局，适配 Discourse 明暗主题
- 防 SSRF：拒绝回环、私网、链路本地、组播和保留地址
- DNS 解析后校验所有 IP，并固定连接到已校验的地址，降低 DNS rebinding 风险
- 探测超时、响应体大小上限、定时任务限流

## 安装

仓库名是 `Server-plugin`，但 **Discourse 插件目录名必须是 `minecraft-server-directory`**。原因是 Discourse 用目录名生成样式表 URL，且核心只接受小写目录名；目录名与 `# name:` 不一致还会导致管理页和样式表查找失败。

```bash
cd /var/discourse
./launcher enter app
cd /var/www/discourse/plugins
git clone https://github.com/CloudRail-BBS/Server-plugin.git minecraft-server-directory
exit
./launcher rebuild app
```

或在 `containers/app.yml` 的 `after_code` 中显式指定目标目录：

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/CloudRail-BBS/Server-plugin.git minecraft-server-directory
```

更新时先拉取代码，再重建；`rebuild` 本身不会自动更新已存在的插件目录：

```bash
cd /var/discourse/plugins/minecraft-server-directory
git pull
cd /var/discourse
./launcher rebuild app
```

## 启用与配置

安装后进入 `/admin/site_settings/category/plugins`，确认 `minecraft_server_enabled` 已启用。

主要设置：

| 设置 | 默认值 | 说明 |
| --- | --- | --- |
| `minecraft_server_enabled` | `true` | 插件总开关 |
| `minecraft_server_allow_user_submissions` | `true` | 是否允许用户提交 |
| `minecraft_server_min_trust_level` | `1` | 提交所需最低信任等级 |
| `minecraft_server_max_servers_per_user` | `3` | 每用户最多服务器数 |
| `minecraft_server_require_approval` | `true` | 提交或修改后是否需要审核 |
| `minecraft_server_auto_approve` | `false` | 是否自动通过（仅在关闭审核要求时生效） |
| `minecraft_server_probe_interval_minutes` | `5` | 探测间隔 |
| `minecraft_server_probe_timeout_seconds` | `5` | 探测超时 |
| `minecraft_server_show_ip` | `false` | 公开列表是否显示服务器地址 |
| `minecraft_server_refresh_seconds` | `30` | 前端刷新间隔 |
| `minecraft_server_submission_cooldown_seconds` | `300` | 提交冷却时间 |
| `minecraft_server_description_max_length` | `280` | 简介最大长度 |

管理员审核页：`/admin/plugins/minecraft-server-directory` → “我的世界服务器”。

## 安全设计

用户提交的是网络地址，因此插件不把任意地址直接交给 `Net::HTTP` 或 socket：

1. 只接受裸主机名或 `host:port`，不接受 URL、路径、用户信息。
2. 校验主机名标签、端口范围和总长度。
3. 对主机名做 DNS 解析，并检查解析出的 **每一个** IP。
4. 拒绝回环、RFC1918 私网、链路本地、组播、CGNAT、文档/测试网段等特殊地址。
5. 探测时连接到已校验的 IP，同时把原始主机名放进 Minecraft 握手包，避免二次 DNS 解析。
6. 探测有连接/读取超时和响应体上限。
7. 用户提交默认进入审核；公开列表只查询 `approved` 且 `listed` 的记录。

注意：如果论坛部署在反向代理、容器或 CDN 后面，服务器端看到的网络出口可能与用户不同；请确保 Discourse 所在网络能够访问 Minecraft 服务器的 TCP 端口。

## 协议说明

插件实现的是 Minecraft Java Edition 的 Server List Ping：

- 握手包（packet id `0x00`）
- 状态请求（packet id `0x00`）
- 解析状态响应 JSON 中的 `version`、`players`、`description` 和 `favicon`

不依赖第三方 Minecraft 库。Bedrock/UDP 服务器目前不支持。

## 开发与验证

```bash
ruby spec/test_address_policy.rb
ruby spec/test_status_probe.rb
ruby -c plugin.rb
python -c "import yaml,glob; [yaml.safe_load(open(f, encoding='utf-8')) for f in glob.glob('config/**/*.yml', recursive=True)]"
```

`.gjs` 使用 Discourse 同款 `content-tag` 编译器检查：

```bash
npm install --no-save content-tag
node scripts/check-gjs.mjs
```

静态检查不能替代真实 Discourse 实例验证。部署后建议至少确认：

- 插件能启动且 `/admin/plugins` 中可见
- 直接访问 `/minecraft-servers` 返回页面
- `/minecraft-servers/servers.json` 返回 JSON
- 管理员审核页可加载
- 后台 `Jobs::MinecraftServerProbe` 能正常执行

## 许可

MIT