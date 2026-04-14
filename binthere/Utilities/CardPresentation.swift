import SwiftUI

// MARK: - Card Presentation Modifier

/// Applies Things-style card presentation: grab handle, rounded top, adaptive sizing
struct CardPresentationModifier: ViewModifier {
    var showHandle: Bool = true

    func body(content: Content) -> some View {
        content
            .presentationDetents([.large])
            .presentationDragIndicator(showHandle ? .visible : .hidden)
            .presentationCornerRadius(Theme.Radius.xl)
            .presentationBackground(Theme.Colors.background)
    }
}

extension View {
    func cardPresentation(showHandle: Bool = true) -> some View {
        modifier(CardPresentationModifier(showHandle: showHandle))
    }
}

// MARK: - Animated Sheet Item

/// Wraps sheet presentation with spring animation
struct AnimatedSheetModifier<Item: Identifiable, SheetContent: View>: ViewModifier {
    @Binding var item: Item?
    let content: (Item) -> SheetContent

    func body(content: Content) -> some View {
        content.sheet(item: $item) { item in
            self.content(item)
                .cardPresentation()
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

extension View {
    func animatedSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        modifier(AnimatedSheetModifier(item: item, content: content))
    }
}

// MARK: - Spring Navigation Transition

struct SpringNavigationModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? .none : Theme.Animation.spring, value: true)
    }
}

extension View {
    func springTransition() -> some View {
        modifier(SpringNavigationModifier())
    }
}

// MARK: - Animated Appearance

struct AnimatedAppearanceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.95)
            .onAppear {
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(Theme.Animation.spring) {
                        appeared = true
                    }
                }
            }
    }
}

extension View {
    func animatedAppearance() -> some View {
        modifier(AnimatedAppearanceModifier())
    }
}
