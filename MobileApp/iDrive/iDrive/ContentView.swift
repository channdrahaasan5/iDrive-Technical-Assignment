//
//  ContentView.swift
//  iDrive
//
//  Created by Aptiway on 18/02/26.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Item>

    private var initialToken: String?
    private var initialActiveRideId: String?
    @State private var token: String?
    @State private var selectedRide: Ride?
    @State private var activeRideToShow: Ride?
    @State private var showActive = false
    @State private var refreshOnDismiss: Bool = true
    @State private var showLogoutBlockedAlert: Bool = false
    @State private var isCheckingActiveRide: Bool = false

    init(initialToken: String? = nil) {
        self.initialToken = initialToken
        _token = State(initialValue: initialToken)
    }

    init(initialToken: String? = nil, initialActiveRideId: String? = nil) {
        self.initialToken = initialToken
        self.initialActiveRideId = initialActiveRideId
        _token = State(initialValue: initialToken)
    }

    var body: some View {
        Group {
            if token == nil {
                LoginView() { tok in
                    self.token = tok
                }
            } else if let tok = token {
                if showActive, let ride = activeRideToShow {
                    ActiveRideView(vm: ActiveRideViewModel(ride: ride, token: tok)) {
                        // onClose -> go back to dashboard (keep active_ride_id so sending/restore continues)
                        self.activeRideToShow = nil
                        self.showActive = false
                    }
                } else if isCheckingActiveRide {
                    VStack { ProgressView("Checking active ride...").padding() }
                } else {
                    DashboardView(vm: DashboardViewModel(token: tok), token: tok, onSelect: { ride, refresh in
                        self.selectedRide = ride
                        self.refreshOnDismiss = refresh
                    }, onLogout: {
                        let pending = LocationQueueManager.shared.pendingCount()
                        if pending > 0 {
                            // prevent logout if there are unsent logs
                            self.showLogoutBlockedAlert = true
                        } else {
                            KeychainHelper.shared.delete("api_token")
                            self.token = nil
                        }
                    }, onStart: { ride in
                        // navigate to active ride view when dashboard start succeeds
                        self.activeRideToShow = ride
                        self.showActive = true
                        UserDefaults.standard.set(ride.id, forKey: "active_ride_id")
                    })
                }
            }
        }
        .onAppear {
            // If we have an initial active ride id, fetch it and show active view
            if let id = initialActiveRideId, let tok = token {
                isCheckingActiveRide = true
                APIClient.shared.getRide(rideId: id, token: tok) { result in
                    DispatchQueue.main.async {
                        defer { self.isCheckingActiveRide = false }
                        switch result {
                        case .success(let r):
                            if r.status == "STARTED" {
                                self.activeRideToShow = r
                                self.showActive = true
                            }
                        case .failure:
                            break
                        }
                    }
                }
            }
        }
        // Present RideDetail as a sheet when a ride is selected
        .sheet(item: $selectedRide) { ride in
            if let tok = token {
                RideDetailView(vm: RideViewModel(ride: ride, token: tok), refreshOnDismiss: refreshOnDismiss) { r in
                    // when RideDetail signals active ride, dismiss sheet and show ActiveRideView
                    self.selectedRide = nil
                    self.activeRideToShow = r
                    self.showActive = true
                }
            } else {
                // fallback: empty view
                Text("No token")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("rideUpdated"))) { not in
            guard let r = not.object as? Ride else { return }
            if let active = activeRideToShow, r.id == active.id && r.status == "COMPLETED" {
                // ride completed -> go back to dashboard
                self.activeRideToShow = nil
                self.showActive = false
                UserDefaults.standard.removeObject(forKey: "active_ride_id")
                // refresh requests
                NotificationCenter.default.post(name: Notification.Name("refreshRequested"), object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .apiUnauthorized)) { _ in
            // clear token and force user back to login
            KeychainHelper.shared.delete("api_token")
            self.token = nil
            UserDefaults.standard.removeObject(forKey: "active_ride_id")
        }
        .alert("Cannot logout", isPresented: $showLogoutBlockedAlert) {
            Button("OK", role: .cancel) { showLogoutBlockedAlert = false }
        } message: {
            Text("There are unsent location logs. Please go online and upload them before logging out.")
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
