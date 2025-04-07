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
import FirebaseFirestore

class MapViewController: UIViewController, CLLocationManagerDelegate {
    
    
    @IBOutlet weak var profilePic: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    private var userAnnotations: [String: PhotoPost] = [:]   // uid → annotation
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
//        postDailyPic()
        refreshAllPins()
        mapView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // postDailyPic()
        refreshAllPins()
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
    
    // load up daily photo posts from Firebase
    private func showDailyPic(for uid: String) {
        let dailyRef = Storage.storage().reference()
                         .child("\(uid)/daily_pic.jpg")

        dailyRef.getMetadata { [weak self] metaResult in
            guard let self = self else { return }

            switch metaResult {
            case .failure(let error):
                print("Error retrieving metadata: \(error.localizedDescription)")
                return

            case .success(let metadata):
                guard
                    let custom = metadata.customMetadata,
                    let latStr = custom["latitude"],
                    let lonStr = custom["longitude"],
                    let lat    = Double(latStr),
                    let lon    = Double(lonStr)
                else { return }

                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)

                dailyRef.getData(maxSize: 10 * 1024 * 1024) { [weak self] dataResult in
                    guard let self = self else { return }

                    switch dataResult {
                    case .failure(let error):
                        print("Error downloading daily picture: \(error.localizedDescription)")
                        return

                    case .success(let data):
                        guard let img = UIImage(data: data) else { return }

                        DispatchQueue.main.async {
                            if let old = self.userAnnotations[uid] {
                                self.mapView.removeAnnotation(old)
                            }

                            let post = PhotoPost(coordinate: coord, image: img)
                            self.mapView.addAnnotation(post)
                            self.userAnnotations[uid] = post
                            
                            print("Total pins on map: \(self.userAnnotations.count)")
                        }
                    }
                }
            }
        }
    }
    
    // show photos on map for user AND friends
    func refreshAllPins() {
        guard let me = Auth.auth().currentUser else { return }
        let users = Firestore.firestore().collection("users")
        
        users.document(me.uid).getDocument { [weak self] snap, error in
            guard let self = self else { return }

            if let error = error {
                print("Firestore error: \(error.localizedDescription)")
                return
            }

            let friendUIDs: [String] = (snap?.data()?["friends"] as? [[String: Any]] ?? [])
                .compactMap { $0["uid"] as? String }
            self.showDailyPic(for: me.uid)

            for uid in friendUIDs {
                self.showDailyPic(for: uid)
            }
            self.mapView.showAnnotations(Array(self.userAnnotations.values), animated: true)
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
