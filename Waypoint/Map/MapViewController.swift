//  Project: Waypoint
//  Course: CS371L
//
//  MapViewController.swift
//  Waypoint
//
//  Created by Tarun Somisetty on 3/10/25.
//

import UIKit
import MapKit
import CoreLocation
import FirebaseStorage
import FirebaseAuth

class MapViewController: UIViewController, CLLocationManagerDelegate {
    
    
    @IBOutlet weak var profilePic: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    var dailyAnnotation: PhotoPost?
    var posted: Bool = false
    
    let manager = CLLocationManager()
    
    
//    private var position = MKMapCamera
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        profilePic.layer.cornerRadius = profilePic.frame.width / 2
//        print("profileButton frame, viewDidLoad: \(profilePic.frame)")
        profilePic.clipsToBounds = true
        profilePic.imageView?.contentMode = .scaleAspectFit
        getProfilePic()
        postDailyPic()
        mapView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        postDailyPic()
    }
    
    func getProfilePic() {
        guard let user = Auth.auth().currentUser else {
            print("No user logged in")
            profilePic.setImage(UIImage(systemName: "person.crop.circle"), for: .normal)
            return
        }
        
        let userId = user.uid
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let profilePicRef = storageRef.child("\(userId)/profile_pic.jpg")
        
        profilePicRef.getData(maxSize: 10 * 1024 * 1024) { [weak self] data, error in
            if let error = error {
                print("Error fetching profile picture: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.profilePic.setImage(UIImage(systemName: "person.crop.circle"), for: .normal)
                }
                return
            }
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    let scaledImage = self?.scaleImage(image, toSize: CGSize(width: 50, height: 50))
                    self?.profilePic.setImage(scaledImage, for: .normal)
                }
            }
        }
    }
    
    private func scaleImage(_ image: UIImage, toSize size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    func postDailyPic() {
        guard let user = Auth.auth().currentUser else {
            print("No user logged in")
            return
        }
        let userId = user.uid
        let storageRef = Storage.storage().reference()
        let dailyPicRef = storageRef.child("\(userId)/daily_pic.jpg")
        
        dailyPicRef.getMetadata { metadata, error in
            if let error = error {
                print("Error retrieving metadata: \(error.localizedDescription)")
                return
            }
            guard let metadata = metadata,
                  let customMetadata = metadata.customMetadata,
                  let latString = customMetadata["latitude"],
                  let lonString = customMetadata["longitude"],
                  let latitude = Double(latString),
                  let longitude = Double(lonString) else {
                print("Missing or invalid metadata")
                return
            }
            
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            
            dailyPicRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                if let error = error {
                    print("Error downloading daily picture: \(error.localizedDescription)")
                    return
                }
                var image: UIImage? = nil
                if let data = data {
                    image = UIImage(data: data)
                }
                
                // add the post on main thread
                DispatchQueue.main.async {
                    if let existing = self.dailyAnnotation {
                        self.mapView.removeAnnotation(existing)
                    }
                    
                    let photoPost = PhotoPost(coordinate: coordinate, image: image)
                    self.mapView.addAnnotation(photoPost)
                    
                    self.dailyAnnotation = photoPost
                    
//                    let photoPost = PhotoPost(coordinate: coordinate, image: image)
//                    self.mapView.addAnnotation(photoPost)
//                    self.posted = true
                }
            }
        }
    }
    
    func circularImage(from image: UIImage, size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            context.cgContext.addEllipse(in: rect)
            context.cgContext.clip()
            image.draw(in: rect)
        }
    }

    
    // setting up the map view based on the simulated location
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
//        print("profilePic frame in viewDidAppear: \(profilePic.frame)")
    }
    
    // showing what location is going to show up
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            manager.stopUpdatingLocation()
            
            render(location)
        }
    }
    
    // based on simulated location
    func render(_ location: CLLocation) {
        mapView.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    }

}

extension MapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // Skip the user location annotation
        if annotation is MKUserLocation {
            return nil
        }
        let identifier = "PhotoPost"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        
        if annotationView == nil {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = false
        } else {
            annotationView?.annotation = annotation
        }
        
        if let photoPost = annotation as? PhotoPost, let photoImage = photoPost.image {
            let size = CGSize(width: 50, height: 50)
                if let circularImg = circularImage(from: photoImage, size: size) {
                    annotationView?.image = circularImg
                } else {
                    annotationView?.image = photoImage
                }
        }
        
        return annotationView
    }
}
