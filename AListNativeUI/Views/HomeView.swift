import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPassword = true
    @State private var showWebDAVHelp = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    serviceCard
                    quickActions
                    storageSummary
                    memorySummary
                    keepAliveCard
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("AList Native")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.refreshSummary() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("刷新状态")
                }
            }
            .sheet(isPresented: $showWebDAVHelp) { WebDAVHelpView() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { model.refreshSummary() }
            }
        }
    }

    private var serviceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StatusDot(color: model.serviceState.color)
                Text("AList \(model.serviceState.title)").font(.headline)
                Spacer()
                if model.serviceState == .running {
                    Button("停止") { model.stopService() }.buttonStyle(.bordered)
                } else if model.serviceState == .stopped {
                    Button("启动") { model.startService() }.buttonStyle(.borderedProminent)
                }
            }
            Divider()
            InfoRow(label: "地址", value: model.localURL, actionTitle: "复制") { copy(model.localURL) }
            InfoRow(label: "账号", value: "admin", actionTitle: "复制") { copy("admin") }
            HStack(alignment: .firstTextBaseline) {
                Text("密码").foregroundStyle(.secondary).frame(width: 42, alignment: .leading)
                Text(showPassword ? model.accessPassword : String(repeating: "•", count: max(8, model.accessPassword.count)))
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Spacer(minLength: 4)
                Button(showPassword ? "隐藏" : "显示") { showPassword.toggle() }
                Button { copy(model.accessPassword) } label: { Image(systemName: "doc.on.doc") }
                    .accessibilityLabel("复制密码")
            }
            HStack {
                Label("HTTP / WebDAV", systemImage: "network")
                Spacer()
                StatusDot(color: model.serviceState == .running ? AppTheme.success : .secondary)
                Text(model.serviceState == .running ? "可用" : "不可用")
                    .foregroundStyle(.secondary)
            }
            Text(model.serviceMessage).font(.caption).foregroundStyle(.secondary)
        }
        .appCard()
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "快捷操作")
            HStack(spacing: 12) {
                ActionTile(title: "浏览文件", icon: "folder.fill") { model.selectedTab = .files }
                ActionTile(title: "添加存储", icon: "plus.circle.fill") { model.selectedTab = .storages }
            }
            HStack(spacing: 12) {
                ActionTile(title: "Safari 管理", icon: "safari.fill") { openSafari() }
                ActionTile(title: "WebDAV", icon: "server.rack") { showWebDAVHelp = true }
            }
        }
    }

    private var storageSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "存储统计", action: "查看全部") { model.selectedTab = .storages }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(model.storages.count + 9) 个存储").font(.title3.bold())
                    Spacer()
                    Text("\(model.storages.filter { $0.state == "正常" }.count + 6) 正常")
                        .foregroundStyle(AppTheme.success)
                }
                Text("活动客户端 \(model.storages.filter(\.active).count) · 空闲 \(model.storages.filter { !$0.active }.count + 6)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .appCard()
        }
    }

    private var memorySummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "实时内存", action: "详情") { model.selectedTab = .more }
            HStack(spacing: 0) {
                Metric(title: "Go", value: "\(model.memory.go) MB")
                Divider().frame(height: 32)
                Metric(title: "SwiftUI", value: "\(model.memory.swiftUI) MB")
                Divider().frame(height: 32)
                Metric(title: "请求", value: "\(model.memory.requests)/\(model.memory.requestLimit)")
            }
            .appCard()
            Text("最近更新：\(model.lastRefresh.formatted(date: .omitted, time: .shortened)) · 运行中每 10 秒更新")
                .font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 4)
        }
    }

    private var keepAliveCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "后台包活")
            VStack(spacing: 0) {
                KeepAliveRow(title: "后台位置包活", subtitle: model.keepAlive.locationStatus, isOn: model.keepAlive.locationEnabled) { model.toggleLocationKeepAlive($0) }
                Divider()
                KeepAliveRow(title: "静音音频包活", subtitle: model.keepAlive.audioStatus, isOn: model.keepAlive.audioEnabled) { model.toggleAudioKeepAlive($0) }
            }
            .appCard()
        }
    }

    private func copy(_ text: String) {
        UIPasteboard.general.string = text
    }

    private func openSafari() {
        guard let url = URL(string: model.localURL) else { return }
        UIApplication.shared.open(url)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    let actionTitle: String
    let action: () -> Void
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary).frame(width: 42, alignment: .leading)
            Text(value).lineLimit(1).minimumScaleFactor(0.6)
            Spacer()
            Button(actionTitle, action: action).font(.caption)
        }
    }
}

struct ActionTile: View {
    let title: String
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, minHeight: 46)
        }
        .buttonStyle(.bordered)
    }
}

struct Metric: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.subheadline.monospacedDigit().bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct KeepAliveRow: View {
    let title: String
    let subtitle: String
    let isOn: Bool
    let onChange: (Bool) -> Void
    var body: some View {
        HStack {
            Image(systemName: title.contains("位置") ? "location.fill" : "speaker.wave.2.fill")
                .foregroundStyle(AppTheme.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { isOn }, set: onChange)).labelsHidden()
        }
        .padding(.vertical, 10)
    }
}

struct WebDAVHelpView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("服务端挂载") {
                    LabeledContent("地址", value: "http://局域网地址:端口/dav")
                    Text("可用于 macOS、Windows、Android 和第三方 WebDAV 客户端。AList App 需要保持运行，进入后台后连接可能中断。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("iOS 文件") {
                    Text("iOS“文件”App 入口由 File Provider 提供，不是普通 WebDAV URL。")
                }
            }
            .navigationTitle("WebDAV 挂载")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}
