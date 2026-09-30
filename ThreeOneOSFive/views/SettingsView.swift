import SwiftUI

struct SettingsView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.beuTheme) private var theme
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var licenseManager: LicenseManager
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    @AppStorage("themeAccentHue") private var themeHue: Double = 0.08
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue

    /// Persists across tab switches (comma-separated field ids).
    @AppStorage("hiddenDeviceFields") private var hiddenDeviceFieldsRaw = ""

    private var hiddenDeviceFields: Set<String> {
        get {
            Set(hiddenDeviceFieldsRaw.split(separator: ",", omittingEmptySubsequences: true).map(String.init))
        }
        set {
            hiddenDeviceFieldsRaw = newValue.sorted().joined(separator: ",")
        }
    }

    private var appearanceMode: Binding<String> { $appearanceModeRaw }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        AppLogo(size: 48)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Beu").font(.headline)
                            Text(language.text("common.version", "1.0.0"))
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .beuCard(corner: 16)

                    cardSection(language.text("license.settings_title")) {
                        HStack(spacing: 10) {
                            Image(systemName: licenseManager.isAuthorized ? "checkmark.seal.fill" : "xmark.seal.fill")
                                .foregroundStyle(licenseManager.isAuthorized ? theme.success : theme.danger)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(licenseManager.isAuthorized ? language.text("license.active") : language.text("license.inactive"))
                                    .font(.subheadline.weight(.semibold))
                                if licenseManager.isAuthorized {
                                    Text(licenseManager.activeKey)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(theme.secondaryText)
                                }
                            }
                            Spacer()
                        }

                        Button { licenseManager.signOutLocal() } label: {
                            Label(language.text("license.change_key"), systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                    }

                    cardSection(language.text("settings.language")) {
                        Picker("", selection: $languageCode) {
                            ForEach(AppLanguage.allCases) { option in
                                Text(option.displayName).tag(option.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .transaction { transaction in
                            // Avoid animating the whole app UI when language strings swap.
                            transaction.animation = nil
                        }
                    }

                    cardSection(language.text("settings.appearance")) {
                        Picker("", selection: appearanceMode) {
                            ForEach(AppAppearanceMode.allCases) { mode in
                                Text(mode.displayName(language: language)).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                    }

                    cardSection(language.text("settings.theme_color")) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(AppTheme.accent(hue: themeHue))
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(theme.cardBorder, lineWidth: 1))
                            Slider(value: $themeHue, in: 0...1)
                                .tint(AppTheme.accent(hue: themeHue))
                        }
                        Text(language.text("settings.theme_hint"))
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }

                    cardSection(language.text("common.device")) {
                        privateDeviceRow(
                            id: "hardware",
                            key: language.text("dashboard.hardware_model"),
                            value: AppInfo.displayMachineName
                        )
                        privateDeviceRow(
                            id: "ios",
                            key: language.text("settings.ios_version"),
                            value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))"
                        )
                        privateDeviceRow(
                            id: "machine",
                            key: language.text("settings.machine_id"),
                            value: AppInfo.machineName
                        )
                        privateDeviceRow(
                            id: "compatibility",
                            key: language.text("settings.compatibility"),
                            value: language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"),
                            valueColor: appState.isSupported ? theme.success : theme.danger
                        )
                    }

                    cardSection(language.text("settings.social_media")) {
                        social("TikTok", "@beuu1411", "https://www.tiktok.com/@beuu1411")
                        social("Facebook", "beu1411", "https://web.facebook.com/beu1411")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
            .background(theme.pageBackground)
            .navigationTitle(language.text("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .beuChrome()
        .transaction { $0.animation = nil }
        }
    }
    private func cardSection<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
            content()
        }
        .padding(14)
        .beuCard(corner: 16)
    }

    private func privateDeviceRow(
        id: String,
        key: String,
        value: String,
        valueColor: Color? = nil
    ) -> some View {
        let hidden = hiddenDeviceFields.contains(id)

        return Button {
            var next = hiddenDeviceFields
            if hidden {
                next.remove(id)
            } else {
                next.insert(id)
            }
            hiddenDeviceFieldsRaw = next.sorted().joined(separator: ",")
        } label: {
            HStack {
                Text(key)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
                Spacer()
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(valueColor ?? theme.primaryText)
                    .blur(radius: hidden ? 6 : 0)
                Image(systemName: hidden ? "eye.slash" : "eye")
                    .font(.caption)
                    .foregroundStyle(theme.tertiaryText)
                    .frame(width: 22)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func social(_ name: String, _ sub: String, _ url: String) -> some View {
        if let u = URL(string: url) {
            Link(destination: u) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name).font(.headline).foregroundStyle(theme.primaryText)
                        Text(sub).font(.caption).foregroundStyle(theme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(theme.accent)
                }
            }
        }
    }
}
