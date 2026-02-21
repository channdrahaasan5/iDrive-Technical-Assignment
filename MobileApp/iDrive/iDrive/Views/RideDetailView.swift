import SwiftUI

struct RideDetailView: View {
    @StateObject var vm: RideViewModel
    var onActive: (Ride) -> Void
    var refreshOnDismiss: Bool = true
    @ObservedObject private var locMgr = LocationManager.shared
    @State private var pendingAccept: Bool = false
    @State private var showLocationAlert: Bool = false
    @State private var showWaitingForFix: Bool = false
    @State private var pendingQueueCount: Int = LocationQueueManager.shared.pendingCount()
    @State private var showApiError: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            let passenger = (vm.ride.payload?["passenger"]).flatMap { value -> String? in
                switch value {
                case .string(let s): return s
                case .int(let i): return String(i)
                case .double(let d): return String(d)
                case .bool(let b): return b ? "true" : "false"
                default: return nil
                }
            } ?? vm.ride.id
            Text("Ride \(vm.ride.id)").font(.title)
            Text("Passenger: \(passenger)")
            Text("Status: \(vm.ride.status)")
            if let payload = vm.ride.payload, case let .string(name)? = payload["passengerName"] {
                Text("Passenger: \(name)")
            }
            HStack(spacing: 12) {
                HStack {
                    Button("Accept") {
                        handleAcceptTap()
                    }
                    .disabled(vm.ride.status != "REQUESTED" || vm.isLoading || pendingQueueCount > 0)
                    if vm.isLoading && vm.ride.status == "REQUESTED" {
                        ProgressView().scaleEffect(0.6)
                    }
                }
                if pendingQueueCount > 0 {
                    Text("Please upload queued location logs before accepting a new ride.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                HStack {
                    Button("Start") { vm.start() }
                        .disabled(vm.ride.status != "ACCEPTED" || vm.isLoading)
                    if vm.isLoading && vm.ride.status == "ACCEPTED" {
                        ProgressView().scaleEffect(0.6)
                    }
                }

                HStack {
                    Button("Complete") { vm.complete() }
                        .disabled(vm.ride.status != "STARTED" || vm.isLoading)
                    if vm.isLoading && vm.ride.status == "STARTED" {
                        ProgressView().scaleEffect(0.6)
                    }
                }

                HStack {
                    Button("Cancel") { vm.cancel() }
                        .disabled(vm.ride.status != "ACCEPTED" || vm.isLoading)
                    if vm.isLoading && vm.ride.status == "ACCEPTED" {
                        ProgressView().scaleEffect(0.6)
                    }
                }
            }
            if let err = vm.errorMessage { Text(err).foregroundColor(.red) }
            if showWaitingForFix {
                Text("Waiting for GPS fix...").font(.footnote).foregroundColor(.orange)
            }
            Spacer()
        }
        .padding()
        .onDisappear {
            if refreshOnDismiss {
                NotificationCenter.default.post(name: Notification.Name("refreshRequested"), object: nil)
            }
        }
        .onChange(of: locMgr.authorizationStatus) { status in
            if pendingAccept {
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    pendingAccept = false
                    // require a GPS fix
                    if let _ = LocationManager.shared.lastLocation {
                        vm.accept()
                    } else {
                        showWaitingForFix = true
                    }
                } else if status == .denied || status == .restricted {
                    pendingAccept = false
                    showLocationAlert = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .locationQueueUpdated)) { _ in
            pendingQueueCount = LocationQueueManager.shared.pendingCount()
        }
        .alert("Location permission required", isPresented: $showLocationAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This app needs location permission to accept/start rides. Please enable location access in Settings.")
        }
        .onChange(of: vm.ride.status) { newStatus in
            if newStatus == "STARTED" {
                onActive(vm.ride)
            }
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
    
    private func handleAcceptTap() {
        let status = locMgr.authorizationStatus
        if status == .notDetermined {
            pendingAccept = true
            LocationManager.shared.requestWhenInUsePermission()
        } else if status == .denied || status == .restricted {
            showLocationAlert = true
        } else { // authorized
            if LocationManager.shared.lastLocation != nil {
                vm.accept()
            } else {
                showWaitingForFix = true
            }
        }
    }
}

struct RideDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let r = Ride(id: "r1", status: "REQUESTED", driverId: nil, payload: ["passengerName": .string("Alice")], createdAt: Int(Date().timeIntervalSince1970), locations: [])
        RideDetailView(vm: RideViewModel(ride: r, token: "t")) { _ in }
    }
}

