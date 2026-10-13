# RK Issue Board

Rockchip Redmine 问题看板，显示当前用户所有指派和关注的问题。

## 快速启动

```bash
# 前台运行（Ctrl+C 停止）
python3 server.py

# 使用管理脚本（推荐）
./server.sh start    # 后台启动
./server.sh stop     # 停止
./server.sh restart  # 重启
./server.sh status   # 查看状态
./server.sh open     # 启动并打开浏览器
```

然后浏览器打开 http://localhost:8100（端口可在 `server.sh` 中修改 `PORT` 变量）

首次打开需要输入 Redmine API Key（Redmine → 我的账号 → API 访问密钥 → 显示）。

## 功能

- 显示所有指派给我及我关注的问题
- 状态快捷筛选（全部/指派/关注/新建/已确认/待反馈/进行中/已解决/已关闭）
- 项目、优先级、类型、来源、关键词筛选
- 点击表头列名排序（升序/降序切换）
- 60 秒自动刷新
- 统计信息与筛选按钮合一

## 文件说明

| 文件 | 说明 |
|------|------|
| `index.html` | 看板主页面，单 HTML 文件（内含 CSS/JS） |
| `server.py` | 本地代理服务器，解决浏览器跨域限制 |
| `server.sh` | 服务器管理脚本（start/stop/restart/status/open） |

## 为什么需要代理服务器

浏览器出于安全策略（同源策略），会拦截从 `file://` 协议直接访问 `https://redmine.rock-chips.com` 的跨域请求。`server.py` 运行在本地，作为中间人转发请求，浏览器认为是同源访问，不会拦截。

```
浏览器 (localhost:<PORT>)  →  server.py  →  Redmine 服务器
     同源请求                  服务端转发（无 CORS 限制）
```

### 不使用代理的替代方案

1. **Redmine 管理员配置 CORS**（推荐）— 在 Redmine 的 nginx 配置中添加：

   ```nginx
   add_header Access-Control-Allow-Origin *;
   add_header Access-Control-Allow-Headers "Content-Type, X-Redmine-API-Key";
   ```

   配置后即可直接双击打开 `index.html`，无需代理。

2. **浏览器插件** — 安装 "Allow CORS" 扩展（仅开发环境使用，存在安全风险）

## 技术细节

- Redmine REST API：`/users/current.json`、`/issues.json`、`/issue_statuses.json`
- 认证方式：`X-Redmine-API-Key` 请求头
- 代理使用系统代理（ClashX）访问 Redmine（Redmine nginx 有 IP 白名单）
- 代理请求使用浏览器 User-Agent 绕过 nginx UA 过滤
- 支持分页获取（每页 100 条，自动循环获取全部）
