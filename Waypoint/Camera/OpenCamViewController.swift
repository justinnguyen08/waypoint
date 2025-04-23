//  Project: Waypoint
//  Course: CS371L
//
//  OpenCamViewController.swift
//  Waypoint
//
//  Created by Pranav Sridhar on 3/7/25.
//

import UIKit
import AVFoundation
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth
import CoreLocation

class OpenCamViewController: UIViewController, AVCapturePhotoCaptureDelegate, CLLocationManagerDelegate {

    var session: AVCaptureSession?
    var device: AVCaptureDevice?
    var preview: AVCaptureVideoPreviewLayer?
    var position: AVCaptureDevice.Position = .front
    var photoOutput: AVCapturePhotoOutput?
    var flashMode: AVCaptureDevice.FlashMode = .off
    var stillImageView: UIImageView?
    var capturedData: Data?
    var validPicture = false
    var timestamp: Date?
    var locManager = CLLocationManager()
    var location: CLLocation?

    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var sendPostButton: UIButton!
    @IBOutlet weak var pinPhotoButton: UIButton!
    @IBOutlet weak var tagFriendsButton: UIButton!
    @IBOutlet weak var flipButton: UIButton!
    @IBOutlet weak var capturePicButton: UIButton!
    @IBOutlet weak var resumeLiveButton: UIButton!
    
    let db = Firestore.firestore()
    
    var postRef: Any!
    var postID: String!
    
    var doDelete = true
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        capturePicButton.layer.cornerRadius = capturePicButton.frame.width / 2
        capturePicButton.clipsToBounds = true
        flipButton.layer.cornerRadius = 25
        flipButton.clipsToBounds = true
        flashButton.layer.cornerRadius = 25
        flashButton.clipsToBounds = true
        resumeLiveButton.isHidden = true
        resumeLiveButton.layer.cornerRadius = 25
        resumeLiveButton.clipsToBounds = true
        sendPostButton.isHidden = true
        pinPhotoButton.isHidden = true
        tagFriendsButton.isHidden = true
        
        locManager.delegate = self
        locManager.requestWhenInUseAuthorization()
        locManager.startUpdatingLocation()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupCaptureSession(with: position)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        session?.stopRunning()
        session = nil
        preview?.removeFromSuperlayer()
        preview = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let currentLocation = locations.last {
            location = currentLocation
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session?.stopRunning()
        session = nil
        preview?.removeFromSuperlayer()
        preview = nil
    }
    
    // Start live camera session, request access to camera if needed
    func setupCaptureSession(with position: AVCaptureDevice.Position) {
        if postID == nil{
            postRef = Firestore.firestore().collection("mapPosts").document()
            postID = (postRef as AnyObject).documentID
        }
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            print("Camera unavailable for position \(position.rawValue)")
            return
        }
        doDelete = true
        self.device = newDevice
        do {
            let input = try AVCaptureDeviceInput(device: self.device!)
            self.session = AVCaptureSession()
            session!.sessionPreset = .photo

            if session!.canAddInput(input) {
                session!.addInput(input)
            } else {
                print("Cannot add input to session")
                return
            }
            
            // fit tab bar on screen under camera view
            self.preview = AVCaptureVideoPreviewLayer(session: session!)
            preview!.videoGravity = .resizeAspectFill
            let tabBarController = self.tabBarController
            let tabBarHeight = tabBarController?.tabBar.frame.height
            preview!.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - tabBarHeight!)
            view.layer.insertSublayer(preview!, at: 0)
            
            self.photoOutput = AVCapturePhotoOutput()
            if session!.canAddOutput(photoOutput!) {
                session!.addOutput(photoOutput!)
            } else {
                print("Cannot add photo output to session")
                return
            }

            session!.startRunning()
            print("Session running: \(session?.isRunning ?? false)")
        } catch {
            print("Unable to create input: \(error.localizedDescription)")
        }
    }
    
    @IBAction func triggerFlash(_ sender: Any) {
        flashMode = (flashMode == .off ? .on : .off)
        let symbol = (flashMode == .off ? "bolt.slash" : "bolt")
        flashButton.setImage(UIImage(systemName: symbol), for: .normal)
    }
    @IBAction func flipCamera(_ sender: Any) {
        guard let currentSession = session, currentSession.isRunning else { return }
        
        let newPosition: AVCaptureDevice.Position = (position == .front) ? .back : .front
        
        currentSession.beginConfiguration()
        
        // Stopping active camera
        if let currentInput = currentSession.inputs.first as? AVCaptureDeviceInput {
            currentSession.removeInput(currentInput)
        }
        
        // Setting up device
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            print("Camera unavailable for position \(newPosition.rawValue)")
            currentSession.commitConfiguration()
            return
        }
        
        // Add to session
        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            if currentSession.canAddInput(newInput) {
                currentSession.addInput(newInput)
                self.device = newDevice
                self.position = newPosition
            } else {
                print("Cannot add new input to session")
            }
        } catch {
            print("Error creating new input: \(error.localizedDescription)")
        }
        
        currentSession.commitConfiguration()
    }
    
    // show captured photo still on screen
    @IBAction func capturePicture(_ sender: UIButton) {
        guard let photoOutput = photoOutput else { return }
        self.tabBarController?.tabBar.isHidden = true
        let settings = AVCapturePhotoSettings()
        if photoOutput.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
        validPicture = true
        
        let postData: [String : Any] = ["imageURL" : "", "userID" : Auth.auth().currentUser?.uid, "time" : 0, "likes" : [], "comments" : [], "tagged" : []]
        (self.postRef as AnyObject).setData(postData)
    }
    
    // set image to whatever's currently on screen
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else { return }
        guard var image = UIImage(data: imageData) else { return }
        
        timestamp = Date()
        
        if let exifMeta = photo.metadata[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let originalDate = exifMeta[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            print("EXIF Timestamp: \(originalDate)")
        } else {
            print("Using current timestamp: \(timestamp)")
        }
        
        // flips image for front camera
        if self.position == .front {
            guard let cgImage = image.cgImage else { return }
            image = UIImage(cgImage: cgImage, scale: image.scale, orientation: .leftMirrored)
        }
        
        self.capturedData = image.jpegData(compressionQuality: 1)
        // capture and display still image
        DispatchQueue.main.async {
            self.session?.stopRunning()
            self.preview?.removeFromSuperlayer()
            
            if self.stillImageView == nil {
                let tabBarController = self.tabBarController
                let tabBarHeight = tabBarController?.tabBar.frame.height
                self.stillImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height - tabBarHeight!))
                self.stillImageView!.contentMode = .scaleAspectFill
                self.stillImageView!.clipsToBounds = true
                self.view.insertSubview(self.stillImageView!, belowSubview: self.resumeLiveButton)
            }
            
            self.resumeLiveButton.isHidden = false
            self.tagFriendsButton.isHidden = false
            self.sendPostButton.isHidden = false
            self.pinPhotoButton.isHidden = false
            self.stillImageView!.image = image
            self.flipButton.isHidden = true
            self.flashButton.isHidden = true
            self.capturePicButton.isHidden = true
            
            self.capturedData = imageData
        }
    }
    
    // Resume live feed, after returning from the still view
    @IBAction func resumeLiveFeed(_ sender: UIButton) {
        stillImageView?.removeFromSuperview()
        stillImageView = nil
        preview?.removeFromSuperlayer()
        sender.isHidden = true
        sendPostButton.isHidden = true
        pinPhotoButton.isHidden = true
        tagFriendsButton.isHidden = true
        capturePicButton.isHidden = false
        self.tabBarController?.tabBar.isHidden = false
        flipButton.isHidden = false
        flashButton.isHidden = false
        if doDelete{
            print("DELETING: \(postID)")
            db.collection("mapPosts").document(postID).delete { error in
                if let error = error{
                    print("Error: \(error.localizedDescription)")
                }
            }
        }
        setupCaptureSession(with: position)
        validPicture = false
        capturedData = nil
    }
    
    // if user's taken a new picture, post to map
    @IBAction func onSendPressed(_ sender: UIButton) {
        guard let imageData = capturedData else {
            print("Take a picture first")
            return
        }
        if (!validPicture) {
            print("Picture already uploaded")
            return
        }
        uploadImage(imageData: imageData, postType: "daily_pic.jpg")
        validPicture = false
    }
    
    
    // confirm and allow user to upload and pin current image on map
    @IBAction func onPinPressed(_ sender: UIButton) {
        guard let imageData = capturedData else {
            return
        }
        if (!validPicture) {
            return
        }
        let alert = UIAlertController(title: "Pin Photo",
                                      message: "Are you sure you want to pin this photo?",
                                      preferredStyle: .alert)
                
        alert.addAction(UIAlertAction( title: "Yes",
                                       style: .default)
                        { _ in self.uploadImage(imageData: imageData, postType: "pinned_pic.jpg")
                            self.validPicture = false})
        
        alert.addAction(UIAlertAction(title: "No",
                                      style: .cancel)
                        { _ in print("Pin cancelled")})
        
        present(alert, animated: true)
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
    
    // upload picture and its metadata to firebase
    func uploadImage(imageData: Data, postType: String) {
        guard let user = Auth.auth().currentUser,
              let time = timestamp else { return }
        let userId = user.uid
        let storage = Storage.storage().reference()
        let date = readableDate(from: time)
        let imageRef = storage.child("\(userId)/\(date)/\(postType)")
        let dailyImageRef = storage.child("\(userId)/\(postType)")
        let allPicsRef = storage.child("\(userId)/all_pics/\(Int(time.timeIntervalSince1970)).jpg")

        doDelete = false
        let tempPostID = postID
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        if let currLocation = location {
            metadata.customMetadata = [
                "timestamp": "\(timestamp!.timeIntervalSince1970)",
                "latitude": "\(currLocation.coordinate.latitude)",
                "longitude": "\(currLocation.coordinate.longitude)",
                "postID": postID
                
            ]
        } else {
            metadata.customMetadata = ["timestamp": "\(timestamp!.timeIntervalSince1970)", "postID" : postID]
        }

        imageRef.putData(imageData, metadata: metadata) { (metadata, error) in
            if let error = error {
                print("Upload error: \(error.localizedDescription)")
                return
            }
            imageRef.downloadURL { (url, error) in
                if let error = error {
                    print("Failed to download: \(error.localizedDescription)")
                } else if let downloadURL = url {
                    print("Image uploaded successfully: \(downloadURL.absoluteString)")
                    self.db.collection("mapPosts").document(tempPostID!).updateData(["time" : Date().timeIntervalSince1970, "imageURL" : downloadURL.absoluteString])
                }
            }
        }
        
        dailyImageRef.putData(imageData, metadata: metadata) { (metadata, error) in
            if let error = error {
                print("Upload error: \(error.localizedDescription)")
                return
            }
            dailyImageRef.downloadURL { (url, error) in
                if let error = error {
                    print("Failed to download: \(error.localizedDescription)")
                } else if let downloadURL = url {
                    print("Image uploaded successfully: \(downloadURL.absoluteString)")
                    
                    // update daily photo streak in user's document
                    self.db.collection("users").document(userId).getDocument() {
                        (document, error) in
                        if let error = error{
                            print("Error retrieving user document: \(error.localizedDescription)")
                            return
                        }
                        if let document = document, let data = document.data(){
                            guard let lastDailyPhotoDate = data["lastDailyPhotoDate"] as? TimeInterval else{
                                print("Error retrieving lastDailyPhotoDate")
                                return
                            }
                            guard let currentStreak = data["streak"] as? Int else{
                                print("Error retrieving streak")
                                return
                            }
                            let calendar = Calendar.current
                            
                            if calendar.isDateInYesterday(Date(timeIntervalSince1970: lastDailyPhotoDate)){
                                self.db.collection("users").document(userId).updateData(["streak" : currentStreak + 1])
                            }
                            else if !calendar.isDateInToday(Date(timeIntervalSince1970: lastDailyPhotoDate)){
                                self.db.collection("users").document(userId).updateData(["streak" : 1])
                            }
                            self.db.collection("users").document(userId).updateData(["lastDailyPhotoDate" : Date().timeIntervalSince1970])
                            self.db.collection("mapPosts").document(tempPostID!).updateData(["time" : Date().timeIntervalSince1970, "imageURL" : downloadURL.absoluteString])
                            
                        }
                    }
                    
                    
                }
            }
        }
        
        allPicsRef.putData(imageData, metadata: metadata) { (_, error) in
            if let error = error {
                print("Upload error (all_pics): \(error)")
                return
            }
            allPicsRef.downloadURL { (url, error) in
                if let url = url {
                    print("Also added to all_pics: \(url.absoluteString)")
                }
            }
        }
        postID = nil
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "tagSegue", let nextVC = segue.destination as? TagFriendsViewController{
            guard let uid = Auth.auth().currentUser?.uid else{
                return
            }
            nextVC.uid = uid
            nextVC.delegate = self
            nextVC.postID = postID
        }
    }
}
