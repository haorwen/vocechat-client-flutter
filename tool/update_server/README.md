# VoceChat 更新管理服务 0.2.0

包含 Web 管理页面、Android 检查接口和管理员发布接口。前端由 Python 服务直接提供，
不需要 Node、npm 或前端构建。Python 3.12 和环境使用 uv 管理。

## 解压后直接启动

先安装 [uv](https://docs.astral.sh/uv/getting-started/installation/)。在解压目录中运行：

```bash
uv sync
uv run vocechat-update-server
```

服务默认监听 `0.0.0.0:8080`，浏览器访问：

```text
http://你的服务器IP:8080/admin/
```

根路径 `/` 也可打开管理页。若外部无法访问，需要让服务器防火墙/云安全组允许该端口，
或通过已有 HTTPS 反向代理访问。正式域名应使用 `https://update.voce.chat/admin/`。

第一次启动自动生成强随机管理员令牌，保存在 `data/admin-token.txt`（Linux 权限 600）。
在服务器另一个终端执行以下命令查看，再填入 Web 页面的“管理员令牌”：

```bash
cat data/admin-token.txt
```

重启不会更换令牌。数据库在 `data/releases.sqlite3`，请保留和备份整个 `data/` 目录。
不要将它放入公开静态文件目录。管理页面不会把令牌保存到浏览器 localStorage 或 cookie，
发布成功后会清空令牌输入框。页面是公开的，但所有发布请求都必须通过令牌鉴权。

`uv run` 本身是 uv 的运行器，需要接入口名称；完整启动命令为 `uv run vocechat-update-server`。
已有 Python 3.12 时直接复用，没有时 uv 可自动下载。无需激活虚拟环境。

## 在 Web 页面发布

1. 上传与现有应用 ID 和签名兼容的 APK，准备可访问的 HTTPS APK 下载直链（不能是 HTML 下载网页）。
2. 页面会从同一服务器请求 `/client/android`，显示当前版本和最近强制构建号。
3. 输入版本名、严格递增的 Android 构建号和下载地址，按需开启强制更新。
4. 填写中文/英文公告，可在右侧切换预览语言；也可以添加扩展 JSON 字段。
5. 输入管理员令牌，点击“预览并发布”，核对请求内容后点击“确认发布”。

页面不上传 APK，发布接口只保存版本元数据。发布不会唤醒或打断当前正在运行的客户端。
客户端下次冷启动检查时生效。发布记录不可修改；重复提交相同最新版是幂等操作。

## 配置

无需配置即可启动。需要修改监听地址、端口或数据库路径时：

```bash
cp config.example.toml config.toml
```

编辑 `config.toml`：

```toml
host = "0.0.0.0"
port = 8080
database = "./data/releases.sqlite3"
```

环境变量 `UPDATE_HOST`、`UPDATE_PORT`、`UPDATE_DB` 的优先级高于配置文件。
可通过 `UPDATE_ADMIN_TOKEN` 使用已有令牌，覆盖自动生成的文件令牌。
有 `.env` 时使用 `uv run --env-file .env vocechat-update-server`；默认不会读取 `.env`。
所有相对路径相对于启动时的工作目录。请固定在解压目录启动，避免误用新的数据库。

## API 与版本策略

- `GET /client/android`：公开检查接口，返回最新版本信息。
- `POST /admin/client/android/releases`：发布接口，必须传 `Authorization: Bearer <token>`。

发布请求示例：

```json
{
  "version": "0.3.24",
  "version_code": 24,
  "force_update": false,
  "update_url": "https://update.voce.chat/downloads/vocechat-0.3.24.apk",
  "announcement": {
    "zh": "修复已知问题，优化聊天体验。",
    "en": "Bug fixes and improvements to the chat experience."
  }
}
```

响应额外包含服务器生成的 `timestamp`（Unix 毫秒）和 `last_force_version_code`。
不要在发布请求中提交这两个字段。强制发布会更新历史强制构建号，普通发布继承它；
旧数据库会自动迁移。尚未发布版本时检查接口返回 `503/no_release`，管理页显示“尚未发布”。

公告可省略。双语对象需有 `zh` 和 `en` 两个字符串；可为空，客户端在目标语言为空时
回退另一份非空公告。仍接受旧字符串公告。额外 JSON 字段保留并返回，旧客户端忽略未知字段。

客户端更新策略：普通更新可跳过此版本；强制更新有 3 次应急跳过，每次免提醒 24 小时，
次数跨重启保留。新发普通版本不会覆盖旧强制要求。完整协议见 `android-updates.md`
（源代码仓库中位于 `../../docs/android-updates.md`）。

## HTTPS / Caddy

附带 `Caddyfile.example`。将域名 DNS 指向服务器后，使用 Caddy 配置反向代理并签发证书。
它同时代理管理页及 API。如果提供同域名 APK 下载，将文件放入
`/srv/update/downloads/`；也可使用已有 HTTPS 对象存储 URL。

## 后台运行 / Docker

直接运行命令用于前台启动。长期运行可采用附带的 `vocechat-update.service.example`
配置 systemd，或在此目录执行：

```bash
docker compose up -d --build
```

Docker 构建同样使用 uv 安装锁定依赖。Compose 只暴露本机 `127.0.0.1:8080`，数据存入
命名卷；通过 HTTPS 反向代理提供外部访问。未配置令牌时可查看自动生成值：

```bash
docker compose exec update cat /data/admin-token.txt
```

## 验证和升级

```bash
uv sync --locked
uv run --locked python -m unittest -v test_server.py
```

升级时先备份 `data/`，保留该目录及自己的配置，更新代码，再运行 `uv sync --locked` 并重启。
ZIP 不包含令牌、数据库、虚拟环境或已发布 APK，每个部署实例独立生成自己的令牌。

Android 客户端通过原生 DownloadManager 下载，App 内显示进度，完成后唤起系统安装器。
安装包应用 ID、构建号必须对应已发布元数据，签名必须与已安装 App 兼容。

下载链接后缀不限，支持无后缀、`.bin` 或带签名参数的 URL。客户端保留原始请求地址，
下载文件统一保存为本地 `.apk` 后调用安装器；服务端返回的内容必须是有效 APK。
