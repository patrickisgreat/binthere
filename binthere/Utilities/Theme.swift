import SwiftUI

// MARK: - Theme

enum Theme {

    // MARK: Colors

    enum Colors {
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let cardBackground = Color(.tertiarySystemBackground)
        static let groupedBackground = Color(.systemGroupedBackground)

        static let primaryText = Color(.label)
        static let secondaryText = Color(.secondaryLabel)
        static let tertiaryText = Color(.tertiaryLabel)

        static let accent = Color.blue
        static let destructive = Color.red
        static let success = Color.green
        static let warning = Color.orange
        static let checkedOut = Color.orange

        static let separator = Color(.separator)
        static let thinSeparator = Color(.opaqueSeparator).opacity(0.3)
    }

    // MARK: Typography

    enum Typography {
        static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
        static let title = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 17)
        static let subheadline = Font.system(size: 15)
        static let caption = Font.system(size: 13)
        static let caption2 = Font.system(size: 11)
        static let code = Font.system(size: 15, weight: .medium, design: .monospaced)
        static let codeTitle = Font.system(size: 28, weight: .bold, design: .monospaced)
    }

    // MARK: Spacing

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: Radius

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }

    // MARK: Animation

    enum Animation {
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.85)
        static let quick = SwiftUI.Animation.easeOut(duration: 0.2)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)
    }

    // MARK: Shadows

    enum Shadow {
        static func card(_ scheme: ColorScheme) -> some View {
            EmptyView()
                .shadow(
                    color: scheme == .dark ? .clear : .black.opacity(0.06),
                    radius: 8, y: 2
                )
        }

        static let cardRadius: CGFloat = 8
        static let cardY: CGFloat = 2
        static func cardColor(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? .clear : .black.opacity(0.06)
        }
    }
}

// MARK: - View Modifiers

struct ThemeCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .shadow(
                color: Theme.Shadow.cardColor(colorScheme),
                radius: Theme.Shadow.cardRadius,
                y: Theme.Shadow.cardY
            )
    }
}

struct ThemeSectionHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Colors.secondaryText)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

extension View {
    func themeCard() -> some View {
        modifier(ThemeCardModifier())
    }

    func themeSectionHeader() -> some View {
        modifier(ThemeSectionHeaderModifier())
    }
}

// MARK: - Haptics

enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
