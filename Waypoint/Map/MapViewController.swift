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
    }
    
//    override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//        profilePic.layer.cornerRadius = profilePic.frame.width / 2
//        print("profilePic frame, viewDidLayoutSubviews: \(profilePic.frame)")
//    }
    
    func getProfilePic() {
        guard let user = Auth.auth().currentUser else {
            print("No user logged in")
            profilePic.setImage(UIImage(systemName: "person.crop.circle"), for: .normal)
            return
        }
        
        let userId = user.uid
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let profilePicRef = storageRef.child("\(userId)/profile_pic/.jpg")
        
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
