import Foundation
import Combine

final class RideViewModel: ObservableObject {
    @Published var ride: Ride
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    var token: String

    init(ride: Ride, token: String) {
        self.ride = ride
        self.token = token
    }

    func accept() {
        guard !isLoading else { return }
        isLoading = true
        APIClient.shared.acceptRide(rideId: ride.id, token: token) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let r):
                    self.ride = r
                    self.errorMessage = nil
                    // notify dashboard that a ride was accepted/updated for this driver
                    NotificationCenter.default.post(name: Notification.Name("rideUpdated"), object: r)
                case .failure(let e):
                    self.errorMessage = e.localizedDescription
                }
            }
        }
    }

    func start() {
        guard !isLoading else { return }
        isLoading = true
        APIClient.shared.startRide(rideId: ride.id, token: token) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let r):
                    self.ride = r
                    self.errorMessage = nil
                    NotificationCenter.default.post(name: Notification.Name("rideUpdated"), object: r)
                case .failure(let e):
                    self.errorMessage = e.localizedDescription
                }
            }
        }
    }

    func complete() {
        guard !isLoading else { return }
        isLoading = true
        APIClient.shared.completeRide(rideId: ride.id, token: token) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let r):
                    self.ride = r
                    self.errorMessage = nil
                    NotificationCenter.default.post(name: Notification.Name("rideUpdated"), object: r)
                case .failure(let e):
                    self.errorMessage = e.localizedDescription
                }
            }
        }
    }

    func cancel() {
        guard !isLoading else { return }
        isLoading = true
        APIClient.shared.cancelRide(rideId: ride.id, token: token) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let r):
                    self.ride = r
                    self.errorMessage = nil
                    NotificationCenter.default.post(name: Notification.Name("rideUpdated"), object: r)
                case .failure(let e):
                    self.errorMessage = e.localizedDescription
                }
            }
        }
    }
}

