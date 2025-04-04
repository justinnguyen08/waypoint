//  Project: Waypoint
//  Course: CS371L
//
//  ChallengesViewController.swift
//  Waypoint
//
//  Created by Tony Ngo on 3/10/25.
//

import UIKit
import AVFoundation
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

var challengeText = ["Testing"]

class ChallengesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, AVCapturePhotoCaptureDelegate {
    

    @IBOutlet weak var dailyView: UIView!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var rotateCameraButton: UIButton!
    
    @IBOutlet weak var backButton: UIButton!
    
    @IBOutlet weak var monthlyView: UIView!
    @IBOutlet weak var monthlyTableView: UITableView!
    
    @IBOutlet weak var segmentControl: UISegmentedControl!
    
    
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
    
    // challanges info
    var dailyChallenge: ChallengeInfo!
    var monthlyChallenges: [ChallengeInfo]!
    var currentDateSince1970: TimeInterval!
    
    var didDoDailyChallenge: Bool!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        dailyView.isHidden = false
        monthlyView.isHidden = true
        self.sendButton.isHidden = true
        self.backButton.isHidden = true
        
        monthlyTableView.delegate = self
        monthlyTableView.dataSource = self
        
        currentDateSince1970 = Date().timeIntervalSince1970
        loadChallenges()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if didDoDailyChallenge{
            
        }
        else{
            setupCaptureSession(with: position)
        }
    }
    
    
    
    func loadChallenges(){
        FirestoreManager.shared.db.collection("dailyChallenges").getDocuments { (querySnapshot, error) in
            if let error = error {
                print("Error getting documents: \(error)")
            } else {
                let currentMomentInTime = Date()
                let weekdayIndex = Calendar.current.component(.weekday, from: currentMomentInTime)
                print("Current weekday index: \(weekdayIndex)")
                if let documents = querySnapshot?.documents {
                    let sortedDocumentsById = documents.sorted {
                        ($0.data()["id"] as? Int ?? 0) < ($1.data()["id"] as? Int ?? 0)
                    }
                    // set the daily challenge
                    self.dailyChallenge = ChallengeInfo(data: sortedDocumentsById[weekdayIndex].data())
                }
            }
        }
        
    }
    
    func dismissCamera(){
        session?.stopRunning()
        session = nil
        preview?.removeFromSuperlayer()
        preview = nil
    }
    
    // Start live camera session, request access to camera if needed
    func setupCaptureSession(with position: AVCaptureDevice.Position) {
        self.tabBarController?.tabBar.isHidden = true
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
            
            let previewWidth: CGFloat = view.safeAreaLayoutGuide.layoutFrame.width
            let previewHeight: CGFloat = 500
            
            let xOffset = view.safeAreaLayoutGuide.layoutFrame.minX
            let yOffset = dailyView.frame.minY + 30
            
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
    
    // For right now, just shows the still on the screen at the time the button is pressed.
    @IBAction func capturePicture(_ sender: UIButton) {
        guard let photoOutput = photoOutput else { return }
        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
        photoOutput.capturePhoto(with: settings, delegate: self)
        validPicture = true
        self.backButton.isHidden = false
        self.view.bringSubviewToFront(self.backButton)
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
            print("Using current timestamp: \(timestamp)")
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
                let yOffset = self.dailyView.frame.minY + 30
                
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
            
            self.rotateCameraButton.isHidden = true
            self.flashButton.isHidden = true
            self.cameraButton.isHidden = true
            
            self.sendButton.isHidden = false
            self.backButton.isHidden = false
            
            self.capturedData = imageData
        }
    }
    
    @IBAction func sendPhotoButtonPressed(_ sender: Any) {
        guard let imageData = capturedData else {
            print("No image data to upload")
            return
        }
        if (!validPicture) {
            print("Picture already uploaded")
            return
        }
        uploadImage(imageData: self.capturedData!)
        resumeCamera()
        validPicture = false
    }
    
    
    @IBAction func backButtonPressed(_ sender: UIButton) {
        sender.isHidden = true
        resumeCamera()
    }
    
    func resumeCamera(){
        stillImageView?.removeFromSuperview()
        stillImageView = nil
        sendButton.isHidden = true
        rotateCameraButton.isHidden = false
        cameraButton.isHidden = false
        flashButton.isHidden = false
        setupCaptureSession(with: position)
        validPicture = false
        capturedData = nil
    }
    
    func uploadImage(imageData: Data) {
        guard let user = Auth.auth().currentUser else { return }
        let userId = user.uid
        let storage = Storage.storage()
        let storageRef = storage.reference()
        
        
        let imageRef = storageRef.child("\(userId)/challenges/dailyChallenge/\(timestamp!.timeIntervalSince1970).jpg") // Unique filename

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = ["timestamp": "\(timestamp!.timeIntervalSince1970)",
                                   "id": String(dailyChallenge.id)]

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
    
    
    
    
    
    
    
    
    
    @IBAction func onSegmentChange(_ sender: Any) {
        
        switch segmentControl.selectedSegmentIndex {
        case 0: // daily view
            dailyView.isHidden = false
            monthlyView.isHidden = true
            view.bringSubviewToFront(dailyView)
            setupCaptureSession(with: position)
        case 1: // monthly view
            monthlyView.isHidden = false
            dailyView.isHidden = true
            monthlyTableView.reloadData()
            view.bringSubviewToFront(monthlyView)
            dismissCamera()
        case 2: // segue to feed page
            dismissCamera()
            performSegue(withIdentifier: "ChallengeFeedSegue", sender: self)
        default:
            print("should never get here")
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return challengeText.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = monthlyTableView.dequeueReusableCell(withIdentifier: "challengeCell", for: indexPath)
        cell.textLabel?.text = challengeText[indexPath.row]
        return cell
    }
    

}
