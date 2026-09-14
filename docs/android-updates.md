# Android 更新系统

实现范围：独立的版本发布服务 + Flutter Android 启动检查。域名为
`https://update.voce.chat`，不依赖用户登录、聊天服务器或聊天服务的 API Key。

管理员发布后，正在运行的客户端保持原状态。只有下一次冷启动（结束应用进程后重新打开）
才检查新版本。从后台回到前台、切换聊天服务器、打开设置页均不重新检查。Android 后台
进程如果尚未结束，重新点击桌面图标不一定构成冷启动。

## 1. 检查接口

```http
GET https://update.voce.chat/client/android
Accept: application/json
```

无需鉴权，无必需查询参数。始终返回已发布的最新 Android 版本，客户端在本地比较构建号。

成功响应 `200 OK`，`Content-Type: application/json; charset=utf-8`，
`Cache-Control: no-store`：

```json
{
  "version": "0.3.23",
  "version_code": 23,
  "timestamp": 1789056000000,
  "force_update": false,
  "last_force_version_code": 22,
  "update_url": "https://update.voce.chat/downloads/vocechat-0.3.23.apk",
  "announcement": {
    "zh": "本次更新：\n1. 修复已知问题\n2. 优化聊天体验",
    "en": "What's new:\n1. Bug fixes\n2. Improved chat experience"
  }
}
```

| 字段 | 类型 | 必需 | 含义 |
| --- | --- | --- | --- |
| `version` | string | 是 | 展示版本名，对应 Android `versionName`，例如 `0.3.23` |
| `version_code` | integer | 是 | Android `versionCode`，用于判断新旧；范围 1–2100000000，发布时严格递增 |
| `timestamp` | integer | 是，仅响应 | 服务器生成本次响应时的 Unix 毫秒时间戳，UTC；不是发布时间 |
| `force_update` | boolean | 是 | 本次发布是否为强制更新；false 不会撤销历史强制更新 |
| `last_force_version_code` | integer | 是，仅响应 | 最近一次强制更新的构建号，包含当前发布；从未强制更新时为 0，由服务端维护 |
| `update_url` | string | 是 | HTTPS 下载直链，链接后缀不限；响应必须为完整 APK 安装包，不支持 HTML 下载页面 |
| `announcement` | object / null | 否 | 双语纯文本公告，提供 `zh`、`en` 两个字符串，支持换行；缺省、null 或两者皆空白时隐藏 |

下载链接不要求以 `.apk` 结尾，可以是无后缀接口、`.bin` 文件或带签名参数的 URL。
客户端保留完整请求 URL，下载时统一保存为本地 `<随机标识>.apk`，再以 APK MIME 类型
交给系统安装器，不会在原始 URL 后追加 `.apk` 或修改签名参数。后缀更名不改变文件内容，
下载内容仍须是有效 APK，并通过应用 ID 和构建号检查。

公告随客户端界面语言选择：中文（`zh`，包括区域变体）显示 `zh`，英文及其他界面语言显示
`en`。若目标语言为空，回退到另一份非空公告；切换界面语言后公告立即跟随。为兼容旧记录，
服务端和新客户端仍支持旧的纯字符串 `announcement`，但新发布应使用双语对象。

服务端规则：强制发布时 `last_force_version_code = version_code`，普通发布时继承上一条记录
的值，永不自动降低。现有数据库会自动迁移，并根据历史强制版本补齐该字段。
新客户端对缺少该字段的旧响应回退为 0，同时继续识别 `force_update`。

客户端仅在最新构建号更高时处理更新，其强制判定为：

```text
force_update == true 或 当前安装构建号 < last_force_version_code
```

例如先发布强制版 23，再发布普通版 24：响应为 `version_code: 24`、`force_update: false`、
`last_force_version_code: 23`。构建号 22 仍按强制更新处理（下载最新的 24），构建号 23 则可
选择跳过 24；不会因为新发普通版本而丢失强制升级要求。

本项目 `pubspec.yaml` 中的 `version: 0.3.22+22` 对应 `version = 0.3.22`、
`version_code = 22`。打包时如使用 `--build-number` 覆盖，以最终 APK 的构建号为准。
`version_code` 必须与实际 APK 一致，不使用版本字符串或时间戳判断新旧。

若尚未发布任何版本，返回 `503`，正文如下；客户端正常进入应用，等待下次启动再检查：

```json
{
  "error": {
    "code": "no_release",
    "message": "No Android release has been published"
  },
  "timestamp": 1789056000000
}
```

## 2. 管理员发布接口

```http
POST https://update.voce.chat/admin/client/android/releases
Authorization: Bearer <UPDATE_ADMIN_TOKEN>
Content-Type: application/json
```

请求正文与检查响应相同，但**不发送 `timestamp` 和 `last_force_version_code`**；两者由服务端
生成，管理员不能手动降低历史强制版本。完整请求示例：

```bash
cat > release.json <<'JSON'
{
  "version": "0.3.23",
  "version_code": 23,
  "force_update": false,
  "update_url": "https://update.voce.chat/downloads/vocechat-0.3.23.apk",
  "announcement": {
    "zh": "本次更新：\n1. 修复已知问题\n2. 优化聊天体验",
    "en": "What's new:\n1. Bug fixes\n2. Improved chat experience"
  }
}
JSON

curl --fail-with-body \
  -X POST 'https://update.voce.chat/admin/client/android/releases' \
  -H "Authorization: Bearer ${UPDATE_ADMIN_TOKEN}" \
  -H 'Content-Type: application/json' \
  --data-binary @release.json
```

管理员令牌只配置在更新服务和发布机器/CI，绝不写入 Flutter 客户端。正文最多 64 KiB，
包含公告和扩展字段。公告通过 JSON 编码提交，换行写为 `\n`。

| 状态码 | 含义 |
| --- | --- |
| `201` | 新版本已持久化并生效；响应为最新版本元数据及当前时间戳 |
| `200` | 最新构建号及全部元数据与上次发布相同，幂等成功 |
| `400` | JSON、字段、类型或 URL 不合法，双语公告缺少 `zh`/`en`，或提交服务端生成字段 |
| `401` | 缺失或无效管理员令牌 |
| `409` | 构建号低于当前最新版，或尝试修改同一构建号已有元数据 |
| `413` | 正文超出 64 KiB |
| `415` | 请求不是 `application/json` |
| `503` | 版本数据库暂不可用 |

版本记录不可变。需要修正错误版本时，发布更高构建号的 APK 和记录；当前不提供删除、
降级回滚或单独编辑旧版本公告/强制策略的接口。SQLite 事务保证并发发布不会让低构建号
覆盖高构建号，容器重启不会丢失版本，历史记录保存在数据库中。

发布接口只发布版本元数据，不上传 APK、不远程安装、不推送或唤醒客户端。
应先上传并验证可下载的正式签名 APK，再发布元数据。安装包必须使用相同应用 ID 和
兼容的签名证书。示例下载地址仅为示例，需实际放置 APK。

## 3. 客户端行为

1. Android 进程启动后发起一次检查，不等待登录；其他平台不发起请求。
2. 读取实际安装包的构建号，只有远端 `version_code` 更高才显示更新提示。
3. 普通更新显示“稍后再说”“跳过此版本”和“下载更新”。“稍后再说”仅关闭本次提示；
   “跳过此版本”持久保存该构建号，之后重启也不提示同一版本。出现更高构建号时正常提示。
   强制要求的优先级高于“跳过此版本”，不能借普通跳过记录绕过强制更新。
4. 强制更新最多可应急跳过 3 次。每次点击扣除一次机会，并从点击时开始获得完整 24 小时
   免提醒期，期间重启或发布其他新版本不重复提醒、不重复扣次数，也不补充次数。第三次
   同样享有完整 24 小时；到期后下一次冷启动检查显示不可跳过的更新提示。
   应用一直运行时，时间到期也不会弹窗打断，仍等下一次冷启动。
5. 应急次数和免提醒期限、普通跳过构建号保存在应用级 SharedPreferences 中，切换账号或
   聊天服务器不重置。只有实际安装构建号达到之前已记录的强制要求后才重置应急周期；
   仅发布新的普通或强制版本不会重置。未达到要求的部分升级也不重置。
   24 小时使用设备时钟计算，本地应用数据清除/卸载会清除该记录。
6. 提示位于路由之上；除上述明确的跳过操作外，返回键、页面导航和点击背景都不能移除
   提示。跳过状态先成功写入本地存储，再关闭提示；存储失败时保留提示并显示错误，
   不提供无法记账的应急跳过。
7. “下载更新”调用 Android 原生 DownloadManager，在 App 内显示下载进度。支持后台下载、
   取消、失败重试；重启后从系统恢复当前构建号的下载状态。APK 保存到应用专属 updates
   目录，无需访问公共文件夹的存储权限。内容长度未知时显示已下载 MB。
8. 下载完成时，若更新页面仍在前台，自动检查 APK 的应用 ID 和构建号，并唤起系统原生
   安装界面。恢复已完成的下载时显示“安装更新”，不会重新下载安装包。
   低版本、构建号不匹配、其他应用或无效文件会拒绝并允许重新下载。
9. Android 8+ 首次安装需要允许 VoceChat 安装应用。点击“允许安装”进入本应用的系统授权
   页面，返回后继续安装；拒绝授权或取消安装都可重试。系统安装器执行签名和平台兼容性
   校验，用户必须确认安装。App 不执行静默安装，也不会把打开安装器当作升级成功。
10. 用户跳过更新提示时，系统下载可以继续，但不会自动在后台打开安装器；下次提示更新时
    可继续安装。取消下载只取消传输，不会解除强制升级要求或消耗应急跳过次数。
11. 网络异常、无已发布版本、响应字段错误、读取本机版本失败时，本次启动正常进入应用。
   不凭本地历史记录离线锁定应用，不轮询；下次启动重试。HTTP 层可能对临时网络/5xx错误有限重试。

这是一套“成功检查后执行强制更新”的客户端机制，不用于保证离线用户必须升级。
如果未来需要禁止旧版访问服务器，需要另行增加聊天服务端的最低版本校验。

实现入口：

- `lib/features/app_update/domain/android_release.dart`：协议模型、字段校验、构建号比较。
- `lib/features/app_update/data/android_update_api.dart`：固定域名检查 API，经现有 Dio 请求层
  显式清除 `X-API-Key` 并禁止 401 刷新登录令牌，禁止跟随检查接口重定向。
- `lib/features/app_update/application/app_update_provider.dart`：Android 平台限制和进程内一次检查。
- `lib/features/app_update/application/app_update_controller.dart`：历史强制要求、跳过策略及 24 小时免提醒。
- `lib/features/app_update/data/update_preferences_store.dart`：应用级更新偏好持久化。
- `lib/features/app_update/presentation/app_update_gate.dart`：全局提示与公告，适配小屏和长公告。
- `lib/features/app_update/presentation/apk_download_panel.dart`：进度、取消、重试与安装授权交互。
- `android/app/src/main/kotlin/com/vocechat/vocechat_client/AndroidUpdateInstaller.kt`：DownloadManager、包信息检查与 FileProvider 安装。
- `lib/main.dart`：在路由上方挂载 `AppUpdateGate`。

提示文案已提供中英文，项目中尚未补齐的其他语言采用英语回退。公告内容由管理员提供两种语言。

## 4. 扩展约定

服务端保留并透传额外 JSON 字段，现有客户端只解析已知字段，忽略未知字段。
新增可选字段不改变原字段的类型、单位或语义；未知字段不能作为旧客户端的必要行为条件。
未来若有破坏性协议变化，使用新的版本化接口，继续保留现有接口供旧客户端使用。

以下仅为候选字段，当前没有对应业务行为：

| 候选字段 | 用途 |
| --- | --- |
| `published_at` | 发布时刻，与每次变化的响应 `timestamp` 区分 |
| `sha256` | 安装包摘要；当前校验包名和构建号，系统验证签名，尚未读取该可选摘要字段 |
| `file_size` | 安装包字节数，显示下载大小 |
| `min_android_sdk` | 安装包所需 Android 最低 API 等级，避免向不兼容设备推送安装包 |
| `channel` | 区分稳定版、测试版；需要同时增加服务端按渠道保存/查询以及客户端渠道选择逻辑 |

当前只有 Android 稳定版一个发布序列；将来可增加 `/client/ios`、`/client/windows` 等平台接口，
各自采用合适的版本和分发规则。

## 5. 部署

独立服务在 `tool/update_server/`，使用 **uv** 管理 Python 3.12 环境与依赖（含 Web 管理页），包含 `pyproject.toml`、
`uv.lock` 和 `.python-version`。运行时仅使用标准库 + SQLite，构建时使用固定版本 setuptools；后续依赖用
`uv add` 添加并一起提交锁文件。无需修改聊天服务器。

将整个 `tool/update_server/` 目录复制到其他机器（或解压发布 ZIP），在该目录中执行：

```bash
uv sync
uv run vocechat-update-server
```

浏览器打开 `http://服务器IP:8080/admin/` 使用 Web 管理页。首次启动自动生成管理员令牌，
保存在数据库所在目录的 `admin-token.txt`（默认 `data/admin-token.txt`），在页面中填写后
即可发布。令牌不会通过 HTTP 提供，也不会保存在浏览器持久存储中。

uv 会创建 `.venv` 并选择 Python 3.12；没有合适解释器时可自动下载安装。
构建依赖 setuptools 版本固定在 `pyproject.toml`，运行时无需 Node 或其他第三方服务。

可复制 `config.example.toml` 为 `config.toml` 调整监听地址、端口和数据库。
环境变量 `UPDATE_HOST`、`UPDATE_PORT`、`UPDATE_DB` 优先于配置文件。
设置 `UPDATE_ADMIN_TOKEN` 可覆盖自动生成的令牌；已有 `.env` 时显式使用
`uv run --env-file .env vocechat-update-server`。

也可使用 Docker：

```bash
docker compose up -d --build
docker compose exec update cat /data/admin-token.txt
```

Compose 在本机 `127.0.0.1:8080` 暴露服务，命名卷 `releases` 保存数据库和自动令牌；
不要使用 `docker compose down -v` 删除生产数据卷。Docker 使用固定版本 uv，构建时按
锁文件安装，运行时无需联网同步依赖。

直接运行默认监听 `0.0.0.0:8080`，可通过 `UPDATE_HOST`、`UPDATE_PORT`、`UPDATE_DB` 配置。
数据库文件放本机持久磁盘，不共享到多个服务实例/网络文件系统；当前面向单实例部署。

将域名 DNS 指向部署主机，在主机上用 Caddy 自动签发 TLS 并代理，例如：

```caddyfile
update.voce.chat {
    handle /downloads/* {
        root * /srv/update
        file_server
    }
    handle {
        request_body {
            max_size 64KB
        }
        reverse_proxy 127.0.0.1:8080
    }
}
```

如果沿用示例下载地址，APK 放在 `/srv/update/downloads/vocechat-0.3.23.apk`。
也可以将 `update_url` 指向已有 HTTPS 对象存储/CDN，这时不需要 `/downloads/*` 配置。
检查和管理接口禁止 CDN 缓存，APK 可单独按不可变版本文件名缓存。

首次部署先发布一条与已分发 APK 对应的正式版本记录，再检查：

```bash
curl --fail-with-body 'https://update.voce.chat/client/android'
```

本仓库提供代码、配置示例和本地测试；没有执行 DNS、TLS、线上部署或上传正式 APK。

## 6. 验证

Flutter 项目目录中：

```bash
flutter test --no-pub test/features/app_update
dart analyze lib/features/app_update lib/main.dart test/features/app_update
```

`tool/update_server/` 目录中：

```bash
uv run --locked python -m unittest -v test_server.py
```

覆盖元数据解析、扩展字段、构建号比较、平台限制、每次进程一次检查、双语公告和界面语言
切换、三次应急跳过及完整 24 小时边界、重启后保留偏好、普通版本跳过、强制版本继承、
升级后额度重置、存储错误、下载失败重试、小屏长公告，以及发布鉴权、幂等、防降级、
事务并发、持久化和旧数据库迁移。
实际 Android APK 下载与系统安装仍需使用正式签名包在设备上验收。

## 原生安装验收

用相同 applicationId、正式签名的较低版本安装到设备，发布更高构建号的 APK 直链。
验证 Android 8+ 拒绝/允许未知来源安装、授权返回、安装取消再试、前后台下载、杀进程恢复、
下载失败与取消、HTML 下载页/错误包名/错误构建号被拒绝，以及成功覆盖安装后的版本检查。
服务端元数据字段没有变化，已部署服务无需升级即可配合原生下载，只需保证 URL 指向 APK。
