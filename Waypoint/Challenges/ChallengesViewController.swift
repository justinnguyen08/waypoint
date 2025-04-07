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
    @IBOutlet weak var dailyChallengeImage: UIImageView!
    
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
    var hasDoneDailyChallenge: Bool = false
    var monthlyChallenges: [ChallengeInfo]!
    var currentDateSince1970: TimeInterval!
    var monthlyChallengeIndex: Int!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        monthlyTableView.delegate = self
        monthlyTableView.dataSource = self
        hideAllButtons()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // get the current date and load daily/monthly challenges
        currentDateSince1970 = Date().timeIntervalSince1970
        loadChallenges{
            self.monthlyTableView.reloadData()
            self.deleteDailyChallenge{
                self.loadDailyChallengePhoto()
                if self.hasDoneDailyChallenge{
                    self.hideAllButtons()
                }
                else{
                    self.showCameraButtons()
                    self.setupCaptureSession(with: .back)
                }
            }
        }
        
    }
    
    func hasUploadedDailyChallenge(_ timestamp: TimeInterval) -> Bool{
        let uploadDate = Date(timeIntervalSince1970: timestamp)
        let calendar = Calendar.current
        return calendar.isDateInToday(uploadDate)
    }
    
    func deleteDailyChallenge(completion: @escaping () -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("User not authenticated!")
            return
        }

        let userDocRef = FirestoreManager.shared.db.collection("users").document(uid)
        
        userDocRef.getDocument { (document, error) in
            
            if let error = error {
                print("Firestore error: \(error.localizedDescription)")
                return
            }

            guard let document = document else {
                print("Document is nil")
                return
            }

            guard document.exists else {
                print("Document does not exist")
                return
            }

            guard let data = document.data() else {
                print("Document has no data")
                return
            }
        
            if let lastUploadTimestamp = data["getDailyChallenge"] as? TimeInterval {
                self.hasDoneDailyChallenge = self.hasUploadedDailyChallenge(lastUploadTimestamp)
                if !self.hasDoneDailyChallenge {
                    self.deleteOldDailyChallengeImages(for: uid)
                }
            } else {
                print("getDailyChallenge field not found or wrong type")
            }
            completion()
        }
        
    }

    
    func deleteOldDailyChallengeImages(for userId: String) {
        let storageRef = Storage.storage().reference()
        let dailyChallengeRef = storageRef.child("\(userId)/challenges/dailyChallenge")

        dailyChallengeRef.listAll { (result, error) in
            if let error = error {
                print("Error listing daily challenge images: \(error)")
                return
            }

            for item in result!.items {
                item.delete { error in
                    if let error = error {
                        print("Failed to delete \(item.name): \(error)")
                    } else {
                        print("Deleted \(item.name)")
                    }
                }
            }
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

    
    func loadDailyChallengePhoto() {
        if !self.hasDoneDailyChallenge{
            return
        }
        guard let user = Auth.auth().currentUser else {
            print("No user logged in")
            return
        }
        let userId = user.uid
        let storage = Storage.storage()
        let storageRef = storage.reference()
        guard let challengeId = dailyChallenge?.id else {
            print("Cannot find daily challenge id while attempting to get the daily challenge photo")
            return
        }
        
        let dailyChallengePicRef = storageRef.child("\(userId)/challenges/dailyChallenge/\(challengeId).jpg")
        
        dailyChallengePicRef.getData(maxSize: 10 * 1024 * 1024) { [weak self] data, error in
            if let error = error {
                print("Error fetching daily challenge photo: \(error.localizedDescription)")
                return
            }
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.dailyChallengeImage.image = image
                }
            }
        }
    }
    
    func loadChallenges(completion: @escaping () -> Void){
        if segmentControl.selectedSegmentIndex == 0{
            FirestoreManager.shared.db.collection("dailyChallenges").getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error getting daily challenge: \(error)")
                } else {
                    let currentMomentInTime = Date()
                    let weekdayIndex = Calendar.current.component(.weekday, from: currentMomentInTime)
                    if let documents = querySnapshot?.documents {
                        let sortedDocumentsById = documents.sorted {
                            ($0.data()["id"] as? Int ?? 0) < ($1.data()["id"] as? Int ?? 0)
                        }
                        // set the daily challenge
                        self.dailyChallenge = ChallengeInfo(data: sortedDocumentsById[weekdayIndex - 1].data())
                        completion()
                    }
                }
            }
        }
        else if segmentControl.selectedSegmentIndex == 1{
            FirestoreManager.shared.db.collection("monthlyChallenges").getDocuments {
                (querySnapshot, error) in
                if let error = error{
                    print("Error getting monthly challenges: \(error)")
                }
                else{
                    self.monthlyChallenges = []
                    if let documents = querySnapshot?.documents{
                        let sortedDocumentsById = documents.sorted {
                            ($0.data()["id"] as? Int ?? 0) < ($1.data()["id"] as? Int ?? 0)
                        }
                        for document in sortedDocumentsById{
                            let data = document.data()
                            let challenge = ChallengeInfo(data: data)
                            self.monthlyChallenges.append(challenge)
                        }
                        DispatchQueue.main.async{
                            self.monthlyTableView.reloadData()
                        }
                        completion()
                    }
                   
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
    
    @IBAction func capturePicture(_ sender: UIButton) {
        guard let photoOutput = photoOutput else { return }
        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
        photoOutput.capturePhoto(with: settings, delegate: self)
        validPicture = true
        self.showAfterCameraTakenButtons()
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
            
            self.showAfterCameraTakenButtons()

            self.capturedData = imageData
        }
    }
    
    @IBAction func sendPhotoButtonPressed(_ sender: Any) {
        print("sendPhotoPressed")
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
        print("user is logged in!")
        userDocRef.getDocument { (document, error) in
            print("inside closure")
            if let document = document, let data = document.data(),
               let lastUploadTime = data["getDailyChallenge"] as? TimeInterval{
                if self.hasUploadedDailyChallenge(lastUploadTime){
                    print("User has attempted to upload daily photo after already uploading one")
                    return
                }
                else{
                    self.uploadImage(imageData: self.capturedData!)
                    self.dismissCamera()
                    self.stillImageView?.removeFromSuperview()
                    self.stillImageView = nil
                    if let imageData = self.capturedData, let image = UIImage(data: imageData) {
                        self.dailyChallengeImage.image = image
                        self.dailyChallengeImage.isHidden = false
                    }
                    self.hideAllButtons()
                    self.validPicture = false
                }
            }
        }
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
        
        
        let imageRef = storageRef.child("\(userId)/challenges/dailyChallenge/\(dailyChallenge.id!).jpg")
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
                } else if let url = url {
                    FirestoreManager.shared.db.collection("users").document(userId).setData(["getDailyChallenge" : Date().timeIntervalSince1970], merge: true)
                    print("set data for getDailyChallenge")
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
        case 1: // monthly view
            monthlyView.isHidden = false
            dailyView.isHidden = true
            loadChallenges {
                self.monthlyTableView.reloadData()
            }
            view.bringSubviewToFront(monthlyView)
            
        case 2: // segue to feed page
            dismissCamera()
            monthlyView.isHidden = true
            dailyView.isHidden = true
            performSegue(withIdentifier: "ChallengeFeedSegue", sender: self)
        default:
            print("should never get here")
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return monthlyChallenges?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "challengeCell", for: indexPath)
        
        let challenge = monthlyChallenges?[indexPath.row]
        
        cell.textLabel?.text = challenge?.description
        cell.detailTextLabel?.text = "\(String(challenge?.points ?? 0)) points"
        return cell
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        monthlyChallengeIndex = indexPath.row
        return indexPath
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "monthlyChallengeSegue", let nextVC = segue.destination as? CompleteChallengeViewController{
            
            guard let index = monthlyChallengeIndex else{
                print("index not set!")
                return
            }
            guard let mChallenges = monthlyChallenges else{
                return
            }
            
            nextVC.challengeDescriptionText = monthlyChallenges[index].description
            nextVC.challengePointsText = String(monthlyChallenges[index].points)
            nextVC.index = index
        }
    }
    

}
