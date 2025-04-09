//  Project: Waypoint
//  Course: CS371L
//
//  AddFriendViewController.swift
//  Waypoint
//
//  Created by Tarun Somisetty on 3/10/25.
//

import UIKit
import Firebase
import FirebaseFirestore
import FirebaseAuth

class AddFriendViewController: UIViewController {

    @IBOutlet weak var username: UILabel!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var pendingButton: UIButton!
    
    @IBOutlet weak var nickname: UILabel!
    @IBOutlet weak var numberForStreak: UILabel!
    @IBOutlet weak var numberOfFriends: UILabel!
    
    var selectedUsernameA: String?
    
    
    override func viewDidLoad() {
        
        // Creating some connections add and pending buttons and hiding them based on what is called
        super.viewDidLoad()
        pendingButton.isHidden = true
        username.text = selectedUsernameA!
//        username.text = selectedUsername!
//        print(username.text!)
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
            
            if let nickname = data["nickname"] as? String {
//                print(nickname)
                self.nickname.text = nickname
            }
            
//            print("Type of streaks field: \(type(of: data["streaks"]))")
            
            if let streak = data["streak"] as? Int {
                self.numberForStreak.text = "\(streak)"
            }
            
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        username.text = selectedUsernameA!
        let uniqueUsername = username.text!
        let db = Firestore.firestore()
        db.collection("users").whereField("username", isEqualTo: uniqueUsername).getDocuments {
            (snapshot, error) in
            if let error = error {
                print("Error fetching user: \(error.localizedDescription)")
                return
            }
            guard let documents = snapshot?.documents, !documents.isEmpty,
                  let document = documents.first else {
                print("No user found with username: \(uniqueUsername)")
                return
            }
            let targetUserUUID = document.documentID
            let data = document.data()
            
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
                self.numberForStreak.text = "\(streak)"
            }
            
            if let nickname = data["nickname"] as? String {
                self.nickname.text = nickname
            }
            
            // Fetch current pendingFriends array
            if var pendingFriends = data["pendingFriends"] as? [[String: Any]] {
                // Check if your UID already exists
                let alreadyPending = pendingFriends.contains { entry in
                    guard let uid = entry["uid"] as? String else { return false }
                    self.pendingButton.isHidden = false
                    return uid == Auth.auth().currentUser?.uid
                }
                if alreadyPending {
                    print("You are already in this user's pending list.")
                    self.pendingButton.isHidden = false
                    return
                } else {
                    self.pendingButton.isHidden = true
                }
            }
        }
    }
    
    
    @IBAction func addButtonPressed(_ sender: Any) {
        let uniqueUsername = username.text!
        let db = Firestore.firestore()
        pendingButton.isHidden = false
        addButton.isHidden = true
        if !pendingButton.isHidden, let currentUser = Auth.auth().currentUser {
            db.collection("users").document(currentUser.uid).getDocument {
                (currentUserSnapshot, error) in
                if let error = error {
                    print("Error fetching current user: \(error.localizedDescription)")
                    return
                }
                guard let currentUserData = currentUserSnapshot?.data(),
                      let username = currentUserData["username"] as? String else {
                    return
                }
                let currentUserStruct = User(uid: currentUser.uid, username: username)
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
                            db.collection("users").document(targetUserUUID).updateData([
                                "pendingFriends": FieldValue.arrayUnion([currentUserDict])
                            ]) { error in
                                if let error = error {
                                    print("Error updating pendingUsers: \(error.localizedDescription)")
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
}
