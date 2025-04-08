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
    private var userAnnotations: [String: PhotoPost] = [:]
    private var pinnedAnnotation: PhotoPost?
    var dailyAnnotation: PhotoPost?
    var posted: Bool = false
    var flushTimer: Timer?
    
    let manager = CLLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        profilePic.layer.cornerRadius = profilePic.frame.width / 2
        profilePic.clipsToBounds = true
        profilePic.imageView?.contentMode = .scaleAspectFit
        getProfilePic()
        refreshAllPins()
        showPinnedPic()
        mapView.delegate = self
        
        scheduleDailyFlush()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshAllPins()
        showPinnedPic()
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
    
    // remove all pins from map, and delete user's daily_picture entry
    private func flushAllAnnotations() {
        
        let dailyAnnotations = mapView.annotations.filter { annotation in
            if let photoPost = annotation as? PhotoPost {
                return userAnnotations.values.contains { $0 === photoPost }
            }
            return false
        }
        guard let mapSnapshot = mapView.snapshot() else { return }
        mapView.removeAnnotations(dailyAnnotations)
        userAnnotations.removeAll()
        print("All daily annotations flushed at \(Date())")
        
        if let user = Auth.auth().currentUser {
            let userId = user.uid
            let storage = Storage.storage()
            let storageRef = storage.reference()
            let dailyImageRef = storageRef.child("\(userId)/daily_pic.jpg")
            let mapImageRef = storageRef.child("\(userId)/mapSnapshots/\(Date())")
            print("Attempting to delete daily picture at \(Date())")
            dailyImageRef.delete { error in
                if let error = error {
                    print("Error deleting daily picture: \(error.localizedDescription)")
                } else {
                    print("Daily picture deleted successfully at \(Date())")
                }
            }
            if let imageData = mapSnapshot.jpegData(compressionQuality: 0.8) {
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                mapImageRef.putData(imageData, metadata: metadata) { metadata, error in
                    if let error = error {
                        print("Error uploading map snapshot: \(error.localizedDescription)")
                    } else {
                        print("Map snapshot uploaded successfully.")
                    }
                }
            } else {
                print("Failed to generate JPEG data from map snapshot")
              }
        } else {
            print("No user logged in, cannot delete daily picture")
        }
    }
    
    // schedule 'flush' event for 11:59 pm
    private func scheduleDailyFlush() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        
        components.hour = 23
        components.minute = 59
        components.second = 0
        
        if let flushTime = calendar.date(from: components) {
            let timeInterval = flushTime.timeIntervalSinceNow
            let finalInterval = timeInterval > 0 ? timeInterval : timeInterval + 24 * 60 * 60
            
            print("Current time: \(Date())")
            print("Scheduled flush time: \(flushTime)")
            print("Time interval until flush: \(finalInterval) seconds")
            
            flushTimer?.invalidate()
            
            flushTimer = Timer.scheduledTimer(withTimeInterval: finalInterval, repeats: false) { [weak self] _ in
                print("Timer fired at \(Date())")
                self?.flushAllAnnotations()
                self?.scheduleDailyFlush()
            }
        } else {
            print("Failed to create flush time")
        }
    }
    
    private func showDailyPic(for uid: String) {
        let dailyRef = Storage.storage().reference().child("\(uid)/daily_pic.jpg")
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
                    let lat = Double(latStr),
                    let lon = Double(lonStr)
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
    
    private func showPinnedPic() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("No user logged in, cannot show pinned pic")
            return
        }
        let pinnedRef = Storage.storage().reference().child("\(uid)/pinned_pic.jpg")
        pinnedRef.getMetadata { [weak self] metaResult in
            guard let self = self else { return }
            switch metaResult {
            case .failure(let error):
                print("Error retrieving pinned metadata: \(error.localizedDescription)")
                return
            case .success(let metadata):
                guard
                    let custom = metadata.customMetadata,
                    let latStr = custom["latitude"],
                    let lonStr = custom["longitude"],
                    let lat = Double(latStr),
                    let lon = Double(lonStr)
                else { return }
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                pinnedRef.getData(maxSize: 10 * 1024 * 1024) { [weak self] dataResult in
                    guard let self = self else { return }
                    switch dataResult {
                    case .failure(let error):
                        print("Error downloading pinned picture: \(error.localizedDescription)")
                        return
                    case .success(let data):
                        guard let img = UIImage(data: data) else { return }
                        DispatchQueue.main.async {
                            if let old = self.pinnedAnnotation {
                                self.mapView.removeAnnotation(old)
                            }
                            let post = PhotoPost(coordinate: coord, image: img)
                            self.mapView.addAnnotation(post)
                            self.pinnedAnnotation = post
                            print("Pinned pic added/updated for user \(uid)")
                        }
                    }
                }
            }
        }
    }
    
    func refreshAllPins() {
        guard let me = Auth.auth().currentUser else { return }
        let users = Firestore.firestore().collection("users")
        users.document(me.uid).getDocument { [weak self] snap, error in
            guard let self = self else { return }
            if let error = error {
                print("Firestore error: \(error.localizedDescription)")
                return
            }
            let friendUIDs: [String] = (snap?.data()?["friends"] as? [[String: Any]] ?? []).compactMap { $0["uid"] as? String }
            self.showDailyPic(for: me.uid)
            for uid in friendUIDs {
                self.showDailyPic(for: uid)
            }
            var allAnnotations = Array(self.userAnnotations.values)
            if let pinned = self.pinnedAnnotation {
                allAnnotations.append(pinned)
            }
            self.mapView.showAnnotations(allAnnotations, animated: true)
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            manager.stopUpdatingLocation()
            render(location)
        }
    }
    
    deinit {
        flushTimer?.invalidate()
    }
    
    func render(_ location: CLLocation) {
        mapView.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    }
}

extension MapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
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
                annotationView?.layer.cornerRadius = (CGSize(width: 50, height: 50)).width / 2
                if pinnedAnnotation === photoPost {
                    annotationView?.layer.borderWidth = 3.0
                    annotationView?.layer.borderColor = UIColor(red: 0, green: 255, blue: 200, alpha: 1).cgColor
                } else {
                    annotationView?.layer.borderWidth = 0.0
                }
            } else {
                annotationView?.image = photoImage
            }
        }
        return annotationView
    }
}

extension MKMapView {
    func snapshot() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, UIScreen.main.scale)
        defer { UIGraphicsEndImageContext() }
        
        self.drawHierarchy(in: self.bounds, afterScreenUpdates: true)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        return image
    }
}
