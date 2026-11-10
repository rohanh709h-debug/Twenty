import UserNotifications
import Foundation

/// Shows banners/sounds even while the app is open.
final class NotifDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotifDelegate()
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

enum Notifier {
    /// Schedules the next 60 alerts (iOS keeps at most 64 pending per app).
    static func schedule(startedAt: Double, work: TimeInterval, rest: TimeInterval,
                         metric: Bool, sound: Bool) {
        let c = UNUserNotificationCenter.current()
        c.removeAllPendingNotificationRequests()
        let cycle = work + rest
        let t0 = Date().timeIntervalSince1970
        let dist = metric ? "6 meters" : "20 feet"
        var count = 0, k = 0
        while count < 60 && k < 4000 {
            let base = startedAt + Double(k) * cycle
            let lookIn = base + work - t0
            let backIn = base + cycle - t0
            if lookIn > 1 {
                add("w\(k)", lookIn, "Look away",
                    "Rest your eyes: look at something \(dist) away for \(Int(rest)) seconds.", sound)
                count += 1
            }
            if backIn > 1 {
                add("b\(k)", backIn, "Break over", "Eyes rested. Back to focus.", sound)
                count += 1
            }
            k += 1
        }
    }

    static func test(sound: Bool) {
        add("test", 5, "Look away", "This is a test alert. Your notifications work.", sound)
    }

    private static func add(_ id: String, _ after: TimeInterval, _ title: String,
                            _ body: String, _ sound: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound ? .default : nil
        if let a = logoAttachment() { content.attachments = [a] }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, after), repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// The logo appears as a thumbnail on the notification (the app icon shows on the left).
    private static func logoAttachment() -> UNNotificationAttachment? {
        guard let src = Bundle.main.url(forResource: "logo", withExtension: "png") else { return nil }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        try? FileManager.default.copyItem(at: src, to: tmp)
        return try? UNNotificationAttachment(identifier: "logo", url: tmp, options: nil)
    }
}
