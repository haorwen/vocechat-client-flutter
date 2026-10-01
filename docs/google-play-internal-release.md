# Google Play 内部测试自动发布

工作流：`.github/workflows/android-play-internal.yml`，Actions 名称 **Android Play Internal Deploy**。

- `main` 的 Android、Dart、资源、依赖或发布工具变更后自动触发。
- 支持 Actions → Run workflow，选择 `main` 手动触发。
- 固定发布到 `internal` 内部测试轨道，不会发布到 production。
- 同一时间只运行一个发布任务，不取消正在上传的任务。GitHub concurrency 只保留一个 pending 任务；连续多次推送时可能跳过中间版本，构建最新的待运行版本。
- 流程仅在 `main` 上执行。对应的 GitHub Environment 为 `google-play-internal`，可放入该环境的 Secrets，或沿用仓库级 Secrets。

## 一次性配置 Google Play

1. 在 Play Console 创建应用，包名必须为 `com.vocechat.vocechat_client`。配置 Play App Signing，保存好 **upload key（上传密钥）**。
2. 首次需在 Play Console 手动上传一个使用 `--flavor play` 构建、同一上传密钥签名的 AAB，使包名在 Play 中建立关联。该上传 action 不能创建一个全新的 Play 应用。
3. 在 Google Cloud 项目启用 **Google Play Android Developer API**，创建服务账号并生成 JSON 密钥。
4. 在 Play Console → 用户和权限，邀请该服务账号的 `client_email`，授权它访问此应用并发布到测试轨道。需要应用读取权限及测试轨道发布权限；不需要给它生产发布权限。
5. 配置内部测试的测试者列表和加入链接。商店资料、应用内容申报或审核要求仍需在 Play Console 完成；CI 上传成功不等于 Google 已完成处理/审核。

服务账号配置参考：[Android Publisher API 入门](https://developers.google.com/android-publisher/getting_started)。服务账号 JSON 是发布凭据，不是 Firebase 的 `google-services.json`，两者不能互换。

## GitHub Secrets

进入仓库 **Settings → Secrets and variables → Actions**，或 **Settings → Environments → google-play-internal**。

| Secret | 内容 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Play 上传密钥 `.jks` / `.keystore` 文件的 Base64 |
| `ANDROID_KEYSTORE_PASSWORD` | 上传密钥库密码 |
| `ANDROID_KEY_ALIAS` | 密钥别名 |
| `ANDROID_KEY_PASSWORD` | 该密钥的密码 |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | 上述 Play 服务账号 JSON 的完整原文，**不是 Base64** |
| `GOOGLE_SERVICES_JSON_BASE64` | Firebase Android 配置 `google-services.json` 的 Base64；当前仓库已配置该 Secret |

Firebase 配置必须包含包名 `com.vocechat.vocechat_client`，缺失或不匹配会停止流水线。所有签名参数必须存在，CI 不会走项目本地构建时的 debug 签名回退。

Windows PowerShell 生成二进制文件的 Base64 并复制到剪贴板，例如：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\keys\upload-keystore.jks')) | Set-Clipboard
```

随后粘贴到 `ANDROID_KEYSTORE_BASE64`。Play 服务账号 JSON 直接将文件原文保存为 `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`。无需把密钥文件或内容提交进仓库，也无需发到聊天中。

## 版本号

- versionName 来自 `pubspec.yaml`，例如 `0.3.25`。
- CI versionCode = `PLAY_VERSION_CODE_BASE + GITHUB_RUN_NUMBER × 100 + GITHUB_RUN_ATTEMPT`。
- `PLAY_VERSION_CODE_BASE` 是可选的 Actions Variable，默认 `100000`；第一次运行通常为 `100101`。**首次启用前确认它大于 Play 已上传过的最高版本号**，必要时将 base 设得更高。
- 新 run 和当前 run 的重试会分配不同版本号，最多支持每个 run 99 次尝试；超过 Android 的 `2100000000` 上限则停止。
- 不修改工作区的 `pubspec.yaml`，不生成版本提交。
- 已有更新版本上传后，不要重新运行历史旧 run 来发布旧代码。应从 `main` 新建一次手动运行；如需回滚代码，也用新 run 发布更高 versionCode。
- 两个 flavor 使用相同包名；日后需要用 standalone APK 覆盖 Play 安装时，必须使用兼容签名及更高 versionCode。

可选 Variable `FLUTTER_VERSION` 用于固定 Flutter SDK 版本；未设置时与现有 iOS/macOS 流水线一样使用 stable channel。

## 发布流程

1. 执行发布工具单元测试，校验必需 Secrets、Firebase 包名和版本号，生成仅用于 CI 的签名配置。
2. 配置 Java 17、Android SDK、Flutter，验证上传 keystore 别名和密码。
3. 执行后台消息/更新功能回归及 Play 专属排除测试。
4. 构建签名的 `playRelease` AAB。
5. 用固定版本、校验 SHA-256 的 bundletool 从 **实际 AAB** 导出 Manifest：检查包名、versionCode、Play 渠道标记、FCM 服务及通知权限，并拒绝包含常驻后台服务、电池优化豁免、相关前台服务权限、APK 安装权限或更新 FileProvider 的包。
6. 保存 AAB 到 GitHub Actions Artifacts（14 天），再通过固定提交版本的 Google Play 上传 action 发布到 internal。
7. 无论成功失败，清理临时签名和 Firebase 文件。

测试者使用 Play Console 内部测试页面提供的加入链接；此工作流使用的是 **internal testing**，不是 `internalsharing`。

## 首次运行与常见失败

第一次可先手动运行，`release_status` 默认 `completed`，表示提交内部测试发布。若应用仍处于 Play 的初始草稿状态并只允许草稿上传，手动选择 `draft`，之后在 Play Console 完成首次发布。后续 push 仍默认 `completed`。

`changes_not_sent_for_review` 默认关闭。仅当 Play API 明确要求把变更保留在控制台后再手动送审时启用；启用后流水线不会代替控制台的送审操作。

| 失败 | 处理 |
| --- | --- |
| Missing GitHub Actions secrets | 按上表补齐，之后重新运行 |
| Firebase config must include Android package | 下载正确 Firebase Android 应用的配置 |
| 上传密钥/签名不匹配 | 使用 Play Console 中登记的 upload key，不能临时生成另一个密钥代替 |
| Package not found | 先在 Play Console 建立应用并手动上传首个 AAB |
| 403 / permission denied | 检查 API 是否启用、服务账号是否已获得该应用的测试发布权限 |
| versionCode 已使用/太小 | 检查版本 base，或新建 main 手动运行；不要重复上传旧产物 |
| 缺少资料、草稿状态或要求手动送审 | 按 Play Console 状态完成操作，必要时用上述手动输入 |
| AAB Manifest 校验失败 | 修复 play flavor，不能跳过校验上传 standalone 包 |

## 本地验证

```sh
python3 -m unittest discover -s tool/play_release -p 'test_*.py' -v
flutter test --no-pub --flavor play test/core/background/play_distribution_test.dart
```

工作流已经过 actionlint 校验，发布脚本具备无真实凭据的单元测试。实际 Google Play 上传仍依赖完成账号、签名和 Secret 配置；未通过真实上传前不能将本地校验视为发布成功。
