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

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
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
        refreshAllPins(date: readableDate(from: Date()))
        mapView.delegate = self
        scheduleDailyFlush()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getProfilePic()
        refreshAllPins(date: readableDate(from: Date()))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    // retrieve and show profile picture
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
        
        // screenshot of map with daily annotations
        guard let mapSnapshot = mapView.snapshot() else { return }
        mapView.removeAnnotations(dailyAnnotations)
        userAnnotations.removeAll()
        print("All daily annotations flushed at \(Date())")
        
        // grab current user
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
            // update to firebase
            if let imageData = mapSnapshot.jpegData(compressionQuality: 1) {
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
                print("Failed to get JPEG data from map snapshot")
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
    
    // retrieve daily pic and its metadata from Firebase, add annotation to map according to coordinates
    private func showDailyPic(for uid: String, date: String) {
        let dailyRef = Storage.storage().reference()
                       .child("\(uid)/\(date)/daily_pic.jpg")

        dailyRef.getMetadata { [weak self] metaResult in
            guard let self = self else { return }
            switch metaResult {
            case .failure(let error):
                print("No daily for \(uid) on \(date): \(error.localizedDescription)")
                return
            case .success(let metadata):
                guard
                    let custom = metadata.customMetadata,
                    let latStr = custom["latitude"],
                    let lonStr = custom["longitude"],
                    let lat = Double(latStr),
                    let lon = Double(lonStr),
                    let postID = custom["postID"]
                else { return }

                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)

                dailyRef.getData(maxSize: 10 * 1024 * 1024) { [weak self] dataResult in
                    guard let self = self else { return }
                    switch dataResult {
                    case .failure(let error):
                        print("Download error: \(error.localizedDescription)")
                    case .success(let data):
                        guard let img = UIImage(data: data) else { return }

                        DispatchQueue.main.async {
                            // clear any old annotation for this uid if present
                            if let old = self.userAnnotations[uid] {
                                self.mapView.removeAnnotation(old)
                            }
                            let post = PhotoPost(coordinate: coord, image: img, postID: postID)
                            self.mapView.addAnnotation(post)
                            self.userAnnotations[uid] = post
                        }
                    }
                }
            }
        }
    }
    
    // very similar to dailyPic, just retrieving from different location in Firebase Storage
    private func showPinnedPic(for uid: String, date: String, pinnedToday: Bool = false) {
        
        let pinnedRef = Storage.storage().reference().child("\(uid)/\(date)/pinned_pic.jpg")

        pinnedRef.getMetadata { [weak self] metaResult in
            guard let self = self else { return }
            switch metaResult {
            case .failure(let error):
                if !pinnedToday {
                    print("No dated pin; looking for root pin …")
                    self.showPinnedPic(for: uid, date: date, pinnedToday: true)

                } else {
                    print("Pinned‑metadata error: \(error.localizedDescription)")
                }
            case .success(let metadata):
                guard
                    let custom = metadata.customMetadata,
                    let latStr = custom["latitude"],
                    let lonStr = custom["longitude"],
                    let lat = Double(latStr),
                    let lon = Double(lonStr),
                    let postID = custom["postID"]
                else { return }

                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)

                pinnedRef.getData(maxSize: 10 * 1024 * 1024) { [weak self] dataResult in
                    guard let self = self else { return }
                    switch dataResult {
                    case .failure(let error):
                        print("Download error: \(error.localizedDescription)")
                    case .success(let data):
                        guard let img = UIImage(data: data) else { return }

                        DispatchQueue.main.async {
                            let post = PhotoPost(coordinate: coord, image: img, postID: postID)
                            self.mapView.addAnnotation(post)
                            self.pinnedAnnotation = post
                        }
                    }
                }
            }
        }
    }
    
    // show all pins on map for user. includes pinned and daily pictures, for user and all added friends
    func refreshAllPins(date: String) {
        mapView.removeAnnotations(mapView.annotations)
        userAnnotations.removeAll()
        pinnedAnnotation = nil
        
        guard let me = Auth.auth().currentUser else { return }
        let users = Firestore.firestore().collection("users")
        users.document(me.uid).getDocument { [weak self] snap, error in
            guard let self = self else { return }
            if let error = error {
                print("Firestore error: \(error.localizedDescription)")
                return
            }
            let friendUIDs: [String] = (snap?.data()?["friends"] as? [[String: Any]] ?? []).compactMap { $0["uid"] as? String }
            let allUIDs = [me.uid] + friendUIDs
            
            for uid in allUIDs {
                self.showDailyPic(for: uid, date: date)
                self.findPinnedPic(for: uid, date: date) {
                    self.showPinnedPic(for: uid, date: date)
                }
            }
            var allAnnotations = Array(self.userAnnotations.values)
            if let pinned = self.pinnedAnnotation {
                allAnnotations.append(pinned)
            }
            self.mapView.showAnnotations(allAnnotations, animated: true)
        }
    }
    
    // update pinned picture; if one hasn't been posted today, use yesterday's entry
    func findPinnedPic(for uid: String, date: String, completion: @escaping () -> Void) {
        let storage = Storage.storage()
        let datedRef = storage.reference().child("\(uid)/\(date)/pinned_pic.jpg")
        let rootRef = storage.reference().child("\(uid)/pinned_pic.jpg")

        datedRef.getMetadata { metaResult in
            switch metaResult {
            case .success:
                completion()

            case .failure:
                rootRef.getMetadata { rootMetaResult in
                    switch rootMetaResult {
                    case .failure(let error):
                        print("No root pinned_pic to copy: \(error.localizedDescription)")
                        completion()

                    case .success(let rootMetadata):
                        let newMeta = StorageMetadata()
                        newMeta.contentType = rootMetadata.contentType
                        newMeta.customMetadata = rootMetadata.customMetadata

                        rootRef.getData(maxSize: 10 * 1024 * 1024) { dataResult in
                            switch dataResult {
                            case .failure(let err):
                                print("Failed to download root pinned_pic: \(err.localizedDescription)")
                                completion()

                            case .success(let data):
                                datedRef.putData(data, metadata: newMeta) { _, uploadError in
                                    if let uploadError = uploadError {
                                        print("Error copying pinned_pic into dated folder: \(uploadError)")
                                    } else {
                                        print("Dated pinned_pic created for \(date)")
                                    }
                                    completion()
                                }
                            }
                        }
                    }
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
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            manager.stopUpdatingLocation()
            render(location)
        }
    }
    
    // to flush before deallocating
    deinit {
        flushTimer?.invalidate()
    }
    
    func render(_ location: CLLocation) {
        mapView.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    }
    
    func readableDate(from date: Date) -> String {
        let fmt = DateFormatter()
        // user’s timezone
        fmt.calendar = Calendar.current
        fmt.timeZone = .current
        fmt.locale   = Locale(identifier: "en_US_POSIX")
        // e.g. 2025‑04‑17
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }
    
    // open up full photo view when photo annotation on map is tapped
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation as? PhotoPost else {
            return
        }
        mapView.deselectAnnotation(annotation, animated: true)
        
        let photo = annotation.image
        let map = UIStoryboard(name: "Map", bundle: nil)
        
        guard let fullPhotoView = map.instantiateViewController(withIdentifier: "FullPhotoViewController") as? FullPhotoViewController else {
            return
        }
        fullPhotoView.photo = photo
        fullPhotoView.postID = annotation.postID
        fullPhotoView.location = annotation.coordinate
        self.present(fullPhotoView, animated: true, completion: nil)
    }
    
    // format picture view on map. make circular, and add a border for pinned photos
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

// capture screenshot of the map. called right before nightly flush occurs
extension MKMapView {
    func snapshot() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, UIScreen.main.scale)
        defer { UIGraphicsEndImageContext() }
        
        self.drawHierarchy(in: self.bounds, afterScreenUpdates: true)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        return image
    }
}
