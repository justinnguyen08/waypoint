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
    @IBOutlet weak var monthlyChallengeImage: UIImageView!
    @IBOutlet weak var challengeDescription: UILabel!
    @IBOutlet weak var challengePoints: UILabel!
    @IBOutlet weak var monthlyChallengeSelectedView: UIView!
    
    // camerea type stuff
    var session: AVCaptureSession?
    var device: AVCaptureDevice?
    var preview: AVCaptureVideoPreviewLayer?
    var position: AVCaptureDevice.Position = .back
    var photoOutput: AVCapturePhotoOutput?
    var stillImageView: UIImageView?
    var capturedData: Data?
    var validPicture = false
    var flashMode: AVCaptureDevice.FlashMode = .off
    var timestamp: Date?
    
    var challengeDescriptionText: String?
    var challengePointsText: String?
    var index: Int?
    
    var didDoMonthlyChallenge: Bool!
    
    var isCameraRunning = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        hideAllButtons()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        challengeDescription.text = challengeDescriptionText ?? ""
        challengePoints.text = challengePointsText ?? "0"
        
        getMonthlyChallengePhoto{
            if self.didDoMonthlyChallenge{
                self.hideAllButtons()
            }
            else{
                self.showCameraButtons()
                self.setupCaptureSession(with: .back)
            }
        }
        
    }
    
    // Start live camera session, request access to camera if needed
    func setupCaptureSession(with position: AVCaptureDevice.Position) {
//        print("setting up camera!")
        guard !isCameraRunning else{
            return
        }
//        self.tabBarController?.tabBar.isHidden = true
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            print("Camera unavailable for position \(position.rawValue)")
            return
        }
        self.device = newDevice
        isCameraRunning = true
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
            
            let previewWidth: CGFloat = view.safeAreaLayoutGuide.layoutFrame.width
            let previewHeight: CGFloat = 500
            
            let xOffset = view.safeAreaLayoutGuide.layoutFrame.minX
            let yOffset = monthlyChallengeSelectedView.frame.minY + 30
            
            preview!.frame =  CGRect(x: xOffset, y: yOffset, width: previewWidth, height: previewHeight)
            
            view.layer.addSublayer(preview!)
            
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
    
    func dismissCamera(){
        print("Stopping camera session and removing preview layer...")
        session?.stopRunning()
        session = nil
        if preview != nil{
            preview?.removeFromSuperlayer()
            preview = nil
        }
        isCameraRunning = false
    }
    
    @IBAction func flashButtonPressed(_ sender: Any) {
        self.flashMode = (self.flashMode == .off) ? .on : .off
        if self.flashMode == .on{
            self.flashButton.setImage(UIImage(systemName: "flashlight.on.fill"), for: .normal)
        }
        else{
            self.flashButton.setImage(UIImage(systemName: "flashlight.slash"), for: .normal)
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
    
    @IBAction func capturePicture(_ sender: UIButton) {
        guard let photoOutput = photoOutput else { return }
        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
        photoOutput.capturePhoto(with: settings, delegate: self)
        validPicture = true
        self.showAfterCameraTakenButtons()
    }
    
    @IBAction func backButtonPressed(_ sender: UIButton) {
        sender.isHidden = true
        resumeCamera()
    }
    
    func resumeCamera(){
        stillImageView?.removeFromSuperview()
        stillImageView = nil
        showCameraButtons()
        setupCaptureSession(with: position)
        validPicture = false
        capturedData = nil
    }
    
    func uploadImage(imageData: Data) {
        print("inside uploadImage")
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
                } else if let url = url {
                    
                    let userDocRef = FirestoreManager.shared.db.collection("users").document(userId)
                    
                    userDocRef.getDocument{
                        (document, error) in
                        if let error = error{
                            print("Error getting users document: \(error)")
                            return
                        }
                        
                        guard let document = document, var data = document.data() else{
                            print("Document does not exist or has no data")
                            return
                        }
                        
                        if var monthlyChallengeStatus = data["didMonthlyChallenges"] as? [Bool]{
                            monthlyChallengeStatus[self.index!] = true
                            
                            userDocRef.setData(["didMonthlyChallenges" : monthlyChallengeStatus], merge: true){
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
    
    // Saves still image of captured photo
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
            print("Using current timestamp instead")
        }
        if self.position == .front {
            guard let cgImage = image.cgImage else { return }
            image = UIImage(cgImage: cgImage, scale: image.scale, orientation: .leftMirrored)
        }
        
        DispatchQueue.main.async {
            self.session?.stopRunning()
            self.preview?.removeFromSuperlayer()
            
            if self.stillImageView == nil {
                let previewWidth: CGFloat = self.view.safeAreaLayoutGuide.layoutFrame.width
                let previewHeight: CGFloat = 500
                
                let xOffset = self.view.safeAreaLayoutGuide.layoutFrame.minX
                let yOffset = self.monthlyChallengeSelectedView.frame.minY + 30
                
                self.stillImageView = UIImageView(frame: CGRect(x: xOffset, y: yOffset, width: previewWidth, height: previewHeight))
                self.stillImageView!.contentMode = .scaleAspectFill
                self.stillImageView!.clipsToBounds = true
                self.view.addSubview(self.stillImageView!)
                self.backButton.removeFromSuperview()
                self.view.addSubview(self.backButton)
                
                if let stillImageView = self.stillImageView {
                    let padding: CGFloat = 10
                    self.backButton.frame = CGRect(
                        x: stillImageView.frame.minX + padding,
                        y: stillImageView.frame.minY + padding,
                        width: self.backButton.frame.width,
                        height: self.backButton.frame.height
                    )
                }
            }
            
            self.stillImageView!.image = image
            
            self.showAfterCameraTakenButtons()

            self.capturedData = imageData
        }
    }
    
    @IBAction func sendPhotoButtonPressed(_ sender: Any) {
        guard capturedData != nil else {
            print("No image data to upload")
            return
        }
        if (!validPicture) {
            print("Picture already uploaded")
            return
        }
        
        guard let user = Auth.auth().currentUser else { return }
        let userId = user.uid
        let userDocRef = FirestoreManager.shared.db.collection("users").document(userId)
        userDocRef.getDocument { (document, error) in
            if let document = document, let data = document.data(),
               let monthlyChallengeStatus = data["didMonthlyChallenges"] as? [Bool]{
                if monthlyChallengeStatus[self.index!]{
                    print("User has attempted to upload a monthly photo after already uploading one")
                    return
                }
                else{
                    self.validPicture = false
                    self.didDoMonthlyChallenge = true

                    self.uploadImage(imageData: self.capturedData!)
                    self.dismissCamera()

                    DispatchQueue.main.async {
                        self.stillImageView?.removeFromSuperview()
                        self.stillImageView = nil

                        if let image = UIImage(data: self.capturedData!) {
                            self.monthlyChallengeImage.image = image
                            self.monthlyChallengeImage.isHidden = false
                        }

                        self.hideAllButtons()
                    }
                }
            }
        }
    }
    
    
    func getMonthlyChallengePhoto(completion: @escaping () -> Void){
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
        
        monthlyChallengePicRef.getData(maxSize: 10 * 1024 * 1024) { [weak self] data, error in
            if let error = error {
                self?.didDoMonthlyChallenge = false
                print("Error fetching monthly challenge photo: \(error.localizedDescription)")
                completion()
            }
            if let data = data, let image = UIImage(data: data) {
                self?.didDoMonthlyChallenge = true
                DispatchQueue.main.async {
                    self?.monthlyChallengeImage.image = image
                }
            }
            completion()
        }
    }
    
    
    func showCameraButtons(){
        flashButton.isHidden = false
        cameraButton.isHidden = false
        rotateCameraButton.isHidden = false
        sendButton.isHidden = true
        backButton.isHidden = true
    }
    
    func showAfterCameraTakenButtons(){
        flashButton.isHidden = true
        cameraButton.isHidden = true
        rotateCameraButton.isHidden = true
        
        sendButton.isHidden = false
        backButton.isHidden = false
        self.view.bringSubviewToFront(self.backButton)
    }
    
    func hideAllButtons(){
        flashButton.isHidden = true
        cameraButton.isHidden = true
        rotateCameraButton.isHidden = true
        
        sendButton.isHidden = true
        backButton.isHidden = true
        self.view.bringSubviewToFront(self.backButton)
    }

}
