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

class ChallengesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, AVCapturePhotoCaptureDelegate {
    
    @IBOutlet weak var dailyView: UIView!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var pointsLabel: UILabel!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var rotateCameraButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var monthlyView: UIView!
    @IBOutlet weak var monthlyTableView: UITableView!
    @IBOutlet weak var segmentControl: UISegmentedControl!
    @IBOutlet weak var cameraDisplayView: UIView!
    
    // camera information
    var capturedData: Data?
    var timestamp: Date?
    
    // challanges info
    var dailyChallenge: ChallengeInfo!
    var hasDoneDailyChallenge: Bool = false
    var monthlyChallenges: [ChallengeInfo]!
    var currentDateSince1970: TimeInterval!
    var monthlyChallengeIndex: Int!
    
    // allows us access into the Google Firebase Firestore
    let db = Firestore.firestore()
    
    var photoManager: ChallengePhotoManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        monthlyTableView.delegate = self
        monthlyTableView.dataSource = self
        hideAllButtons()
    }
    
    // when the view appears do different things depending o nthe index
    override func viewWillAppear(_ animated: Bool) {
        
        // coming back from the feed ensure that we go back to daily challenge
        if segmentControl.selectedSegmentIndex == 2 {
            segmentControl.selectedSegmentIndex = 0
        }
        
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
        
        dailyView.isHidden = true
            
        // on the daily challenge segment
        if segmentControl.selectedSegmentIndex == 0 {
            // get the current date and load daily/monthly challenges
            // time doesn't start til 1970
            currentDateSince1970 = Date().timeIntervalSince1970
            cameraDisplayView.subviews.forEach { $0.removeFromSuperview() }
            loadChallenges{
                self.monthlyTableView.reloadData()
                self.deleteDailyChallenge{
                    self.loadDailyChallengePhoto()
                    if self.hasDoneDailyChallenge{
                        self.hideAllButtons()
                    }
                    else{
                        self.dailyView.isHidden = false
                        self.showCameraButtons()
                        self.photoManager.setupCaptureSession(with: .back, view: self.cameraDisplayView)
                    }
                }
            }
        }
    }
    
    // ensure that if we ever leave then we do not need the camera running anymore
    override func viewDidDisappear(_ animated: Bool) {
        if photoManager != nil{
            photoManager.dismissCamera()
            photoManager = nil
        }
    }
    
    // checks to see if the given date is today or not.
    // if false that means that the user has not uploaded their daily challenge today
    func hasUploadedDailyChallenge(_ timestamp: TimeInterval) -> Bool{
        let uploadDate = Date(timeIntervalSince1970: timestamp)
        let calendar = Calendar.current
        return calendar.isDateInToday(uploadDate)
    }
    
    // delete the daily challenge photo and user data
    func deleteDailyChallenge(handler: @escaping () -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("User is not logged in")
            return
        }
        
        db.collection("users").document(uid).getDocument {
            (document, error) in
            if let error = error {
                print("Error getting user document: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, let data = document.data() else{
                print("Document is nil or document has no data")
                return
            }
        
            if let lastUploadTimestamp = data["getDailyChallenge"] as? TimeInterval {
                self.hasDoneDailyChallenge = self.hasUploadedDailyChallenge(lastUploadTimestamp)
                if !self.hasDoneDailyChallenge {
                    self.deleteOldDailyChallengeImages(userId: uid)
                }
            } else {
                print("getDailyChallenge field not found or wrong type")
            }
            
            // loads photo or sets up camera depending on challenge completion status
            handler()
        }
    }
    
    // actually deletes the image from the Firebase Storage
    func deleteOldDailyChallengeImages(userId: String) {
        let storageRef = Storage.storage().reference()
        let dailyChallengeRef = storageRef.child("\(userId)/challenges/dailyChallenge")

        dailyChallengeRef.listAll { (result, error) in
            if let error = error {
                print("Error listing daily challenge images: \(error)")
                return
            }
            for item in result!.items {
                
                let name = item.name
                
                let dailyChallengeImageRef = storageRef.child("\(userId)/challenges/dailyChallenge/\(name)")
                
                // TODO: delete from firestore
                dailyChallengeImageRef.getMetadata() {
                    (metadata, error) in
                    if let error = error{
                        print("error getting photo metadata! :\(error.localizedDescription)")
                        return
                    }
                    else{
                        if let metadata = metadata, let customMetadata = metadata.customMetadata, let postID = customMetadata["postID"]{
                            self.db.collection("challengePosts").document(postID).delete { error in
                                if let error = error{
                                    print("error: \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                }
                
                
                item.delete {
                    (error) in
                    if let error = error {
                        print("Failed to delete \(item.name): \(error)")
                    }
                    else{
                        print("Deleted \(name)")
                    }
                }
            }
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

    // load the daily photo into the imageView if it exists
    func loadDailyChallengePhoto() {
        if !self.hasDoneDailyChallenge {
            return
        }
        guard let uid = Auth.auth().currentUser?.uid else {
            print("No user logged in")
            return
        }
        
        let storage = Storage.storage()
        let storageRef = storage.reference()
        guard let challengeId = dailyChallenge?.id else {
            print("Cannot find daily challenge id while attempting to get the daily challenge photo")
            return
        }
        
        let dailyChallengePicRef = storageRef.child("\(uid)/challenges/dailyChallenge/\(challengeId).jpg")
        
        dailyChallengePicRef.getData(maxSize: 10 * 1024 * 1024) { [weak self] data, error in
            if let error = error {
                print("Error fetching daily challenge photo: \(error.localizedDescription)")
                return
            }
            if let data = data, let image = UIImage(data: data), let self = self {
                cameraDisplayView.subviews.forEach { $0.removeFromSuperview() }
                let imageView = UIImageView(frame: self.cameraDisplayView.bounds)
                imageView.image = image
                imageView.contentMode = .scaleAspectFill
                self.cameraDisplayView.addSubview(imageView)
                self.dailyView.isHidden = false
            }
        }
    }
    
    // https://medium.com/@dhavalkansara51/completion-handler-in-swift-with-escaping-and-nonescaping-closures-1ea717dc93a4
    // https://medium.com/@bestiosdevelope/what-do-mean-escaping-and-nonescaping-closures-in-swift-d404d721f39d
    // load either the daily or monthly challenges depending on the segment index
    func loadChallenges(handler: @escaping () -> Void){
        if segmentControl.selectedSegmentIndex == 0{
            db.collection("dailyChallenges").getDocuments { (querySnapshot, error) in
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
                        self.descriptionLabel.text = self.dailyChallenge.description
                        self.pointsLabel.text = "Points: \(self.dailyChallenge.points ?? 0)"
                        handler()
                    }
                }
            }
        }
        else if segmentControl.selectedSegmentIndex == 1{
            db.collection("monthlyChallenges").getDocuments {
                (querySnapshot, error) in
                if let error = error{
                    print("Error getting monthly challenges: \(error)")
                }
                else{
                    self.monthlyChallenges = []
                    if let documents = querySnapshot?.documents{
                        // don't know which order so sort them so that we know what challenge is what
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
                        handler()
                    }
                   
                }
            }
        }
        
    }
    
    // turn the flash on or off for the camera
    @IBAction func flashButtonPressed(_ sender: Any) {
        if photoManager.toggleFlash(){
            self.flashButton.setImage(UIImage(systemName: "flashlight.on.fill"), for: .normal)
        }
        else{
            self.flashButton.setImage(UIImage(systemName: "flashlight.slash"), for: .normal)
        }
    }
    
    // flip from the back or front camera
    @IBAction func flipCamera(_ sender: Any) {
        photoManager.flipCamera()
    }
    
    // actually take the picture
    @IBAction func capturePicture(_ sender: UIButton) {
        photoManager.capturePhoto()
    }
    
    // actually upload the photo and update necessary information
    @IBAction func sendPhotoButtonPressed(_ sender: Any) {
        guard capturedData != nil else {
            print("No image data to upload")
            return
        }
        
        guard let uid = Auth.auth().currentUser?.uid else {
            print("User is not logged in!")
            return
        }
        
        db.collection("users").document(uid).getDocument { (document, error) in
            if let document = document, let data = document.data(),
               let lastUploadTime = data["getDailyChallenge"] as? TimeInterval{
                if self.hasUploadedDailyChallenge(lastUploadTime){
                    print("User has attempted to upload daily photo after already uploading one")
                    return
                }
                else{
                    
                    self.uploadImage(imageData: self.capturedData!)
                    if self.photoManager != nil{
                        self.photoManager.dismissCamera()
                        self.photoManager = nil
                    }
                    // update the UI
                    DispatchQueue.main.async {
                        if let imageData = self.capturedData, let image = UIImage(data: imageData) {
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
    
    // actually upload the image to the database
    func uploadImage(imageData: Data) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("User is not logged in!")
            return
        }
        
        let storage = Storage.storage()
        let storageRef = storage.reference()
        
        let postRef = self.db.collection("challengePosts").document()
        let postID = postRef.documentID
        
        let imageRef = storageRef.child("\(uid)/challenges/dailyChallenge/\(dailyChallenge.id!).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = ["timestamp": "\(timestamp!.timeIntervalSince1970)",
                                   "id": String(dailyChallenge.id),
                                   "postID" : postID]

        imageRef.putData(imageData, metadata: metadata) { (metadata, error) in
            if let error = error {
                print("Upload error: \(error.localizedDescription)")
                return
            }
            imageRef.downloadURL { (url, error) in
                if let error = error {
                    print("Failed to get download URL: \(error.localizedDescription)")
                }
                else {
                    self.db.collection("users").document(uid).updateData(["getDailyChallenge" : Date().timeIntervalSince1970])
                    
                    let postData: [String: Any] = ["imageURL" : url?.absoluteString, "userID" : uid, "time": Date().timeIntervalSince1970, "likes" : [], "comments" : []]
                    postRef.setData(postData)
                    
                    // after updating, update information
                    self.updateChallengePoints(points: self.dailyChallenge.points)
                    self.updateStreak()
                }
            }
        }
    }
    
    // update the user's challenge points
    func updateChallengePoints(points: Int){
        guard let uid = Auth.auth().currentUser?.uid else {
            print("User is not logged in while attempting to update the challenge points")
            return
        }
        
        db.collection("users").document(uid).getDocument() {
            (document, error) in
            if let error = error{
                print("Error collecting user document when updating challenge points: \(error.localizedDescription)")
                return
            }
            if let document = document, let data = document.data(){
                guard let currentWeeklyPoints = data["weeklyChallengeScore"] as? Int else{
                    print("Error retrieving weeklyChallengeScore")
                    return
                }
                guard let currentMonthlyPoints = data["monthlyChallengeScore"] as? Int else{
                    print("Error retrieving monthlyChallengeScore")
                    return
                }
                
                self.db.collection("users").document(uid).updateData(["weeklyChallengeScore" : currentWeeklyPoints + points, "monthlyChallengeScore" : currentMonthlyPoints + points])
            }
        }
    }
    
    // update the challenge streak
    func updateStreak(){
        guard let uid = Auth.auth().currentUser?.uid else{
            print("User is not logged in while attempting to update the challenge streak")
            return
        }
        
        db.collection("users").document(uid).getDocument(){
            (document, error) in
            if let error = error{
                print("Error collecting user document when updating challenge streak: \(error.localizedDescription)")
                return
            }
            if let document = document, let data = document.data(){
                guard let lastChallengeCompletedDate = data["lastChallengeCompletedDate"] as? TimeInterval else{
                    print("Error retrieving lastChallengeCompletedDate")
                    return
                }
                guard let currentStreak = data["challengeStreak"] as? Int else{
                    print("Error retrieving challengeStreak")
                    return
                }
                
                let calendar = Calendar.current
                if calendar.isDateInYesterday(Date(timeIntervalSince1970: lastChallengeCompletedDate)){
                    self.db.collection("users").document(uid).updateData(["challengeStreak" : currentStreak + 1])
                }
                else{
                    // reset to 1
                    self.db.collection("users").document(uid).updateData(["challengeStreak" : 1])
                }
                
                self.db.collection("users").document(uid).updateData(["lastChallengeCompletedDate" : Date().timeIntervalSince1970])
            }
        }
    }

    // control the segment control
    @IBAction func onSegmentChange(_ sender: Any) {
        switch segmentControl.selectedSegmentIndex {
        case 0: // daily view
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
                        self.photoManager = ChallengePhotoManager()
                        self.photoManager.onImageCaptured = {
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
                        
                        self.photoManager.setupCaptureSession(with: .back, view: self.cameraDisplayView)
                    }
                }
            }
            dailyView.isHidden = false
            monthlyView.isHidden = true
            view.bringSubviewToFront(dailyView)
        case 1: // monthly view
            if photoManager != nil{
                photoManager.dismissCamera()
                photoManager = nil
            }
            monthlyView.isHidden = false
            dailyView.isHidden = true
            loadChallenges {
                self.monthlyTableView.reloadData()
            }
            view.bringSubviewToFront(monthlyView)
        default:
            print("should never get here")
        }
    }
    
    // table view functions
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
    
    // send data to monthly challenge
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "monthlyChallengeSegue", let nextVC = segue.destination as? CompleteChallengeViewController{
            guard let index = monthlyChallengeIndex else{
                print("index not set!")
                return
            }
            guard let _ = monthlyChallenges else{
                print("monthly challenges is nil!")
                return
            }
            
            nextVC.challengeDescriptionText = monthlyChallenges[index].description
            nextVC.challengePointsText = String(monthlyChallenges[index].points)
            nextVC.index = index
        }
    }
}
