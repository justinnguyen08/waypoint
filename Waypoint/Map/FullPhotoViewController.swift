//
//  FullPhotoViewController.swift
//  Waypoint
//
//  Created by Pranav Sridhar on 4/14/25.
//

import UIKit
import FirebaseFirestore
import CoreLocation

class FullPhotoViewController: UIViewController {
    
    @IBOutlet weak var photoView: UIImageView!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var likeButton: UIButton!
    
    @IBOutlet weak var commentButton: UIButton!
    
    @IBOutlet weak var taggedButton: UIButton!
        
    var photo: UIImage?
    var postID: String?
    var location: CLLocationCoordinate2D?
    
    
    var likes: [String] = []
    var comments: [CommentInfo] = []
    var tagged: [String] = []
    var profilePicture: UIImage?
    var locationName: String?
    var username: String?
    
    let manager = FirebaseManager()
    let db = Firestore.firestore()
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        photoView.contentMode = .scaleAspectFit
        photoView.image = photo
        
        
        // get the username
        Task{
            
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
                
                // get the username from the userID
                let userData = await self.manager.getUserDocumentData(uid: uid)
                
                guard let username = userData?["username"] as? String else{
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
                async let profilePicture = self.manager.getProfilePicture(uid: uid)
                
                // get the likes and comments and tagged
                async let likesTask = self.manager.getPostLikes(collection: "mapPosts", postID: postID)
                async let commentsTask = self.manager.getPostComments(collection: "mapPosts", postID: postID)
                
                async let taggedTask = self.manager.getPostTagged(collection: "mapPosts", postID: postID)
                
                
                // build everything now!
                
                self.username = username
                self.locationName = try await cityNameTask.first?.locality ?? "Austin"
                self.likes = await likesTask ?? []
                self.tagged = await taggedTask ?? []
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
                    self.locationLabel.text = self.locationName
                    self.likeButton.setTitle("\(self.likes.count)", for: .normal)
                    self.commentButton.setTitle("\(self.comments.count)", for: .normal)
                    
                    self.view.bringSubviewToFront(self.likeButton)
                    self.view.bringSubviewToFront(self.commentButton)
                    self.view.bringSubviewToFront(self.taggedButton)
                }
            }
            catch{
                print("Error getting post data!")
            }
            
        }
    }
    
    @IBAction func likeButtonPressed(_ sender: Any) {
    }
    
    @IBAction func commentButtonPressed(_ sender: Any) {
    }
    
    
    @IBAction func taggedButtonPressed(_ sender: Any) {
    }
    
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
