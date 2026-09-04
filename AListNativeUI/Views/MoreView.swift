import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showPasswordEditor = false

    var body: some View {
        NavigationStack {
            List {
                Section("完整管理") {
                    Button { openSafari() } label: {
                        Label("Safari 打开 AList 管理", systemImage: "safari.fill")
                    }
                }
                Section("服务与安全") {
                    LabeledContent("局域网绑定", value: "默认开启")
                    LabeledContent("访问账号", value: "admin")
                    Button("修改 admin 访问密码") { showPasswordEditor = true }
                }
                Section("数据与诊断") {
                    NavigationLink { DiagnosticsView() } label: { Label("日志与运行诊断", systemImage: "waveform.path.ecg") }
                    NavigationLink { CacheView() } label: { Label("数据与缓存", systemImage: "internaldrive") }
                }
                Section("关于") {
                    LabeledContent("版本", value: "Native UI 0.1")
                    LabeledContent("AList 核心", value: "ios-full")
                    Text("AList 使用 AGPL-3.0；第三方组件许可证应在发布包中完整列出。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("更多")
            .sheet(isPresented: $showPasswordEditor) { PasswordEditorView() }
        }
    }

    private func openSafari() {
        guard let url = URL(string: model.localURL) else { return }
        UIApplication.shared.open(url)
    }
}

struct DiagnosticsView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        List {
            Section("内存摘要") {
                LabeledContent("Go 核心", value: "\(model.memory.go) MB")
                LabeledContent("SwiftUI", value: "\(model.memory.swiftUI) MB")
                LabeledContent("活动驱动", value: "\(model.memory.activeDrivers)")
                LabeledContent("网络请求", value: "\(model.memory.requests)/\(model.memory.requestLimit)")
            }
            Section("运行日志") {
                Text("服务已启动")
                Text("WebDAV listener 已就绪")
                Text("驱动客户端按需激活")
            }
        }
        .navigationTitle("诊断")
    }
}

struct CacheView: View {
    var body: some View {
        List {
            LabeledContent("临时文件", value: "按任务清理")
            LabeledContent("缩略图", value: "按需")
            Button("清理可回收缓存") {}
        }
        .navigationTitle("数据与缓存")
    }
}

struct PasswordEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmation = ""
    @State private var error = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("账号") { LabeledContent("用户名", value: "admin") }
                Section("新密码") {
                    SecureField("请输入新密码（不限长度）", text: $password)
                    SecureField("确认新密码", text: $confirmation)
                }
                if !error.isEmpty { Text(error).foregroundStyle(AppTheme.danger) }
                Button("保存密码") {
                    guard !password.isEmpty, password == confirmation else {
                        error = "密码不一致或密码为空"
                        return
                    }
                    model.changePassword(password)
                    dismiss()
                }
            }
            .navigationTitle("修改访问密码")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
    }
}
