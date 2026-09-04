import SwiftUI

struct FilesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedStorage = "全部存储"
    @State private var path = "/"
    @State private var searchText = ""
    @State private var showUpload = false

    private let files = [
        FileRowModel(name: "预告片.mp4", detail: "1.2 GB · 今天 12:30", icon: "film.fill", isFolder: false),
        FileRowModel(name: "纪录片", detail: "文件夹 · 18 项", icon: "folder.fill", isFolder: true),
        FileRowModel(name: "清单.txt", detail: "4 KB · 昨天 09:16", icon: "doc.text.fill", isFolder: false),
        FileRowModel(name: "项目归档.zip", detail: "3.4 GB · 2026/09/04", icon: "archivebox.fill", isFolder: false)
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("存储", selection: $selectedStorage) {
                        Text("全部存储").tag("全部存储")
                        ForEach(model.storages) { storage in
                            Text(storage.name).tag(storage.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                        Text(path).font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Text("列表模式").font(.caption).foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                }

                Section {
                    ForEach(filteredFiles) { file in
                        Button {
                            if file.isFolder { path = path == "/" ? "/纪录片" : "\(path)/纪录片" }
                        } label: {
                            FileRow(file: file)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {} label: { Label("删除", systemImage: "trash") }
                            Button {} label: { Label("更多", systemImage: "ellipsis") }
                        }
                    }
                } header: {
                    Text("当前目录 · 50 条/页")
                } footer: {
                    Text("低内存模式：不加载缩略图，目录按页读取")
                }
            }
            .searchable(text: $searchText, prompt: "搜索当前目录")
            .navigationTitle("文件")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showUpload = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showUpload) { UploadSheet() }
        }
    }

    private var filteredFiles: [FileRowModel] {
        guard !searchText.isEmpty else { return files }
        return files.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

private struct FileRowModel: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let icon: String
    let isFolder: Bool
}

private struct FileRow: View {
    let file: FileRowModel
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: file.icon)
                .font(.title3)
                .foregroundStyle(file.isFolder ? AppTheme.accent : .secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name).lineLimit(1)
                Text(file.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: file.isFolder ? "chevron.right" : "ellipsis")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}

private struct UploadSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("上传方式") {
                    Label("从文件 App 选择", systemImage: "doc.badge.plus")
                    Label("从照片选择", systemImage: "photo.badge.plus")
                    Label("扫描文稿", systemImage: "doc.viewfinder")
                }
                Section {
                    Text("上传任务使用受限并发和流式 I/O，不会把整个文件载入内存。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("上传文件")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}
