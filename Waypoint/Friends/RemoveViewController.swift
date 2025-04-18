//  Project: Waypoint
//  Course: CS371L
//
//  RemoveViewController.swift
//  Waypoint
//
//  Created by Tarun Somisetty on 3/10/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

class RemoveViewController: UIViewController {
    
    @IBOutlet weak var nickname: UILabel!
    @IBOutlet weak var username: UILabel!
    var selectedUsername: String?
    
    @IBOutlet weak var dailyPic: UIImageView!
    @IBOutlet weak var pinnedPic: UIImageView!
    @IBOutlet weak var profilePic: UIImageView!
    @IBOutlet weak var numberForStreak: UILabel!
    @IBOutlet weak var numberOfFriends: UILabel!
    
    // Portray all the values for nickname, # of friends, and pictures
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
            
            // fetch friends count data
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
                self.numberOfFriends.text = "\(count) \nfriends"
            }
            
            // fetch other user profile data
            if let nickname = data["nickname"] as? String {
                self.nickname.text = nickname
            }
            
            if let streak = data["streak"] as? Int {
                self.numberForStreak.text = "\(streak)"
            }
            let storage = Storage.storage()
            let profilePicRef = storage.reference().child("\(targetUserUUID)/profile_pic.jpg")
            let pinnedPicRef = storage.reference().child("\(targetUserUUID)/pinned_pic.jpg")
            let dailyPicRef = storage.reference().child("\(targetUserUUID)/daily_pic.jpg")
            
            self.fetchImage(from: profilePicRef, for: self.profilePic, fallback: "person.circle")
            self.profilePic.layer.cornerRadius = self.profilePic.frame.height / 2
            self.profilePic.contentMode = .scaleAspectFill
            
            self.fetchImage(from: pinnedPicRef, for: self.pinnedPic, fallback: "pin.circle")
            self.fetchImage(from: dailyPicRef, for: self.dailyPic, fallback: "person.circle")
        }
    }
    
    // Portray all the values for nickname, # of friends, and pictures
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
            
            // fetch friends count data
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
                self.numberOfFriends.text = "\(count) \nfriends"
            }
            
            // fetch other user profile data
            if let streak = data["streak"] as? Int {
                self.numberForStreak.text = "\(streak)"
            }
            
            if let nickname = data["nickname"] as? String {
                self.nickname.text = nickname
            }
        }
    }
    
    // Fetches the image from storage to for any reference such as profile or regular pics
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

    // Removing the friend from my friends array
    @IBAction func removeButtonPressed(_ sender: Any) {
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
                        // Removing the current user in the target's database
                        db.collection("users").document(targetUserUUID).updateData([
                            "friends": FieldValue.arrayRemove([currentUserDict])
                        ]) { error in
                            if let error = error {
                                print("Error updating pendingFriends: \(error.localizedDescription)")
                            } else {
                                print("Successfully removed \(currentUserStruct.username) to \(targetUserUUID)'s pendingFriends.")
                            }
                        }
                        
                        // Removing the target in the current users' database
                        let targetUserDict: [String: Any] = [
                            "uid": targetUserUUID,
                            "username": uniqueUsername
                        ]
                        db.collection("users").document(currentUser!.uid).updateData(["friends": FieldValue.arrayRemove([targetUserDict])]) {
                            error in
                            if let error = error {
                                print("Error updating friends: \(error.localizedDescription)")
                            } else {
                                print("Successfully removed \(targetUserUUID) to \(currentUserStruct.username)'s friends.")
                            }
                        }
                    }
                } else {
                    print("No user found with username: \(uniqueUsername)")
                }
            }
            
        }
    }
}
