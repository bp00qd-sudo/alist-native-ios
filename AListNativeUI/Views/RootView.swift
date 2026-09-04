import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.needsInitialPassword {
                PasswordSetupView()
            } else {
                TabView(selection: $model.selectedTab) {
                    HomeView().tabItem { Label("首页", systemImage: "house.fill") }.tag(AppTab.home)
                    FilesView().tabItem { Label("文件", systemImage: "folder.fill") }.tag(AppTab.files)
                    StoragesView().tabItem { Label("存储", systemImage: "externaldrive.fill") }.tag(AppTab.storages)
                    MoreView().tabItem { Label("更多", systemImage: "ellipsis.circle.fill") }.tag(AppTab.more)
                }
            }
        }
        .preferredColorScheme(nil)
    }
}

struct PasswordSetupView: View {
    @EnvironmentObject private var model: AppModel
    @State private var password = ""
    @State private var confirmation = ""
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(AppTheme.accent)
                        Text("设置 AList 访问密码")
                            .font(.title2.bold())
                        Text("局域网 HTTP、WebDAV 和 Web 管理共用此密码。设置完成后服务将自动启动。")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                }
                Section("账号") {
                    LabeledContent("用户名", value: "admin")
                }
                Section("访问密码") {
                    SecureField("请输入访问密码（不限长度）", text: $password)
                    SecureField("再次输入密码", text: $confirmation)
                }
                if showError {
                    Text("两次密码不一致，密码不能为空。")
                        .foregroundStyle(AppTheme.danger)
                }
                Section {
                    Button("设置密码并启动服务") {
                        guard !password.isEmpty, password == confirmation else {
                            showError = true
                            return
                        }
                        model.configureInitialPassword(password)
                    }
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
                }
            }
            .navigationTitle("首次启动")
        }
    }
}
