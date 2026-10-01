# Android 发布渠道

Android 使用 `standalone` 和 `play` 两个 product flavor；包名和版本号相同，不安装为两个应用。用 `--flavor` 同时选择 Android 原生配置和 Flutter 的 `appFlavor`，不需要另传功能 dart-define。其他平台仍按原来的命令构建，不要传 Android flavor。

| 功能 | standalone | play |
| --- | --- | --- |
| 现有 FCM 推送 | 保留 | 保留 |
| 用户手动开启常驻后台、本地消息通知 | 保留 | 关闭，无设置入口 |
| 电池优化豁免请求 | 保留 | 移除 |
| 应用启动检查更新、强制/可选更新弹窗 | 保留 | 关闭，不请求更新接口 |
| APK 下载与安装 | 保留 | 无原生入口，移除安装权限与更新 FileProvider |
| 通话、屏幕共享 | 保留 | 保留 |

## 自动发布到内部测试

GitHub Actions 流程、Secrets 和首次 Play Console 配置见 [Google Play 内部测试发布](google-play-internal-release.md)。

## Google Play AAB

在 Flutter 项目目录执行：

```sh
flutter pub get
flutter build appbundle --release --flavor play
```

输出：`build/app/outputs/bundle/playRelease/app-play-release.aab`。

Play flavor 的 Manifest 合并规则移除 `BackgroundMessageService`、`FOREGROUND_SERVICE_SPECIAL_USE`、`FOREGROUND_SERVICE_MICROPHONE`、`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`、`REQUEST_INSTALL_PACKAGES` 以及更新安装使用的 FileProvider。屏幕共享仍需要的通用前台服务和 mediaProjection 权限保留；不能删除所有 FOREGROUND_SERVICE 权限。

Dart 的常驻后台支持和更新检查均按 flavor 关闭；原生 MainActivity 不创建后台消息 bridge、不保留后台 FlutterEngine，也不注册 APK 下载/安装 channel。历史保存的常驻开启状态不会恢复。FCM 保持原有 FlutterFire 初始化、token 注册和通知处理。

使用项目现有的 release/upload 签名配置 `android/key.properties`，并提供真实 `android/app/google-services.json`（CI 也支持 `GOOGLE_SERVICES_JSON_BASE64`）。现有构建在缺少签名文件时会回退 debug 签名，上传 Play 前需配置上传密钥。Play flavor 本身不替代 Firebase 与服务端 FCM 凭据配置。

## 普通 APK

```sh
flutter build apk --release --flavor standalone
```

输出：`build/app/outputs/flutter-apk/app-standalone-release.apk`。

加入 flavor 后，Android 运行、打包和原生测试应显式指定渠道，例如 `flutter run --flavor standalone`、Gradle `:app:testStandaloneDebugUnitTest`。APK/AAB 格式本身不决定功能，必须选对 flavor。Play 版也可构建 APK 供本地验收：`flutter build apk --release --flavor play`。

## 验证

```sh
flutter test --no-pub test/core/background test/core/notifications test/features/app_update
flutter test --no-pub --flavor play test/core/background/play_distribution_test.dart
```

Play 测试验证设置入口隐藏、已有常驻偏好不生效、不会调用后台 channel、不会初始化更新弹窗或请求更新 API。普通渠道继续回归现有后台与更新行为。

构建后用 Android Studio 的 APK Analyzer 或 bundletool 检查 **最终合并 Manifest**，确认上述 service/permissions/provider 不存在，同时保留 FlutterFire 服务与通知权限。随后真机检查 FCM 收取与通知点击、后台设置缺失、启动无更新请求及通话/屏幕共享。

当前开发环境缺少 Android SDK/Java；Flutter 测试不能替代最终 AAB 的原生构建、Manifest 合并检查及真机验收。
