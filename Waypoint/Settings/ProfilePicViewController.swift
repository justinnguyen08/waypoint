//  Project: Waypoint
//  Course: CS371L
//
//  ProfilePicViewController.swift
//  Waypoint
//
//  Created by Pranav Sridhar on 4/2/25.
//

import UIKit
import AVFoundation
import FirebaseStorage
import FirebaseAuth

class ProfilePicViewController: UIViewController, AVCapturePhotoCaptureDelegate {

    var session: AVCaptureSession?
    var device: AVCaptureDevice?
    var preview: AVCaptureVideoPreviewLayer?
    var position: AVCaptureDevice.Position! = .front 
    var photoOutput: AVCapturePhotoOutput?
    var stillImageView: UIImageView?
    var capturedData: Data?
    var validPicture = false
    
    @IBOutlet weak var resumeLiveButton: UIButton!
    @IBOutlet weak var sendPostButton: UIButton!
    @IBOutlet weak var flipButton: UIButton!
    
    @IBOutlet weak var capturePicButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupCaptureSession(with: position)
        
        capturePicButton.layer.cornerRadius = 35
        capturePicButton.clipsToBounds = true
        resumeLiveButton.isHidden = true
        sendPostButton.isHidden = true
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

            self.preview = AVCaptureVideoPreviewLayer(session: session!)
            preview!.videoGravity = .resizeAspectFill
            preview!.frame = view.layer.bounds
            view.layer.insertSublayer(preview!, at: 0)
            
            self.photoOutput = AVCapturePhotoOutput()
            if session!.canAddOutput(photoOutput!) {
                session!.addOutput(photoOutput!)
            } else {
                print("Cannot add photo output to session")
                return
            }

            session!.startRunning()
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
    
    // For right now, just shows the still on the screen at the time the button is pressed.
    @IBAction func capturePicture(_ sender: Any) {
        guard let photoOutput = photoOutput else { return }
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
        validPicture = true
    }
    
    // Saves still image of captured photo
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else { return }
        guard var image = UIImage(data: imageData) else { return }
        
//        timestamp = Date()
//
//        if let exifMeta = photo.metadata[kCGImagePropertyExifDictionary as String] as? [String: Any],
//           let originalDate = exifMeta[kCGImagePropertyExifDateTimeOriginal as String] as? String {
//            print("EXIF Timestamp: \(originalDate)")
//        } else {
//            print("Using current timestamp: \(timestamp)")
//        }
        if self.position == .front {
            guard let cgImage = image.cgImage else { return }
            image = UIImage(cgImage: cgImage, scale: image.scale, orientation: .leftMirrored)
        }
        
        DispatchQueue.main.async {
            self.session?.stopRunning()
            self.preview?.removeFromSuperlayer()
            
            if self.stillImageView == nil {
                self.stillImageView = UIImageView(frame: self.view.bounds)
                self.stillImageView!.contentMode = .scaleAspectFill
                self.stillImageView!.clipsToBounds = true
                self.view.insertSubview(self.stillImageView!, belowSubview: self.resumeLiveButton)
            }
            
            self.resumeLiveButton.isHidden = false
//            self.tagFriendsButton.isHidden = false
            self.sendPostButton.isHidden = false
//            self.pinPhotoButton.isHidden = false
            self.stillImageView!.image = image
            self.flipButton.isHidden = true
            
            self.capturedData = imageData
        }
    }
    
    
    // Resume live feed, after returning from the still view
    @IBAction func resumeLiveFeed(_ sender: UIButton) {
        stillImageView?.removeFromSuperview()
        stillImageView = nil
        sender.isHidden = true
        sendPostButton.isHidden = true
//        pinPhotoButton.isHidden = true
//        tagFriendsButton.isHidden = true
        flipButton.isHidden = false
        setupCaptureSession(with: position)
        validPicture = false
        capturedData = nil
    }
    
    
    @IBAction func onSendPressed(_ sender: Any) {
        guard let imageData = capturedData else {
            print("Take a picture first")
            return
        }
        if (!validPicture) {
            print("Picture already uploaded")
            return
        }
        uploadImage(imageData: imageData)
        validPicture = false
//        resumeLiveFeed(sender)
    }
    
    
    func uploadImage(imageData: Data) {
        guard let user = Auth.auth().currentUser else { return }
        let userId = user.uid
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let imageRef = storageRef.child("\(userId)/profile_pic.jpg") // Unique filename

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
//        metadata.customMetadata = ["timestamp": "\(timestamp!.timeIntervalSince1970)"]

        imageRef.putData(imageData, metadata: metadata) { (metadata, error) in
            if let error = error {
                print("Upload error: \(error.localizedDescription)")
                return
            }
            imageRef.downloadURL { (url, error) in
                if let error = error {
                    print("Failed to get download URL: \(error.localizedDescription)")
                } else if let downloadURL = url {
                    print("Image uploaded successfully: \(downloadURL.absoluteString)")
                }
            }
        }
    }

    
}
