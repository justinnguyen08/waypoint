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
    var stillImageView: UIImageView?
    var capturedData: Data?
    var validPicture = false
    var timestamp: Date?
    var locManager = CLLocationManager()
    var location: CLLocation?

    
    @IBOutlet weak var sendPostButton: UIButton!
    @IBOutlet weak var pinPhotoButton: UIButton!
    @IBOutlet weak var tagFriendsButton: UIButton!
    @IBOutlet weak var flipButton: UIButton!
    @IBOutlet weak var capturePicButton: UIButton!
    @IBOutlet weak var resumeLiveButton: UIButton!
    
    let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        capturePicButton.layer.cornerRadius = 35
        capturePicButton.clipsToBounds = true
        resumeLiveButton.isHidden = true
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
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            print("Camera unavailable for position \(position.rawValue)")
            return
        }
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
        photoOutput.capturePhoto(with: settings, delegate: self)
        validPicture = true
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
        self.tabBarController?.tabBar.isHidden = false
        flipButton.isHidden = false
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
    
    // upload picture and its metadata to firebase
    func uploadImage(imageData: Data, postType: String) {
        guard let user = Auth.auth().currentUser else { return }
        let userId = user.uid
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let imageRef = storageRef.child("\(userId)/all_pics/\(timestamp!.timeIntervalSince1970).jpg")
        let dailyImageRef = storageRef.child("\(userId)/\(postType)")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        if let currLocation = location {
            metadata.customMetadata = [
                "timestamp": "\(timestamp!.timeIntervalSince1970)",
                "latitude": "\(currLocation.coordinate.latitude)",
                "longitude": "\(currLocation.coordinate.longitude)"
            ]
        } else {
            metadata.customMetadata = ["timestamp": "\(timestamp!.timeIntervalSince1970)"]
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
                            
                        }
                    }
                    
                    
                }
            }
        }
    }
}
