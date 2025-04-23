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
    
    let spinnerManager = SpinnerManager()
    var delegate: ChallengesViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        makeCircle(view: rotateCameraButton)
        makeCircle(view: flashButton)
        makeCircle(view: cameraButton)
        
        
        hideAllButtons()
    }
    
    // update the UI and get stuff ready
    override func viewWillAppear(_ animated: Bool) {
        challengeDescription.text = challengeDescriptionText ?? ""
        challengePoints.text = "\(challengePointsText ?? "0") points"
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
        self.spinnerManager.showSpinner(view: view)
        getMonthlyChallengePhoto{
            if self.didDoMonthlyChallenge{
                self.hideAllButtons()
            }
            else{
                self.spinnerManager.hideSpinner()
                self.showCameraButtons()
                self.photoManager.setupCaptureSession(with: .back, view: self.cameraDisplayView)
            }
        }
    }
    
    func makeCircle(view: UIView){
        view.layer.cornerRadius = view.frame.width / 2
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        if photoManager != nil{
            photoManager.dismissCamera()
            photoManager = nil
        }
    }

    // turn the flash on or off for the camera
    @IBAction func flashButtonPressed(_ sender: Any) {
        if photoManager.toggleFlash(){
            self.flashButton.setImage(UIImage(systemName: "bolt"), for: .normal)
        }
        else{
            self.flashButton.setImage(UIImage(systemName: "bolt.slash"), for: .normal)
        }
    }
    
    // flip from the back or front camera
    @IBAction func flipCamera(_ sender: Any) {
        photoManager.flipCamera()
    }
    
    // actually take a picture
    @IBAction func capturePicture(_ sender: UIButton) {
        photoManager.capturePhoto()
    }
    
    // photo canceled after taken
    @IBAction func backButtonPressed(_ sender: UIButton) {
        sender.isHidden = true
        resumeCamera()
    }
    
    // resume the camera session
    func resumeCamera(){
        self.cameraDisplayView.subviews.forEach { $0.removeFromSuperview() }
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
        
        let postRef = self.db.collection("challengePosts").document()
        let postID = postRef.documentID
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = ["timestamp": "\(timestamp!.timeIntervalSince1970)",
                                   "id": String(index!), "postID" : postID]

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
                    
                    let postData: [String: Any] = ["imageURL" : url?.absoluteString, "userID" : userId, "time": Date().timeIntervalSince1970, "likes" : [], "comments" : []]
                    postRef.setData(postData)
                    
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
                                else{
                                    self.delegate.updateMonthlyChallenges(index: self.index!)
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
    
    // actually upload the photo and update necessary information
    @IBAction func sendPhotoButtonPressed(_ sender: Any) {
        guard capturedData != nil else {
            print("No image data to upload")
            return
        }
        
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
                    self.spinnerManager.hideSpinner()
                    self.cameraDisplayView.subviews.forEach { $0.removeFromSuperview() }
                    let imageView = UIImageView(frame: self.cameraDisplayView.bounds)
                    imageView.image = image
                    imageView.contentMode = .scaleAspectFill
                    imageView.clipsToBounds = true
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
