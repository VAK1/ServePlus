//
//  Practice+CoreDataProperties.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 8/5/21.
//
//

import Foundation
import CoreData


extension Practice {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Practice> {
        return NSFetchRequest<Practice>(entityName: "Practice")
    }

    @NSManaged public var date: Date?
    @NSManaged public var urls: [URL]?
    @NSManaged public var vectors: [[Double]]?
    @NSManaged public var timestamps: [[Int]]?

}

extension Practice : Identifiable {

}
