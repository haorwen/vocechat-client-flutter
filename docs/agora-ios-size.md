# iOS Agora 框架裁剪

iOS 通过 CocoaPods 在构建时移除 11 个未使用的可选框架。保持 `agora_rtc_engine: 6.5.4`、`AgoraRtcEngine_Special_iOS:4.5.3.70` 和配套 Iris 版本；不替换 SDK 核心，不改变通话 API。

## 移除和保留

清单在 `ios/agora-excluded-frameworks.txt`：美颜／视频增强、唇形同步、空间音频、虚拟背景、面部动作捕捉、可选人脸分析、美声、内容检测、视频评分、独立的低延迟降噪／回声消除变体。

保留 AgoraRtcKit、AgoraRtcWrapper、ReplayKit、普通版 AI 降噪／回声消除、所有现有编解码及支持框架。PiP 仍由现有原生 Agora 接口实现，Avo 仍使用自己的动画与互动逻辑。没有复制官方示例中排除 ReplayKit 和全部音频处理框架的清单。

当前项目未提交 Podfile；新增标准 Flutter CocoaPods 接入和 Debug/Release 的 Pods xcconfig 引用，沿用当前 iOS 12.0 项目目标。现有 TestFlight 工作流已禁用 Swift Package Manager，以避开 Agora 6.5.4 的 PiP 头文件问题；此次裁剪沿用 CocoaPods。若改用 SPM，应重新设计对应的依赖和嵌入配置。

## 执行顺序与检查

`ios/Podfile` 的 `post_integrate` 在 CocoaPods 完成 Runner 集成之后，将唯一的裁剪阶段放在全部现有 build phases 后面。它在 framework 嵌入后、Runner 最终代码签名前执行，不修改 SDK 缓存或签名后的 IPA；重复执行 pod install 不会重复添加阶段。

当前版本的官方 podspec 已将这些框架列为 `weak_frameworks`。因此不额外修改生成的链接参数。裁剪脚本对 Runner 和所有保留的嵌入框架运行 `xcrun otool -l`：若任何待裁剪框架被强链接，立即中止，尚未删除任何框架。版本变化导致强链接时必须重新审核，不能直接忽略错误。必需的核心、Iris、ReplayKit 和普通音频处理框架缺失也会中止。

项目目前没有 app extension。如果之后增加 ReplayKit Broadcast Upload Extension，脚本会要求扩展依赖审计后再裁剪，避免漏查另一可执行文件。只删除准确清单中的 framework 目录，不使用 Agora 通配删除。

## 实测依据与限制

2026-09-17 下载并检查了官方 `AgoraRtcEngine_Special_iOS-4.5.3.70.zip`，核对 CocoaPods podspec，并解析设备 framework 中的 arm64 Mach-O 切片：

- 11 个待移除框架的 arm64 二进制合计 **31.57 MiB**。
- 这些二进制单独以 zlib level 6 压缩合计 **23.43 MiB**。
- 保留的 SDK 设备 arm64 二进制没有对排除框架的强链接；这是 SDK 静态检查，不包括尚未构建的 Runner／Iris 产物，构建时还会再检查实际应用。

数字未计入框架其他资源、最终链接／strip、代码签名和 App Store 处理，不是最终 IPA 或商店下载实测值。IPA 本身已是压缩容器，没有 Android `useLegacyPackaging` 那种等价开关。不能把 Android 42 MiB 估算套到 iOS，也不能拿包含模拟器切片的整个 XCFramework 大小当设备安装体积。

当前环境为 Linux，没有 Xcode；未构建 IPA、未执行 CocoaPods 完整集成或设备通话验收。已经完成 Podfile Ruby 语法检查、裁剪脚本测试和上述官方 SDK 二进制审计。

## 在 macOS 构建

```sh
flutter config --no-enable-swift-package-manager
flutter pub get
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
python3 ios/scripts/trim_agora_frameworks.py build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app --verify
```

TestFlight 工作流已在上传前加入同样的只读检查。该工作流未由本次修改触发或发布。

手动测量任意已构建 `.app` 中尚未移除的扩展，可不带参数运行脚本；不要对签名完成的产物使用 `--trim`。签名后的检查只使用 `--verify`。

真机需验证现有 Web／旧客户端双向音视频、多人通话、音频路由、回声与降噪、摄像头切换、PiP 前后台恢复和 Avo 动画。构建检查不替代这些功能验证。

来源：

- [Agora Flutter 官方裁剪说明](https://docs.agora.io/en/realtime-media/rtc/build/optimize-and-operate/app-size-optimization/flutter.md)
- [当前 iOS 版本的 CocoaPods podspec](https://trunk.cocoapods.org/api/v1/pods/AgoraRtcEngine_Special_iOS/specs/4.5.3.70)
- [当前版本 SDK](https://download.agora.io/sdk/release/AgoraRtcEngine_Special_iOS-4.5.3.70.zip)
