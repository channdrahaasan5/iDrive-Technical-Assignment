import SwiftUI

struct ActiveRideView: View {
    @StateObject var vm: ActiveRideViewModel
    @AppStorage("is_online") private var isOnline: Bool = true
    @State private var showApiError: Bool = false
    // Closure to dismiss this view and return to dashboard
    var onClose: (() -> Void)? = nil
    @State private var showFlushAlert: Bool = false
    @State private var awaitingFlush: Bool = false
    @State private var showOfflineAlert: Bool = false

    var body: some View {
        VStack {
            let passenger = (vm.ride.payload?["passenger"]).flatMap { value -> String? in
                switch value {
                case .string(let s): return s
                case .int(let i): return String(i)
                case .double(let d): return String(d)
                case .bool(let b): return b ? "true" : "false"
                default: return nil
                }
            } ?? vm.ride.id
            Text("Ride with \(passenger)")
                .font(.title)
            Text("Status: \(vm.ride.status)")
            if vm.isWaitingForStart {
                HStack {
                    ProgressView()
                    Text("Waiting for server to start the ride...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            HStack {
                if vm.isSending {
                    if awaitingFlush {
                        ProgressView("Uploading logs...").scaleEffect(0.9)
                    } else {
                        Button("Complete Ride") {
                            // if there are queued logs, ask to flush before completing
                            let pending = LocationQueueManager.shared.pendingCount()
                            if pending > 0 {
                                showFlushAlert = true
                            } else {
                                vm.completeRide()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    Button("Start Sending Locations") {
                        vm.requestPermissionAndStart()
                    }
                }
                Spacer()
                Button("Back to Dashboard") {
                    onClose?()
                }
                .buttonStyle(.bordered)
            }
            .alert("Upload pending logs?", isPresented: $showFlushAlert) {
                Button("Upload & Complete") {
                    // ensure online
                    let online = UserDefaults.standard.bool(forKey: "is_online")
                    if !online {
                        showOfflineAlert = true
                        return
                    }
                    awaitingFlush = true
                    // start processing
                    LocationQueueManager.shared.startProcessingIfNeeded()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("There are unsent location logs. Upload them now before completing the ride?")
            }
            .alert("You are offline", isPresented: $showOfflineAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Go online to upload queued logs before completing the ride.")
            }
            .onReceive(NotificationCenter.default.publisher(for: .locationQueueUpdated)) { _ in
                if awaitingFlush {
                    let pending = LocationQueueManager.shared.pendingCount()
                    if pending == 0 {
                        awaitingFlush = false
                        vm.completeRide()
                    }
                }
            }
            List {
                ForEach(vm.ride.locations ?? [], id: \.ts) { loc in
                    VStack(alignment: .leading) {
                        Text("lat: \(loc.lat), lng: \(loc.lng)")
                        if let ts = loc.ts { Text("ts: \(ts)") }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            // auto-start sending when ride already STARTED and app is online
            if vm.ride.status == "STARTED" && isOnline && !vm.isSending {
                vm.requestPermissionAndStart()
            }
            print("payload:", vm.ride.payload as Any)
            print("payload[\"passenger\"]:", vm.ride.payload?["passenger"] as Any)
            print("payload type:", type(of: vm.ride.payload))
        }
        .onChange(of: vm.errorMessage) { _ in
            showApiError = vm.errorMessage != nil
        }
        .alert("API Error", isPresented: $showApiError) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "Unknown error")
        }
    }
}

struct ActiveRideView_Previews: PreviewProvider {
    static var previews: some View {
        let r = Ride(id: "r1", status: "STARTED", driverId: "d1", payload: nil, createdAt: Int(Date().timeIntervalSince1970), locations: [])
        ActiveRideView(vm: ActiveRideViewModel(ride: r, token: "t"))
    }
}

