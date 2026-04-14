import SwiftUI

struct BrandedEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var gradient: [Color] = [.blue.opacity(0.6), .blue.opacity(0.3)]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
            }

            Text(title)
                .font(Theme.Typography.title3)
                .foregroundStyle(Theme.Colors.primaryText)

            Text(message)
                .font(Theme.Typography.subheadline)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding(.vertical, Theme.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.9)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(Theme.Animation.spring.delay(0.1)) {
                    appeared = true
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

// MARK: - Preset Empty States

extension BrandedEmptyState {
    static var noBins: BrandedEmptyState {
        BrandedEmptyState(
            icon: "archivebox",
            title: "Your bins are waiting",
            message: "Tap + to create your first bin and start organizing.",
            gradient: [.blue.opacity(0.7), .cyan.opacity(0.4)]
        )
    }

    static var noItems: BrandedEmptyState {
        BrandedEmptyState(
            icon: "cube.box",
            title: "This bin is empty",
            message: "Type below to quick-add items, or tap + for full details.",
            gradient: [.purple.opacity(0.7), .purple.opacity(0.3)]
        )
    }

    static var noZones: BrandedEmptyState {
        BrandedEmptyState(
            icon: "square.grid.2x2",
            title: "Organize your space",
            message: "Zones represent rooms or areas. Tap + to create one.",
            gradient: [.green.opacity(0.7), .mint.opacity(0.4)]
        )
    }

    static var noCheckoutHistory: BrandedEmptyState {
        BrandedEmptyState(
            icon: "clock.arrow.circlepath",
            title: "No checkout history",
            message: "Checkout records will appear here.",
            gradient: [.orange.opacity(0.7), .yellow.opacity(0.4)]
        )
    }

    static var noSearchResults: BrandedEmptyState {
        BrandedEmptyState(
            icon: "magnifyingglass",
            title: "No results",
            message: "No bins match your search.",
            gradient: [.gray.opacity(0.5), .gray.opacity(0.3)]
        )
    }
}
