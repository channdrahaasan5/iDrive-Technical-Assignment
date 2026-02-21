import Foundation
import Combine

final class DashboardViewModel: ObservableObject {
    @Published var requestedRides: [Ride] = []
    @Published var completedRides: [Ride] = []
    @Published var pendingQueueCount: Int = 0
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    var token: String
    @Published var hasActiveRide: Bool = false
    private var driverId: String? = UserDefaults.standard.string(forKey: "driver_id")
    @Published var activeRide: Ride?

    init(token: String) {
        self.token = token
        // observe accept notifications
        NotificationCenter.default.addObserver(forName: Notification.Name("rideUpdated"), object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            if let ride = note.object as? Ride {
                // if this ride belongs to current driver, update active state
                if ride.driverId == self.driverId && (ride.status == "ACCEPTED" || ride.status == "STARTED") {
                    self.hasActiveRide = true
                    self.activeRide = ride
                } else if ride.driverId == nil || ride.status == "REQUESTED" || ride.status == "COMPLETED" {
                    // ride released or completed -> clear active if it was the same
                    if self.activeRide?.id == ride.id {
                        self.activeRide = nil
                        self.hasActiveRide = false
                    }
                }
                // refresh list only if current tab is "requested"
                let tab = UserDefaults.standard.string(forKey: "dashboard_tab") ?? "requested"
                if tab == "requested" {
                    self.fetch(status: "requested")
                }
            }
        }
        NotificationCenter.default.addObserver(forName: Notification.Name("refreshRequested"), object: nil, queue: .main) { [weak self] _ in
            self?.fetchRequested()
        }
        // observe queue updates
        NotificationCenter.default.addObserver(forName: Notification.Name.locationQueueUpdated, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.pendingQueueCount = LocationQueueManager.shared.pendingCount()
        }
        // initial pending count
        self.pendingQueueCount = LocationQueueManager.shared.pendingCount()
    }

    // deinit observer cleanup if needed
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func fetchRequested() {
        fetch(status: "requested")
    }

    func fetch(status: String = "requested") {
        guard !isLoading else { return }
        isLoading = true
        APIClient.shared.getRides(status: status, token: token) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let rides):
                    if status == "completed" {
                        self.completedRides = rides
                    } else {
                        self.requestedRides = rides
                    }
                    self.errorMessage = nil
                    // after fetching requested, check all rides to see if driver has active ride
                    APIClient.shared.getAllRides(token: self.token) { allRes in
                        DispatchQueue.main.async {
                            switch allRes {
                            case .success(let all):
                                if let did = self.driverId {
                                    self.hasActiveRide = all.contains(where: { $0.driverId == did && ($0.status == "ACCEPTED" || $0.status == "STARTED") })
                                    self.activeRide = all.first(where: { $0.driverId == did && ($0.status == "ACCEPTED" || $0.status == "STARTED") })
                                } else {
                                    self.hasActiveRide = false
                                }
                            case .failure(_):
                                break
                            }
                        }
                    }
                case .failure(let e):
                    self.errorMessage = e.localizedDescription
                }
            }
        }
    }

    // Start the active ride
    func startActive(completion: ((Ride?)->Void)? = nil) {
        guard let ride = activeRide, !isLoading else { completion?(nil); return }
        isLoading = true
        APIClient.shared.startRide(rideId: ride.id, token: token) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let r):
                    self.activeRide = r
                    self.hasActiveRide = (r.status == "ACCEPTED" || r.status == "STARTED")
                    self.fetchRequested()
                    completion?(r)
                case .failure(let e):
                    self.errorMessage = e.localizedDescription
                    completion?(nil)
                }
            }
        }
    }

    func completeActive() {
        guard let ride = activeRide, !isLoading else { return }
        isLoading = true
        APIClient.shared.completeRide(rideId: ride.id, token: token) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let r):
                    self.activeRide = nil
                    self.hasActiveRide = false
                    self.fetchRequested()
                case .failure(let e):
                    self.errorMessage = e.localizedDescription
                }
            }
        }
    }

    func cancelActive() {
        guard let ride = activeRide, !isLoading else { return }
        isLoading = true
        APIClient.shared.cancelRide(rideId: ride.id, token: token) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let r):
                    // canceled -> ride becomes REQUESTED, so clear active
                    self.activeRide = nil
                    self.hasActiveRide = false
                    UserDefaults.standard.removeObject(forKey: "active_ride_id")
                    self.fetchRequested()
                case .failure(let e):
                    self.errorMessage = e.localizedDescription
                }
            }
        }
    }
}

