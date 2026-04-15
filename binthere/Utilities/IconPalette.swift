import SwiftUI

enum IconPalette {
    struct IconGroup: Identifiable {
        let id: String
        let name: String
        let icons: [String]
    }

    static let groups: [IconGroup] = [
        IconGroup(id: "general", name: "General", icons: [
            "house", "building.2", "shippingbox", "map",
        ]),
        IconGroup(id: "living", name: "Living", icons: [
            "sofa", "tv", "bed.double", "chair.lounge",
        ]),
        IconGroup(id: "work", name: "Work", icons: [
            "desktopcomputer", "wrench", "hammer", "paintbrush",
        ]),
        IconGroup(id: "storage", name: "Storage", icons: [
            "archivebox", "tray.2", "cabinet", "cube.box",
        ]),
        IconGroup(id: "outdoor", name: "Outdoor", icons: [
            "leaf", "car", "bicycle", "tree",
        ]),
        IconGroup(id: "kitchen", name: "Kitchen & Bath", icons: [
            "fork.knife", "cup.and.saucer", "drop", "washer",
        ]),
    ]

    static let allIcons: [String] = groups.flatMap(\.icons)

    static let defaultIcon = "archivebox"
}

struct IconPickerGrid: View {
    @Binding var selectedIcon: String
    @State private var expandedGroups: Set<String> = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        VStack(spacing: 8) {
            ForEach(IconPalette.groups) { group in
                groupSection(group)
            }
        }
        .onAppear { autoExpandSelectedGroup() }
    }

    @ViewBuilder
    private func groupSection(_ group: IconPalette.IconGroup) -> some View {
        let isExpanded = expandedGroups.contains(group.id)

        Button(action: { toggleGroup(group.id) }) {
            HStack {
                Text(group.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                if let preview = group.icons.first(where: { $0 == selectedIcon }) {
                    Image(systemName: preview)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if isExpanded {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(group.icons, id: \.self) { icon in
                    Image(systemName: icon)
                        .font(.title3)
                        .frame(width: 40, height: 40)
                        .background(
                            selectedIcon == icon
                                ? Color.accentColor.opacity(0.15)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    selectedIcon == icon ? Color.accentColor : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .onTapGesture {
                            selectedIcon = selectedIcon == icon ? "" : icon
                        }
                }
            }
            .padding(.bottom, 8)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }

        Divider()
    }

    private func toggleGroup(_ id: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedGroups.contains(id) {
                expandedGroups.remove(id)
            } else {
                expandedGroups.insert(id)
            }
        }
    }

    private func autoExpandSelectedGroup() {
        for group in IconPalette.groups where group.icons.contains(selectedIcon) {
            expandedGroups.insert(group.id)
        }
    }
}

struct ZoneIcon: View {
    let iconName: String
    let colorName: String
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: iconName.isEmpty ? IconPalette.defaultIcon : iconName)
            .font(.system(size: size * 0.7))
            .foregroundStyle(colorName.isEmpty ? .secondary : ColorPalette.from(colorName).color)
            .frame(width: size, height: size)
    }
}
