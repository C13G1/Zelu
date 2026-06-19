//
//  NotificationManager.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 27/05/26.
//

import Foundation
import UserNotifications
import UIKit
/// Schedules and cancels local reminders that nudge users to honor the meeting goals (`Meta`) attached to each connection.
///
/// `NotificationManager` is intentionally stateless: it works exclusively with the OS notification center and derives
/// every reminder from the live `Connection` payload, so it can be safely called from any layer of the app.
struct NotificationManager {

    /// Requests authorization to display alerts, sounds and badges. Should be called once at app startup.
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Schedules a single reminder for a given connection, replacing any previous one for the same friend.
    ///
    /// The reminder fires at 80% of the meeting interval, so the user still has time to plan the encounter before the goal expires.
    /// - Parameter connection: The `Connection` whose `metaManager` and `lastMet` drive the reminder timing.
    static func scheduleMetaReminder(for connection: Connection) {
        let id = "meta_\(connection.id.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])

        guard let meta = connection.metaManager?.meta else { return }
        guard meta != .nenhuma, meta.days > 0 else { return }

        let reference = connection.lastMet ?? connection.firstConnection
        let totalInterval = TimeInterval(meta.days) * 86400
        let notifyDate = reference.addingTimeInterval(totalInterval * 0.8)
        let deadlineDate = reference.addingTimeInterval(totalInterval)
        let now = Date()

        guard deadlineDate > now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Tá na hora de marcar um encontro!"
        content.body = "Você prometeu se encontrar com \(connection.friend?.name ?? "") \(meta.displayText). O prazo está chegando!"
        content.sound = .default

        let trigger: UNNotificationTrigger?
        if notifyDate <= now {
            trigger = nil
        } else {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notifyDate)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// Removes any pending meta reminder linked to the given connection.
    static func cancelMetaReminder(for connection: Connection) {
        let id = "meta_\(connection.id.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
    
    /// Removes all Notifications.
    static func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UIApplication.shared.unregisterForRemoteNotifications()
    }

    /// Re-schedules reminders for every active connection, used after relaunch or major state changes.
    static func rescheduleAll(connections: [Connection]) {
        for connection in connections {
            scheduleMetaReminder(for: connection)
        }
    }
}
