//
//  PhotoPost.swift
//  Waypoint
//
//  Created by Pranav Sridhar on 4/4/25.
//

import UIKit
import MapKit

class PhotoPost: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var image: UIImage?
    
    init(coordinate: CLLocationCoordinate2D, image: UIImage?) {
        self.coordinate = coordinate
        self.image = image
    }
}
