# AList Native iOS

SwiftUI 主界面与 AList Go 原生 iOS 移植工程。

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
- 首次启动 admin 密码设置，密码不设最小长度限制，但不能为空
- 已移除独立任务模块

## 当前移植结构

- `AListCore/`：固定上游 AList Go 源码快照，保留全部驱动、WebDAV、归档、搜索和服务代码
- `Porting/iosbridge/bridge.go`：iOS 服务生命周期桥接
- `Porting/iosbridge/export.go`：面向 Swift 的 C 导出接口
- `AListNativeUI/Core/AListBridge.swift`：Swift 调用桥接层
- `scripts/build-alist-framework.sh`：macOS + Xcode + iOS SDK Framework 构建脚本

## 构建

本项目需要 macOS、Xcode、Go 1.25 和 iOS SDK。`project.yml` 适用于 XcodeGen。

```bash
xcodegen generate
./scripts/build-alist-framework.sh
xcodebuild -project AListNativeUI.xcodeproj \
  -scheme AListNativeUI -sdk iphoneos -configuration Release \
  -archivePath build/AListNativeUI.xcarchive archive
```

当前 SwiftUI 界面已经连接到 C bridge API；在 `build/AListCore.xcframework` 生成并链接后，由 Go bridge 提供真实服务状态。

## 约束

- 局域网访问默认开启，没有局域网开关。
- 普通 iOS App 的后台运行受系统调度影响；两个包活开关分别控制对应模块，并显示实际状态，不保证永久运行。
- WebDAV 服务端复用 AList 主 HTTP listener；iOS Files 系统入口需另建 File Provider。
- AList 使用 AGPL-3.0；发布时需要附带对应源代码和第三方许可证信息。
