import SwiftUI

enum ColorPalette: String, CaseIterable, Identifiable {
    case none = ""
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case pink
    case teal
    case brown
    case gray

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .none: .primary
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        case .teal: .teal
        case .brown: .brown
        case .gray: .gray
        }
    }

    var displayName: String {
        switch self {
        case .none: "None"
        default: rawValue.capitalized
        }
    }

    static func from(_ rawValue: String) -> Self {
        Self(rawValue: rawValue) ?? .none
    }

    static var selectableColors: [Self] {
        allCases.filter { $0 != .none }
    }
}

struct ColorPickerRow: View {
    @Binding var selectedColor: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ColorPalette.selectableColors) { palette in
                    Circle()
                        .fill(palette.color)
                        .frame(width: 32, height: 32)
                        .overlay {
                            if selectedColor == palette.rawValue {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 2)
                                    .frame(width: 26, height: 26)
                            }
                        }
                        .shadow(
                            color: selectedColor == palette.rawValue ? palette.color.opacity(0.5) : .clear,
                            radius: 4
                        )
                        .padding(.vertical, 4)
                        .onTapGesture {
                            selectedColor = selectedColor == palette.rawValue ? "" : palette.rawValue
                        }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct ColorDot: View {
    let colorName: String
    var size: CGFloat = 12

    var body: some View {
        if !colorName.isEmpty {
            Circle()
                .fill(ColorPalette.from(colorName).color)
                .frame(width: size, height: size)
        }
    }
}
