import Foundation
import Combine

final class ActiveRideViewModel: ObservableObject {
    @Published var ride: Ride
    @Published var errorMessage: String?
    @Published var isSending: Bool = false
    var token: String
    @Published var isWaitingForStart: Bool = false

    private var timer: Timer?
    private var authStatusCancellable: Any?

    init(ride: Ride, token: String) {
        self.ride = ride
        self.token = token
        init_observer()
        self.isWaitingForStart = ride.status != "STARTED"
    }
    
    // Observe global ride updates so this VM can react when server confirms STARTED
    private var rideUpdateObserver: Any?
    private var sentObserver: Any?
    private var queuedObserver: Any?
    func init_observer() {
        rideUpdateObserver = NotificationCenter.default.addObserver(forName: Notification.Name("rideUpdated"), object: nil, queue: .main) { [weak self] note in
            guard let self = self, let updated = note.object as? Ride else { return }
            if updated.id == self.ride.id {
                self.ride = updated
                // stop waiting and start sending if ride moved to STARTED
                if updated.status == "STARTED" {
                    self.isSending = true
                    self.startSending()
                }
            }
        }
        // observe sent/queued notifications from the shared sender service
        sentObserver = NotificationCenter.default.addObserver(forName: .locationSent, object: nil, queue: .main) { [weak self] note in
            guard let self = self, let info = note.userInfo, let rid = info["rideId"] as? String, rid == self.ride.id, let point = info["point"] as? LocationPointModel else { return }
            var locs = self.ride.locations ?? []
            locs.insert(point, at: 0)
            self.ride.locations = locs
        }
        queuedObserver = NotificationCenter.default.addObserver(forName: .locationQueued, object: nil, queue: .main) { [weak self] note in
            guard let self = self, let info = note.userInfo, let rid = info["rideId"] as? String, rid == self.ride.id, let point = info["point"] as? LocationPointModel else { return }
            // show queued points immediately in UI as well
            var locs = self.ride.locations ?? []
            locs.insert(point, at: 0)
            self.ride.locations = locs
        }
    }
    deinit {
        if let obs = rideUpdateObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs2 = sentObserver { NotificationCenter.default.removeObserver(obs2) }
        if let obs3 = queuedObserver { NotificationCenter.default.removeObserver(obs3) }
    }

    func requestPermissionAndStart() {
        LocationManager.shared.requestWhenInUsePermission()
        // Start sending if already authorized
        let st = LocationManager.shared.authorizationStatus
        if st == .authorizedWhenInUse || st == .authorizedAlways {
            startSending()
        } else {
            // Observe authorization changes
            authStatusCancellable = LocationManager.shared.$authorizationStatus
                .sink { [weak self] status in
                    guard let self = self else { return }
                    if status == .authorizedWhenInUse || status == .authorizedAlways {
                        self.startSending()
                    } else if status == .denied {
                        self.errorMessage = "Location permission denied"
                    }
                }
        }
    }

    func startSending() {
        // Delegate periodic sending to the shared service so it survives view dismissal
        isSending = true
        LocationSendService.shared.start(rideId: ride.id, token: token)
    }

    func stopSending() {
        isSending = false
        LocationSendService.shared.stop()
        if let canc = authStatusCancellable as? AnyCancellable { canc.cancel() }
        authStatusCancellable = nil
    }

    func completeRide() {
        guard let _ = ride.id as String?, !isSending == false else { return }
        // call complete API, then stop sending on success
        APIClient.shared.completeRide(rideId: ride.id, token: token) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let r):
                    self.ride = r
                    self.stopSending()
                    NotificationCenter.default.post(name: Notification.Name("rideUpdated"), object: r)
                    // clear active ride id persistence
                    UserDefaults.standard.removeObject(forKey: "active_ride_id")
                case .failure(let e):
                    self.errorMessage = e.localizedDescription
                }
            }
        }
    }

    private func enqueueLatestLocationIfAvailable() {
        guard let loc = LocationManager.shared.lastLocation else {
            self.errorMessage = "Waiting for GPS fix..."
            return
        }
        let lat = loc.coordinate.latitude
        let lng = loc.coordinate.longitude
        // If offline (toggle), persist to queue. Otherwise try immediate send and fall back to enqueue on failure.
        let online = UserDefaults.standard.bool(forKey: "is_online")
        if !online {
            LocationQueueManager.shared.enqueue(rideId: ride.id, lat: lat, lng: lng, ts: Int(Date().timeIntervalSince1970 * 1000))
            var locs = self.ride.locations ?? []
            let lp = LocationPointModel(lat: lat, lng: lng, ts: Int(Date().timeIntervalSince1970 * 1000))
            locs.insert(lp, at: 0)
            self.ride.locations = locs
            self.errorMessage = nil
            return
        }

        APIClient.shared.postLocation(rideId: ride.id, lat: lat, lng: lng, token: token) { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    var locs = self.ride.locations ?? []
                    let lp = LocationPointModel(lat: lat, lng: lng, ts: Int(Date().timeIntervalSince1970 * 1000))
                    locs.insert(lp, at: 0)
                    self.ride.locations = locs
                    self.errorMessage = nil
                case .failure(let e):
                    // on failure, enqueue for retry
                    LocationQueueManager.shared.enqueue(rideId: self.ride.id, lat: lat, lng: lng, ts: Int(Date().timeIntervalSince1970 * 1000))
                    self.errorMessage = e.localizedDescription
                }
            }
        }
    }
}

