import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.14, green: 0.42, blue: 0.99)
    static let success = Color(red: 0.13, green: 0.63, blue: 0.42)
    static let warning = Color(red: 0.85, green: 0.50, blue: 0.14)
    static let danger = Color(red: 0.84, green: 0.25, blue: 0.25)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func appCard() -> some View { modifier(CardModifier()) }
}

struct StatusDot: View {
    let color: Color
    var body: some View {
        Circle().fill(color).frame(width: 9, height: 9)
    }
}

struct SectionHeader: View {
    let title: String
    var action: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            if let action {
                Button(action) { onAction?() }
                    .font(.subheadline)
            }
        }
        .padding(.horizontal, 4)
    }
}
