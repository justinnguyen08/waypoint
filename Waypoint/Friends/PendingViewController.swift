//  Project: Waypoint
//  Course: CS371L
//
//  PendingViewController.swift
//  Waypoint
//
//  Created by Tarun Somisetty on 3/10/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

class PendingViewController: UIViewController {
    
    @IBOutlet weak var profilePic: UIImageView!
    @IBOutlet weak var nickname: UILabel!
    @IBOutlet weak var numberOfStreak: UILabel!
    @IBOutlet weak var numberOfFriends: UILabel!
    @IBOutlet weak var username: UILabel!
    // Does nothing for now needed it for a new controller
    var selectedUsername: String?
    override func viewDidLoad() {
        super.viewDidLoad()
        username.text = selectedUsername!
        let db = Firestore.firestore()
        db.collection("users").whereField("username", isEqualTo: username.text).getDocuments {
            (snapshot, error) in
            if let error = error {
                print("Error fetching user: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty,
                  let document = documents.first else {
                print("No user found with username: \(self.username.text)")
                return
            }
            
            let targetUserUUID = document.documentID
            let data = document.data()
            print("type: \(type(of: data["friends"]))")
            if let friendsData = data["friends"] as? [[String: Any]] {
                var friends: [User] = []
                for friendInfo in friendsData {
                if let uid = friendInfo["uid"] as? String,
                   let username = friendInfo["username"] as? String {
                   let friend = User(uid: uid, username: username)
                    friends.append(friend)
                    }
                }
                let count = friends.count
                print("This is how many friends you have friends you have \(count)")
                self.numberOfFriends.text = "\(count) \nfriends"
            }
            
            if let streak = data["streak"] as? Int {
                self.numberOfStreak.text = "\(streak)"
            }
            
            if let nickname = data["nickname"] as? String {
                self.nickname.text = nickname
            }
            let storage = Storage.storage()
            let profilePicRef = storage.reference().child("\(targetUserUUID)/profile_pic.jpg")
            self.fetchImage(from: profilePicRef, for: self.profilePic, fallback: "person.circle")
            self.profilePic.layer.cornerRadius = self.profilePic.frame.width / 2
            self.profilePic.contentMode = .scaleAspectFill
            
        }

        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let db = Firestore.firestore()
        db.collection("users").whereField("username", isEqualTo: username.text).getDocuments {
            (snapshot, error) in
            if let error = error {
                print("Error fetching user: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty,
                  let document = documents.first else {
                print("No user found with username: \(self.username.text)")
                return
            }
            
            let targetUserUUID = document.documentID
            let data = document.data()
            print("type: \(type(of: data["friends"]))")
            if let friendsData = data["friends"] as? [[String: Any]] {
                var friends: [User] = []
                for friendInfo in friendsData {
                if let uid = friendInfo["uid"] as? String,
                   let username = friendInfo["username"] as? String {
                   let friend = User(uid: uid, username: username)
                    friends.append(friend)
                    }
                }
                let count = friends.count
                print("This is how many friends you have friends you have \(count)")
                self.numberOfFriends.text = "\(count) \nfriends"
            }
            
            if let streak = data["streak"] as? Int {
                self.numberOfStreak.text = "\(streak)"
            }
            
            if let nickname = data["nickname"] as? String {
                self.nickname.text = nickname
            }
            
        }
    }
    
    func fetchImage(from ref: StorageReference, for imageView: UIImageView, fallback: String) {
        imageView.image = UIImage(systemName: fallback)  // Placeholder while loading
        ref.getData(maxSize: 10 * 1024 * 1024) { data, error in
            if let error = error {
                print("Error fetching \(ref.fullPath): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    imageView.image = UIImage(systemName: fallback)
                }
            } else if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    imageView.image = image
                }
            }
        }
    }
    
    @IBAction func acceptButtonPressed(_ sender: Any) {
        let uniqueUsername = username.text!
        let db = Firestore.firestore()
        let currentUser = Auth.auth().currentUser
        db.collection("users").document(currentUser!.uid).getDocument {
            (currentUserSnapshot, error) in
            if let error = error {
                print("Error fetching current user: \(error.localizedDescription)")
                return
            }
            
            guard let currentUserData = currentUserSnapshot?.data(),
                  let currentUsername = currentUserData["username"] as? String else { return }
            let currentUserStruct = User(uid: currentUser!.uid, username: currentUsername)
            let currentUserDict: [String: Any] = [
                "uid": currentUserStruct.uid,
                "username": currentUserStruct.username
            ]
            
            db.collection("users").whereField("username", isEqualTo: uniqueUsername).getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error fetching user: \(error.localizedDescription)")
                    return
                }
                
                if let documents = snapshot?.documents, !documents.isEmpty {
                    if let document = documents.first {
                        let targetUserUUID = document.documentID
                        print("Found user UUID: \(targetUserUUID)")
                        // Adding the current user in the target's database
                        db.collection("users").document(targetUserUUID).updateData([
                            "friends": FieldValue.arrayUnion([currentUserDict])
                        ]) { error in
                            if let error = error {
                                print("Error updating pendingFriends: \(error.localizedDescription)")
                            } else {
                                print("Successfully added \(currentUserStruct.username) to \(targetUserUUID)'s pendingFriends.")
                            }
                        }
                        
                        
                        
                        // Adding the target in the current users' database
                        let targetUserDict: [String: Any] = [
                            "uid": targetUserUUID,
                            "username": uniqueUsername
                        ]
                        
                        db.collection("users").document(currentUser!.uid).updateData(["friends": FieldValue.arrayUnion([targetUserDict])]) {
                            error in
                            if let error = error {
                                print("Error updating friends: \(error.localizedDescription)")
                            } else {
                                print("Successfully added \(targetUserUUID) to \(currentUserStruct.username)'s friends.")
                            }
                        }
                        
                        db.collection("users").document(currentUser!.uid).updateData([
                            "pendingFriends": FieldValue.arrayRemove([targetUserDict])
                        ]) { error in
                            if let error = error {
                                print("Error removing user from pendingFriends: \(error.localizedDescription)")
                            } else {
                                print("Successfully removed user from pendingFriends")
                            }
                        }
                        
                    }
                } else {
                    print("No user found with username: \(uniqueUsername)")
                }
            }
            
        }

    }
    
    @IBAction func denyButtonPressed(_ sender: Any) {
        let uniqueUsername = username.text!
        let db = Firestore.firestore()
        let currentUser = Auth.auth().currentUser
        db.collection("users").document(currentUser!.uid).getDocument { (currentUserSnapshot, error) in
                if let error = error {
                    print("Error fetching current user: \(error.localizedDescription)")
                    return
                }
                
                guard let pendingUserData = currentUserSnapshot?.data()?["pendingFriends"] as? [[String: Any]] else {
                    print("No pending friends found")
                    return
                }
                
                // Find the pending friend dictionary matching the username
                if let targetPendingFriend = pendingUserData.first(where: { ($0["username"] as? String) == uniqueUsername }) {
                    
                    // Now remove that pending friend
                    db.collection("users").document(currentUser!.uid).updateData([
                        "pendingFriends": FieldValue.arrayRemove([targetPendingFriend])
                    ]) { error in
                        if let error = error {
                            print("Error removing user from pendingFriends: \(error.localizedDescription)")
                        } else {
                            print("Successfully denied and removed \(uniqueUsername) from pendingFriends.")
                        }
                    }
                } else {
                    print("User not found in pendingFriends list")
                }
            }
    }


}
