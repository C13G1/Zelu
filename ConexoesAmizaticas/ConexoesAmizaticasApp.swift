//
//  ConexoesAmizaticasApp.swift
//  ConexoesAmizaticas
//
//  Created by Enzo Ferroni on 14/05/26.
//

import SwiftUI
import SwiftData
import Aptabase

@main
struct ConexoesAmizaticasApp: App {
    @AppStorage("isNotificationAllowed") var isNotificationAllowed: Bool = false
    
    init() {
        Aptabase.shared.initialize(appKey: "A-US-8865447669")
        Aptabase.shared.trackEvent("app_started")
        
        if isNotificationAllowed {
            NotificationManager.requestPermission()
            ProximityNotifier.shared.start()
        }
    }
    
    var sharedModelContainer: ModelContainer = {
        let modelConfiguration = ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: AppSchema.schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
