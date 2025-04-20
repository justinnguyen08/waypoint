//  Project: Waypoint
//  Course: CS371L
//
//  PhotoPost.swift
//  Waypoint
//
//  Created by Pranav Sridhar on 4/4/25.
//

import UIKit
import MapKit

// tracks image and location of photo
class PhotoPost: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var image: UIImage?
    var postID: String?
    
    
    init(coordinate: CLLocationCoordinate2D, image: UIImage?, postID: String?) {
        self.coordinate = coordinate
        self.image = image
        self.postID = postID
    }
}
