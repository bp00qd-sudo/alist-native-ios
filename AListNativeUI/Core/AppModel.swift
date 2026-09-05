import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var serviceState: ServiceState
    @Published var serviceMessage = ""
    @Published var coreState = "未接入"
    @Published var accessPassword: String
    @Published var passwordVisible = true
    @Published var needsInitialPassword: Bool
    @Published var localURL = "http://192.168.1.20:5244"
    @Published var webDAVURL = "http://192.168.1.20:5244/dav"
    @Published var memory = MemorySummary(go: 72, swiftUI: 15, activeDrivers: 2, requests: 3, requestLimit: 6)
    @Published var storages: [StorageSummary] = StorageSummary.samples
    @Published var lastRefresh = Date()

    let keepAlive = BackgroundKeepAliveCoordinator()
    private let alistBridge = AListBridge()
    private var startTask: Task<Void, Never>?

    init() {
        let password = KeychainStore.read(service: "AListNative", account: "admin") ?? ""
        accessPassword = password
        needsInitialPassword = password.isEmpty
        serviceState = password.isEmpty ? .setup : .stopped
        if password.isEmpty { serviceMessage = "请先设置 admin 访问密码" }
        else { coreState = "待启动 AList Go 核心" }
    }

    func configureInitialPassword(_ password: String) {
        guard !password.isEmpty else { return }
        KeychainStore.write(password, service: "AListNative", account: "admin")
        accessPassword = password
        needsInitialPassword = false
        startService()
    }

    func changePassword(_ password: String) {
        guard !password.isEmpty else { return }
        if alistBridge.setAdminPassword(password) {
            KeychainStore.write(password, service: "AListNative", account: "admin")
            accessPassword = password
        } else {
            KeychainStore.write(password, service: "AListNative", account: "admin")
            accessPassword = password
        }
    }

    func startService() {
        guard !needsInitialPassword, serviceState != .running, serviceState != .starting else { return }
        serviceState = .starting
        serviceMessage = "正在启动 HTTP 与 WebDAV 服务"
        startTask?.cancel()
        startTask = Task { [weak self] in
            guard let self else { return }
            let dataDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("AList", isDirectory: true).path
            do {
                try FileManager.default.createDirectory(atPath: dataDirectory, withIntermediateDirectories: true)
                switch self.alistBridge.start(dataDirectory: dataDirectory, password: self.accessPassword) {
                case .success(let url):
                    self.localURL = url
                    self.webDAVURL = url + "/dav"
                    self.coreState = "AList Go 核心运行中"
                    self.serviceState = .running
                    self.serviceMessage = "服务已启动，局域网访问已开启"
                case .failure(let error):
                    self.coreState = "桥接待接入"
                    self.serviceState = .error
                    self.serviceMessage = error.localizedDescription
                }
                self.lastRefresh = Date()
            } catch {
                self.serviceState = .error
                self.serviceMessage = error.localizedDescription
            }
        }
    }

    func stopService() {
        startTask?.cancel()
        alistBridge.stop()
        serviceState = .stopped
        coreState = "AList Go 核心已停止"
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
    case home, files, storages, more

    var title: String {
        switch self {
        case .home: return "首页"
        case .files: return "文件"
        case .storages: return "存储"
        case .more: return "更多"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .files: return "folder.fill"
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
