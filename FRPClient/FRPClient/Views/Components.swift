import SwiftUI

// MARK: - Design Tokens

enum GlassTheme {
    static let cornerRadius: CGFloat = 16
    static let cardRadius: CGFloat = 14
    static let inputRadius: CGFloat = 10
    static let borderWidth: CGFloat = 0.3
    static let borderColor: Color = Color.primary.opacity(0.08)
    static let cardShadowColor: Color = Color.black.opacity(0.06)
    static let cardShadowRadius: CGFloat = 8
    static let outerShadowColor: Color = Color.black.opacity(0.03)
    static let outerShadowRadius: CGFloat = 16
    static let innerPadding: CGFloat = 18
    static let sectionSpacing: CGFloat = 20
    static let accentTint: Double = 0.06
}

// MARK: - Card Container

struct CardView<Content: View>: View {
    let content: Content
    var isHovered: Bool = false

    init(isHovered: Bool = false, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.isHovered = isHovered
    }

    var body: some View {
        content
            .padding(GlassTheme.innerPadding)
            .background(
                RoundedRectangle(cornerRadius: GlassTheme.cardRadius, style: .continuous)
                    .fill(Color(.controlBackgroundColor).opacity(0.5))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GlassTheme.cardRadius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassTheme.cardRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: isHovered ? [Color.accentColor.opacity(0.3), Color.purple.opacity(0.15)] : [GlassTheme.borderColor, GlassTheme.borderColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 1.0 : GlassTheme.borderWidth
                    )
            )
            .shadow(color: GlassTheme.cardShadowColor, radius: GlassTheme.cardShadowRadius, x: 0, y: isHovered ? 6 : 3)
            .shadow(color: GlassTheme.outerShadowColor, radius: GlassTheme.outerShadowRadius, x: 0, y: isHovered ? 12 : 6)
    }
}

private extension ShapeStyle where Self == Color {
    static func strokeBorder(_ color: Color, lineWidth: CGFloat) -> some ShapeStyle {
        color
    }
}

// MARK: - Status Card (Overview page)

struct StatusCard: View {
    let icon: String
    let iconColor: Color
    let iconBackground: Color
    let title: String
    let value: String
    let subtitle: String
    
    @State private var isHovered = false

    var body: some View {
        CardView(isHovered: isHovered) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconBackground)
                        .frame(width: 46, height: 46)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(iconColor.opacity(0.2), lineWidth: 0.5)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(iconColor)
                }
                .shadow(color: iconColor.opacity(0.15), radius: 6, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                    Text(value)
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

// MARK: - Metric Card (Dashboard page)

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    @State private var isHovered = false

    var body: some View {
        CardView(isHovered: isHovered) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(color.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(color)
                    }
                    Text(title)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundColor(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isPressed
                                ? [color.opacity(0.22), color.opacity(0.12)]
                                : isHovered
                                ? [color.opacity(0.14), color.opacity(0.06)]
                                : [color.opacity(0.06), color.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: isHovered ? [color.opacity(0.35), color.opacity(0.15)] : [color.opacity(0.2), color.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 0.8 : 0.5
                    )
            )
            .shadow(color: isHovered ? color.opacity(0.15) : Color.clear, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(color.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Grouped Section

struct SectionGroup<Content: View, Label: View>: View {
    let content: Content
    let label: Label

    init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.content = content()
        self.label = label()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            label
            content
        }
        .padding(GlassTheme.innerPadding)
        .background(
            RoundedRectangle(cornerRadius: GlassTheme.cardRadius, style: .continuous)
                .fill(Color(.controlBackgroundColor).opacity(0.3))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GlassTheme.cardRadius, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: GlassTheme.cardRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.primary.opacity(0.06), Color.accentColor.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: GlassTheme.borderWidth
                )
        )
        .shadow(color: GlassTheme.cardShadowColor, radius: GlassTheme.cardShadowRadius, x: 0, y: 3)
    }
}

extension SectionGroup where Label == Text {
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.label = Text(title)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(.primary)
    }
}

// MARK: - Bordered Input Modifier

struct BorderedInput: ViewModifier {
    @FocusState private var isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: GlassTheme.inputRadius, style: .continuous)
                    .fill(Color(.textBackgroundColor).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassTheme.inputRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.primary.opacity(0.12), Color.primary.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}

extension View {
    func borderedInput() -> some View {
        modifier(BorderedInput())
    }
}

// MARK: - Glass Pill (for tags/badges)

struct GlassPill: View {
    let text: String
    let color: Color
    let icon: String?

    init(_ text: String, color: Color, icon: String? = nil) {
        self.text = text
        self.color = color
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.1), in: Capsule())
    }
}

// MARK: - Toolbar Action Button

struct ToolbarActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderless)
    }
}

// MARK: - Form Row (label on left, control on right)

struct FormRow<Content: View>: View {
    let leading: String
    @ViewBuilder let content: () -> Content

    init(leading: String, @ViewBuilder content: @escaping () -> Content) {
        self.leading = leading
        self.content = content
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(leading)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            content()
            Spacer()
        }
    }
}

// MARK: - Category Tab Button

struct CategoryTab: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .rounded))
            }
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isSelected
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color.accentColor.opacity(0.15), Color.purple.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            : AnyShapeStyle(
                                isHovered ? Color.primary.opacity(0.06) : Color.clear
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Sidebar Row

struct SidebarRow: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let hasDot: Bool
    let sidebarSelectionColor: Color
    let sidebarHoverColor: Color

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundColor(isSelected ? .white : .primary)

            Spacer()

            if hasDot {
                Circle()
                    .fill(isSelected ? .white : .green)
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .fill((isSelected ? Color.white : .green).opacity(0.3))
                            .frame(width: 12, height: 12)
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundColor)
                .padding(.horizontal, 4)
        )
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return sidebarSelectionColor
        }
        if isHovered {
            return sidebarHoverColor
        }
        return Color.clear
    }
}
