# Android 白屏排查与恢复

## 已处理的故障路径

### Activity 与 FlutterEngine

standalone 的 FlutterEngine 由 `AppFlutterEngine` 显式创建并管理。Activity
在连接引擎之前登记自己的实例身份，销毁时只能释放自己持有的引擎；后台服务
停止也只能释放没有 Activity 使用的引擎。旧 Activity 的延迟销毁不能影响新界面。

通知入口统一使用 `NEW_TASK | CLEAR_TOP | SINGLE_TOP`，主 Activity 配置为
`singleTask`。如果系统仍创建另一个 Activity 并转移引擎，失去引擎的旧窗口会
退出，不留在返回栈中形成无法自行恢复的白屏。Play 保留标准的 Activity 引擎生命周期。

邀请链接交给 `app_links`，消息通知交给通知 bridge；关闭 Flutter 内置的重复
deep-link 转发，避免通知的身份 URI 被当作聊天路由。

### 启动与页面恢复

`runApp` 不再等待 Firebase、媒体缓存清理或视频代理完成。可选任务各自有超时
和异常记录；Firebase 晚完成仍会启用通知监听并同步设备 token。视频、音频后端
在进程内只注册一次，界面重试不替换正在释放播放器的全局后端。

启动页等待 15 秒后提供手动重试；原任务正常完成时仍能继续进入应用。严重构建、
布局异常会显示可见的恢复页，手动重试重建内存中的界面和 providers，不删除
账号、登录凭据或消息缓存。普通异步请求错误、调试模式的小幅布局溢出不会重建应用。

界面重建时同步撤销旧通知 handler 的所有权，并释放旧通话资源；旧 provider 的
延迟回调不能清除新界面的 handler 或继续修改通话状态。通话引擎的初始化合并为
同一个进行中的操作，新引擎必须等待旧引擎实际释放后才可创建。等待超过 8 秒会
退出通话的加载状态，其他界面仍可操作；若原生释放一直不返回，通话功能仍可能
需要重启进程才能恢复，不能通过重复创建原生引擎强行绕过。

### 通知、路由与异步请求

- 通知只有在目标聊天已经匹配后才消费，不在页面构建期间修改 provider。
- 消费通知不再触发旧地址的额外刷新，避免跳转成功后被撤销；快速点击以最新目标为准。
- 未登录时保留待打开聊天，完成登录后继续；非法 ID 和未知页面都有可见退路。
- 邀请链接串行处理，合并进行中的重复请求，销毁后的旧请求不得继续导航。
- Dio 拦截器遇到异常也必须完成 handler；错误响应字段的类型不符合预期时不再永久挂起。
- 账号切换和手动 bootstrap 失败必须退出 loading。
- 长时间后台恢复时保留最初的暂停时间，恢复途中的 `hidden` 不再覆盖计时。

## 自动回归

在项目根目录运行：

```sh
flutter test --no-pub
flutter test --no-pub --dart-define=FLUTTER_APP_FLAVOR=play test/core/background/play_distribution_test.dart
```

原生通知、生命周期和引擎所有权测试：

```sh
cd android
bash gradlew :app:testStandaloneDebugUnitTest :app:testPlayDebugUnitTest
```

`RetainedEngineOwnerTest` 验证旧实例释放、服务停止、后台引擎重开、配置重建和
创建失败后的重试；`AppLaunchIntentTest` 验证通知复用参数与 Manifest。
`MessageNotificationTest` 使用 API 28 与 Robolectric 原生 SQLite，验证并发去重、
数据库重开和通知目标保留。每个用例独立关闭 SQLite helper，避免测试残留连接。

## Android 运行时回归

1. 冷启动以及后台返回：服务器选择、登录、聊天入口可显示，应用可操作。
2. 点击消息通知、常驻通知、应用图标和最近任务：在现有主界面打开目标，反复点击不留空任务。
3. 打开系统文件选择器或相机后点击通知：回到主界面；再按返回不会进入已失去引擎的旧窗口。
4. 常驻开启后划掉最近任务，再点击通知：保留的引擎重新连接界面，消息连接继续运行。
5. 关闭常驻或退出账号，同时让旧 Activity 销毁：当前可见界面的引擎保持有效。
6. 后台停留超过两分钟再恢复：重新建立消息连接；短暂通知栏和权限弹窗不触发无谓重连。
7. 初始化延迟、未知路由和可控构建错误：显示明确提示，重试可恢复，持久化账号仍在。
8. 通话中恢复界面：旧通话资源释放、旧回调不影响新界面；普通网络异常不打断正常通话。

可用以下日志确认引擎转移、释放顺序（只记录实例 ID 和状态，不记录消息或 token）：

```sh
adb logcat -v threadtime VoceEngineLifecycle:I FlutterActivity:W flutter:E '*:S'
adb shell dumpsys activity activities
```

`evicted ... finishing detached window` 表示异常的重复 Activity 已被关闭。
若可见界面之后出现 `destroy engine`，应核对它是否属于仍有 owner 的引擎。
系统杀进程、Flutter 引擎或第三方原生库崩溃、系统 GPU 故障，不能由 Dart 恢复页兜住，
仍需结合设备日志判断；不能仅凭白屏表现断定为网络故障。

## 本次验证记录（2026-10-01）

- Linux Flutter 3.27.1：全套 Flutter 测试 328 项通过、2 项渠道专属用例跳过；
  单独指定 Play 渠道的 3 项测试全部通过。最终启动、恢复、路由、后台通知 handler
  与通话变更已再次定向回归，最后补充的通话超时边界也通过（通话共 13 项）。
- 原生隔离 Gradle 工程使用项目实际 Kotlin 源码、Flutter embedding 和 Agora Activity
  依赖编译；standalone、Play 各 15 项测试通过。该结果不等同于完整 Flutter APK 构建。
- 完整项目另外在 Windows Flutter 3.44.9 临时副本中构建 standalone 的 x64 和 ARM64
  debug APK。Android API 35 x64 模拟器验证了冷启动、后台返回、使用通知相同参数的
  Intent 冷/暖启动及重复进入、打开添加服务器界面和返回；各 Activity 快照均只有一个
  MainActivity，页面截图可见且可操作。运行日志未见应用崩溃或 Flutter 异常。
- APK 的手写 Dart、ARB 和 Android 产品源码与工作区一致；临时副本的 l10n 生成文件
  因 Flutter 版本不同有生成格式差异，依赖按临时环境解析，工作区依赖锁文件未改动。
- 改动 Dart 文件定向静态检查通过；全项目分析仍有 6 个既有 warning/info，位于
  server_store.dart、message_api.dart 和 server_picker_screen.dart。

本地截图、UI XML、Activity 快照、日志、构建记录和调试 APK 位于
`build/diagnostics/blank-screen/`（不纳入版本管理）。模拟器未配置真实服务器账号；
Intent 回归不代表真实 FCM 通知投递、文件选择器/相机重入或通话中的完整端到端验证。
