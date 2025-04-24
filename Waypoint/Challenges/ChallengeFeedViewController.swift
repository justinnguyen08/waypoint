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
    
    // https://www.hackingwithswift.com/example-code/uikit/how-to-use-uiactivityindicatorview-to-show-a-spinner-when-work-is-happening
    var spinner = UIActivityIndicatorView(style: .large)
    
    
    // allows us access into the Google Firebase Firestore
    let db = Firestore.firestore()
    let manager = FirebaseManager()
    
    var profilePicCache: [String: UIImage] = [:]
    var usernameCache: [String: String] = [:]
    
    var currentUserUsername: String!
    
    var currentUserFriends: [[String : Any]]!
    var currentUserPendingFriends: [[String : Any]]!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    // When the view appears, recreate the feed
    override func viewWillAppear(_ animated: Bool) {
        tableView.isHidden = true
        noDataLabel.isHidden = true
        showSpinner()
        feed.removeAll()
        getCurrentUserFriends{
            self.loadTableInformation()
        }
    }
    
    func showSpinner(){
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        view.addSubview(spinner)

        spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }
    
    func hideSpinner(){
        spinner.stopAnimating()
        spinner.removeFromSuperview()
    }
    
    // https://anasaman-p.medium.com/understanding-async-let-in-swift-unlocking-concurrency-with-ease-3d25473a16db
    func getChallengesFromUser(uid: String, weekdayIndex: Int) async -> [FeedInfo]{
        var results: [FeedInfo] = []
        if didDailyChallenge{
            
            if !profilePicCache.contains(where: { key, value in
                return key == uid
            }){
                profilePicCache[uid] = await self.manager.getProfilePicture(uid: uid) ?? UIImage(systemName: "person.fill")
            }
            if !usernameCache.contains(where: { key, value in
                return key == uid
            }){
                let userData = await self.manager.getUserDocumentData(uid: uid)
                let username = userData?["username"] as? String ?? "unknown"
                usernameCache[uid] = username
            }
            
            let dailyPath = "\(uid)/challenges/dailyChallenge/\(weekdayIndex).jpg"
            
            async let dailyChallengeMetadataTask = manager.getImageMetadata(path: dailyPath)
            
            
            let dailyChallengeMetadata = await dailyChallengeMetadataTask
            
            if let postID = dailyChallengeMetadata?["postID"]{
                async let dailyChallengeImageTask = manager.getChallengePicture(path: dailyPath)
                
                async let likesTask = manager.getPostLikes(collection: "challengePosts", postID: postID)
                async let commentsTask = manager.getPostComments(collection: "challengePosts", postID: postID)
                
                let dailyChallengeImage = await dailyChallengeImageTask
                
                let likes = await likesTask ?? []
                var comments = await commentsTask ?? []
                comments.sort{
                    ($0["timestamp"] as? TimeInterval ?? 0) < ($1["timestamp"] as? TimeInterval ?? 0)
                }
                
                for comment in comments{
                    if let commentUID = comment["uid"] as? String{
                        if !profilePicCache.contains(where: { key, value in
                            return key == commentUID
                        }){
                            profilePicCache[commentUID] = await self.manager.getProfilePicture(uid: commentUID) ?? UIImage(systemName: "person.fill")
                        }
                        if !usernameCache.contains(where: { key, value in
                            return key == commentUID
                        }){
                            let userData = await self.manager.getUserDocumentData(uid: commentUID)
                            let username = userData?["username"] as? String ?? "unknown"
                            usernameCache[commentUID] = username
                        }
                    }
                }
                results.append(FeedInfo(username: usernameCache[uid], indicator: "daily", profilePicture: profilePicCache[uid], mainPicture: dailyChallengeImage, likes: likes, comments: comments, uid: uid, monthlyChallngeIndex: -1, postID: postID))
            }
        }
        
        for index in 1..<6{
            if didMonthChallenge[index - 1]{
                
                if !profilePicCache.contains(where: { key, value in
                    return key == uid
                }){
                    profilePicCache[uid] = await self.manager.getProfilePicture(uid: uid) ?? UIImage(systemName: "person.fill")
                }
                if !usernameCache.contains(where: { key, value in
                    return key == uid
                }){
                    let userData = await self.manager.getUserDocumentData(uid: uid)
                    let username = userData?["username"] as? String ?? "unknown"
                    usernameCache[uid] = username
                }
                
                
                let monthlyPath = "\(uid)/challenges/monthlyChallenges/\(index - 1).jpg"
                
                async let monthlyChallengeMetadataTask = manager.getImageMetadata(path: monthlyPath)
                
                let monthlyChallengeMetadata = await monthlyChallengeMetadataTask
                
                if let postID = monthlyChallengeMetadata?["postID"]{
                    async let monthlyChallengeImageTask = manager.getChallengePicture(path: monthlyPath)
                    async let likesTask = manager.getPostLikes(collection: "challengePosts", postID: postID)
                    async let commentsTask = manager.getPostComments(collection: "challengePosts", postID: postID)
                    
                    let monthlyChallengeImage = await monthlyChallengeImageTask
                    let likes = await likesTask
                    var comments = await commentsTask ?? []
                    comments.sort{
                        ($0["timestamp"] as? TimeInterval ?? 0) < ($1["timestamp"] as? TimeInterval ?? 0)
                    }
                    
                    for comment in comments{
                        if let commentUID = comment["uid"] as? String{
                            if !profilePicCache.contains(where: { key, value in
                                return key == commentUID
                            }){
                                profilePicCache[commentUID] = await self.manager.getProfilePicture(uid: commentUID) ?? UIImage(systemName: "person.fill")
                            }
                            if !usernameCache.contains(where: { key, value in
                                return key == commentUID
                            }){
                                let userData = await self.manager.getUserDocumentData(uid: commentUID)
                                let username = userData?["username"] as? String ?? "unknown"
                                usernameCache[commentUID] = username
                            }
                        }
                    }
                    
                    results.append(FeedInfo(username: usernameCache[uid], indicator: "monthly", profilePicture: profilePicCache[uid], mainPicture: monthlyChallengeImage, likes: likes, comments: comments, uid: uid, monthlyChallngeIndex: index, postID: postID))
                }
            }
        }
        
        return results
    }
    
    // get all of the current user's friends and set up which challenge photos to look for
    func getCurrentUserFriends(handler: @escaping () -> Void){
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
                   let currentUserFriendsList = data["friends"] as? [[String: Any]],
                   let currentUsername = data["username"] as? String,
                   let currentUserPendingFriendsList = data["pendingFriends"] as? [[String: Any]]{
                    
                    self.currentUserFriends = currentUserFriendsList
                    self.currentUserPendingFriends = currentUserPendingFriendsList
                    self.currentUserUsername = currentUsername
                    self.usernameCache[uid] = self.currentUserUsername
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
    func loadTableInformation(){
        let currentMomentInTime = Date()
        let weekdayIndex = Calendar.current.component(.weekday, from: currentMomentInTime)
        Task{
            let allFeeds = await withTaskGroup(of: [FeedInfo].self) { group in
                for uid in allUIds{
                    group.addTask {
                        await self.getChallengesFromUser(uid: uid, weekdayIndex: weekdayIndex)
                    }
                }
                var combined: [FeedInfo] = []
                for await result in group{
                    combined.append(contentsOf: result)
                }
                return combined
            }
            
            self.feed = allFeeds
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.tableView.isHidden = false
                self.hideSpinner()
                if self.feed.count == 0{
                    self.noDataLabel.isHidden = false
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
                    
                    async let profilePictureTask = self.manager.getProfilePicture(uid: commentUID)
                    async let userDocTask = self.manager.getUserDocumentData(uid: commentUID)
                    
                    guard let username = await userDocTask?["username"] as? String else{
                        print("Cannot get username for comment!")
                        return nil
                    }
                    
                    return CommentInfo(uid: commentUID, profilePicture: await profilePictureTask, comment: commentText, likes: likes, username: username, timestamp: timestamp)
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
    }
    
    // table view specific functions (conforming)
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return feed.count
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        willClickCellAt = indexPath.row
        if feed[willClickCellAt].username != usernameCache[Auth.auth().currentUser?.uid ?? ""]{
            self.performSegue(withIdentifier: "ChallengeFeedToRemoveProfile", sender: self)
        }
        return indexPath
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FeedCell", for: indexPath) as! FeedTableViewCell
        let cInfo = feed[indexPath.row]
        
        cell.selectionStyle = .none
        cell.usernameLabel.text = cInfo.username
        cell.typeLabel.text = "\(cInfo.indicator!)" + "\(cInfo.indicator! == "monthly" ? " challenge \(String(cInfo.monthlyChallengeIndex))" : "")"
        cell.profilePictureView.image = cInfo.profilePicture
        cell.profilePictureView.layer.cornerRadius = cell.profilePictureView.frame.width / 2
        cell.profilePictureView.clipsToBounds = true
        cell.profilePictureView.contentMode = .scaleAspectFill
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
            
            if let sheet = nextVC.presentationController as? UISheetPresentationController{
                sheet.detents = [.medium()]
                sheet.prefersGrabberVisible = true
            }
            
            
            nextVC.prevVC = self
            
            guard let currentUserUID = Auth.auth().currentUser?.uid else{
                return
            }
            
            
            let cInfo = feed[willClickCellAt]
            nextVC.profilePicture = profilePicCache[currentUserUID]
            nextVC.allComments = pendingComments
            nextVC.allComments.sort{
                $0.timestamp < $1.timestamp
            }
            nextVC.postID = cInfo.postID
            nextVC.index = willClickCellAt
        }
        else if segue.identifier == "ChallengeFeedToRemoveProfile",
                let nextVC = segue.destination as? RemoveViewController{
            let cInfo = feed[willClickCellAt]
            nextVC.selectedUsername = cInfo.username
        }
    }
}
