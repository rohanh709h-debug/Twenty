import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("accent") private var accentRaw = Accent.cyan.rawValue
    @AppStorage("metric") private var metric = false
    @AppStorage("sound") private var soundOn = true
    @AppStorage("haptics") private var hapticsOn = true
    @AppStorage("keepAwake") private var keepAwake = false
    @AppStorage("totalBreaks") private var totalBreaks = 0

    private var accent: Color { (Accent(rawValue: accentRaw) ?? .cyan).color }

    var body: some View {
        NavigationStack {
            Form {
                Section("Accent colour") {
                    HStack(spacing: 14) {
                        ForEach(Accent.allCases) { a in
                            Button { accentRaw = a.rawValue } label: {
                                Circle()
                                    .fill(LinearGradient(colors: [a.color.shade(1.15), a.color.shade(0.75)],
                                                         startPoint: .top, endPoint: .bottom))
                                    .frame(width: 36, height: 36)
                                    .overlay(Circle().stroke(Color.white, lineWidth: accentRaw == a.rawValue ? 3 : 0))
                                    .shadow(color: a.color.opacity(0.5), radius: 6, y: 3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }

                Section("Distance") {
                    Picker("Unit", selection: $metric) {
                        Text("Feet (20 ft)").tag(false)
                        Text("Metres (6 m)").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Alerts") {
                    Toggle("Sound", isOn: $soundOn)
                    Toggle("Haptics", isOn: $hapticsOn)
                    Button("Send test alert (5 sec)") {
                        UNUserNotificationCenter.current()
                            .requestAuthorization(options: [.alert, .sound]) { granted, _ in
                                if granted { Notifier.test(sound: soundOn) }
                            }
                    }
                }

                Section("Display") {
                    Toggle("Keep screen on while running", isOn: $keepAwake)
                }

                Section("Stats") {
                    LabeledContent("Total breaks taken", value: "\(totalBreaks)")
                    Button("Reset stats", role: .destructive) { totalBreaks = 0 }
                }

                Section("About") {
                    Text("The 20-20-20 rule: every 20 minutes, look at something 20 feet (6 m) away for 20 seconds. Alerts are scheduled on your device and work with the app closed. Open the app now and then to refresh the schedule.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
        .tint(accent)
    }
}
