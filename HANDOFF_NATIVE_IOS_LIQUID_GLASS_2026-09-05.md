# AList Native iOS 交接：Liquid Glass UI 回归

日期：2026-09-05  
项目：`alist-native-ios`  
范围：只处理本项目，不读取、复制或修改其他项目。

## 结论先行

当前 IPA 已经可以打开，AList Go Framework 的链接问题也已经修复；但用户反馈生成的 IPA 显示的是旧版 UI，而上一个版本是 Liquid Glass 风格。

下一位 agent 的首要任务是恢复或确认 Liquid Glass UI，不要继续扩展 AList 后端功能，也不要重新排查已经解决的 C ABI 链接问题。

## 已完成并验证的构建状态

- GitHub Actions：成功运行 [33954400394](https://github.com/bp00qd-sudo/alist-native-ios/actions/runs/33954400394)
- 远端 `main`：`d6e7ab4bb2ae55d8011be4ae3dca26c5ced8599a`
- 当前版本：`MARKETING_VERSION = 2.0.4`
- 当前 Build：`CURRENT_PROJECT_VERSION = 809`
- AList Framework 生成成功：
  - `build/AListCore-device/AListCore.a`
  - `build/AListCore.xcframework`
- C ABI 导出符号检查通过。
- XcodeGen 生成的 Framework 链接检查通过。
- unsigned Archive 成功。
- IPA Artifact 已成功上传，名称为 `AListNativeUI-unsigned-ipa`，约 41 MB。
- 用户已验证 IPA 可以打开；尚未完成真实设备功能验证，因此不要宣称设备验证完成或已经具备签名安装能力。

## Framework 链接修复内容

`project.yml` 当前使用 XcodeGen 正式依赖写法：

```yaml
dependencies:
  - framework: build/AListCore.xcframework
    embed: false
    link: true
```

同时，Go runtime 在 iOS 链接时需要 resolver 库：

```yaml
OTHER_LDFLAGS: "$(inherited) -lc++ -lresolv"
```

不要用 Swift/C 空 stub 掩盖缺少 Go 库的问题。之前的 `_AListEngine*` 和 `_AListFreeString` undefined symbols 已经消失；最近一次失败的真实根因是 `res_9_ninit`、`res_9_nsearch`、`res_9_nclose`，加入 `-lresolv` 后 Archive 成功。

## 当前 UI 的可证实状态

目前源码仍是旧式卡片 UI：

- `AListNativeUI/Core/AppTheme.swift`
  - `AppTheme.card` 使用 `Color(uiColor: .secondarySystemGroupedBackground)`。
  - `CardModifier` 使用普通 `RoundedRectangle` 背景。
- `AListNativeUI/Views/HomeView.swift`
  - 页面使用 `ScrollView` / `LazyVStack`。
  - 页面背景使用 `Color(uiColor: .systemGroupedBackground)`。
  - 服务、统计和包活区域通过 `.appCard()` 展示。
  - 快捷操作使用 `.buttonStyle(.bordered)`。
- `AListNativeUI/Views/RootView.swift`
  - 主界面是普通 `TabView`。
- `AListNativeUI/App/AListNativeUIApp.swift`
  - 目前只有 `RootView().environmentObject(model).tint(AppTheme.accent)`。

当前仓库的远端提交历史中能确认的 UI 提交主要是 `685d953` 和 `38f8ae4`，没有找到名字或提交信息明确标记为 Liquid Glass 的版本。用户确认“上一个版本是 Liquid Glass”应作为产品回归事实保留，但不要把当前旧 UI 猜测成 Liquid Glass 的实现来源。

## 下一位 agent 的处理顺序

1. 先确认 Liquid Glass 的权威来源：检查完整 Git 历史、其他远端分支、旧的用户 IPA/截图，或向用户索取上一个版本的 commit、截图或参考构建。当前工作区可能没有 `.git`，不能假设本地 Git 历史完整。
2. 如果找到了旧版实现，优先恢复对应的共享主题和组件，再逐页核对 Home、Files、Storages、More、首次密码页；保留现有服务启动、停止、密码、URL 和 Tab 行为。
3. 如果必须重建视觉，先在 `AppTheme.swift` 和共享 ViewModifier/组件中建立统一玻璃材质、层级、边框、阴影和高亮规则，再让各页面复用；不要只给首页做局部渐变。
4. 项目 deployment target 当前为 iOS 17.0。如果使用仅在较新系统提供的原生 Liquid Glass API，必须增加 availability 处理或先明确调整最低系统版本，不能让 iOS 17 编译失败。
5. 修改后必须通过 GitHub Actions 构建并查看真机或用户提供的截图。每次构建都要同时递增版本号和 Build 号；下一次构建可从 `2.0.5 (810)` 开始，但应以实际提交前的远端版本为准。

## 构建与验证

macOS 上使用：

```bash
brew install go@1.25 xcodegen
export PATH="$(brew --prefix go@1.25)/bin:$PATH"
xcodegen generate
bash ./scripts/build-alist-framework.sh
xcodegen generate
xcodebuild archive \
  -project AListNativeUI.xcodeproj \
  -scheme AListNativeUI \
  -sdk iphoneos \
  -configuration Release \
  -archivePath build/AListNativeUI.xcarchive \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""
```

CI 已包含以下诊断：

- `find build`
- `file build/AListCore-device/AListCore.a`
- `lipo -info`
- `nm -gU`
- `xcodebuild -showBuildSettings`
- verbose Archive 链接命令

本次成功构建中，最终链接命令明确包含：

```text
... -Fbuild ... AListCore.a ... -lc++ -lresolv ...
```

## 已知 warning 与边界

- `CoreAudioTypes` warning 和 `SwiftUICore implicit framework` warning 曾出现，但不是之前 AList C ABI undefined symbols 的根因；不要仅凭 warning 回退 Framework 配置。
- Action 还报告了 Node.js 20 action 和 Go 1.25 的弃用提示；它们不影响本次构建成功。
- Go 对象以 iOS 18.2 SDK 构建、App deployment target 为 iOS 17.0 时会出现版本 warning；当前不是阻塞项，但真实设备测试时要留意。
- IPA 是 unsigned artifact。没有签名、安装和真机运行验证前，不要称其为可直接安装的正式 IPA。
- 不要把任何私钥、Cookie、验证码、API key、证书密码、用户密码或其他 Secret 写入仓库、日志或交接文档。
- 不要删除 AList Application Support 数据、配置或存储凭据。
- AList 使用 AGPL-3.0；发布时继续提供对应源代码和第三方许可证。

## 相关文件

- `AListNativeUI/Core/AppTheme.swift`
- `AListNativeUI/Views/RootView.swift`
- `AListNativeUI/Views/HomeView.swift`
- `AListNativeUI/Views/FilesView.swift`
- `AListNativeUI/Views/StoragesView.swift`
- `AListNativeUI/Views/MoreView.swift`
- `AListNativeUI/Core/AppModel.swift`
- `AListNativeUI/Core/AListBridge.swift`
- `project.yml`
- `.github/workflows/build.yml`
- `scripts/build-alist-framework.sh`
