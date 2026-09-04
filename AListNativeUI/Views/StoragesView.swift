import SwiftUI

struct StoragesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("全部驱动").font(.title3.bold())
                            Text("驱动工厂已编译，客户端访问时激活")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { showAdd = true } label: {
                            Image(systemName: "plus.circle.fill").font(.title2)
                        }
                    }
                }
                Section("已配置存储") {
                    ForEach(model.storages) { storage in
                        StorageRow(storage: storage)
                    }
                }
                Section("兼容状态") {
                    Label("已适配 · OneDrive、S3、WebDAV", systemImage: "checkmark.circle")
                        .foregroundStyle(AppTheme.success)
                    Label("远程依赖 · aria2、qBittorrent", systemImage: "link")
                    Label("系统限制 · 需要外部守护进程的功能", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(AppTheme.warning)
                }
            }
            .navigationTitle("存储")
            .sheet(isPresented: $showAdd) { AddStorageView() }
        }
    }
}

private struct StorageRow: View {
    let storage: StorageSummary
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.fill").foregroundStyle(AppTheme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(storage.name)
                Text("\(storage.driver) · \(storage.mountPath)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(storage.state).font(.caption)
                if storage.active { Text("客户端活动").font(.caption2).foregroundStyle(AppTheme.success) }
            }
        }
    }
}

private struct AddStorageView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    private let drivers = ["OneDrive", "S3", "WebDAV", "Google Drive", "阿里云盘", "115", "123", "FTP", "SFTP", "SMB", "Local"]

    var body: some View {
        NavigationStack {
            List {
                Section { TextField("搜索全部驱动", text: $search) }
                Section("全部驱动") {
                    ForEach(drivers.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }, id: \.self) { driver in
                        HStack {
                            Image(systemName: "shippingbox.fill").foregroundStyle(AppTheme.accent)
                            Text(driver)
                            Spacer()
                            Text("按需").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    Text("选择驱动后只加载当前驱动的配置表单；未访问的驱动不会创建客户端。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("添加存储")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}
