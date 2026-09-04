# AList Native iOS

SwiftUI 主界面与 AList Go 原生 iOS 移植工程。当前正在把上游 AList 核心接入 iOS Framework。

## 当前界面

- 首页 Dashboard
- AList 服务状态与局域网地址
- admin 账号与访问密码显示/复制/隐藏
- WebDAV 挂载卡片
- 快捷操作
- 存储统计摘要
- 实时内存摘要
- 后台位置包活开关
- 静音音频包活开关
- 文件、存储、更多页面
- 首次启动 admin 密码设置

## 构建

本项目需要 macOS + Xcode。`project.yml` 适用于 XcodeGen：

```bash
xcodegen generate
xcodebuild -project AListNativeUI.xcodeproj \
  -scheme AListNativeUI -sdk iphoneos -configuration Release \
  -archivePath build/AListNativeUI.xcarchive archive
```

当前 `AppModel` 中的 AList、内存和存储数据是 UI 原型数据。后续将通过 Go bridge 替换为真实服务状态；不会把密码硬编码到仓库。任务模块已按要求移除，密码不设最小长度限制但不能为空。

## 说明

- 局域网访问默认开启，没有局域网开关。
- 普通 iOS App 的后台运行受系统调度影响；两个包活开关分别控制对应模块，并显示实际状态，不保证永久运行。
- AList 使用 AGPL-3.0；发布时需要附带对应源代码和第三方许可证信息。
