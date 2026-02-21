//
//  iDriveApp.swift
//  iDrive
//
//  Created by Aptiway on 18/02/26.
//

import SwiftUI

@main
struct iDriveApp: App {
    let persistenceController = PersistenceController.shared
    @State private var savedToken: String? = KeychainHelper.shared.read("api_token")
    @State private var savedActiveRideId: String? = UserDefaults.standard.string(forKey: "active_ride_id")

    var body: some Scene {
        WindowGroup {
            ContentView(initialToken: savedToken, initialActiveRideId: savedActiveRideId)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // When app comes to foreground, ensure queued locations start uploading if online.
                    let online = UserDefaults.standard.bool(forKey: "is_online")
                    if online {
                        LocationQueueManager.shared.startProcessingIfNeeded()
                        // if we have an active ride and a token, resume periodic sending
                        if let rid = UserDefaults.standard.string(forKey: "active_ride_id"),
                           let token = KeychainHelper.shared.read("api_token") {
                            LocationSendService.shared.start(rideId: rid, token: token)
                        }
                    }
                }
        }
    }
}
