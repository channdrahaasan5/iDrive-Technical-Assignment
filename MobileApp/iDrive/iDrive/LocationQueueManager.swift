import Foundation
import CoreData

/// Persistent FIFO queue for location points using Core Data.
final class LocationQueueManager {
    static let shared = LocationQueueManager()

    private let container = PersistenceController.shared.container
    private let processingQueue = DispatchQueue(label: "LocationQueueManager.processing")
    private var isProcessing = false

    private init() {}

    /// Enqueue a location for later delivery.
    func enqueue(rideId: String, lat: Double, lng: Double, ts: Int) {
        let ctx = container.viewContext
        ctx.perform {
            // Deduplicate: if an unsent point for same rideId and ts exists, skip enqueue.
            let req: NSFetchRequest<LocationPoint> = LocationPoint.fetchRequest()
            req.predicate = NSPredicate(format: "rideId == %@ AND ts == %d AND sent == NO", rideId, Int64(ts))
            req.fetchLimit = 1
            do {
                let existing = try ctx.fetch(req)
                if existing.count > 0 {
                    // Already queued — no-op
                    return
                }
            } catch {
                // ignore fetch error and proceed to enqueue
            }

            let lp = LocationPoint(context: ctx)
            lp.id = UUID()
            lp.rideId = rideId
            lp.lat = lat
            lp.lng = lng
            lp.ts = Int64(ts)
            lp.createdAt = Date()
            lp.sent = false
            lp.attempts = 0
            lp.lastError = nil
            do {
                try ctx.save()
                NotificationCenter.default.post(name: .locationQueueUpdated, object: nil)
            } catch {
                print("LocationQueueManager enqueue save error:", error)
            }
        }
    }

    /// Returns current pending (unsent) count.
    func pendingCount() -> Int {
        let ctx = container.viewContext
        let req: NSFetchRequest<LocationPoint> = LocationPoint.fetchRequest()
        req.predicate = NSPredicate(format: "sent == NO")
        do {
            return try ctx.count(for: req)
        } catch {
            return 0
        }
    }

    /// Start processing queue if online. Uses the app's is_online flag as source of truth.
    func startProcessingIfNeeded() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            if self.isProcessing { return }
            self.isProcessing = true
            Task {
                await self.processLoop()
            }
        }
    }

    /// Stops processing (processing loop will exit when sees isOnline false).
    func stopProcessing() {
        processingQueue.async { [weak self] in
            self?.isProcessing = false
        }
    }

    private func processLoop() async {
        while isProcessing {
            // check online flag (AppStorage-backed UserDefaults)
            let online = UserDefaults.standard.bool(forKey: "is_online")
            if !online {
                isProcessing = false
                return
            }

            // fetch oldest unsent
            let ctx = container.newBackgroundContext()
            var next: LocationPoint? = nil
            await ctx.perform {
                let req: NSFetchRequest<LocationPoint> = LocationPoint.fetchRequest()
                req.predicate = NSPredicate(format: "sent == NO")
                req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
                req.fetchLimit = 1
                do {
                    let items = try ctx.fetch(req)
                    next = items.first
                } catch {
                    print("LocationQueueManager fetch error:", error)
                }
            }

            guard let item = next else {
                // nothing to send -> stop processing until new items arrive
                isProcessing = false
                NotificationCenter.default.post(name: .locationQueueUpdated, object: nil)
                return
            }

            // try to send
            await send(item: item, in: ctx)
            // small pause to avoid tight loop
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
        }
    }

    private func send(item: LocationPoint, in ctx: NSManagedObjectContext) async {
        let rideId = item.rideId ?? ""
        let lat = item.lat
        let lng = item.lng
        let ts = Int(item.ts)
        let sem = DispatchSemaphore(value: 0)
        var sendResultError: Error?
        APIClient.shared.postLocation(rideId: rideId, lat: lat, lng: lng, token: KeychainHelper.shared.read("api_token") ?? "") { result in
            switch result {
            case .success():
                // mark sent and delete in background context
                ctx.performAndWait {
                    item.sent = true
                    do {
                        ctx.delete(item)
                        try ctx.save()
                    } catch {
                        print("LocationQueueManager delete save error:", error)
                    }
                }
            case .failure(let e):
                sendResultError = e
                // persist attempt count and lastError
                ctx.performAndWait {
                    item.attempts += 1
                    item.lastError = (e as NSError).localizedDescription
                    do {
                        try ctx.save()
                    } catch {
                        print("LocationQueueManager save error:", error)
                    }
                }
            }
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 30)
        NotificationCenter.default.post(name: .locationQueueUpdated, object: nil)
    }
}

extension Notification.Name {
    static let locationQueueUpdated = Notification.Name("locationQueueUpdated")
}

