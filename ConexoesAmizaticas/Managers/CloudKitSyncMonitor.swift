//
//  CloudKitSyncMonitor.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 18/06/26.
//

import SwiftUI
import CoreData

/// Tracks the CloudKit mirroring lifecycle so the UI can wait for the first import to land before
/// deciding between the main app and onboarding — avoiding the onboarding flash and showing data
/// (including friend photos) only once it has actually synced down.
@Observable
final class CloudKitSyncMonitor {
    /// `true` once the initial CloudKit import has finished, or once setup failed (e.g. no iCloud account),
    /// meaning there is nothing left to wait for and the launch decision can be made.
    private(set) var hasFinishedInitialSync = false

    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                  event.endDate != nil else { return }

            switch event.type {
            case .import:
                self?.hasFinishedInitialSync = true
            case .setup where event.error != nil:
                // Setup failed (commonly no signed-in iCloud account): no import will ever come.
                self?.hasFinishedInitialSync = true
            default:
                break
            }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }
}
