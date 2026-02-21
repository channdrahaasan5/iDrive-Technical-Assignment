import Foundation
import CoreLocation

/// Singleton service that drives periodic location sends for the active ride.
/// Runs independently of any ViewModel so sending continues when views are dismissed.
final class LocationSendService {
    static let shared = LocationSendService()

    private var timer: DispatchSourceTimer?
    private var currentRideId: String?
    private var token: String = ""
    private let interval: TimeInterval = 5.0
    private let queue = DispatchQueue(label: "LocationSendService.queue")

    private init() {}

    /// Start periodic sending for a ride. No-op if same ride already running.
    func start(rideId: String, token: String) {
        queue.async {
            if self.currentRideId == rideId && self.timer != nil { return }
            self.currentRideId = rideId
            self.token = token
            self.stopTimerLocked()
            let t = DispatchSource.makeTimerSource(queue: self.queue)
            t.schedule(deadline: .now(), repeating: self.interval)
            t.setEventHandler { [weak self] in
                Task { await self?.sendOnce() }
            }
            self.timer = t
            t.resume()
            // ensure location updates are active
            LocationManager.shared.startUpdates()
            // ensure queue processing running when online
            if UserDefaults.standard.bool(forKey: "is_online") {
                LocationQueueManager.shared.startProcessingIfNeeded()
            }
        }
    }

    /// Stop sending for current ride.
    func stop() {
        queue.async {
            self.stopTimerLocked()
            self.currentRideId = nil
            // we don't stop LocationManager here (it may be used elsewhere)
        }
    }

    private func stopTimerLocked() {
        if let t = timer {
            t.cancel()
            timer = nil
        }
    }

    /// Send one location immediately (called by timer)
    private func sendOnce() async {
        guard let rideId = currentRideId else { return }
        guard let loc = LocationManager.shared.lastLocation else {
            NotificationCenter.default.post(name: .locationSendFailed, object: nil, userInfo: ["rideId": rideId, "error": "No GPS fix"])
            return
        }
        let lat = loc.coordinate.latitude
        let lng = loc.coordinate.longitude
        let ts = Int(Date().timeIntervalSince1970 * 1000)

        let online = UserDefaults.standard.bool(forKey: "is_online")
        if !online {
            LocationQueueManager.shared.enqueue(rideId: rideId, lat: lat, lng: lng, ts: ts)
            let lp = LocationPointModel(lat: lat, lng: lng, ts: ts)
            NotificationCenter.default.post(name: .locationQueued, object: nil, userInfo: ["rideId": rideId, "point": lp])
            return
        }

        let sem = DispatchSemaphore(value: 0)
        var resultError: Error?
        APIClient.shared.postLocation(rideId: rideId, lat: lat, lng: lng, token: token) { res in
            switch res {
            case .success():
                let lp = LocationPointModel(lat: lat, lng: lng, ts: ts)
                NotificationCenter.default.post(name: .locationSent, object: nil, userInfo: ["rideId": rideId, "point": lp])
            case .failure(let e):
                // enqueue for retry and notify
                LocationQueueManager.shared.enqueue(rideId: rideId, lat: lat, lng: lng, ts: ts)
                resultError = e
                NotificationCenter.default.post(name: .locationQueued, object: nil, userInfo: ["rideId": rideId, "error": e.localizedDescription])
            }
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 30)
    }
}

extension Notification.Name {
    static let locationSent = Notification.Name("LocationSendService.locationSent")
    static let locationQueued = Notification.Name("LocationSendService.locationQueued")
    static let locationSendFailed = Notification.Name("LocationSendService.locationSendFailed")
}

