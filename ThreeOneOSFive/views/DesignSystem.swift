import SwiftUI
import UIKit

// MARK: - Theme tokens

struct BeuTheme {
    let accent: Color
    let pageBackground: Color
    let surface: Color
    let elevatedSurface: Color
    let primaryText: Color
    let secondaryText: Color
    let tertiaryText: Color
    let separator: Color
    let controlBackground: Color
    let success: Color
    let danger: Color
    let warning: Color
    /// Thin accent-tinted stroke like anh1.jpg
    let cardBorder: Color

    static func make(accent: Color) -> BeuTheme {
        BeuTheme(
            accent: accent,
            pageBackground: Color(uiColor: .systemGroupedBackground),
            surface: Color(uiColor: .secondarySystemGroupedBackground),
            elevatedSurface: Color(uiColor: .tertiarySystemBackground),
            primaryText: Color(uiColor: .label),
            secondaryText: Color(uiColor: .secondaryLabel),
            tertiaryText: Color(uiColor: .tertiaryLabel),
            separator: Color(uiColor: .separator),
            controlBackground: Color(uiColor: .secondarySystemFill),
            success: Color(uiColor: .systemGreen),
            danger: Color(uiColor: .systemRed),
            warning: Color(uiColor: .systemOrange),
            cardBorder: accent.opacity(0.28)
        )
    }
}

private struct BeuThemeKey: EnvironmentKey {
    static let defaultValue = BeuTheme.make(accent: AppTheme.defaultAccent)
}

extension EnvironmentValues {
    var beuTheme: BeuTheme {
        get { self[BeuThemeKey.self] }
        set { self[BeuThemeKey.self] = newValue }
    }
    var accentColorTheme: Color {
        get { self[BeuThemeKey.self].accent }
        set { self[BeuThemeKey.self] = BeuTheme.make(accent: newValue) }
    }
}

enum AppTheme {
    static let pageBackground = Color(uiColor: .systemGroupedBackground)
    static let consoleBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let pageInset: CGFloat = 16
    static let rowIconSize: CGFloat = 17
    static let rowIconFrame: CGFloat = 28
    static let fileRowIconSize: CGFloat = 17
    static let fileRowIconFrame: CGFloat = 30
    static let fileRowHeight: CGFloat = 60
    static let appIconSize: CGFloat = 32
    static let emptyIconSize: CGFloat = 30
    static let selectionIconSize: CGFloat = 18
    static let radiusSmall: CGFloat = 14
    static let radiusMedium: CGFloat = 18
    static let radiusLarge: CGFloat = 22
    static let radiusXLarge: CGFloat = 28
    static let radiusPill: CGFloat = 999
    static let cardCorner: CGFloat = 18
    static let cardBorderWidth: CGFloat = 1

    static var accent: Color { defaultAccent }

    static let defaultAccent = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1.00, green: 0.64, blue: 0.42, alpha: 1.00)
                : UIColor(red: 0.85, green: 0.42, blue: 0.20, alpha: 1.00)
        }
    )

    static func accent(hue: Double) -> Color {
        Color(hue: hue, saturation: 0.72, brightness: 0.95)
    }
}

// MARK: - Card border (anh1 style)

struct BeuCardModifier: ViewModifier {
    @Environment(\.beuTheme) private var theme
    var corner: CGFloat = AppTheme.cardCorner

    func body(content: Content) -> some View {
        content
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(theme.cardBorder, lineWidth: AppTheme.cardBorderWidth)
            )
    }
}

extension View {
    /// Soft rounded card + thin accent border (see anh1.jpg)
    func beuCard(corner: CGFloat = AppTheme.cardCorner) -> some View {
        modifier(BeuCardModifier(corner: corner))
    }

    func beuChrome() -> some View {
        modifier(BeuChromeModifier())
    }
}

private struct BeuChromeModifier: ViewModifier {
    @Environment(\.beuTheme) private var theme

    func body(content: Content) -> some View {
        content
            .background(theme.pageBackground)
            .toolbarBackground(theme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(theme.accent)
    }
}

// MARK: - Dividers

struct BeuFullDivider: View {
    @Environment(\.beuTheme) private var theme

    var body: some View {
        Rectangle()
            .fill(theme.separator)
            .frame(maxWidth: .infinity)
            .frame(height: 1 / UIScreen.main.scale)
            .ignoresSafeArea(edges: .horizontal)
            .accessibilityHidden(true)
    }
}

struct BeuInsetDivider: View {
    @Environment(\.beuTheme) private var theme
    var leadingInset: CGFloat = AppTheme.pageInset

    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: leadingInset, height: 1)
            Rectangle()
                .fill(theme.separator)
                .frame(maxWidth: .infinity)
                .frame(height: 1 / UIScreen.main.scale)
        }
        .accessibilityHidden(true)
    }
}

struct BeuHeaderBand<Content: View>: View {
    @Environment(\.beuTheme) private var theme
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surface)
            BeuFullDivider()
        }
    }
}

struct BeuSectionHeader: View {
    @Environment(\.beuTheme) private var theme
    let title: String
    var systemImage: String? = nil

    var body: some View {
        Group {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(theme.secondaryText)
        .textCase(nil)
    }
}

// MARK: - Root header: title + search + ONE divider (no system hairline)

struct BeuRootHeader<Trailing: View>: View {
    @Environment(\.beuTheme) private var theme
    let title: String
    @Binding var searchText: String
    let searchPrompt: String
    let clearLabel: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(spacing: 0) {
            // Centered title; trailing actions on the right (balanced layout)
            ZStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 72) // keep clear of trailing buttons

                HStack(spacing: 16) {
                    Spacer(minLength: 0)
                    trailing()
                        .imageScale(.medium)
                        .font(.body.weight(.semibold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .frame(minHeight: 44)

            AppSearchField(
                text: $searchText,
                prompt: searchPrompt,
                clearLabel: clearLabel
            )

            BeuFullDivider()
        }
        .background(theme.surface)
    }
}

// MARK: - Shared controls

struct AppRowIcon: View {
    let systemName: String
    var tint: Color? = nil
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = AppTheme.rowIconFrame
    @Environment(\.beuTheme) private var theme

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: symbolSize, weight: .medium))
            .foregroundStyle(tint ?? theme.accent)
            .frame(width: frameSize, height: frameSize)
            .accessibilityHidden(true)
    }
}

struct AppSearchField: View {
    @Environment(\.beuTheme) private var theme
    @Binding var text: String
    let prompt: String
    let clearLabel: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.secondaryText)
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .font(.body)
                .foregroundStyle(theme.primaryText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.tertiaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearLabel)
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                .fill(theme.controlBackground)
        }
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.bottom, 10)
    }
}

struct AppLogo: View {
    var size: CGFloat = 44
    @Environment(\.beuTheme) private var theme

    var body: some View {
        Group {
            if let icon = UIImage(named: "AppLogo") ?? UIImage(named: "AppIcon") {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.accent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    func displayName(language: AppLanguage) -> String {
        switch self {
        case .system: return language.text("settings.appearance_system")
        case .light: return language.text("settings.appearance_light")
        case .dark: return language.text("settings.appearance_dark")
        }
    }
}

struct PillTabBar: View {
    let sections: [AppSection]
    @Binding var selection: Int
    let titles: [Int: String]
    let systemImages: [Int: String]
    @Environment(\.beuTheme) private var theme
    @Namespace private var tabNS

    var body: some View {
        HStack(spacing: 0) {
            ForEach(sections) { section in
                let selected = selection == section.rawValue
                Button {
                    withAnimation(.easeInOut(duration: 0.36)) {
                        selection = section.rawValue
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: systemImages[section.rawValue] ?? "circle")
                            .font(.system(size: 20, weight: selected ? .semibold : .medium))
                            .symbolRenderingMode(.hierarchical)
                        Text(titles[section.rawValue] ?? "")
                            .font(.system(size: 10, weight: selected ? .semibold : .medium))
                    }
                    .foregroundStyle(selected ? theme.accent : theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if selected {
                            Capsule()
                                .fill(theme.accent.opacity(0.20))
                                .padding(.horizontal, 3)
                                .padding(.vertical, 2)
                                .matchedGeometryEffect(id: "tabPill", in: tabNS)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(AnyShapeStyle(.ultraThinMaterial))
                .overlay(Capsule().stroke(theme.cardBorder, lineWidth: 1))
                .shadow(color: .black.opacity(0.16), radius: 14, y: 5)
        }
        .padding(.horizontal, 18)
        .animation(.easeInOut(duration: 0.36), value: selection)
    }
}
