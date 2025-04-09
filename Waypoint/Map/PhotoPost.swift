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
    
    init(coordinate: CLLocationCoordinate2D, image: UIImage?) {
        self.coordinate = coordinate
        self.image = image
    }
}
