import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var serviceState: ServiceState
    @Published var serviceMessage = ""
    @Published var accessPassword: String
    @Published var passwordVisible = true
    @Published var needsInitialPassword: Bool
    @Published var localURL = "http://192.168.1.20:5244"
    @Published var webDAVURL = "http://192.168.1.20:5244/dav"
    @Published var memory = MemorySummary(go: 72, swiftUI: 15, activeDrivers: 2, requests: 3, requestLimit: 6)
    @Published var tasks: [TaskSummary] = TaskSummary.samples
    @Published var storages: [StorageSummary] = StorageSummary.samples
    @Published var lastRefresh = Date()

    let keepAlive = BackgroundKeepAliveCoordinator()
    private var startTask: Task<Void, Never>?

    init() {
        let password = KeychainStore.read(service: "AListNative", account: "admin") ?? ""
        accessPassword = password
        needsInitialPassword = password.isEmpty
        serviceState = password.isEmpty ? .setup : .stopped
        if password.isEmpty { serviceMessage = "请先设置 admin 访问密码" }
    }

    func configureInitialPassword(_ password: String) {
        guard password.count >= 6 else { return }
        KeychainStore.write(password, service: "AListNative", account: "admin")
        accessPassword = password
        needsInitialPassword = false
        startService()
    }

    func changePassword(_ password: String) {
        guard password.count >= 6 else { return }
        KeychainStore.write(password, service: "AListNative", account: "admin")
        accessPassword = password
    }

    func startService() {
        guard !needsInitialPassword, serviceState != .running, serviceState != .starting else { return }
        serviceState = .starting
        serviceMessage = "正在启动 HTTP 与 WebDAV 服务"
        startTask?.cancel()
        startTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, let self else { return }
            self.serviceState = .running
            self.serviceMessage = "服务已启动，局域网访问已开启"
            self.lastRefresh = Date()
        }
    }

    func stopService() {
        startTask?.cancel()
        serviceState = .stopped
        serviceMessage = "服务已停止"
    }

    func refreshSummary() {
        lastRefresh = Date()
    }

    func toggleLocationKeepAlive(_ enabled: Bool) {
        keepAlive.setLocationEnabled(enabled)
    }

    func toggleAudioKeepAlive(_ enabled: Bool) {
        keepAlive.setAudioEnabled(enabled)
    }
}

enum AppTab: String, CaseIterable, Hashable {
    case home, files, tasks, storages, more

    var title: String {
        switch self {
        case .home: return "首页"
        case .files: return "文件"
        case .tasks: return "任务"
        case .storages: return "存储"
        case .more: return "更多"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .files: return "folder.fill"
        case .tasks: return "arrow.down.circle.fill"
        case .storages: return "externaldrive.fill"
        case .more: return "ellipsis.circle.fill"
        }
    }
}

enum ServiceState: String {
    case setup, starting, running, stopped, error

    var title: String {
        switch self {
        case .setup: return "等待首次设置"
        case .starting: return "正在启动"
        case .running: return "服务运行中"
        case .stopped: return "服务已停止"
        case .error: return "服务异常"
        }
    }

    var color: Color {
        switch self {
        case .running: return AppTheme.success
        case .starting: return AppTheme.warning
        case .error: return AppTheme.danger
        default: return .secondary
        }
    }
}

struct MemorySummary {
    var go: Int
    var swiftUI: Int
    var activeDrivers: Int
    var requests: Int
    var requestLimit: Int
}

struct TaskSummary: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let progress: Double
    let state: String

    static let samples = [
        TaskSummary(icon: "arrow.up.circle.fill", title: "上传 movie.mkv", detail: "1.2 GB · 8.4 MB/s", progress: 0.68, state: "进行中"),
        TaskSummary(icon: "arrow.down.circle.fill", title: "下载 archive.zip", detail: "3.4 GB · 等待资源", progress: 0, state: "等待中")
    ]
}

struct StorageSummary: Identifiable {
    let id = UUID()
    let name: String
    let driver: String
    let mountPath: String
    let state: String
    let active: Bool

    static let samples = [
        StorageSummary(name: "OneDrive", driver: "OneDrive", mountPath: "/onedrive", state: "正常", active: true),
        StorageSummary(name: "阿里云盘", driver: "Aliyundrive", mountPath: "/aliyun", state: "空闲", active: false),
        StorageSummary(name: "WebDAV", driver: "WebDAV", mountPath: "/remote", state: "正常", active: false)
    ]
}
