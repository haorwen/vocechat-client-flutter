# Android Agora SDK 精简

Android 构建默认排除 `android/agora-excluded-libraries.txt` 中的 11 个可选扩展，适用于 standalone/play 两个渠道和全部已构建 ABI。保持 `agora_rtc_engine: 6.5.4` 及其配套原生版本，不修改 Pub 缓存或生成的插件文件。

裁剪内容为：美颜／视频增强、唇形同步、空间音频、虚拟背景、面部动作捕捉、可选人脸 ROI 分析、美声、内容检测、主观视频质量评分。当前应用未启用这些扩展；Avo 头像通过音量和自己的互动协议驱动，不依赖 Agora 唇形同步或面捕。

第二轮额外移除低延迟 AI 降噪／回声消除两个 `_ll_extension` 变体。官方说明普通版和低延迟版独立，默认使用普通版，切换低延迟版需额外配置；当前项目没有该配置。保留普通版 AI 降噪和回声消除，同时保留 RTC 核心、Iris／Flutter 桥接和渲染、屏幕采集、全部现有编解码库。视频质量评分扩展不是视频编码器，也不是网络质量回调。没有启用的美声效果与通话所需的降噪／回声消除不同，不应一并删除。

本文记录 Android 打包；iOS 的对应实现见 [iOS Agora 框架裁剪](agora-ios-size.md)。macOS 和 Windows 仍需要各自验证，不能直接套用 `.so` 排除规则。

## 体积依据

2026-09-17 对工作区根目录已有 `app-release.apk` 的 ZIP 条目统计如下。它是历史产物，不是本次源码重新构建结果。

| ABI | 11 个可选扩展合计 |
| --- | ---: |
| arm64-v8a | 36.37 MiB |
| armeabi-v7a | 29.43 MiB |
| x86_64 | 9.44 MiB |
| 合计（按未取整数计算） | 75.24 MiB |

该 APK 为 265.22 MiB，扩展条目没有压缩。其他内容相同的情况下，排除这些条目的文件负载约降至 189.98 MiB；不是已经生成的新 APK 实测值，最终大小还受版本、ZIP 对齐和签名等影响。第一轮 9 个扩展节省 66.19 MiB，第二轮低延迟变体额外节省约 9.05 MiB（三架构合计）。

本次还检查了历史 APK 中保留 `.so` 的 ELF `DT_NEEDED`，没有发现它们对排除库的直接依赖。SDK 动态加载行为仍需要实际构建和真机测试；静态依赖检查不等于运行验证。裁掉未加载的扩展主要减少包体，不据此承诺 CPU、内存或耗电改善。

## 构建与产物检查

在 Flutter 项目目录执行。裁剪和 APK 原生库压缩默认生效：

```sh
flutter build apk --release --flavor standalone
python3 tool/rtc_size/audit.py build/app/outputs/flutter-apk/app-standalone-release.apk --verify --verify-compressed
```

按架构分发可以进一步避免每位用户下载三份原生库；保留每种受支持架构的 APK，不用删除架构来换取体积数字：

```sh
flutter build apk --release --flavor standalone --split-per-abi
python3 tool/rtc_size/audit.py build/app/outputs/flutter-apk/app-armeabi-v7a-standalone-release.apk --verify --verify-compressed
python3 tool/rtc_size/audit.py build/app/outputs/flutter-apk/app-arm64-v8a-standalone-release.apk --verify --verify-compressed
python3 tool/rtc_size/audit.py build/app/outputs/flutter-apk/app-x86_64-standalone-release.apk --verify --verify-compressed
```

Play 继续使用 AAB，商店按设备交付所需架构。不要把 AAB 总大小当成用户下载大小：

```sh
flutter build appbundle --release --flavor play
python3 tool/rtc_size/audit.py build/app/outputs/bundle/playRelease/app-play-release.aab --verify
```

`audit.py` 不传 `--verify` 时可分析旧 APK 的可裁剪条目和占用；传入后会检查 11 个扩展全部不存在，并且每种 ABI 的 RTC 核心、屏幕共享、Iris 桥接／渲染、普通版 AI 降噪／回声消除库仍存在。它不修改 APK，不验证签名，不替代通话验收。

需要对比完整 SDK 时，可关闭裁剪：

```sh
ORG_GRADLE_PROJECT_keepAgoraExtensions=true flutter build apk --release --flavor standalone
```

对照构建会覆盖同路径产物，比较前先各自保存。不要对未裁剪的对照包使用 `--verify`。

## 进一步减少直接下载 APK

历史 APK 的 `.so` 条目采用未压缩存储，以便系统直接从 APK 映射加载。项目现在默认压缩 APK 原生库，将安装时解压的成本换成更小的下载包；建议同时按架构构建：

```sh
flutter build apk --release --flavor standalone --split-per-abi
```

默认设置 AGP 的 `jniLibs.useLegacyPackaging = true`。压缩不删除功能，但安装器需要解压原生库，安装后通常同时保留压缩 APK 和提取的原生库，磁盘占用可能增加；不要把下载减少量当成安装占用减少量。它也不会解决 ELF 页面对齐问题。Play AAB 继续按商店交付方式处理，不据此推算 Play 下载大小。`audit.py --verify-compressed` 检查 APK 内所有 `.so` 条目是否采用 DEFLATE，仅适用于 APK。

如果需要恢复原生库直接加载，可显式关闭压缩：

```sh
ORG_GRADLE_PROJECT_compressNativeLibraries=false flutter build apk --release --flavor standalone --split-per-abi
```

以旧 APK 的条目进行模拟：排除其他两种 ABI 和 11 个扩展，保留其他内容，文件负载约 84.90 MiB；将剩余 arm64 原生库按 zlib level 6 压缩，其他条目保持原压缩大小，合计约 42.03 MiB。这个数字不是新构建的可安装 APK；实际 ZIP DEFLATE、签名、对齐、资源及源码版本都会影响最终结果。

## 继续缩小的边界

旧包 arm64 中，当前必须保留或不能直接删除的大项：Agora 主库约 26.79 MiB、它直接依赖的 `libagora_ffmpeg.so` 约 6.23 MiB、Flutter 引擎约 11.05 MiB、Dart AOT 业务代码约 10.25 MiB，以及播放器 `libffmpeg.so` 约 7.69 MiB。

- `readelf` 确认 Agora 主库直接依赖 `libagora_ffmpeg.so`、FDK AAC、SoundTouch、`libvideo_dec.so` 和 `libaosl.so`，不能通过排除文件来删除它们。
- 播放器的 FFmpeg 不是重复打包的同一个 Agora FFmpeg。`lib/main.dart` 明确为 Android 启用了 FVP，用于硬件不支持部分 HEVC 视频时的软件解码回退。移除它会削弱现有附件视频播放兼容性。
- Maven 的 `lite-sdk` 列表包含 4.5.3，但未列出当前 Flutter 插件绑定的 special 版本 4.5.3.70。当前 `agora-special-full:4.5.3.70` 是一个 AAR，没有可直接从 POM 排除的分模块依赖。要更换 Lite 核心，需要验证 Iris ABI、屏幕共享和音频处理能力，不能把版本号相近当成二进制兼容。

因此现阶段进一步降低直接下载体积的可用手段是按 ABI 分发＋原生库压缩；更换核心属于下一阶段的兼容性迁移，而非再删几个库名。

## 验收与维护

发布前用裁剪包验证：与现有 Web／旧客户端双向语音视频、多人通话、静音／屏蔽声音、摄像头切换、屏幕共享开始／停止／取消授权、画中画与后台恢复、耳机／蓝牙切换、Avo 音量动画。音频回声和降噪效果应与完整包对比。

本地缺少 Java／Android SDK，本次未构建新的 APK/AAB，也未完成设备通话验收。构建配置及历史包依赖检查已完成；上线前应补齐构建和上述验收。

升级 Agora 或增加美颜、虚拟背景等功能时，重新核对清单及版本。不要使用 `libagora_*_extension.so` 通配删除，会连屏幕共享和音频处理一起裁掉。若以后使用清单中的功能，先从排除清单移除相应库。

官方依据：[Flutter App size optimization](https://docs.agora.io/en/realtime-media/rtc/build/optimize-and-operate/app-size-optimization/flutter.md)，使用 Gradle packaging exclusions 移除未使用的可选动态库。
