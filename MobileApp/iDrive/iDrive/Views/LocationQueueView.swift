import SwiftUI
import CoreData

struct LocationQueueView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: LocationPoint.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \LocationPoint.createdAt, ascending: true)],
        predicate: NSPredicate(format: "sent == NO"),
        animation: .default)
    private var pending: FetchedResults<LocationPoint>

    var body: some View {
        NavigationView {
            List {
                if pending.isEmpty {
                    Text("No queued locations").foregroundColor(.secondary)
                } else {
                    ForEach(pending) { lp in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Ride: \(lp.rideId ?? "N/A")").font(.subheadline).bold()
                                Spacer()
//                                Text("Attempts: \(lp.attempts)").font(.caption)
                            }
                            Text("lat: \(lp.lat), lng: \(lp.lng)").font(.caption)
                            if let err = lp.lastError {
                                Text("Last error: \(err)").font(.caption).foregroundColor(.red)
                            }
                            if let dt = lp.createdAt {
                                Text("Queued: \(dt.formatted(date: .numeric, time: .standard))").font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete(perform: delete)
                }
            }
            .navigationTitle("Queued Locations")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Flush Queue") {
                        LocationQueueManager.shared.startProcessingIfNeeded()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { pending[$0] }.forEach { lp in
            viewContext.delete(lp)
        }
        do {
            try viewContext.save()
        } catch {
            print("Failed to delete queued items:", error)
        }
        NotificationCenter.default.post(name: .locationQueueUpdated, object: nil)
    }
}

struct LocationQueueView_Previews: PreviewProvider {
    static var previews: some View {
        LocationQueueView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

