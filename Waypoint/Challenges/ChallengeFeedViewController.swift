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
    
    var willClickCellAt: Int!
    var pendingComments: [CommentInfo] = []
    
    
    
    // allows us access into the Google Firebase Firestore
    let db = Firestore.firestore()
    let manager = FirebaseManager()
    
    var profilePicCache: [String: UIImage] = [:]
    var usernameCache: [String: String] = [:]
    
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
    
    func getChallengesFromUser(uid: String, weekdayIndex: Int) async {
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
        // https://www.swiftbysundell.com/articles/connecting-async-await-with-other-swift-code/
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
                    dailyChallengePhotoComments!.sort{
                        $0["timestamp"] as? TimeInterval ?? 0 < $1["timestamp"] as? TimeInterval ?? 0
                    }
                    
                    for comment in dailyChallengePhotoComments!{
                        if let commentUID = comment["uid"] as? String,
                           let commentUserData = await self.manager.getUserDocumentData(uid: commentUID),
                           let username = commentUserData["username"] as? String,
                           let profilePicture = await self.manager.getProfilePicture(uid: commentUID)
                        {
                            DispatchQueue.main.async {
                                self.profilePicCache[commentUID] = profilePicture
                                self.usernameCache[commentUID] = username
                            }
                        }
                    }
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
                        
                        for comment in monthlyChallengePhotosComments[index - 1]!{
                            if let commentUID = comment["uid"] as? String,
                               let commentUserData = await self.manager.getUserDocumentData(uid: commentUID),
                               let username = commentUserData["username"] as? String,
                               let profilePicture = await self.manager.getProfilePicture(uid: commentUID)
                            {
                                DispatchQueue.main.async {
                                    self.profilePicCache[commentUID] = profilePicture
                                    self.usernameCache[commentUID] = username
                                }
                            }
                        }
                    }
                }
            }
        }
        
        if self.didDailyChallenge{
            if let username = userData?["username"],
               let profilePicture = profilePicture,
               let mainPicture = dailyChallengePhoto,
               let likes = dailyChallengePhotoLikes,
               var comments = dailyChallengePhotoComments,
               let postID = dailyChallengeMetadata?["postID"]{
                comments.sort{
                    ($0["timestamp"] as? TimeInterval ?? 0) > ($1["timestamp"] as? TimeInterval ?? 0)
                }
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
                   var comments = monthlyChallengePhotosComments[index - 1],
                   let postID = monthlyChallengeMetadata[index - 1]?["postID"]{
                    
                    comments.sort{
                        ($0["timetamp"] as? TimeInterval ?? 0) > ($1["timestamp"] as? TimeInterval ?? 0)
                    }
                    
                    let monthlyChallengeFeed = FeedInfo(username: userData?["username"] as? String, indicator: "monthly", profilePicture: profilePicture, mainPicture: monthlyChallengePhotos[index - 1], likes: monthlyChallengePhotosLikes[index - 1], comments: monthlyChallengePhotosComments[index - 1], uid: uid, monthlyChallngeIndex: index, postID: monthlyChallengeMetadata[index - 1]?["postID"])
                    self.feed.append(monthlyChallengeFeed)
                }
                
            }
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
    // https://www.avanderlee.com/concurrency/task-groups-in-swift/
    func loadTableInformation2(){
        let currentMomentInTime = Date()
        let weekdayIndex = Calendar.current.component(.weekday, from: currentMomentInTime)
        
        Task{
            await withTaskGroup(of: Void.self) { group in
                for uid in allUIds{
                    group.addTask {
                        await self.getChallengesFromUser(uid: uid, weekdayIndex: weekdayIndex)
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
    
    // logic for posting a comment!
    func postComment(commentText: String, postID: String, index: Int) async {
        guard let uid = Auth.auth().currentUser?.uid else{
            print("User is not logged in")
            return
        }
        guard !commentText.isEmpty else{
            return
        }
        
        let postReference = db.collection("challengePosts").document(postID)
        
        do{
            let _ = try await db.runTransaction { transaction, errorPointer -> Any? in
                let postDocument: DocumentSnapshot
                do{
                    try postDocument = transaction.getDocument(postReference)
                }
                catch let fetchError as NSError{
                    errorPointer?.pointee = fetchError
                    return
                }
                
                guard var oldComments = postDocument.data()?["comments"] as? [[String : Any]] else{
                    let error = NSError(
                      domain: "AppErrorDomain",
                      code: -1,
                      userInfo: [
                        NSLocalizedDescriptionKey: "Unable to retrieve population from snapshot \(postDocument)"
                      ]
                    )
                    errorPointer?.pointee = error
                    return
                }
                
                let newComment = ["comment" : commentText, "likes" : [], "uid" : uid, "timestamp" : Date().timeIntervalSince1970]
                
                oldComments.append(newComment)
                
                DispatchQueue.main.async {
                    self.feed[index].comments = oldComments
                    self.tableView.reloadData()
                }
                transaction.updateData(["comments": oldComments], forDocument: postReference)
                return
            }
        }
        catch{
            print("Transaction failed!")
        }
        return
    }
    
    // handle liking a post from the feed
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
    
    // handles comment like from a specific post
    func handleCommentLike(postID: String, rowIndex: Int, commentIndex: Int) async -> Bool{
        guard let uid = Auth.auth().currentUser?.uid else{
            print("User is not logged in")
            return false
        }
        
        let postReference = db.collection("challengePosts").document(postID)
        
        // copied from https://firebase.google.com/docs/firestore/manage-data/transactions
        do {
            var didLike: Bool = false
            let _ = try await db.runTransaction({ (transaction, errorPointer) -> Any? in
                let postDocument: DocumentSnapshot
                do {
                  try postDocument = transaction.getDocument(postReference)
                }
                catch let fetchError as NSError {
                  errorPointer?.pointee = fetchError
                  return false
                }

                guard var comments = postDocument.data()?["comments"] as? [[String: Any]],
                      var oldLikes = comments[commentIndex]["likes"] as? [String]
                else {
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
                
                comments[commentIndex]["likes"] = oldLikes
                
                transaction.updateData(["comments" : comments], forDocument: postReference)
                return didLike
          })
            print("Transaction successfully committed!")
            return didLike
        } catch {
          print("Transaction failed: \(error)")
        }
        return false
    }
    
    // https://medium.com/@viveksehrawat36/migrating-from-dispatchgroup-to-async-await-with-taskgroup-in-swift-44725e207f3c
    // https://www.avanderlee.com/concurrency/task-groups-in-swift/
    func getNewData(index: Int) async -> [CommentInfo]{

        guard let postID = feed[index].postID else {
            print("no valid post id for this feed post!")
            return []
        }
        
        let postRef = db.collection("challengePosts").document(postID)
        var rawComments: [[String : Any]] = []
        do{
            let document = try await postRef.getDocument()
            if document.exists{
                if let data = document.data(){
                    rawComments = data["comments"] as! [[String : Any]]
                    rawComments.sort{
                        $0["timestamp"] as? TimeInterval ?? 0 < $1["timestamp"] as? TimeInterval ?? 0
                    }
                }
            }
        }
        catch{
            print("error getting lated data from storage")
            return []
        }
        
        var loadedComments: [CommentInfo] = []
        
        await withTaskGroup(of: CommentInfo?.self) { group in
            for comment in rawComments{
                group.addTask{
                    guard let commentUID = comment["uid"] as? String else{
                        print("Cannot get uid for comment!")
                        return nil
                    }
                    
                    guard let commentText = comment["comment"] as? String else{
                        print("Cannot get uid for comment!")
                        return nil
                    }
                    
                    guard let likes = comment["likes"] as? [String] else{
                        print("Cannot get uid for comment!")
                        return nil
                    }
                    
                    guard let timestamp = comment["timestamp"] as? Double else{
                        print("Cannot get timestamp for comment!")
                        return nil
                    }
                    
                    let profilePicture = await self.manager.getProfilePicture(uid: commentUID)
                    let userDoc = await self.manager.getUserDocumentData(uid: commentUID)
                
                    guard let username = userDoc?["username"] as? String else{
                        print("Cannot get username for comment!")
                        return nil
                    }
                    
                    return CommentInfo(uid: commentUID, profilePicture: profilePicture, comment: commentText, likes: likes, username: username, timestamp: timestamp)
                }
            }
            
            for await result in group{
                if let commentInfo = result{
                    loadedComments.append(commentInfo)
                }
            }
        }
        return loadedComments.sorted { $0.timestamp < $1.timestamp }
    }
    
    // https://medium.com/@viveksehrawat36/migrating-from-dispatchgroup-to-async-await-with-taskgroup-in-swift-44725e207f3c
    // https://www.avanderlee.com/concurrency/task-groups-in-swift/
    // handles going into the view by getting the comments ready!
    func handleCommentSegue(index: Int){
        let cInfo = feed[index]
        var loadedComments: [CommentInfo] = []
        
        for comment in cInfo.comments{
            if let commentUID = comment["uid"] as? String,
               let commentText = comment["comment"] as? String,
               let likes = comment["likes"] as? [String],
               let timestamp = comment["timestamp"] as? TimeInterval{
                let commentInfo = CommentInfo(uid: commentUID, profilePicture: profilePicCache[commentUID], comment: commentText, likes: likes, username: usernameCache[commentUID], timestamp: timestamp)
                loadedComments.append(commentInfo)
            }
        }
        
        self.pendingComments = loadedComments
        self.willClickCellAt = index

        self.performSegue(withIdentifier: "commentSegue", sender: self)

        
//        // https://www.swiftbysundell.com/articles/connecting-async-await-with-other-swift-code/
//        Task{
//            await withTaskGroup(of: CommentInfo?.self) { group in
//                for comment in cInfo.comments{
//                    group.addTask{
//                        guard let commentUID = comment["uid"] as? String else{
//                            print("Cannot get uid for comment!")
//                            return nil
//                        }
//                        
//                        guard let commentText = comment["comment"] as? String else{
//                            print("Cannot get uid for comment!")
//                            return nil
//                        }
//                        
//                        guard let likes = comment["likes"] as? [String] else{
//                            print("Cannot get uid for comment!")
//                            return nil
//                        }
//                        
//                        guard let timestamp = comment["timestamp"] as? Double else{
//                            print("Cannot get timestamp for comment!")
//                            return nil
//                        }
//                        
//                        let profilePicture = await self.manager.getProfilePicture(uid: commentUID)
//                        let userDoc = await self.manager.getUserDocumentData(uid: commentUID)
//                    
//                        guard let username = userDoc?["username"] as? String else{
//                            print("Cannot get username for comment!")
//                            return nil
//                        }
//                        
//                        return CommentInfo(uid: commentUID, profilePicture: profilePicture, comment: commentText, likes: likes, username: username, timestamp: timestamp)
//                    }
//                }
//                
//                for await result in group{
//                    if let commentInfo = result{
//                        loadedComments.append(commentInfo)
//                    }
//                }
//            }
//            
//            self.pendingComments = loadedComments
//            self.willClickCellAt = index
//            
//            self.performSegue(withIdentifier: "commentSegue", sender: self)
//        }
    }
    
    // table view specific functions (conforming)
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return feed.count
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        willClickCellAt = indexPath.row
        return indexPath
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FeedCell", for: indexPath) as! FeedTableViewCell
        let cInfo = feed[indexPath.row]
        
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
        cell.commentLabel.text = String(cInfo.comments.count)
        return cell
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "commentSegue",
           let nextVC = segue.destination as? ChallengeFeedCommentViewController{
            nextVC.prevVC = self
            let cInfo = feed[willClickCellAt]
            nextVC.profilePicture = cInfo.profilePicture
            nextVC.allComments = pendingComments
            nextVC.allComments.sort{
                $0.timestamp < $1.timestamp
            }
            nextVC.postID = cInfo.postID
            nextVC.index = willClickCellAt
        }
    }
}
