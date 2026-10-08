import SwiftUI
import UIKit
import AudioToolbox
import AVFoundation

// MARK: - Root after license

struct ContentView: View {
    @EnvironmentObject private var licenseManager: LicenseManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.appLanguage) private var language

    @State private var showSideMenu = false
    @State private var showAccount = false
    @State private var selectedPage: HomePage = .home
    @State private var openGame: OpenGameTarget? = nil
    @State private var keyHidden = false
    @State private var uuidHidden = false
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.vietnamese.rawValue
    @State private var homeRingSpin = false
    @State private var showLoginSuccessBanner = false
    @State private var remainingText = "—"
    @State private var tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let silver = Color(white: 0.72)

    enum HomePage {
        case home, settings
    }

    struct OpenGameTarget: Identifiable, Equatable {
        let id: String
        let title: String
        let package: String
        let asset: String
        var isFreeFireTH: Bool { package == "com.dts.freefireth" }
        var isFreeFireMax: Bool { package == "com.dts.freefiremax" }
    }

    var body: some View {
        ZStack {
            // Background only — full bleed under status bar / home indicator
            Color.black.ignoresSafeArea()
            backgroundLayer
            Color.black.opacity(0.40).ignoresSafeArea()
            FloatingHomeParticles(count: 50)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Foreground respects safe area so top buttons clear the status bar
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 4)

                Group {
                    switch selectedPage {
                    case .home:
                        homeContent
                    case .settings:
                        settingsPlaceholder
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if showLoginSuccessBanner {
                loginSuccessBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(50)
            }

            if showSideMenu {
                sideMenuOverlay
                    .transition(.opacity)
                    .zIndex(20)
            }

            if showAccount {
                accountSheet
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .zIndex(30)
            }

            if let game = openGame {
                FreeFireGamePanel(game: game) {
                    openGame = nil
                }
                .transition(.opacity)
                .zIndex(40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .onReceive(tick) { _ in
            remainingText = Self.formatRemaining(until: licenseManager.keyInfo?.expiresAt)
        }
        .onAppear {
            remainingText = Self.formatRemaining(until: licenseManager.keyInfo?.expiresAt)
            homeRingSpin = true
            showLoginSuccessBanner = true
            BeuSound.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    showLoginSuccessBanner = false
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: showLoginSuccessBanner)
        .animation(.easeInOut(duration: 0.28), value: showSideMenu)
        .animation(.easeInOut(duration: 0.28), value: showAccount)
        .animation(.easeInOut(duration: 0.25), value: openGame?.id)
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        Group {
            if UIImage(named: "LoginBackground") != nil {
                Image("LoginBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
            } else {
                Color(white: 0.06)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            circleIconButton(systemName: "line.3.horizontal") {
                showSideMenu = true
            }
            Spacer()
            circleIconButton(systemName: "person.fill") {
                showAccount = true
            }
        }
    }

    private func circleIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button {
            BeuSound.soft()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.white.opacity(0.10)))
                .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Home content

    private var homeContent: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 12)

            homeAvatar
                .padding(.top, 8)

            Text("HUYMINH")
                .font(.system(size: 28, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(.white)
                .padding(.top, 14)

            HStack(spacing: 8) {
                Capsule().fill(silver.opacity(0.6)).frame(width: 16, height: 1)
                Text("IPA PROXY BY HUYMINH")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(silver)
                Capsule().fill(silver.opacity(0.6)).frame(width: 16, height: 1)
            }
            .padding(.top, 8)

            VStack(spacing: 10) {
                gameCard(title: "Free Fire Max", package: "com.dts.freefiremax", asset: "FreeFireMax")
                gameCard(title: "Free Fire", package: "com.dts.freefireth", asset: "FreeFire")
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)

            Spacer(minLength: 12)

            keyBar
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var homeAvatar: some View {
        ZStack {
            Circle()
                .fill(silver.opacity(0.18))
                .frame(width: 108, height: 108)
                .blur(radius: 14)

            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white, location: 0),
                            .init(color: silver, location: 0.12),
                            .init(color: silver.opacity(0.25), location: 0.32),
                            .init(color: .clear, location: 0.45),
                            .init(color: .clear, location: 0.62),
                            .init(color: silver.opacity(0.55), location: 0.78),
                            .init(color: Color.white, location: 1)
                        ]),
                        center: .center
                    ),
                    lineWidth: 2.8
                )
                .frame(width: 96, height: 96)
                .rotationEffect(.degrees(homeRingSpin ? 360 : 0))
                .animation(.linear(duration: 5).repeatForever(autoreverses: false), value: homeRingSpin)

            Group {
                if UIImage(named: "AppAvatar") != nil {
                    Image("AppAvatar").resizable().scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(16)
                        .background(Color(white: 0.12))
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color(white: 0.1), lineWidth: 3))
        }
    }

    private func gameCard(title: String, package: String, asset: String) -> some View {
        HStack(spacing: 12) {
            Group {
                if UIImage(named: asset) != nil {
                    Image(asset).resizable().scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.7))
                        .overlay(Text("FF").font(.headline.bold()).foregroundStyle(.white))
                }
            }
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(.white)
                Text(package)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                BeuSound.tick()
                openGame = OpenGameTarget(id: package, title: title, package: package, asset: asset)
            } label: {
                HStack(spacing: 4) {
                    Text("OPEN")
                        .font(.system(size: 12.5, weight: .bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(0.08)))
                .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Key bar

    private var keyBar: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: "key.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Key:")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                    Text(displayKey)
                        .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    Text("Thời Hạn Còn Lại:")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                    Text(remainingText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                keyHidden.toggle()
            } label: {
                Image(systemName: keyHidden ? "eye.slash" : "eye")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                UIPasteboard.general.string = licenseManager.activeKey
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var displayKey: String {
        let key = licenseManager.activeKey
        guard !key.isEmpty else { return "—" }
        if keyHidden {
            return String(repeating: "•", count: min(key.count, 14))
        }
        return key
    }

    // MARK: - Settings

    private var settingsPlaceholder: some View {
        ScrollView {
            VStack(spacing: 14) {
                // App identity
                HStack(spacing: 12) {
                    Group {
                        if UIImage(named: "AppAvatar") != nil {
                            Image("AppAvatar").resizable().scaledToFill()
                        } else {
                            Image(systemName: "person.fill").foregroundStyle(.white)
                        }
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("HUYMINH IOS")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text("\(language == .vietnamese ? "Phiên bản" : "Version") \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                }
                .padding(14)
                .background(glassCard)

                // Device & license
                settingsSection(title: language == .vietnamese ? "THÔNG TIN THIẾT BỊ & BẢN QUYỀN" : "DEVICE & LICENSE") {
                    settingsCopyRow(label: language == .vietnamese ? "UUID Thiết Bị" : "Device UUID", value: deviceUUIDShort, copyValue: licenseManager.installationIDDisplay)
                    settingsKeyRow
                    settingsStatusRow(
                        label: language == .vietnamese ? "Trạng Thái Kernel" : "Kernel Status",
                        value: kernelStatusText,
                        ok: appState.exploitStatus.isSuccess
                    )
                }

                // Language
                settingsSection(title: language.text("settings.language").uppercased()) {
                    HStack(spacing: 6) {
                        languageChip("Tiếng Việt", code: AppLanguage.vietnamese.rawValue)
                        languageChip("English", code: AppLanguage.english.rawValue)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                }

                // Hardware
                settingsSection(title: language == .vietnamese ? "THÔNG TIN PHẦN CỨNG" : "HARDWARE INFO") {
                    settingsPlainRow(label: language == .vietnamese ? "Nền tảng phần cứng" : "Hardware Platform", value: AppInfo.displayMachineName)
                    settingsPlainRow(label: language.text("settings.ios_version"), value: "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))")
                    settingsStatusRow(
                        label: language.text("settings.exploit_status"),
                        value: appState.exploitStatus.isSuccess ? "VERIFIED" : kernelStatusText,
                        ok: appState.exploitStatus.isSuccess
                    )
                }

                // Verified iOS list
                settingsSection(title: language.text("settings.verified_versions").uppercased()) {
                    verifiedIOSRow("iOS 16", "16.0 – 16.7.1 (kernel exploit)")
                    verifiedIOSRow("iOS 17", ExploitSupportPolicy.verifiedIOS17Range + " (kernel exploit)")
                    verifiedIOSRow("iOS 18", ExploitSupportPolicy.verifiedIOS18Range + " (kernel exploit)")
                    verifiedIOSRow("iOS 26", ExploitSupportPolicy.verifiedIOS26Range)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(language == .vietnamese ? "Các bản Beta" : "Beta builds")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(betaListText)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.45))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }

                // Notes
                settingsSection(title: language == .vietnamese ? "LƯU Ý CÀI ĐẶT & CHỨNG CHỈ" : "INSTALL NOTES & CERTIFICATE") {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.white.opacity(0.6))
                        Text(language == .vietnamese ? "Các chức năng trên thiết bị yêu cầu ứng dụng được ký bằng chứng chỉ doanh nghiệp." : "On-device features require the app to be signed with an enterprise certificate.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(Color.orange.opacity(0.85))
                        Text(language == .vietnamese ? "Không hỗ trợ SideStore, AltStore, 3uTools hoặc LiveContainer." : "SideStore, AltStore, 3uTools, and LiveContainer are not supported.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }


    private func settingsStatusRow(label: String, value: String, ok: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(ok ? Color(red: 0.30, green: 0.90, blue: 0.50) : Color(red: 0.95, green: 0.35, blue: 0.35))
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private var loginSuccessBanner: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(red: 0.30, green: 0.90, blue: 0.50))
                Text(language == .vietnamese ? "Đăng nhập thành công" : "Login successful")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.72))
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.35))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(red: 0.30, green: 0.90, blue: 0.50).opacity(0.45), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var glassCard: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.black.opacity(0.50))
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.28))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }

    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                content()
            }
            .background(glassCard)
        }
    }

    private func settingsPlainRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private func settingsCopyRow(label: String, value: String, copyValue: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Button {
                UIPasteboard.general.string = copyValue
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private var settingsKeyRow: some View {
        HStack {
            Text(language == .vietnamese ? "Key Bản Quyền" : "License Key")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
            Spacer()
            Text(displayKey)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Button { keyHidden.toggle() } label: {
                Image(systemName: keyHidden ? "eye.slash" : "eye")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .buttonStyle(.plain)
            Button { UIPasteboard.general.string = licenseManager.activeKey } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private func languageChip(_ title: String, code: String) -> some View {
        Button {
            languageCode = code
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(languageCode == code ? .black : .white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(languageCode == code ? Color.white : Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    private func verifiedIOSRow(_ left: String, _ right: String) -> some View {
        HStack {
            Text(left)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Text(right)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
    }

    private var kernelStatusText: String {
        switch appState.exploitStatus {
        case .success(let method):
            return language == .vietnamese ? "Hoạt động (\(method))" : "Active (\(method))"
        case .failed:
            return language == .vietnamese ? "Thất bại" : "Failed"
        case .unsupported:
            return language.text("settings.unsupported")
        case .notStarted:
            if appState.kernelExploitRunning {
                return language == .vietnamese ? "Đang chạy…" : "Running…"
            }
            return language == .vietnamese ? "Chưa chạy" : "Not started"
        }
    }

    private var betaListText: String {
        let items = ExploitSupportPolicy.verifiedIOS27Builds.map { row in
            if let pb = row.publicBeta {
                return "Beta \(row.beta) / PB \(pb) (\(row.build))"
            }
            return "Beta \(row.beta) (\(row.build))"
        }
        return "iOS 27 " + items.joined(separator: ", ")
    }


    // MARK: - Side menu (liquid glass cards)

    private var sideMenuOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { showSideMenu = false }

            VStack(spacing: 0) {
                HStack {
                    Text("HUYMINH MENU")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(.white)
                    Spacer()
                    Button { showSideMenu = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.white.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 18)

                VStack(spacing: 10) {
                    sideNavItem(title: "Trang chủ", systemImage: "house.fill", page: .home)
                    sideNavItem(title: "Cài đặt", systemImage: "gearshape.fill", page: .settings)
                }
                .padding(.horizontal, 16)

                Spacer()
            }
            .frame(maxWidth: 320)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black.opacity(0.72))
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.35))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .padding(.top, 56)
            .padding(.horizontal, 18)
            .padding(.bottom, 40)
        }
    }

    private func sideNavItem(title: String, systemImage: String, page: HomePage) -> some View {
        Button {
            selectedPage = page
            showSideMenu = false
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selectedPage == page ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(selectedPage == page ? 0.16 : 0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Account card (centered liquid glass)

    private var accountSheet: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { showAccount = false }

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 40, height: 40)
                        Image(systemName: "person.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("TÀI KHOẢN HUYMINH")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Thành viên • Key đang hoạt động")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                    Button { showAccount = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.65))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 14)

                // Info rows inside inner glass card
                VStack(spacing: 0) {
                    accountInfoRow(label: "Gói Bản\nQuyền:", value: "KEY ACTIVE")
                    accountInfoRow(label: "Phiên Bản iOS:", value: "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))", pill: true)
                    accountKeyRow
                    accountInfoRow(label: "Hạn Sử Dụng:", value: remainingText)
                    accountUUIDRow
                    accountInfoRow(label: "Máy:", value: AppInfo.displayMachineName)
                }
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 14)

                // Buttons
                Button {
                    // Reset UUID = clear local key binding / logout
                    licenseManager.signOutLocal()
                    showAccount = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Reset UUID Khỏi Key (Tự Logout)")
                            .font(.system(size: 13.5, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.top, 14)

                Button {
                    licenseManager.signOutLocal()
                    showAccount = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Logout (Không Reset UUID)")
                            .font(.system(size: 13.5, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 18)
            }
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.78))
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.4))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
    }

    private func accountInfoRow(label: String, value: String, pill: Bool = false) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 100, alignment: .leading)
            Spacer(minLength: 8)
            if pill {
                Text(value)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
            } else {
                Text(value)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var accountKeyRow: some View {
        HStack(alignment: .center) {
            Text("Key Đang Dùng:")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 100, alignment: .leading)
            Spacer(minLength: 6)
            Text(displayKey)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Button { keyHidden.toggle() } label: {
                Image(systemName: keyHidden ? "eye.slash" : "eye")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .buttonStyle(.plain)
            Button { UIPasteboard.general.string = licenseManager.activeKey } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var accountUUIDRow: some View {
        HStack(alignment: .center) {
            Text("UUID Thiết Bị:")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 100, alignment: .leading)
            Spacer(minLength: 6)
            Text(uuidHidden ? "••••••••-••••-••••" : deviceUUIDShort)
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Button { uuidHidden.toggle() } label: {
                Image(systemName: uuidHidden ? "eye.slash" : "eye")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .buttonStyle(.plain)
            Button {
                UIPasteboard.general.string = licenseManager.installationIDDisplay
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var deviceUUIDShort: String {
        let id = licenseManager.installationIDDisplay
        if id.count > 22 {
            return String(id.prefix(20)) + "…"
        }
        return id
    }

    // MARK: - Countdown helper

    static func formatRemaining(until date: Date?) -> String {
        guard let date else { return "Không giới hạn" }
        let remaining = date.timeIntervalSinceNow
        if remaining <= 0 { return "Đã hết hạn" }
        let total = Int(remaining)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        return String(format: "%d Ngày %02d:%02d:%02d", days, hours, mins, secs)
    }
}

// MARK: - Particles (home)

private struct FloatingHomeParticles: View {
    let count: Int
    private let particles: [HomeParticle]

    init(count: Int) {
        self.count = count
        var rng = HomeSeededRNG(seed: 0x4D494F53)
        self.particles = (0..<count).map { _ in
            HomeParticle(
                x: Double.random(in: 0...1, using: &rng),
                y: Double.random(in: 0...1, using: &rng),
                r: CGFloat.random(in: 0.8...2.4, using: &rng),
                a: Double.random(in: 0.08...0.32, using: &rng),
                vx: Double.random(in: -0.014...0.014, using: &rng),
                vy: Double.random(in: -0.012...0.012, using: &rng)
            )
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for p in particles {
                    var x = p.x + p.vx * t
                    var y = p.y + p.vy * t
                    x = x.truncatingRemainder(dividingBy: 1); if x < 0 { x += 1 }
                    y = y.truncatingRemainder(dividingBy: 1); if y < 0 { y += 1 }
                    let rect = CGRect(
                        x: x * size.width - p.r,
                        y: y * size.height - p.r,
                        width: p.r * 2,
                        height: p.r * 2
                    )
                    context.opacity = p.a
                    context.fill(Path(ellipseIn: rect), with: .color(.white))
                }
            }
        }
    }
}

private struct HomeParticle {
    let x, y: Double
    let r: CGFloat
    let a, vx, vy: Double
}

private struct HomeSeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9e3779b97f4a7c15 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}


// MARK: - Free Fire game panel (OPEN) — remote assets from funcition

private enum FFTab: Int, CaseIterable, Identifiable {
    case menu, aim, chams, mods, other
    var id: Int { rawValue }
    func title(_ language: AppLanguage) -> String {
        switch self {
        case .menu: return "Menu"
        case .aim: return language.text("home.ff.aim")
        case .chams: return "Chams"
        case .mods: return language.text("home.ff.mods")
        case .other: return "Other"
        }
    }
}

private struct FreeFireGamePanel: View {
    let game: ContentView.OpenGameTarget
    var onClose: () -> Void

    @Environment(\.appLanguage) private var language

    @State private var tab: FFTab = .menu
    @State private var appliedIDs: Set<String> = []
    @State private var busyID: String?
    @State private var errorText: String?
    @State private var infoText: String?
    @State private var showHelp = false

    private var package: String { game.package }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Group {
                if UIImage(named: "LoginBackground") != nil {
                    Image("LoginBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .clipped()
                } else {
                    Color(white: 0.06)
                }
            }
            .ignoresSafeArea()
            Color.black.opacity(0.50).ignoresSafeArea()
            FloatingHomeParticles(count: 50)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                tabBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                ScrollView {
                    VStack(spacing: 10) {
                        tabContent
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.red.opacity(0.9))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
                if let infoText {
                    Text(infoText)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.30, green: 0.90, blue: 0.50))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
        }
        .onAppear { refreshApplied() }
        .sheet(isPresented: $showHelp) {
            helpSheet
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Group {
                if UIImage(named: game.asset) != nil {
                    Image(game.asset).resizable().scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.6))
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(game.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                HStack(spacing: 4) {
                    Circle().fill(Color.white.opacity(0.5)).frame(width: 4, height: 4)
                    Text(game.package)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            Spacer()
            Button { showHelp = true } label: {
                Image(systemName: "questionmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.45)))
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.45)))
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(FFTab.allCases) { item in
                Button {
                    BeuSound.glass()
                    tab = item
                } label: {
                    Text(item.title(language))
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(tab == item ? .black : .white.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(tab == item ? Color.white : Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule().fill(Color.black.opacity(0.35))
        )
    }

        @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .menu:
            ForEach(FreeFireRemoteAssetService.menuItems(forPackage: package)) { item in
                remoteFeatureRow(
                    id: "menu.\(item.id)",
                    title: item.title,
                    subtitle: "Assembly + localConfig → Documents",
                    badge: game.isFreeFireMax ? "FFM" : "FFTH",
                    systemImage: "line.3.horizontal.circle",
                    on: appliedIDs.contains("menu.\(item.id)")
                ) {
                    toggleMenu(item)
                }
            }
        case .aim:
            ForEach(FreeFireRemoteAssetService.aimItems(forPackage: package)) { item in
                remoteFeatureRow(
                    id: "aim.\(item.id)",
                    title: item.title,
                    subtitle: "file đích → .../gameassetbundles/avatar",
                    badge: "REMOTE",
                    systemImage: "scope",
                    on: appliedIDs.contains("aim.\(item.id)")
                ) {
                    toggleAim(item)
                }
            }
        case .chams:
            ForEach(FreeFireRemoteAssetService.chamsItems(forPackage: package)) { item in
                remoteFeatureRow(
                    id: "chams.\(item.id)",
                    title: item.title,
                    subtitle: "shader → .../contentcache/Optional/ios/gameassetbundles",
                    badge: game.isFreeFireMax ? "FFM" : "FFTH",
                    systemImage: "person.crop.circle.badge.checkmark",
                    on: appliedIDs.contains("chams.\(item.id)")
                ) {
                    toggleChams(item)
                }
            }
        case .mods:
            let characters = FreeFireRemoteAssetService.modCharacters(forPackage: package)
            if characters.isEmpty {
                emptyCategory(title: game.isFreeFireMax ? "MODS FFM (trống)" : "MODS FFTH (trống)")
            } else {
                ForEach(characters) { ch in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(ch.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.top, 6)
                        ForEach(ch.versions) { ver in
                            remoteFeatureRow(
                                id: "mod.\(ver.id)",
                                title: "\(ch.title) — \(ver.title)",
                                subtitle: ver.remoteDir,
                                badge: game.isFreeFireMax ? "FFM" : "FFTH",
                                systemImage: "checkmark.shield.fill",
                                on: appliedIDs.contains("mod.\(ver.id)")
                            ) {
                                toggleMod(ver)
                            }
                        }
                    }
                }
            }
        case .other:
            ForEach(FreeFireRemoteAssetService.otherItems(forPackage: package)) { item in
                actionFeatureRow(
                    id: "other.\(item.id)",
                    title: item.title,
                    subtitle: "Tải file cuối từ OTHER/... → Documents → mở game → xóa sau 15s",
                    badge: game.isFreeFireMax ? "FFM" : "FFTH",
                    systemImage: "person.crop.circle.badge.arrow.right"
                ) {
                    resetGuestAccount(item)
                }
            }
        }
    }

    private func emptyCategory(title: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white.opacity(0.3))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(language == .vietnamese ? "Đang trống" : "Empty")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func actionFeatureRow(
        id: String,
        title: String,
        subtitle: String,
        badge: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        let busy = busyID == id
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(2)
            }
            Spacer()
            if busy {
                ProgressView().tint(.white)
            } else {
                Button(action: {
                    BeuSound.toggle()
                    action()
                }) {
                    Text(language == .vietnamese ? "Thực hiện" : "Run")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color.white))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.50))
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.28))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func remoteFeatureRow(
        id: String,
        title: String,
        subtitle: String,
        badge: String,
        systemImage: String,
        on: Bool,
        onToggle: @escaping () -> Void
    ) -> some View {
        let busy = busyID == id
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }
            Spacer()
            if busy {
                ProgressView().tint(.white)
            } else {
                Toggle("", isOn: Binding(
                    get: { on },
                    set: { _ in
                        BeuSound.toggle()
                        onToggle()
                    }
                ))
                .labelsHidden()
                .tint(Color(red: 0.20, green: 0.84, blue: 0.45))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.50))
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.28))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func refreshApplied() {
        var set = Set<String>()
        for item in FreeFireRemoteAssetService.menuItems(forPackage: package) {
            if FreeFireRemoteAssetService.isMenuApplied(package: package, item: item) {
                set.insert("menu.\(item.id)")
            }
        }
        for item in FreeFireRemoteAssetService.aimItems(forPackage: package) {
            if FreeFireRemoteAssetService.isAimApplied(package: package, item: item) {
                set.insert("aim.\(item.id)")
            }
        }
        for item in FreeFireRemoteAssetService.chamsItems(forPackage: package) {
            if FreeFireRemoteAssetService.isChamsApplied(package: package, item: item) {
                set.insert("chams.\(item.id)")
            }
        }
        for ch in FreeFireRemoteAssetService.modCharacters(forPackage: package) {
            for ver in ch.versions {
                if FreeFireRemoteAssetService.isModVersionApplied(package: package, version: ver) {
                    set.insert("mod.\(ver.id)")
                }
            }
        }
        appliedIDs = set
    }

    private func toggleMenu(_ item: RemoteMenuItem) {
        let id = "menu.\(item.id)"
        let on = appliedIDs.contains(id)
        runWork(id: id, currentlyOn: on) {
            if on {
                try FreeFireRemoteAssetService.restoreMenu(package: package, item: item)
            } else {
                try FreeFireRemoteAssetService.applyMenu(package: package, item: item)
            }
        }
    }

    private func toggleAim(_ item: RemoteAimItem) {
        let id = "aim.\(item.id)"
        let on = appliedIDs.contains(id)
        runWork(id: id, currentlyOn: on) {
            if on {
                try FreeFireRemoteAssetService.restoreAim(package: package, item: item)
            } else {
                try FreeFireRemoteAssetService.applyAim(package: package, item: item)
            }
        }
    }

    private func toggleChams(_ item: RemoteChamsItem) {
        let id = "chams.\(item.id)"
        let on = appliedIDs.contains(id)
        runWork(id: id, currentlyOn: on) {
            if on {
                try FreeFireRemoteAssetService.restoreChams(package: package, item: item)
            } else {
                try FreeFireRemoteAssetService.applyChams(package: package, item: item)
            }
        }
    }

    private func toggleMod(_ ver: RemoteModVersion) {
        let id = "mod.\(ver.id)"
        let on = appliedIDs.contains(id)
        runWork(id: id, currentlyOn: on) {
            if on {
                try FreeFireRemoteAssetService.restoreMod(package: package, version: ver)
            } else {
                try FreeFireRemoteAssetService.applyMod(package: package, version: ver)
            }
        }
    }

    private func resetGuestAccount(_ item: RemoteOtherItem) {
        let id = "other.\(item.id)"
        runWork(id: id, currentlyOn: false) {
            try FreeFireRemoteAssetService.resetGuestAccount(package: package, item: item)
        }
    }

    private func runWork(id: String, currentlyOn: Bool, work: @escaping () throws -> Void) {
        guard busyID == nil else { return }
        errorText = nil
        infoText = nil
        busyID = id
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try work()
                DispatchQueue.main.async {
                    busyID = nil
                    refreshApplied()
                    infoText = currentlyOn
                        ? (language == .vietnamese ? "Đã tắt" : "Disabled")
                        : (language == .vietnamese ? "Đã bật / đã tải" : "Enabled / downloaded")
                }
            } catch {
                DispatchQueue.main.async {
                    busyID = nil
                    refreshApplied()
                    errorText = error.localizedDescription
                }
            }
        }
    }

    private var helpSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    helpBlock(
                        title: "Menu",
                        body: "FFTH = Free Fire, FFM = Free Fire Max. Tải toàn bộ file trong MENU/... (Assembly-CSharp-patch.bytes, localConfig.json, …) vào Documents của container game đang OPEN."
                    )
                    helpBlock(
                        title: "Aim",
                        body: "Bật Aim sẽ tải file cache_res từ repo funcition (AIM/<tên>) và ghi vào Documents/contentcache/compulsory/ios/gameassetbundles của game đang OPEN (Free Fire hoặc Free Fire Max)."
                    )
                    helpBlock(
                        title: "Chams",
                        body: "Bật Chams sẽ tải shader mới nhất trong CHAMS/FFTH hoặc CHAMS/FFM từ repo funcition và ghi vào Documents/contentcache/Optional/ios/gameassetbundles của game đang mở. Tắt Chams sẽ xóa đúng file shader đã ghi."
                    )
                    helpBlock(
                        title: "Other",
                        body: "Reset tài khoản khách sẽ lấy file cuối trong OTHER/FFTH hoặc OTHER/FFM, ghi vào Documents của game đang mở, tự mở game rồi xóa file đó sau 15 giây."
                    )
                    helpBlock(
                        title: "Mods",
                        body: "FFTH = Free Fire, FFM = Free Fire Max. File ghi vào Documents/contentcache/optional/ios/optionalavatarres/gameassetbundles. ALOK / IGNIS có các bản V1, V2…"
                    )
                }
                .padding(20)
            }
            .background(Color(white: 0.08).ignoresSafeArea())
            .navigationTitle(language.text("home.ff.help"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language == .vietnamese ? "Đóng" : "Close") { showHelp = false }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func helpBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Text(body)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}


// MARK: - System UI sounds

enum BeuSound {
    private static var players: [String: AVAudioPlayer] = [:]
    private static var sessionReady = false

    private static func ensureSession() {
        guard !sessionReady else { return }
        sessionReady = true
        let session = AVAudioSession.sharedInstance()
        // ambient: không cắt nhạc nền, không crash nếu session fail
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
    }

    private static func player(named name: String) -> AVAudioPlayer? {
        ensureSession()
        if let existing = players[name] {
            return existing
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav")
                ?? Bundle.main.url(forResource: name, withExtension: "caf") else {
            return nil
        }
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return nil }
        p.prepareToPlay()
        p.volume = 1.0
        players[name] = p
        return p
    }

    private static func playFile(_ name: String) {
        DispatchQueue.main.async {
            guard let p = player(named: name) else { return }
            p.currentTime = 0
            p.play()
        }
    }

    /// Single soft click — tabs, đăng nhập
    static func glass() { playFile("ui_click") }

    /// Menu / icon
    static func soft() { playFile("ui_unclick") }

    /// OPEN
    static func tick() { playFile("ui_double") }

    /// Toggle
    static func toggle() { playFile("ui_unclick") }

    /// Login success — system chime (giữ nguyên)
    static func success() {
        DispatchQueue.main.async {
            AudioServicesPlaySystemSound(1111)
        }
    }

    static func error() {
        DispatchQueue.main.async {
            AudioServicesPlaySystemSound(1073)
        }
    }

    static func click() { glass() }
}
