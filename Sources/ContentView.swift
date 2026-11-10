import SwiftUI
import UserNotifications

private typealias Phase = (isRest: Bool, remaining: TimeInterval, total: TimeInterval)

struct ContentView: View {
    @AppStorage("startedAt") private var startedAt: Double = 0   // 0 = stopped
    @AppStorage("workMin") private var workMin = 20
    @AppStorage("restSec") private var restSec = 20
    @AppStorage("accent") private var accentRaw = Accent.cyan.rawValue
    @AppStorage("metric") private var metric = false
    @AppStorage("sound") private var soundOn = true
    @AppStorage("haptics") private var hapticsOn = true
    @AppStorage("keepAwake") private var keepAwake = false
    @AppStorage("totalBreaks") private var totalBreaks = 0

    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date()
    @State private var wasRest = false
    @State private var notifDenied = false
    @State private var showSettings = false
    private let tick = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    // MARK: derived state
    private var accent: Color { (Accent(rawValue: accentRaw) ?? .cyan).color }
    private var running: Bool { startedAt > 0 }
    private var work: TimeInterval { Double(workMin) * 60 }
    private var rest: TimeInterval { Double(restSec) }
    private var cycle: TimeInterval { work + rest }
    private var dist: String { metric ? "6 m" : "20 ft" }
    private var distSpoken: String { metric ? "6 meters" : "20 feet" }
    private var elapsed: TimeInterval { running ? max(0, now.timeIntervalSince1970 - startedAt) : 0 }
    private var sessionBreaks: Int { running ? Int(elapsed / cycle) : 0 }

    private var phase: Phase {
        guard running else { return (false, work, work) }
        let pos = elapsed.truncatingRemainder(dividingBy: cycle)
        return pos < work ? (false, work - pos, work) : (true, cycle - pos, rest)
    }

    // MARK: body
    var body: some View {
        let p = phase
        let tint = (running && p.isRest) ? restColor : accent
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height * 1.15
            let ring = max(220, min(wide ? geo.size.height * 0.62 : geo.size.width * 0.72, 460))
            ScrollView {
                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 16)
                    if wide {
                        HStack(spacing: 64) {
                            ringSection(p, tint, ring)
                            controls(p, tint).frame(maxWidth: 420)
                        }
                    } else {
                        VStack(spacing: 32) {
                            ringSection(p, tint, ring)
                            controls(p, tint).frame(maxWidth: 520)
                        }
                    }
                    Spacer(minLength: 16)
                }
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
                .padding(.horizontal, 24)
            }
        }
        .background(background(tint).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .tint(accent)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onAppear {
            UNUserNotificationCenter.current().delegate = NotifDelegate.shared
            refreshAuth()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                refreshAuth()
                if running { schedule() }   // top up the 64-notification window
            }
        }
        .onChange(of: metric) { _ in if running { schedule() } }
        .onChange(of: soundOn) { _ in if running { schedule() } }
        .onReceive(tick) { date in
            now = date
            UIApplication.shared.isIdleTimerDisabled = keepAwake && running
            let r = phase.isRest
            if running && r != wasRest && hapticsOn {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
            wasRest = r
        }
    }

    // MARK: pieces
    private var header: some View {
        HStack(spacing: 12) {
            if let img = Brand.logo {
                Image(uiImage: img)
                    .resizable()
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1))
            }
            Text("20-20-20")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .tracking(1)
            Spacer()
            Button { showSettings = true; tap() } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .buttonStyle(Raised3DStyle(face: keyFace, radius: 14, depth: 4))
            .frame(width: 48, height: 52)
        }
        .padding(.top, 8)
    }

    private func ringSection(_ p: Phase, _ tint: Color, _ size: CGFloat) -> some View {
        VStack(spacing: 22) {
            Text(running ? (p.isRest ? "LOOK AWAY" : "FOCUS") : "READY")
                .font(.system(size: 13, weight: .semibold))
                .tracking(5)
                .foregroundStyle(tint)

            ZStack {
                Circle().fill(Color(red: 0.05, green: 0.05, blue: 0.06))
                Circle().stroke(Color.white.opacity(0.07), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: running ? 1 - p.remaining / p.total : 0)
                    .stroke(AngularGradient(colors: [tint.shade(0.55), tint, tint.shade(1.2)], center: .center),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: tint.opacity(0.6), radius: 10)
                    .animation(.linear(duration: 0.25), value: p.remaining)
                VStack(spacing: 6) {
                    Text(format(p.remaining))
                        .font(.system(size: size * 0.23, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                    Text(running ? (p.isRest ? "look \(dist) away" : "until next break")
                                 : "\(workMin) min focus")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: size, height: size)

            Text(running && p.isRest ? "Focus on something \(distSpoken) away"
                                     : "\(workMin) min · \(dist) · \(restSec) sec")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    private func controls(_ p: Phase, _ tint: Color) -> some View {
        VStack(spacing: 18) {
            if !running { durationCard }
            statsRow(p)
            if notifDenied {
                Text("Notifications are off. Enable them in Settings › 20-20-20.")
                    .font(.system(size: 12))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Button(action: toggle) {
                HStack(spacing: 10) {
                    Image(systemName: running ? "stop.fill" : "play.fill")
                    Text(running ? "Stop" : "Start")
                }
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(running ? Color.white : Color.black)
            }
            .buttonStyle(Raised3DStyle(face: running ? Color(red: 0.88, green: 0.22, blue: 0.27) : tint,
                                       radius: 22, depth: 7))
            .frame(height: 70)
        }
    }

    private var durationCard: some View {
        VStack(spacing: 14) {
            stepRow("Focus", "\(workMin) min",
                    minus: { workMin = max(1, workMin - 1) },
                    plus: { workMin = min(120, workMin + 1) })
            stepRow("Break", "\(restSec) sec",
                    minus: { restSec = max(5, restSec - 5) },
                    plus: { restSec = min(300, restSec + 5) })
            HStack(spacing: 8) {
                ForEach([15, 20, 30, 45], id: \.self) { m in
                    Button { workMin = m; tap() } label: {
                        Text("\(m)m")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(workMin == m ? Color.black : Color.white)
                    }
                    .buttonStyle(Raised3DStyle(face: workMin == m ? accent : keyFace, radius: 12, depth: 3))
                    .frame(height: 40)
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func stepRow(_ title: String, _ value: String,
                         minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .monospacedDigit()
            roundKey("minus", minus)
            roundKey("plus", plus)
        }
    }

    private func roundKey(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button { action(); tap() } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(accent)
        }
        .buttonStyle(Raised3DStyle(face: keyFace, radius: 12, depth: 4))
        .frame(width: 46, height: 50)
    }

    private func statsRow(_ p: Phase) -> some View {
        HStack(spacing: 10) {
            stat("Session", Text(running ? "\(sessionBreaks)" : "–"))
            stat("Total", Text("\(totalBreaks + sessionBreaks)"))
            stat("Next alert",
                 running ? Text(Date(timeIntervalSince1970: now.timeIntervalSince1970 + p.remaining), style: .time)
                         : Text("–"))
        }
    }

    private func stat(_ title: String, _ value: Text) -> some View {
        VStack(spacing: 4) {
            value
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(1.5)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func background(_ tint: Color) -> some View {
        ZStack {
            Color.black
            RadialGradient(colors: [tint.opacity(0.22), Color.clear],
                           center: .top, startRadius: 0, endRadius: 560)
        }
    }

    // MARK: actions
    private func format(_ t: TimeInterval) -> String {
        let s = Int(ceil(t))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    private func tap() {
        if hapticsOn { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }

    private func refreshAuth() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            DispatchQueue.main.async { notifDenied = (s.authorizationStatus == .denied) }
        }
    }

    private func schedule() {
        Notifier.schedule(startedAt: startedAt, work: work, rest: rest, metric: metric, sound: soundOn)
    }

    private func toggle() {
        now = Date()
        if running {
            totalBreaks += sessionBreaks
            startedAt = 0
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        } else {
            startedAt = Date().timeIntervalSince1970
            wasRest = false
            schedule()
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
                DispatchQueue.main.async { refreshAuth() }
            }
        }
        tap()
    }
}
