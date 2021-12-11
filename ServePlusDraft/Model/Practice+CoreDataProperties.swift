//
//  Practice+CoreDataProperties.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 8/5/21.
//
//  Extension of the Practice class that details
//  the variables that define a single Practice
//  entity.

import Foundation
import CoreData


extension Practice {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Practice> {
        return NSFetchRequest<Practice>(entityName: "Practice")
    }

    @NSManaged public var date: Date?           // date of the practice session
    @NSManaged public var urls: [URL]?          // local URLs of the individual serves'
                                                // videos
    @NSManaged public var vectors: [[Double]]?  // serve scores for each individual serve.
                                                // Each vector contains 8 elements for
                                                // each of the scoring categories.
    @NSManaged public var timestamps: [[Int]]?  // starting and ending frames for each
                                                // serve in a continuous practice video.
                                                // Instead of creating a new video for
                                                // every serves, this array helps to
                                                // split a continuous practice video
                                                // into individual serves on the spot.

}

extension Practice : Identifiable {

}
