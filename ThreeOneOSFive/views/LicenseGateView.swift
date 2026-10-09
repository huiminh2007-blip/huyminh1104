import SwiftUI
import AudioToolbox

// MARK: - Login / License Gate (redesigned)

struct LicenseGateView: View {
    @ObservedObject var licenseManager: LicenseManager

    @State private var keyText = ""
    @FocusState private var keyFocused: Bool
    @State private var ringSpin = false

    /// Silver / gunmetal ring (no orange accent).
    private let silver = Color(white: 0.72)
    private let silverSoft = Color(white: 0.55)

    var body: some View {
        ZStack {
            // Solid black underlay — kills gray safe-area bars from parent theme
            Color.black
                .ignoresSafeArea()

            backgroundLayer

            Color.black.opacity(0.38)
                .ignoresSafeArea()

            FloatingParticlesView(count: 58)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                    .frame(maxHeight: 72)

                VStack(spacing: 0) {
                    avatarSection

                    Text("HUYMINH IOS")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(2.0)
                        .foregroundStyle(Color.white.opacity(0.96))
                        .padding(.top, 18)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    darkCard
                        .padding(.top, 26)

                    if let error = licenseManager.errorMessage {
                        Text(error)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.red.opacity(0.92))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.85)
                            .padding(.top, 12)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 0)

                badge
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
        .onAppear { ringSpin = true }
        .onChange(of: licenseManager.isAuthorized) { ok in
            if ok { BeuSound.success() }
        }
        // No auto-focus — keyboard only when user taps the field
    }

    // MARK: - Background (true full-bleed)

    private var backgroundLayer: some View {
        Group {
            if UIImage(named: "LoginBackground") != nil {
                Image("LoginBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.07, blue: 0.10),
                        Color(red: 0.10, green: 0.08, blue: 0.12),
                        Color(red: 0.04, green: 0.05, blue: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Avatar (larger + silver ring)

    private var avatarSection: some View {
        ZStack {
            // Soft silver glow
            Circle()
                .fill(silver.opacity(0.20))
                .frame(width: 136, height: 136)
                .blur(radius: 18)

            // Silver conic ring
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white, location: 0.0),
                            .init(color: silver, location: 0.12),
                            .init(color: silverSoft.opacity(0.25), location: 0.32),
                            .init(color: Color.clear, location: 0.45),
                            .init(color: Color.clear, location: 0.62),
                            .init(color: silver.opacity(0.55), location: 0.78),
                            .init(color: Color.white, location: 1.0)
                        ]),
                        center: .center
                    ),
                    lineWidth: 3.0
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(ringSpin ? 360 : 0))
                .animation(.linear(duration: 5).repeatForever(autoreverses: false), value: ringSpin)

            Group {
                if UIImage(named: "AppAvatar") != nil {
                    Image("AppAvatar")
                        .resizable()
                        .scaledToFill()
                } else if UIImage(named: "AppLogo") != nil {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.white.opacity(0.85))
                        .padding(18)
                        .background(Color(white: 0.12))
                }
            }
            .frame(width: 112, height: 112)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color(white: 0.10), lineWidth: 3)
            )
        }
        .frame(width: 136, height: 136)
    }

    // MARK: - Dark card (key + login) — VANDUYIOS style

    private var darkCard: some View {
        VStack(spacing: 12) {
            keyField
            loginButton
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Key field

    private var keyField: some View {
        HStack(spacing: 10) {
            Image(systemName: "key.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.80))

            TextField("", text: $keyText, prompt: Text("Nhập mã Key")
                .foregroundColor(Color.white.opacity(0.40))
                .font(.system(size: 13))
            )
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .font(.system(size: 13))
            .foregroundStyle(Color.white.opacity(0.95))
            .tint(silver)
            .focused($keyFocused)
            .submitLabel(.done)
            .onSubmit { activate() }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Login button

    private var loginButton: some View {
        Button {
            BeuSound.glass()
            activate()
        } label: {
            Group {
                if licenseManager.isChecking {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.9)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.to.line")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Đăng nhập")
                            .font(.system(size: 13.5, weight: .bold))
                    }
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
            )
        }
        .buttonStyle(.plain)
        .disabled(licenseManager.isChecking || keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(
            (licenseManager.isChecking || keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            ? 0.55 : 1.0
        )
    }

    // MARK: - Bottom badge (with border pill)

    private var badge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(silver)
                .frame(width: 5, height: 5)

            Text("WELCOME TO PROXY IPA HUYMINH")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(silver)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.45))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions (logic unchanged)

    private func activate() {
        keyFocused = false
        Task { await licenseManager.activate(keyText) }
    }
}

// MARK: - Floating particles

private struct FloatingParticlesView: View {
    let count: Int
    private let particles: [ParticleSeed]

    init(count: Int) {
        self.count = count
        var rng = SeededGenerator(seed: 0xBE1411)
        self.particles = (0..<count).map { _ in
            ParticleSeed(
                xNorm: Double.random(in: 0...1, using: &rng),
                yNorm: Double.random(in: 0...1, using: &rng),
                radius: CGFloat.random(in: 1.0...2.6, using: &rng),
                opacity: Double.random(in: 0.12...0.36, using: &rng),
                vx: Double.random(in: -0.016...0.016, using: &rng),
                vy: Double.random(in: -0.013...0.013, using: &rng)
            )
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for p in particles {
                    var x = p.xNorm + p.vx * t
                    var y = p.yNorm + p.vy * t
                    x = x.truncatingRemainder(dividingBy: 1.0)
                    if x < 0 { x += 1.0 }
                    y = y.truncatingRemainder(dividingBy: 1.0)
                    if y < 0 { y += 1.0 }

                    let pt = CGPoint(x: x * size.width, y: y * size.height)
                    let rect = CGRect(
                        x: pt.x - p.radius,
                        y: pt.y - p.radius,
                        width: p.radius * 2,
                        height: p.radius * 2
                    )
                    context.opacity = p.opacity
                    context.fill(Path(ellipseIn: rect), with: .color(.white))
                }
            }
        }
    }
}

private struct ParticleSeed {
    let xNorm: Double
    let yNorm: Double
    let radius: CGFloat
    let opacity: Double
    let vx: Double
    let vy: Double
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x853c49e6748fea9b : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}
