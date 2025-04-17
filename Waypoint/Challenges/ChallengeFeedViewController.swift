//  Project: Waypoint
//  Course: CS371L
//
//  ChallengeFeedViewController.swift
//  Waypoint
//
//  Created by Tony Ngo on 3/28/25.
//

import UIKit
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

class ChallengeFeedViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var noDataLabel: UILabel!
    
    // variables for controlling the feed
    var feed: [FeedInfo] = []
    var allUIds: [String] = []
    var didDailyChallenge: Bool = false
    var didMonthChallenge: [Bool] = [false, false, false, false, false]
    
    // allows us access into the Google Firebase Firestore
    let db = Firestore.firestore()
    let manager = FirebaseManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
    }
    
    // When the view appears, recreate the feed
    override func viewWillAppear(_ animated: Bool) {
        tableView.isHidden = true
        noDataLabel.isHidden = false
        feed.removeAll()
        getAllUsers{
            self.loadTableInformation2()
        }
    }
    
    // get all of the current user's friends and set up which challenge photos to look for
    func getAllUsers(handler: @escaping () -> Void){
        guard let uid = Auth.auth().currentUser?.uid else{
            print("user is not logged in")
            return
        }
        db.collection("users").document(uid).getDocument(){
            (document, error) in
            if let error = error{
                print("Error fetching logged in user document: \(error.localizedDescription)")
                return
            }
            else{
                if let document = document, let data = document.data(),
                   let getDailyChallenge = data["getDailyChallenge"] as? TimeInterval,
                   let didMonthlyChallenges = data["didMonthlyChallenges"] as? [Bool],
                   let currentUserFriendsList = data["friends"] as? [[String: Any]]{

                    let calendar = Calendar.current
                    self.didDailyChallenge = calendar.isDateInToday(Date(timeIntervalSince1970: getDailyChallenge))
                    self.didMonthChallenge = didMonthlyChallenges
                    self.allUIds = [uid]
                    for entry in currentUserFriendsList{
                        self.allUIds.append(entry["uid"] as! String)
                    }
                    handler()
                }
                else{
                    print("Error fetching logged in user document")
                }
            }
        }
    }

    
    
    // https://medium.com/@viveksehrawat36/migrating-from-dispatchgroup-to-async-await-with-taskgroup-in-swift-44725e207f3c
    func loadTableInformation2(){
        let currentMomentInTime = Date()
        let weekdayIndex = Calendar.current.component(.weekday, from: currentMomentInTime)
        
        for uid in allUIds{
            var profilePicture: UIImage?
            var userData: [String: Any]?
            var dailyChallengePhoto: UIImage?
            var dailyChallengeMetadata: [String: String]?
            var dailyChallengePhotoLikes: [String]?
            var dailyChallengePhotoComments: [[String : Any]]?
            var monthlyChallengePhotos = [UIImage?](repeating: nil, count: 5)
            var monthlyChallengeMetadata = [[String: String]?](repeating: nil, count: 5)
            var monthlyChallengePhotosLikes =  [[String]?](repeating: nil, count: 5)
            var monthlyChallengePhotosComments = [[[String : Any]]?](repeating: nil, count: 5)
            
            Task{
                await withTaskGroup(of: Void.self) { taskGroup in
                    // first get the user document
                    taskGroup.addTask {
                        userData = await self.manager.getUserDocumentData(uid: uid)
                    }
                    // get their profile picture
                    taskGroup.addTask{
                        profilePicture = await self.manager.getProfilePicture(uid: uid)
                    }
                    
                    // get their daily challenge if we have done it
                    if self.didDailyChallenge{
                        // get the photo
                        taskGroup.addTask {
                            let path = "\(uid)/challenges/dailyChallenge/\(weekdayIndex).jpg"
                            dailyChallengePhoto = await self.manager.getChallengePicture(path: path)
                        }
                        // get the metadata of the photo
                        taskGroup.addTask {
                            let path = "\(uid)/challenges/dailyChallenge/\(weekdayIndex).jpg"
                            dailyChallengeMetadata = await self.manager.getImageMetadata(path: path)
                        }
                    }
                    
                    // go through each of the 5 monthly challenges
                    for index in 1..<6{
                        let path = "\(uid)/challenges/monthlyChallenges/\(index - 1).jpg"
                        // only check if we did it ourselves
                        if self.didMonthChallenge[index - 1]{
                            // get the photo
                            taskGroup.addTask {
                                monthlyChallengePhotos[index - 1] = await self.manager.getChallengePicture(path: path)
                            }
                            
                            // get the metadata
                            taskGroup.addTask{
                                monthlyChallengeMetadata[index - 1] = await self.manager.getImageMetadata(path: path)
                            }
                        }
                    }
                }
                
                await withTaskGroup(of: Void.self){ taskGroup in
                    // get the likes of the daily photo
                    taskGroup.addTask {
                        if await self.didDailyChallenge, let postID = dailyChallengeMetadata?["postID"]{
                            dailyChallengePhotoLikes = await self.manager.getChallengePostLikes(postID: postID)
                        }
                    }
                    // get the comments of the daily photo
                    taskGroup.addTask {
                        if await self.didDailyChallenge, let postID = dailyChallengeMetadata?["postID"]{
                            dailyChallengePhotoComments = await self.manager.getChallengePostComments(postID: postID)
                        }
                    }
                }
                
                await withTaskGroup(of: Void.self) { taskGroup in
                    for index in 1..<6{
                        if self.didMonthChallenge[index - 1]{
                            // get the likes
                            taskGroup.addTask{
                                guard let postID = monthlyChallengeMetadata[index - 1]?["postID"]! else{
                                    return
                                }
                                monthlyChallengePhotosLikes[index - 1] = await self.manager.getChallengePostLikes(postID: postID)
                            }
                            
                            
                            taskGroup.addTask{
                                guard let postID = monthlyChallengeMetadata[index - 1]?["postID"]! else{
                                    return
                                }
                                monthlyChallengePhotosComments[index - 1] = await self.manager.getChallengePostComments(postID: postID)
                            }
                        }
                    }
                }
                
                if self.didDailyChallenge{
                    if let username = userData?["username"],
                       let profilePicture = profilePicture,
                       let mainPicture = dailyChallengePhoto,
                       let likes = dailyChallengePhotoLikes,
                       let comments = dailyChallengePhotoComments,
                       let postID = dailyChallengeMetadata?["postID"]{
                        let dailyChallengeFeed = FeedInfo(username: userData?["username"] as? String, indicator: "daily", profilePicture: profilePicture, mainPicture: dailyChallengePhoto, likes: dailyChallengePhotoLikes, comments: dailyChallengePhotoComments, uid: uid, monthlyChallngeIndex: -1, postID: dailyChallengeMetadata?["postID"])
                        self.feed.append(dailyChallengeFeed)
                    }
                }
                
                for index in 1..<6{
                    if self.didMonthChallenge[index - 1]{
                        if let username = userData?["username"],
                           let profilePicture = profilePicture,
                           let mainPicture = monthlyChallengePhotos[index - 1],
                           let likes = monthlyChallengePhotosLikes[index - 1],
                           let comments = monthlyChallengePhotosComments[index - 1],
                           let postID = monthlyChallengeMetadata[index - 1]?["postID"]{
                            let monthlyChallengeFeed = FeedInfo(username: userData?["username"] as? String, indicator: "monthly", profilePicture: profilePicture, mainPicture: monthlyChallengePhotos[index - 1], likes: monthlyChallengePhotosLikes[index - 1], comments: monthlyChallengePhotosComments[index - 1], uid: uid, monthlyChallngeIndex: index, postID: monthlyChallengeMetadata[index - 1]?["postID"])
                            self.feed.append(monthlyChallengeFeed)
                        }
                        
                    }
                }
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    if self.feed.count > 0{
                        self.tableView.isHidden = false
                        self.noDataLabel.isHidden = true
                    }
                }
            }
        }
    }
    
    
    
    // grab information from Firebase and update the table
//    func loadTableInformation(){
//        let storage = Storage.storage()
//        let storageRef = storage.reference()
//        
//        let currentMomentInTime = Date()
//        let weekdayIndex = Calendar.current.component(.weekday, from: currentMomentInTime)
//        
//        for uid in allUIds{
//            let dailyChallengePicRef = storageRef.child("\(uid)/challenges/dailyChallenge/\(weekdayIndex).jpg")
//            let profilePicRef = storageRef.child("\(uid)/profile_pic.jpg")
//            var newFeedUsername: String!
//            var newFeedProfilePicture: UIImage!
//            // first ensure that we can access the user document from firebase
//            db.collection("users").document(uid).getDocument() { document, error in
//                if let error = error{
//                    print("Error reading user document: \(error.localizedDescription)")
//                }
//                else if let data = document?.data(){
//                    newFeedUsername = data["username"] as? String
//                    
//                    // get that user's profile picture
//                    // if we cannot get that user's profile picture abandon that user
//                    profilePicRef.getData(maxSize: 10 * 1024 * 1024) {
//                         data, error in
//                        if let error = error{
//                            print("Error fetching profile picture for \(uid): \(error.localizedDescription)")
//                        }
//                        else if let data = data, let image = UIImage(data: data){
//                            newFeedProfilePicture = image
//                            var newFeedMainPicture: UIImage!
//                            let newFeedComments: [CommentInfo] = []
//                            
//                            // get their daily challenge if it exists
//                            // only get them if the logged in user has also completed that challenge
//                            if self.didDailyChallenge{
//                                dailyChallengePicRef.getData(maxSize: 10 * 1024 * 1024) {
//                                    [weak self] (data, error) in
//                                    if let error = error{
//                                        print("Error fetching daily photo for \(uid): \(error.localizedDescription)")
//                                    }
//                                    else{
//                                        if let data = data, let image = UIImage(data: data){
//                                            newFeedMainPicture = image
//                                            
//                                            dailyChallengePicRef.getMetadata {
//                                                (metadata, error) in
//                                                if let error = error{
//                                                    print("error getting metadata!")
//                                                    return
//                                                }
//                                                else{
//                                                    if let metadata = metadata{
//                                                        if let postID = metadata.customMetadata?["postID"]{
//                                                            
//                                                            var newFeedLikes: [String] = []
//                                                            self?.db.collection("challengePosts").document(postID).getDocument() {
//                                                                (document, error) in
//                                                                if let error = error{
//                                                                    print("error getting challengePost: \(error.localizedDescription)")
//                                                                }
//                                                                else{
//                                                                    if let document = document, let data = document.data(){
//                                                                        newFeedLikes = data["likes"] as! [String]
//                                                                        let dailyImageIntoFeed = FeedInfo(username: newFeedUsername, indicator: "daily", profilePicture: newFeedProfilePicture, mainPicture: newFeedMainPicture, likes: newFeedLikes, comments: newFeedComments, uid: uid, monthlyChallngeIndex: -1, postID: postID)
//                                                                        self?.feed.append(dailyImageIntoFeed)
//                                                                        self?.tableView.reloadData()
//                                                                        self?.tableView.isHidden = false
//                                                                        self?.noDataLabel.isHidden = true
//                                                                    }
//                                                                }
//                                                            }
//                                                        }
//                                                    }
//                                                }
//                                            }
//                                        }
//                                    }
//                                }
//                            }
//                            
//                            // get all of their monthly challenge if it exists
//                            // only get them if the logged in user has also completed that challenge
//                            for index in 1..<6{
//                                let monthlyChallengePicRef = storageRef.child("\(uid)/challenges/monthlyChallenges/\(index - 1).jpg")
//                                
//                                if self.didMonthChallenge[index - 1]{
//                                    monthlyChallengePicRef.getData(maxSize: 10 * 1024 * 1024) {
//                                        [weak self] (data, error) in
//                                        if let error = error{
//                                            print("Error fetching monthly photo for \(uid): \(error.localizedDescription)")
//                                        }
//                                        else{
//                                            if let data = data, let image = UIImage(data: data){
//                                                
//                                                monthlyChallengePicRef.getMetadata {
//                                                    (metadata, error) in
//                                                    if let error = error{
//                                                        print("error getting metadata: \(error.localizedDescription)")
//                                                        return
//                                                    }
//                                                    else{
//                                                        if let metadata = metadata{
//                                                            if let postID: String = metadata.customMetadata?["postID"]{
//                                                                var newFeedLikes: [String] = []
//                                                                self?.db.collection("challengePosts").document(postID).getDocument() {
//                                                                    (document, error) in
//                                                                    if let error = error{
//                                                                        print("error getting doc: \(error.localizedDescription)")
//                                                                    }
//                                                                    else{
//                                                                        if let document = document, let data = document.data(){
//                                                                            newFeedLikes = data["likes"] as! [String]
//                                                                            let newFeedMainPicture = image
//                                                                            let dailyImageIntoFeed = FeedInfo(username: newFeedUsername, indicator: "monthly", profilePicture: newFeedProfilePicture, mainPicture: newFeedMainPicture, likes: newFeedLikes, comments: newFeedComments, uid: uid, monthlyChallngeIndex: index,
//                                                                                                              postID: postID)
//                                                                            self?.feed.append(dailyImageIntoFeed)
//                                                                            self?.tableView.reloadData()
//                                                                            self?.tableView.isHidden = false
//                                                                            self?.noDataLabel.isHidden = true
//                                                                        }
//                                                                    }
//                                                                }
//                                                            }
//                                                        }
//                                                    }
//                                                }
//                                            }
//                                        }
//                                    }
//                                }
//                            }
//                        }
//                    }
//                }
//                else{
//                    print("Error getting document")
//                }
//            }
//        }
//    }
    
    
    func handleLike(rowIndex: Int) async -> Bool{
        
        guard let uid = Auth.auth().currentUser?.uid else{
            print("User is not logged in")
            return false
        }
        
        let currentFeedInfo: FeedInfo = feed[rowIndex]
        let currentPostID: String = currentFeedInfo.postID
        let postReference = db.collection("challengePosts").document(currentPostID)
        
        
        // copied from https://firebase.google.com/docs/firestore/manage-data/transactions
        do {
            var didLike: Bool = false
          let _ = try await db.runTransaction({ (transaction, errorPointer) -> Any? in
            let postDocument: DocumentSnapshot
            do {
              try postDocument = transaction.getDocument(postReference)
            } catch let fetchError as NSError {
              errorPointer?.pointee = fetchError
              return false
            }

            guard var oldLikes = postDocument.data()?["likes"] as? [String] else {
              let error = NSError(
                domain: "AppErrorDomain",
                code: -1,
                userInfo: [
                  NSLocalizedDescriptionKey: "Unable to retrieve population from snapshot \(postDocument)"
                ]
              )
              errorPointer?.pointee = error
              return false
            }

            // Note: this could be done without a transaction
            //       by updating the population using FieldValue.increment()
              if oldLikes.contains(uid){
                  oldLikes.removeAll { $0 == uid}
              }
              else{
                  oldLikes.append(uid)
                  didLike = true
              }
              DispatchQueue.main.async {
                  self.feed[rowIndex].likes = oldLikes
                  self.tableView.reloadData()
              }
            transaction.updateData(["likes": oldLikes], forDocument: postReference)
            return didLike
          })
            print("Transaction successfully committed!")
            return didLike
        } catch {
          print("Transaction failed: \(error)")
        }
        return false
    }
    
    
    
    
    // table view specific functions (conforming)
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return feed.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FeedCell", for: indexPath) as! FeedTableViewCell
        let cInfo = feed[indexPath.row]
        cInfo.describe()
        
        
        
        
        cell.selectionStyle = .none
        cell.usernameLabel.text = cInfo.username
        cell.typeLabel.text = "\(cInfo.indicator!)" + "\(cInfo.indicator! == "monthly" ? " challenge \(String(cInfo.monthlyChallengeIndex))" : "")"
        cell.profilePictureView.image = cInfo.profilePicture
        cell.mainImageView.image = cInfo.mainPicture
        cell.delegate = self
        cell.index = indexPath.row
        let uid = Auth.auth().currentUser?.uid
        let isLiked = cInfo.likes.contains(uid!)
        let imageName = isLiked ? "hand.thumbsup.fill" : "hand.thumbsup"
        cell.likeButton.setImage(UIImage(systemName: imageName), for: .normal)
        cell.likeLabel.text = String(cInfo.likes.count)
        return cell
    }
}
