//
//  CloudKitReset.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 18/06/26.
//

import CloudKit

/// Server-side wipe for account deletion.
///
/// Deleting the local SwiftData rows only *queues* matching deletions for CloudKit; the export is async
/// and best-effort, so removing the app before it finishes leaves the records on the server and a reinstall
/// imports the "deleted" profile back. Dropping the whole mirror zone removes everything in one awaitable
/// network call, so the account cannot come back. The container recreates an empty zone on the next export.
enum CloudKitReset {
    // Mirrors the identifier configured on the ModelContainer in `ConexoesAmizaticasApp`.
    private static let containerID = "iCloud.com.AppleDeveloperAcademyMackenzie.ConexoesAmizaticas"
    // Fixed zone NSPersistentCloudKitContainer mirrors every model into, in the private database.
    private static let zoneName = "com.apple.coredata.cloudkit.zone"

    /// Best-effort deletion of the private mirror zone. Never throws: with no iCloud account, offline, or
    /// an already-missing zone there is nothing left to wipe, and the local store has already been cleared.
    static func wipePrivateZone() async {
        let database = CKContainer(identifier: containerID).privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        do {
            _ = try await database.modifyRecordZones(saving: [], deleting: [zoneID])
        } catch {
            print("CloudKit zone wipe failed: \(error)")
        }
    }
}
