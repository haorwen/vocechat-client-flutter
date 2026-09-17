# 自实现 Agora 通话客户端：API 与可行性核查

核查日期：2026-09-17。

## 目标与结论

参考 Agora Web SDK 的 API 和行为，自行实现 Flutter 客户端需要的语音、视频、屏幕共享功能，替换当前 `agora_rtc_engine` 全量封装。必须保留 Agora 服务和现有 VoceChat Web／旧客户端互通。不使用 WebView，不改为独立的 WebRTC 通话网络。

公开资料可以支持“自建通话控制和媒体层，保留必要的 Agora 传输组件”。本次没有找到足以实现独立 Agora 兼容传输客户端的完整公开信令／传输协议规范。Web SDK 的 `join/publish/subscribe` 是 SDK 方法，不是可以直接用 HTTP 调用的服务端媒体 API。不能据此把标准 WebRTC PeerConnection 接上当前 token 接口，就声称完成了 Agora 互通。

找到了接近目标的 **RTSA Lite C API**，并检查了官方下载的 Android 包：其 arm64 传输库仅 2,176,488 字节（2.08 MiB）。但官方把 Android 1.8.0 标记为 **no longer updated**；这个二进制的 ELF LOAD 段是 4 KiB 对齐；公开头文件没有 VP8 类型。因此不能直接将其替换进正式客户端并承诺功能、设备兼容性不下降。

可维护的候选路线是自己编写小范围的 Flutter 原生插件，直接接入经过兼容性验证的 Agora 原生核心，绕过完整 Flutter/Iris 封装；需要自行掌控的媒体功能使用系统 API。是否进一步缩到 RTSA 传输层，取决于当前受支持版本、平台、编解码互通和音频处理的验证结果。**这是调查结论，尚未完成 SDK 替换或运行时性能验证。**

## 当前项目的功能基线

- Flutter 依赖为 `agora_rtc_engine: 6.5.4`。本地包 Android 依赖为 `iris-rtc:4.5.3-build.1`、`full-screen-sharing-special:4.5.3.70`、`agora-special-full:4.5.3.70`。
- `lib/features/voice/application/voice_controller.dart`：单聊／群聊加入退出、成员状态、静音／屏蔽声音、摄像头切换、摄像头与屏幕互斥、音量、网络状态、重连状态，以及 Android/iOS 原生画中画。
- `lib/features/voice/presentation/voice_participant_video_tile.dart`：通过 `AgoraVideoView` 渲染，直接依赖 Agora engine，替换时必须一起解除耦合。
- `lib/features/voice/presentation/voice_operations_bar.dart`：屏幕共享入口目前仅向原生 Android、Windows、macOS 显示；iOS 和 Web 未显示此入口。控制器存在 iOS 分支，不代表 iOS 完整 ReplayKit 屏幕共享已实现。
- 移动端屏幕采集明确 `captureAudio: false`；系统声音共享和摄像头＋屏幕双视频流不是当前已实现的功能基线。
- `lib/features/voice/application/avo_interaction_controller.dart` 的头像互动独立于 Agora 媒体；不能用 Agora 唇形同步扩展是否保留来判断头像互动是否保留。
- Web 参考实现 `../vocechat-web-just-reference/src/components/Voice/index.tsx` 创建 `mode: "rtc", codec: "vp8"` 客户端；视频互通必须包含这一配置。
- 现有 Token API 返回 `app_id/channel_name/uid/agora_token/expired_in`；房间命名由服务端决定，UID 是数字。来电发现、活跃房间和成员查询继续复用现有接口。保持同名方法不等于保持实际通话互通。

## 可参考的 Web API 与自实现职责

官方 API：https://api-ref.agora.io/en/video-sdk/web/4.x/index.html 。本次 npm `latest` 返回 4.24.8；以下为公开 API，并非底层协议定义。

| 功能 | Web SDK API／事件 | 自实现需要承担的职责 |
| --- | --- | --- |
| 初始化与连接 | `createClient`、`join`、`leave` | 状态机、异步取消、失败清理、重连、成员身份；仍需 Agora 兼容的传输实现 |
| 鉴权续期 | `renewToken`、`token-privilege-will-expire`、`token-privilege-did-expire` | 用原目标重新取 token，更新连接，处理退出与续期竞态 |
| 麦克风 | `createMicrophoneAudioTrack`、`publish` | 权限、采样、编码、回声消除、降噪、增益、音频路由与中断 |
| 摄像头 | `createCameraVideoTrack`、`publish` | 采集、旋转／镜像、硬件编解码、相机切换、前后台生命周期 |
| 屏幕 | `createScreenVideoTrack` | 用各平台屏幕采集 API，处理授权、终止、方向变化和摄像头互斥 |
| 外部媒体 | `createCustomAudioTrack`、`createCustomVideoTrack` | Web 侧接收的是浏览器 `MediaStreamTrack`；不是接入 Agora 服务器的独立上传接口 |
| 收流 | `user-published`、`subscribe`、远端 track `play` | 远端成员和流状态、解码、播放队列、音画同步、Flutter 视频表面 |
| 静音／屏蔽声音 | 本地 `setMuted`／`setEnabled`、远端 `setVolume` 或停止订阅 | 维持现有“取消静音解除屏蔽声音”语义，新加入的远端流也应用屏蔽状态 |
| 设备选择 | `getDevices`、track `setDevice`、远端音频 `setPlaybackDevice` | 音频路由与蓝牙变化、设备拔插、摄像头重启 |
| 成员／音量 | `user-joined`、`user-left`、`enableAudioVolumeIndicator`、`volume-indicator` | UI 状态归一化，音量量程和更新频率适配 |
| 质量与重连 | `network-quality`、`connection-state-change`、统计 API | 带宽自适应、错误映射、连接恢复、性能观测 |
| 停止与释放 | `unpublish`、track `stop`／`close`、`leave` | 释放采集、编解码器、播放表面和连接，防止麦克风持续占用 |

Web SDK 自身提供 ESM tree shaking，但那只能优化 Web 构建，并不能自动转换为 Flutter 原生实现。本次下载包的标准 JS 入口为 1,609,469 字节、gzip 为 430,063 字节；这是 JS 文件大小，未包含浏览器提供的 WebRTC 引擎，不能视作原生全功能实现的包体预算。

## 更接近自实现的 RTSA C API

来源：官方下载页列出的 Android RTSA Lite 1.8.0，包内 `agora_android_sdk/include/agora_rtc_api.h`，已经实际读取头文件。

| 用途 | 已核实的符号 |
| --- | --- |
| 引擎和连接 | `agora_rtc_init`、`agora_rtc_create_connection` |
| 加入／退出／续期 | `agora_rtc_join_channel`、`agora_rtc_leave_channel`、`agora_rtc_renew_token` |
| 发送声音／视频 | `agora_rtc_send_audio_data`、`agora_rtc_send_video_data` |
| 收流 | `on_audio_data`、`on_mixed_audio_data`、`on_video_data` |
| 静音 | `agora_rtc_mute_local_audio`、`agora_rtc_mute_local_video`、`agora_rtc_mute_remote_audio`、`agora_rtc_mute_remote_video` |
| 弱网适配 | `on_target_bitrate_changed`，应用负责调整编码器码率 |
| 关键帧 | `on_key_frame_gen_req`、`agora_rtc_request_video_key_frame` |
| Token 即将过期 | `on_token_privilege_will_expire` |

`rtc_channel_options_t` 提供音频抖动缓冲、混音、音频编解码配置。头文件列出 Opus/G722 等音频类型；视频类型列出 YUV420、H.264、H.265、generic/JPEG，没有明确列出 VP8。类型枚举存在也不等于该二进制支持全部采集／编码行为，应逐项用样例与实测确认。

已核实的限制：

1. 官方 Android 下载版本为 1.8.0，标记停止更新。官方另有较新的 Linux RTSA 包，不能当成 Android/iOS 兼容包使用。
2. arm64 `.so` 的 LOAD 对齐均为 `0x1000`，未达到现代 Android 16 KiB 页面对齐要求；不能靠 APK zipalign 修复 ELF 内部布局。
3. 当前 Web 参考客户端使用 VP8，不能假设改成 H.264 发流后即可与其双向互通；还必须验证接收旧客户端发布的视频。不能把修改旧客户端编码器配置当作无损兼容。
4. 本次没有确认现代 iOS/macOS/Windows 对等 RTSA 版本、完整平台功能、持续维护及实际通话互通。
5. 2.08 MiB 仅为传输库，不包含我们新增的采集、编解码回退、音频处理、渲染和画中画实现。它不是最终 APK 大小，也不能据此声称已获得等比例性能收益。

因此，RTSA 证明了“自己做媒体层、只留小型 Agora 传输组件”这种接口形态确实存在，但当前公开 Android 包不满足直接上线的前提。

## 自建插件的实现边界

建议的分层是：现有 Flutter 通话 UI／业务状态 → 自有 `CallEngine` 接口 → 自有原生媒体与生命周期实现 → 已验证的最小 Agora 传输／媒体核心。

自有接口至少覆盖 join/leave、mute/deafen、camera/screen、token 更新、成员／网络／音量事件、视频表面和画中画。不要在业务层继续暴露 `RtcEngine`、`VideoCanvas` 或 Agora 枚举，否则替换仍会遍及 UI。

原生实现可使用：

- Android：Camera2、MediaProjection、MediaCodec、AudioRecord/AudioTrack、系统音频焦点／路由、Activity PiP。
- iOS：AVFoundation、ReplayKit（若后续补充 iOS 全屏共享）、VideoToolbox、AVAudioSession、AVPictureInPictureController。
- Windows/macOS：分别使用平台摄像头／屏幕采集和硬件编解码接口；要实测多屏和最小化窗口行为。

Flutter 的 MethodChannel 只传控制命令和低频状态，媒体帧留在原生层。视频通过 Flutter Texture／适当的原生视图渲染；避免把每帧 YUV/PCM 转成 Dart 列表或 JSON 来回传输。相机／屏幕切换必须串行化，并处理授权被取消、退出通话与异步启动交错的情况。

音频质量是性能与功能不降级的重要部分。仅用 AudioRecord/AudioTrack 不会自动等价于 Agora 的回声消除、降噪、混音和蓝牙兼容性；完整音频处理模块的体积与 CPU 成本需纳入评估。仅替换 Flutter 包装层通常不能消除 Agora 核心体积；用自定义采集 API 也不自动意味着依赖库变小。

如果选择仍受支持的原生 RTC 核心，可以使用 `createCustomVideoTrack`、`pushExternalVideoFrameById` 等官方 API 接入自采集视频。它们仍依赖原生 RTC 核心；须检查所选 Lite／模块化版本是否支持所需外部媒体和屏幕流，不能混用当前 special 版与其他版本组件。

## 当前 APK 体积证据

分析对象为工作区根目录已有的 `app-release.apk`，不是本次从当前源码重新构建的产物。

| 项目 | 实测大小 |
| --- | ---: |
| APK 文件 | 265.22 MiB |
| arm64 全部原生库 | 116.90 MiB |
| arm64 文件名包含 Agora/Iris 的原生库合计 | 80.17 MiB |
| 其中 `libagora-rtc-sdk.so` | 26.79 MiB |
| 其中 `libagora_clear_vision_extension.so` | 9.21 MiB |
| 其中 `libagora_lip_sync_extension.so` | 6.61 MiB |
| 其中 `libagora_spatial_audio_extension.so` | 4.42 MiB |

APK 还包含 armeabi-v7a 和 x86_64，不能把整个 APK 大小算成单台设备必需的 Agora 体积。按 ABI 分发可以独立优化下载大小，但不是本需求中的自实现替换。APK 中这些 `.so` 未压缩；没有据此推断运行内存或耗电。

## 互通与无降级的验收条件

实现前应先验证候选传输核心，避免先重写 UI 再发现协议／编解码不兼容：

1. 使用当前服务端签发的真实 token、数字 UID 和原房间名，与现有 Web VP8 客户端和旧原生客户端进行双向语音、视频验证；不能只测新客户端之间。
2. 验证多人订阅、成员静音状态、迟到加入、摄像头／屏幕切换、拒绝授权、系统停止共享、断网恢复和 token 更新。
3. 验证扬声器回声、耳机／蓝牙切换、系统来电打断、锁屏／后台、画中画恢复；对照当前平台已支持的行为。
4. 在相同设备、网络、分辨率和人数下对比包体、冷启动、入会首帧、CPU、内存、帧率、音画延迟、耗电和发热。未采集基线前不承诺具体性能百分比。
5. 验证 Android ELF 页面对齐及目标系统兼容性。分别保留各受支持 ABI 的发布产物，不能以删除受支持设备架构冒充功能无损瘦身。

目前只完成公开资料、SDK 头文件／二进制结构和本地代码检查；未修改通话代码、未执行 Agora 联机测试、未构建替换后的 APK。当前环境未检测到 Java／Android SDK，无法用静态检查替代 Android 编译和真机验收。

## 官方来源

- Web API 总览：https://api-ref.agora.io/en/video-sdk/web/4.x/index.html
- Web 加入、发布、订阅及事件：https://api-ref.agora.io/en/video-sdk/web/4.x/interfaces/iagorartcclient.html
- Web 采集与自定义 track：https://api-ref.agora.io/en/video-sdk/web/4.x/interfaces/iagorartc.html
- SDK 下载与 Android RTSA 停更标记：https://docs.agora.io/en/api-reference/sdks.md
- 已检查的 Android RTSA 包：https://download.agora.io/rtsasdk/release/Agora-RTSALite-LJAutRmAcAjCP-Android-v1.8.0-20230421_161341-262178.tgz
- Android 自定义视频：https://docs.agora.io/en/realtime-media/rtc/build/capture-and-render-video/custom-video/android.md
- Web ESM 与模块化：https://docs.agora.io/en/realtime-media/rtc/build/optimize-and-operate/app-size-optimization/web.md
- Flutter 可选原生扩展说明：https://docs.agora.io/en/realtime-media/rtc/build/optimize-and-operate/app-size-optimization/flutter.md
- Server Gateway：https://docs.agora.io/en/realtime-media/rtc-server-sdk.md 。它是服务端 SDK，需要额外的媒体网关实现和部署，不能视为手机端可直接调用的 WebRTC 信令接口。
