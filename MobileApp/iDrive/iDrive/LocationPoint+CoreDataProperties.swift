//
//  LocationPoint+CoreDataProperties.swift
//  iDrive
//
//  Created by Aptiway on 19/02/26.
//
//

import Foundation
import CoreData


extension LocationPoint {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LocationPoint> {
        return NSFetchRequest<LocationPoint>(entityName: "LocationPoint")
    }

    @NSManaged public var attempts: Int16
    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var lastError: String?
    @NSManaged public var lat: Double
    @NSManaged public var lng: Double
    @NSManaged public var rideId: String?
    @NSManaged public var sent: Bool
    @NSManaged public var ts: Int64

}

extension LocationPoint : Identifiable {

}
