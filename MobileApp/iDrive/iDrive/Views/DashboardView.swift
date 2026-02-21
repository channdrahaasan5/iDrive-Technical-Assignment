import SwiftUI

struct DashboardView: View {
    @StateObject var vm: DashboardViewModel
    var token: String
    var onSelect: (Ride, Bool) -> Void
    var onLogout: () -> Void
    var onStart: (Ride) -> Void
    @State private var showLocationAlert: Bool = false
    @State private var pendingRide: Ride? = nil
    @ObservedObject private var locMgr = LocationManager.shared
    @State private var showSettingsAlert: Bool = false
    @AppStorage("is_online") private var isOnline: Bool = true
    @State private var showApiError: Bool = false
    @State private var showQueueSheet: Bool = false
    @State private var dashboardTab: String = UserDefaults.standard.string(forKey: "dashboard_tab") ?? "requested"

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                HStack {
                    Picker("", selection: $dashboardTab) {
                        Text("Requested").tag("requested")
                        Text("Completed").tag("completed")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .onChange(of: dashboardTab) { new in
                        UserDefaults.standard.set(new, forKey: "dashboard_tab")
                        vm.fetch(status: new)
                    }
                }
                let ridesToShow = dashboardTab == "completed" ? vm.completedRides : vm.requestedRides
            if let active = vm.activeRide {
                    // Requested rides take the upper portion
                List(ridesToShow) { ride in
                        Button(action: {
                            // check location permission before navigating to ride detail
                            let status = locMgr.authorizationStatus
                            if status == .authorizedWhenInUse || status == .authorizedAlways {
                                onSelect(ride, true)
                            } else {
                                // ask user to enable location
                                pendingRide = ride
                                showLocationAlert = true
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Ride \(ride.id)").font(.headline)
                                    if let p = ride.payload, case let .string(name)? = p["passengerName"] {
                                        Text(name).font(.subheadline).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text(ride.status).font(.caption).foregroundColor(.blue)
                            }
                            .padding(.vertical, 6)
                        }
                        .disabled(vm.hasActiveRide)
                    }
                    .frame(maxHeight: .infinity)

                    // Active ride card at bottom
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Active Ride").font(.headline)
                                Text("Ride \(active.id)").font(.title2).bold()
                                Text("Status: \(active.status)").font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        HStack {
                                if active.status == "ACCEPTED" {
                                Button(action: {
                                    vm.startActive { r in
                                        if let rr = r {
                                            onStart(rr)
                                        }
                                    }
                                }) {
                                    Text("Start").frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(vm.isLoading)

                                Button(action: { vm.cancelActive() }) {
                                    Text("Cancel").frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                                .disabled(vm.isLoading)
                        } else if active.status == "STARTED" {
                            Button(action: {
                                // navigate to ActiveRideView
                                onStart(active)
                            }) {
                                Text("On Going ride").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(vm.isLoading)
                        }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 6)
                    .padding()
                    .frame(maxHeight: 220)
                } else {
                    // No active ride — full screen requested rides
                List(ridesToShow) { ride in
                        Button(action: {
                            let status = locMgr.authorizationStatus
                            if status == .authorizedWhenInUse || status == .authorizedAlways {
                                onSelect(ride, false)
                            } else {
                                pendingRide = ride
                                showLocationAlert = true
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Ride \(ride.id)").font(.headline)
                                    if let p = ride.payload, case let .string(name)? = p["passengerName"] {
                                        Text(name).font(.subheadline).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text(ride.status).font(.caption).foregroundColor(.blue)
                            }
                            .padding(.vertical, 6)
                        }
                        .disabled(vm.hasActiveRide)
                    }
                }
            }
            .navigationTitle("iDrive Rides")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Logout") { onLogout() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if vm.pendingQueueCount > 0 {
                        Button(action: { showQueueSheet = true }) {
                            Text("Queued: \(vm.pendingQueueCount)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.trailing, 6)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if vm.isLoading {
                        ProgressView()
                    } else {
                        Button("Refresh") { vm.fetchRequested() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle(isOn: $isOnline) {
                           Text(isOnline ? "Online" : "Offline")
                       }
                       .toggleStyle(SwitchToggleStyle(tint: .green))
                }
            }
            .onAppear {
                // check permission on dashboard load
                let status = locMgr.authorizationStatus
                if status == .denied || status == .restricted {
                    showSettingsAlert = true
                } else if status == .notDetermined {
                    // optionally request permission proactively
                    locMgr.requestWhenInUsePermission()
                }
                // start processing queued locations if online
                if isOnline {
                    LocationQueueManager.shared.startProcessingIfNeeded()
                }
            }
            .onChange(of: isOnline) { new in
                if new {
                    LocationQueueManager.shared.startProcessingIfNeeded()
                } else {
                    LocationQueueManager.shared.stopProcessing()
                }
            }
            .alert("Location permission required", isPresented: $showSettingsAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enable location access in Settings so you can accept and start rides.")
            }
        }
        // Alert to prompt user to open Settings for location permission
        .alert("Location permission required", isPresented: $showLocationAlert, presenting: pendingRide) { ride in
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { pendingRide = nil }
        } message: { _ in
            Text("This app needs location permission to accept/start rides. Please enable location access in Settings.")
        }
        .onChange(of: vm.errorMessage) { _ in
            showApiError = vm.errorMessage != nil
        }
        .alert("API Error", isPresented: $showApiError) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "Unknown error")
        }
        .onAppear { vm.fetchRequested() }
        .sheet(isPresented: $showQueueSheet) {
            LocationQueueView().environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        }
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView(vm: DashboardViewModel(token: "token"), token: "token", onSelect: { _, _ in }, onLogout: { }, onStart: { _ in })
    }
}

