//  Project: Waypoint
//  Course: CS371L
//
//  CompleteChallengeViewController.swift
//  Waypoint
//
//  Created by Tony Ngo on 3/28/25.
//

import UIKit
import AVFoundation
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

class CompleteChallengeViewController: UIViewController, AVCapturePhotoCaptureDelegate{
    
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var rotateCameraButton: UIButton!
    @IBOutlet weak var challengeDescription: UILabel!
    @IBOutlet weak var challengePoints: UILabel!
    @IBOutlet weak var monthlyChallengeSelectedView: UIView!
    @IBOutlet weak var cameraDisplayView: UIView!
    
    
    // camerea type stuff
    var capturedData: Data?
    var timestamp: Date?
    var challengeDescriptionText: String?
    var challengePointsText: String?
    var index: Int?
    var didDoMonthlyChallenge: Bool!
    
    // allows us access into the Google Firebase Firestore
    let db = Firestore.firestore()
    
    var photoManager: ChallengePhotoManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        hideAllButtons()
    }
    
    // update the UI and get stuff ready
    override func viewWillAppear(_ animated: Bool) {
        challengeDescription.text = challengeDescriptionText ?? ""
        challengePoints.text = challengePointsText ?? "0"
        photoManager = ChallengePhotoManager()
        
        photoManager.onImageCaptured = {
            image, imageData in
            self.capturedData = imageData
            self.timestamp = Date()
            
            self.cameraDisplayView.subviews.forEach { $0.removeFromSuperview() }
            let imageView = UIImageView(frame: self.cameraDisplayView.bounds)
            imageView.image = image
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            self.cameraDisplayView.addSubview(imageView)
            
            self.showAfterCameraTakenButtons()
        }
        
        getMonthlyChallengePhoto{
            if self.didDoMonthlyChallenge{
                self.hideAllButtons()
            }
            else{
                self.showCameraButtons()
                self.photoManager.setupCaptureSession(with: .back, view: self.cameraDisplayView)
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        if photoManager != nil{
            photoManager.dismissCamera()
            photoManager = nil
        }
    }
    
//    // Start live camera session, request access to camera if needed
//    func setupCaptureSession(with position: AVCaptureDevice.Position) {
//        // if the camera is already running do not try to set up another one
//        guard !isCameraRunning else{
//            return
//        }
//        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
//            print("Camera unavailable for position \(position.rawValue)")
//            return
//        }
//        self.device = newDevice
//        isCameraRunning = true
//        do {
//            let input = try AVCaptureDeviceInput(device: self.device!)
//            self.session = AVCaptureSession()
//            session!.sessionPreset = .photo
//
//            if session!.canAddInput(input) {
//                session!.addInput(input)
//            } else {
//                print("Cannot add input to session")
//                return
//            }
//
//            self.preview = AVCaptureVideoPreviewLayer(session: session!)
//            preview!.videoGravity = .resizeAspectFill
//            
//            let previewWidth: CGFloat = view.safeAreaLayoutGuide.layoutFrame.width
//            let previewHeight: CGFloat = 500
//            
//            let xOffset = view.safeAreaLayoutGuide.layoutFrame.minX
//            let yOffset = monthlyChallengeSelectedView.frame.minY + 30
//            
//            preview!.frame =  CGRect(x: xOffset, y: yOffset, width: previewWidth, height: previewHeight)
//            
//            view.layer.addSublayer(preview!)
//            
//            self.photoOutput = AVCapturePhotoOutput()
//            if session!.canAddOutput(photoOutput!) {
//                session!.addOutput(photoOutput!)
//            } else {
//                print("Cannot add photo output to session")
//                return
//            }
//
//            session!.startRunning()
//        } catch {
//            print("Unable to create input: \(error.localizedDescription)")
//        }
//    }
    
//    // stop the camera session
//    func dismissCamera(){
//        session?.stopRunning()
//        session = nil
//        preview?.removeFromSuperlayer()
//        preview = nil
//        isCameraRunning = false
//    }
//    
    // turn the flash on or off for the camera
    @IBAction func flashButtonPressed(_ sender: Any) {
//        self.flashMode = (self.flashMode == .off) ? .on : .off
//        if self.flashMode == .on{
//            self.flashButton.setImage(UIImage(systemName: "flashlight.on.fill"), for: .normal)
//        }
//        else{
//            self.flashButton.setImage(UIImage(systemName: "flashlight.slash"), for: .normal)
//        }
        if photoManager.toggleFlash(){
            self.flashButton.setImage(UIImage(systemName: "flashlight.on.fill"), for: .normal)
        }
        else{
            self.flashButton.setImage(UIImage(systemName: "flashlight.slash"), for: .normal)
        }
    }
    
    // flip from the back or front camera
    @IBAction func flipCamera(_ sender: Any) {
//        guard let currentSession = session, currentSession.isRunning else { return }
//        
//        let newPosition: AVCaptureDevice.Position = (position == .front) ? .back : .front
//        currentSession.beginConfiguration()
//        
//        // Stopping active camera
//        if let currentInput = currentSession.inputs.first as? AVCaptureDeviceInput {
//            currentSession.removeInput(currentInput)
//        }
//        
//        // Setting up device
//        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
//            print("Camera unavailable for position \(newPosition.rawValue)")
//            currentSession.commitConfiguration()
//            return
//        }
//        
//        // Add to session
//        do {
//            let newInput = try AVCaptureDeviceInput(device: newDevice)
//            if currentSession.canAddInput(newInput) {
//                currentSession.addInput(newInput)
//                self.device = newDevice
//                self.position = newPosition
//            } else {
//                print("Cannot add new input to session")
//            }
//        } catch {
//            print("Error creating new input: \(error.localizedDescription)")
//        }
//        
//        currentSession.commitConfiguration()
        photoManager.flipCamera()
    }
    
    // actually take a picture
    @IBAction func capturePicture(_ sender: UIButton) {
//        guard let photoOutput = photoOutput else { return }
//        let settings = AVCapturePhotoSettings()
//        settings.flashMode = self.flashMode
//        photoOutput.capturePhoto(with: settings, delegate: self)
//        validPicture = true
//        self.showAfterCameraTakenButtons()
        photoManager.capturePhoto()
    }
    
    // photo canceled after taken
    @IBAction func backButtonPressed(_ sender: UIButton) {
        sender.isHidden = true
        resumeCamera()
    }
    
    // resume the camera session
    func resumeCamera(){
        photoManager.setupCaptureSession(with: .back, view: cameraDisplayView)
        showCameraButtons()
        capturedData = nil
    }
    
    // upload image to the monthlyChallenges
    func uploadImage(imageData: Data) {
        guard let user = Auth.auth().currentUser else { return }
        let userId = user.uid
        let storage = Storage.storage()
        let storageRef = storage.reference()
        
        let imageRef = storageRef.child("\(userId)/challenges/monthlyChallenges/\(index!).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = ["timestamp": "\(timestamp!.timeIntervalSince1970)",
                                   "id": String(index!)]

        imageRef.putData(imageData, metadata: metadata) { (metadata, error) in
            if let error = error {
                print("Upload error: \(error.localizedDescription)")
                return
            }
            imageRef.downloadURL { (url, error) in
                if let error = error {
                    print("Failed to get download URL: \(error.localizedDescription)")
                }
                else{
                    // update the user document information for the monthly challenge status
                    self.db.collection("users").document(userId).getDocument{
                        (document, error) in
                        if let error = error{
                            print("Error getting users document: \(error)")
                            return
                        }
                        
                        guard let document = document, let data = document.data() else{
                            print("Document does not exist or has no data")
                            return
                        }
                        
                        if var monthlyChallengeStatus = data["didMonthlyChallenges"] as? [Bool]{
                            monthlyChallengeStatus[self.index!] = true
                            self.db.collection("users").document(userId).setData(["didMonthlyChallenges" : monthlyChallengeStatus], merge: true){
                                (error) in
                                if let error = error{
                                    print("Error updating didMonthlyChallenges: \(error.localizedDescription)")
                                }
                            }
                        }
                        else{
                            print("monthlyChallengeStatus does not exist")
                        }
                    }
                }
            }
        }
    }
    
//    // Saves still image of captured photo
//    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
//        if let error = error {
//            print("Error capturing photo: \(error.localizedDescription)")
//            return
//        }
//        
//        guard let imageData = photo.fileDataRepresentation() else { return }
//        guard var image = UIImage(data: imageData) else { return }
//        
//        timestamp = Date()
//        
//        if let exifMeta = photo.metadata[kCGImagePropertyExifDictionary as String] as? [String: Any],
//           let originalDate = exifMeta[kCGImagePropertyExifDateTimeOriginal as String] as? String {
//            print("EXIF Timestamp: \(originalDate)")
//        } else {
//            print("Using current timestamp instead")
//        }
//        if self.position == .front {
//            guard let cgImage = image.cgImage else { return }
//            image = UIImage(cgImage: cgImage, scale: image.scale, orientation: .leftMirrored)
//        }
//        
//        DispatchQueue.main.async {
//            self.session?.stopRunning()
//            self.preview?.removeFromSuperlayer()
//            
//            if self.stillImageView == nil {
//                let previewWidth: CGFloat = self.view.safeAreaLayoutGuide.layoutFrame.width
//                let previewHeight: CGFloat = 500
//                
//                let xOffset = self.view.safeAreaLayoutGuide.layoutFrame.minX
//                let yOffset = self.monthlyChallengeSelectedView.frame.minY + 30
//                
//                self.stillImageView = UIImageView(frame: CGRect(x: xOffset, y: yOffset, width: previewWidth, height: previewHeight))
//                self.stillImageView!.contentMode = .scaleAspectFill
//                self.stillImageView!.clipsToBounds = true
//                self.view.addSubview(self.stillImageView!)
//                self.backButton.removeFromSuperview()
//                self.view.addSubview(self.backButton)
//                
//                if let stillImageView = self.stillImageView {
//                    let padding: CGFloat = 10
//                    self.backButton.frame = CGRect(
//                        x: stillImageView.frame.minX + padding,
//                        y: stillImageView.frame.minY + padding,
//                        width: self.backButton.frame.width,
//                        height: self.backButton.frame.height
//                    )
//                }
//            }
//            self.stillImageView!.image = image
//            self.showAfterCameraTakenButtons()
//            self.capturedData = imageData
//        }
//    }
    
    // actually upload the photo and update necessary information
    @IBAction func sendPhotoButtonPressed(_ sender: Any) {
        guard capturedData != nil else {
            print("No image data to upload")
            return
        }
//        if (!validPicture) {
//            print("Picture already uploaded")
//            return
//        }
        
        guard let uid = Auth.auth().currentUser?.uid else {
            print("User is not logged in")
            return
        }
        db.collection("users").document(uid).getDocument { (document, error) in
            if let document = document, let data = document.data(),
               let monthlyChallengeStatus = data["didMonthlyChallenges"] as? [Bool]{
                if monthlyChallengeStatus[self.index!]{
                    print("User has attempted to upload a monthly photo after already uploading one")
                    return
                }
                else{
                    self.didDoMonthlyChallenge = true

                    self.uploadImage(imageData: self.capturedData!)
                    if self.photoManager != nil{
                        self.photoManager.dismissCamera()
                        self.photoManager = nil
                    }

                    DispatchQueue.main.async {
                        if let image = UIImage(data: self.capturedData!) {
                            self.cameraDisplayView.subviews.forEach { $0.removeFromSuperview() }
                            let imageView = UIImageView(frame: self.cameraDisplayView.bounds)
                            imageView.image = image
                            imageView.contentMode = .scaleAspectFill
                            self.cameraDisplayView.addSubview(imageView)
                            self.cameraDisplayView.isHidden = false
                        }
                        self.hideAllButtons()
                    }
                }
            }
        }
    }
    
    // if the user has done the specific monthly challenge then display it
    func getMonthlyChallengePhoto(handler: @escaping () -> Void){
        guard let uid = Auth.auth().currentUser?.uid else {
            print("No user logged in")
            return
        }
        
        guard let monthlyChallengeIndex = index else{
            print("monthly challenge index not set!")
            return
        }
        
        let storage = Storage.storage()
        let storageRef = storage.reference()
        
        let monthlyChallengePicRef = storageRef.child("\(uid)/challenges/monthlyChallenges/\(monthlyChallengeIndex).jpg")
        
        monthlyChallengePicRef.getData(maxSize: 10 * 1024 * 1024) {(data, error) in
            if let error = error {
                self.didDoMonthlyChallenge = false
                print("Error fetching monthly challenge photo: \(error.localizedDescription)")
                handler()
            }
            if let data = data, let image = UIImage(data: data) {
                self.didDoMonthlyChallenge = true
                DispatchQueue.main.async {
                    self.cameraDisplayView.subviews.forEach { $0.removeFromSuperview() }
                    let imageView = UIImageView(frame: self.cameraDisplayView.bounds)
                    imageView.image = image
                    imageView.contentMode = .scaleAspectFill
                    self.cameraDisplayView.addSubview(imageView)
                }
            }
            handler()
        }
    }
    
    // show all buttons necessary for the camera
    func showCameraButtons(){
        flashButton.isHidden = false
        cameraButton.isHidden = false
        rotateCameraButton.isHidden = false
        sendButton.isHidden = true
        backButton.isHidden = true
    }
    
    // show all buttons necessary after the photo is taken
    func showAfterCameraTakenButtons(){
        flashButton.isHidden = true
        cameraButton.isHidden = true
        rotateCameraButton.isHidden = true
        
        sendButton.isHidden = false
        backButton.isHidden = false
        self.view.bringSubviewToFront(self.backButton)
    }
    
    // hide every single button related to the camera and after camera
    func hideAllButtons(){
        flashButton.isHidden = true
        cameraButton.isHidden = true
        rotateCameraButton.isHidden = true
        
        sendButton.isHidden = true
        backButton.isHidden = true
        self.view.bringSubviewToFront(self.backButton)
    }
}
