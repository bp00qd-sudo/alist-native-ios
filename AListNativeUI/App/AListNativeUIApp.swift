import SwiftUI

@main
struct AListNativeUIApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .tint(AppTheme.accent)
        }
    }
}
