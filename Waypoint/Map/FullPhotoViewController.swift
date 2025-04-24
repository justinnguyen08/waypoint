//
//  FullPhotoViewController.swift
//  Waypoint
//
//  Created by Pranav Sridhar on 4/14/25.
//

import UIKit
import FirebaseFirestore
import CoreLocation
import FirebaseAuth

class FullPhotoViewController: UIViewController {
    
    @IBOutlet weak var photoView: UIImageView!
    
    @IBOutlet weak var profilePictureView: UIImageView!
    
    @IBOutlet weak var usernameLabel: UILabel!
    
    
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var likeButton: UIButton!
    
    @IBOutlet weak var commentButton: UIButton!
    
    @IBOutlet weak var taggedButton: UIButton!
    
    var photo: UIImage?
    var postID: String?
    var location: CLLocationCoordinate2D?
    
    
    var likes: [String] = []
    var comments: [CommentInfo] = []
    var toConvertComments: [[String : Any]] = []
    var tagged: [String] = []
    var profilePicture: UIImage?
    var locationName: String?
    var username: String?
    
    let manager = FirebaseManager()
    let db = Firestore.firestore()
    
    var uid: String?
    
    var currentUserUID: String?
    var currentUserProfilePicture: UIImage?
    var currentUserUsername: String?
    var currentUserFriends: [[String : Any]]!
    var currentUserPendingFriends: [[String : Any]]!
    
    var pendingTagged: [TaggedEntry] = []
    
    let spinner = SpinnerManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        spinner.showSpinner(view: view)
        let df = DateFormatter()
        df.calendar = Calendar.current
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "MMMM d, yyyy"
        dateLabel.text = df.string(from: Date())
        hideAll()
        // Do any additional setup after loading the view.

        photoView.contentMode = .scaleAspectFit
        photoView.image = photo
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(recognizeTapGesture(recognizer:)))
        self.view.addGestureRecognizer(tapGestureRecognizer)
        
        
        // get the username
        Task{
            guard let currentUserUID = Auth.auth().currentUser?.uid else{
                return
            }
            
            guard let postID = self.postID else{
                print("There is no valid postID!")
                return
            }
            
            do{
                let postDocument = try await db.collection("mapPosts").document(postID).getDocument()
                
                guard let data = postDocument.data() else{
                    print("Error getting data!")
                    return
                }
                
                guard let uid = data["userID"] as? String else{
                    print("no user with this post!")
                    return
                }
                self.uid = uid
                
                // get the username from the userID
                let userData = await self.manager.getUserDocumentData(uid: uid)
                let currentUserData = await self.manager.getUserDocumentData(uid: currentUserUID)
                
                self.currentUserFriends = currentUserData?["friends"] as? [[String : Any]] ?? [[:]]
                self.currentUserPendingFriends = currentUserData?["pendingFriends"] as? [[String : Any]] ?? [[:]]
                
                guard let username = userData?["username"] as? String, let currentUsername = currentUserData?["username"] as? String  else{
                    print("not username with this uid!")
                    return
                }
                
                
                
                // get the location of the image
                // reverse geocode location snippet inspired from
                // https://developer.apple.com/documentation/corelocation/clgeocoder
                // https://developer.apple.com/documentation/corelocation/clplacemark
                let swiftLocation = CLLocation(latitude: location!.latitude, longitude: location!.longitude)
                async let cityNameTask = CLGeocoder().reverseGeocodeLocation(swiftLocation)
                
                // get the current user profile picture
                async let profilePictureTask = self.manager.getProfilePicture(uid: uid)
                
                async let currentUserProfileTask = self.manager.getProfilePicture(uid: currentUserUID)
                
                // get the likes and comments and tagged
                async let likesTask = self.manager.getPostLikes(collection: "mapPosts", postID: postID)
                async let commentsTask = self.manager.getPostComments(collection: "mapPosts", postID: postID)
                
                async let taggedTask = self.manager.getPostTagged(collection: "mapPosts", postID: postID)
                
                self.currentUserUID = currentUserUID
                self.currentUserProfilePicture = await currentUserProfileTask
                // build everything now!
                
                self.username = username
                self.currentUserUsername = currentUsername
                self.locationName = try await cityNameTask.first?.locality ?? "Austin"
                self.likes = await likesTask ?? []
                self.tagged = await taggedTask ?? []
                self.profilePicture = await profilePictureTask
                // get comments here
                guard let tempComments = await commentsTask else{
                    print("no comments")
                    return
                }
                await withTaskGroup(of: CommentInfo?.self) { group in
                    for comment in tempComments{
                        group.addTask{
                            guard let commentUID = comment["uid"] as? String else{
                                print("this comment has no uid!")
                                return nil
                            }
                            
                            guard let commentUserData = await self.manager.getUserDocumentData(uid: commentUID) else{
                                print("This uid has no user data!")
                                return nil
                            }
                            
                            guard let username = commentUserData["username"] as? String else{
                                print("This user data has no username!")
                                return nil
                            }
                            
                            let commentProfilePicture = await self.manager.getProfilePicture(uid: commentUID)
                            let commentText = comment["comment"] as? String ?? ""
                            let likes = comment["likes"] as? [String] ?? []
                            let timestamp = comment["timestamp"] as? TimeInterval ?? 0
                            return CommentInfo(uid: commentUID, profilePicture: commentProfilePicture, comment: commentText, likes: likes, username: username, timestamp: timestamp)
                        }
                    }
                    
                    for await result in group{
                        if let canAdd = result{
                            self.comments.append(canAdd)
                        }
                    }
                    self.comments.sort{
                        $0.timestamp < $1.timestamp
                    }
                }
                
                DispatchQueue.main.async{
                    self.usernameLabel.text = self.username
                    self.locationLabel.text = " is in \(self.locationName!)"
                    self.locationLabel.textColor = UIColor(red: (177/255.0), green: (63/255.0),                                         blue: (49/255.0), alpha: 1.0)
                    self.profilePictureView.image = self.profilePicture
                    self.profilePictureView.layer.cornerRadius = self.profilePictureView.frame.width / 2
                    self.profilePictureView.clipsToBounds = true
                    self.profilePictureView.contentMode = .scaleAspectFill
                    self.likeButton.setTitle("\(self.likes.count)", for: .normal)
                    if self.likes.contains(self.currentUserUID!){
                        self.likeButton.setImage(UIImage(systemName: "hand.thumbsup.fill"), for: .normal)
                    }
                    else{
                        self.likeButton.setImage(UIImage(systemName: "hands.thumbsup"), for: .normal)
                    }
                    self.commentButton.setTitle("\(self.comments.count)", for: .normal)
                    
                    self.view.bringSubviewToFront(self.likeButton)
                    self.view.bringSubviewToFront(self.commentButton)
                    self.view.bringSubviewToFront(self.taggedButton)
                    self.spinner.hideSpinner()
                    self.showAll()
                }
            }
            catch{
                print("Error getting post data!")
            }
            
        }
    }
    
    @IBAction func recognizeTapGesture(recognizer: UITapGestureRecognizer){
        if usernameLabel.text != currentUserUsername{
            performSegue(withIdentifier: "FullPhotoToRemoveProfile", sender: self)
        }
    }
    
    
    func hideAll(){
        profilePictureView.isHidden = true
        usernameLabel.isHidden = true
        locationLabel.isHidden = true
        photoView.isHidden = true
        likeButton.isHidden = true
        commentButton.isHidden = true
        taggedButton.isHidden = true
        dateLabel.isHidden = true
    }
    
    func showAll(){
        profilePictureView.isHidden = false
        usernameLabel.isHidden = false
        locationLabel.isHidden = false
        photoView.isHidden = false
        likeButton.isHidden = false
        commentButton.isHidden = false
        taggedButton.isHidden = false
        dateLabel.isHidden = false
    }
    
    func handleLike() async -> Bool{
        let postReference = db.collection("mapPosts").document(postID!)
        
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
                if oldLikes.contains(self.currentUserUID!){
                    oldLikes.removeAll { $0 == self.currentUserUID! }
                }
                else{
                    oldLikes.append(self.currentUserUID!)
                    didLike = true
                }
                
                DispatchQueue.main.async {
                    self.likes = oldLikes
                    if didLike{
                        self.likeButton.setTitle("\(self.likes.count)", for: .normal)
                        self.likeButton.setImage(UIImage(systemName: "hand.thumbsup.fill"), for: .normal)
                    }
                    else{
                        self.likeButton.setTitle("\(self.likes.count)", for: .normal)
                        self.likeButton.setImage(UIImage(systemName: "hand.thumbsup"), for: .normal)
                    }
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
    
    // logic for posting a comment!
    func postComment(commentText: String, postID: String) async {
        guard !commentText.isEmpty else{
            return
        }
        print("attempting to post comment to: \(postID)")
        let postReference = db.collection("mapPosts").document(postID)
        
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
                
                let newComment = ["comment" : commentText, "likes" : [], "uid" : self.currentUserUID!, "timestamp" : Date().timeIntervalSince1970]
                
                oldComments.append(newComment)
                self.toConvertComments = oldComments
                
                
                transaction.updateData(["comments": oldComments], forDocument: postReference)
                return
            }
        }
        catch{
            print("Transaction failed: \(error.localizedDescription)")
        }
        await convertComments()
        return
    }
    
    
    func convertComments() async{
        await withTaskGroup(of: CommentInfo?.self) { group in
            for entry in self.toConvertComments{
                group.addTask{
                    guard let uid = entry["uid"] as? String else{
                        return nil
                    }
                    async let profilePictureTask = self.manager.getProfilePicture(uid: uid)
                    async let userDataTask = self.manager.getUserDocumentData(uid: uid)
                    
                    guard let userData = await userDataTask else{
                        return nil
                    }
                    
                    guard let username = userData["username"] else{
                        return nil
                    }
                    
                    guard let profilePicture = await profilePictureTask else{
                        return nil
                    }
                    return CommentInfo(uid: uid, profilePicture: profilePicture, comment: entry["comment"] as? String, likes: entry["likes"] as? [String], username: username as? String, timestamp: entry["timestamp"] as? TimeInterval)
                }
            }
            self.comments = []
            for await result in group{
                if let result = result{
                    self.comments.append(result)
                }
            }
            DispatchQueue.main.async{
                self.commentButton.setTitle("\(self.comments.count)", for: .normal)
            }
        }
    }
    
    func handleCommentLike(postID: String, commentIndex: Int) async -> Bool{
        let postReference = db.collection("mapPosts").document(postID)
        
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
                if oldLikes.contains(self.currentUserUID!){
                    oldLikes.removeAll { $0 == self.currentUserUID! }
                }
                else{
                    oldLikes.append(self.currentUserUID!)
                    didLike = true
                }
                comments[commentIndex]["likes"] = oldLikes
                DispatchQueue.main.async {
                    self.comments[commentIndex].likes = oldLikes
                }
                
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
    
    
    @IBAction func likeButtonPressed(_ sender: Any) {
        Task{
            let _ = await handleLike()
        }
    }
    
    @IBAction func commentButtonPressed(_ sender: Any) {
        
    }
    
    
    @IBAction func taggedButtonPressed(_ sender: Any) {
        Task{
            await withTaskGroup(of: TaggedEntry?.self) { group in
                for entry in self.tagged{
                    group.addTask{
                        // get the username and profile picture of every uid
                        async let userDataTask = self.manager.getUserDocumentData(uid: entry)
                        async let profilePictureTask = self.manager.getProfilePicture(uid: entry)
                        
                        guard let taggedUserData = await userDataTask else{
                            return nil
                        }
                        
                        guard let taggedUsername = taggedUserData["username"] as? String else{
                            return nil
                        }
                        
                        guard let taggedProfilePicture = await profilePictureTask else{
                            return nil
                        }
                        
                        return TaggedEntry(profilePicture: taggedProfilePicture, username: taggedUsername, uid: entry)
                    }
                }
                var willBeAdded: [TaggedEntry] = []
                for await result in group{
                    if let taggedResult = result{
                        willBeAdded.append(taggedResult)
                    }
                }
                
                self.pendingTagged = willBeAdded
                
                DispatchQueue.main.async{
                    self.performSegue(withIdentifier: "mapTaggedSegue", sender: self)
                }
            }
            
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "mapTaggedSegue", let nextVC = segue.destination as? MapTaggedViewController{
            // https://www.youtube.com/watch?v=lZQUk8gz4wc
            if let sheet = nextVC.presentationController as? UISheetPresentationController{
                sheet.detents = [.medium()]
                sheet.prefersGrabberVisible = true
            }
            nextVC.allTagged = self.pendingTagged
        }
        else if segue.identifier == "MapCommentSegue", let nextVC = segue.destination as? MapCommentsViewController{
            
            if let sheet = nextVC.presentationController as? UISheetPresentationController{
                sheet.detents = [.medium()]
                sheet.prefersGrabberVisible = true
            }
            
            
            nextVC.allComments = comments
            nextVC.prevVC = self
            nextVC.postID = postID
            nextVC.profilePicture = currentUserProfilePicture
        }
        else if segue.identifier == "FullPhotoToRemoveProfile", let nextVC = segue.destination as? RemoveViewController{
            nextVC.selectedUsername = usernameLabel.text
        }
    }
}
