# Android 本地消息通知去重

## 范围

本功能仅修改 Flutter/Android 客户端，使用现有服务端接口。FCM 保持原有 FlutterFire 注册和接收方式，不新增服务端 API 或推送协议。

WebSocket 本地通知进入 `MessageNotificationRouter`，用 SQLite `(session, mid)` 唯一约束记录是否已处理；`session = serverId::recipientUid`。不使用消息内容或最大 mid 推测重复。

## 行为

- 通知前提交记录。清空通知栏、切换账号、关闭常驻、进程重启都不删除记录；并发或重连补收不会重复提醒同一条本地消息。
- 前台收到的消息及被通知偏好过滤的消息也记录为已处理，避免退到后台后补收重新提醒。通知权限阻止展示时不占用记录，允许后续本地投递重试。
- 常驻关闭时不显示 WebSocket 本地通知，FCM 仍按原有机制工作。通知去重不会跳过消息落盘与聊天内容更新。
- 不接收当前账号以外的消息；通知 PendingIntent 使用包含完整账号和会话的 URI。私聊标题显示联系人名，群聊标题显示群名，正文包含发送者名。优先使用已加载的名称，其次读取本地缓存，不额外请求网络。
- 记录保留 8 天，拒绝创建时间超过 7 天或明显超前的消息通知。聊天历史仍正常同步。不以固定条数淘汰记录，避免大量消息把仍有效的记录挤掉。

## 限制

现有服务端 FCM payload 不包含与 WebSocket 一致的消息 ID，后台 notification 消息由 Firebase SDK 自动展示，不经过本地去重入口。因此 FCM 与 WebSocket 同时可用时仍可能显示重复通知；不能仅靠客户端可靠实现跨通道去重，也不按正文与时间猜测重复而误吞消息。

SQLite 提交与 Android NotificationManager 之间不能原子执行。如果进程在提交后、展示前崩溃，该条本地提醒可能缺失；重放仍会被去重，聊天内容可由同步恢复。

## 验证

- Flutter：`flutter test --no-pub test/core/notifications test/core/background`，覆盖本地去重 key、前后台路由、名称与缓存回退、账号切换及通知过滤。
- Android：`cd android && bash gradlew :app:testDebugUnitTest --tests '*MessageNotificationTest'`，覆盖重复投递、并发争抢、数据库重开、清空通知、账号隔离、乱序 mid、前台/过滤消息及过期记录。
- 真机：断线重连与清空通知后补收不重复；私聊和群聊名称显示正确；通知点击进入正确会话；分别检查常驻开启/关闭及 FCM 可用/不可用时的行为。

当前环境缺少 Android SDK/Java，原生 Robolectric、Android 构建及真机检查需在完整 Android 环境运行。
