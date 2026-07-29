import SwiftUI
import SwiftData
import CoreData
import Combine

/// Monitors iCloud sync status via NSPersistentCloudKitContainer events
@Observable
final class SyncMonitor {
    enum Status: Equatable {
        case upToDate
        case syncing
        case imported(Date)
        case exported(Date)
        case error(String)
    }

    private(set) var status: Status = .upToDate
    private(set) var lastSyncDate: Date?
    private var pendingEvents = 0

    init() {
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.handleEvent(note)
        }
    }

    private func handleEvent(_ note: Notification) {
        guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }

        let isFinished = event.endDate != nil

        if !isFinished {
            // Event started — increment pending count
            pendingEvents += 1
            status = .syncing
        } else {
            // Event finished
            pendingEvents = max(0, pendingEvents - 1)

            if event.succeeded {
                lastSyncDate = event.endDate
                if event.type == .import {
                    status = pendingEvents > 0 ? .syncing : .imported(event.endDate ?? Date())
                    // Post notification so views can react to remote changes
                    NotificationCenter.default.post(name: .cloudKitDataImported, object: nil)
                } else if event.type == .export {
                    status = pendingEvents > 0 ? .syncing : .exported(event.endDate ?? Date())
                } else {
                    status = pendingEvents > 0 ? .syncing : .upToDate
                }
            } else {
                let message = (event.error as NSError?)?.localizedDescription ?? "Unknown sync error"
                status = .error(message)
                print("[SyncMonitor] Sync failed: \(message)")
            }
        }
    }
}

extension Notification.Name {
    static let cloudKitDataImported = Notification.Name("InklingCloudKitDataImported")
}
