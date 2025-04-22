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
import FirebaseStorage

class AddFriendViewController: UIViewController {

    @IBOutlet weak var mutualFriends: UIStackView!
    @IBOutlet weak var username: UILabel!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var pendingButton: UIButton!
    
    @IBOutlet weak var nickname: UILabel!
    @IBOutlet weak var numberForStreak: UILabel!
    @IBOutlet weak var numberOfFriends: UILabel!
    
    @IBOutlet weak var profilePic: UIImageView!
    var selectedUsernameA: String?
    
    
    override func viewDidLoad() {
        
        // Creating some connections add and pending buttons and hiding them based on what is called
        super.viewDidLoad()
        pendingButton.isHidden = true
        username.text = selectedUsernameA!
        let db = Firestore.firestore()
        
        // Gets the data for the user's profile that we logged into such as: streak, # of friends, profile pic
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
            var targetFriends: [User] = []
//            if let friends = data["friends"] as? [String] {
//                let count = friends.count
//                print(count)
//                self.numberOfFriends.text = "\(count) friends"
//            }
            
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
                targetFriends = friends
            }
            
            // Nickname retreival
            if let nickname = data["nickname"] as? String {
                self.nickname.text = nickname
            }
            
            // Streak data retrieval
            if let streak = data["streak"] as? Int {
                self.numberForStreak.text = "\(streak)"
            }
            
            // Profile pic retrieval
            let storage = Storage.storage()
            let profilePicRef = storage.reference().child("\(targetUserUUID)/profile_pic.jpg")
            self.fetchImage(from: profilePicRef, for: self.profilePic, fallback: "person.circle")
            self.profilePic.layer.cornerRadius = self.profilePic.frame.width / 2
            self.profilePic.contentMode = .scaleAspectFill
            
            guard let currentUID = Auth.auth().currentUser?.uid else { return }
            
            db.collection("users").document(currentUID).getDocument { (currSnapshot, error) in
                if let error = error {
                    print("Error fetching current user: \(error.localizedDescription)")
                    return
                }
                
                guard let currData = currSnapshot?.data(),
                      let currentFriendsData = currData["friends"] as? [[String: Any]] else {
                    return
                }
                
                var currentFriends: [User] = []
                for friendInfo in currentFriendsData {
                    if let uid = friendInfo["uid"] as? String,
                       let username = friendInfo["username"] as? String {
                        currentFriends.append(User(uid: uid, username: username))
                    }
                }
                
                // 3. Find mutual friends
                let mutuals = self.findMutualFriends(currentUserFriends: currentFriends, targetUserFriends: targetFriends)
                print("Mutual Friends: \(mutuals.map { $0.username })")
                self.configureMutualFriendsView(mutuals: mutuals)
                
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        username.text = selectedUsernameA!
        let uniqueUsername = username.text!
        let db = Firestore.firestore()
        
        // Gets the data for the user's profile that we logged into
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
            
            var targetFriends: [User] = []
            // Friend count retrival
//            if let friends = data["friends"] as? [String] {
//                let count = friends.count
//                print(count)
//                self.numberOfFriends.text = "\(count) friends"
//            }
            
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
                targetFriends = friends
            }
            
            // Streak count retrival
            if let streak = data["streaks"] as? Int {
                self.numberForStreak.text = "\(streak)"
            }
            
            // Nickname retrieval
            if let nickname = data["nickname"] as? String {
                self.nickname.text = nickname
            }
            
            // Fetch current pendingFriends array, to make sure that if in pending then, make add button
            // disappear and have it show as a pending button
            if let pendingFriends = data["pendingFriends"] as? [[String: Any]] {
                // Check if your UID already exists
                let alreadyPending = pendingFriends.contains { entry in
                    guard let uid = entry["uid"] as? String else { return false }
                    self.pendingButton.isHidden = false
                    return uid == Auth.auth().currentUser?.uid
                }
                if alreadyPending {
                    self.pendingButton.isHidden = false
                    return
                } else {
                    self.pendingButton.isHidden = true
                }
            }
            
            guard let currentUID = Auth.auth().currentUser?.uid else { return }
            
            db.collection("users").document(currentUID).getDocument { (currSnapshot, error) in
                if let error = error {
                    print("Error fetching current user: \(error.localizedDescription)")
                    return
                }
                
                guard let currData = currSnapshot?.data(),
                      let currentFriendsData = currData["friends"] as? [[String: Any]] else {
                    return
                }
                
                var currentFriends: [User] = []
                for friendInfo in currentFriendsData {
                    if let uid = friendInfo["uid"] as? String,
                       let username = friendInfo["username"] as? String {
                        currentFriends.append(User(uid: uid, username: username))
                    }
                }
                
                // 3. Find mutual friends
                let mutuals = self.findMutualFriends(currentUserFriends: currentFriends, targetUserFriends: targetFriends)
                print("Mutual Friends: \(mutuals.map { $0.username })")
                self.configureMutualFriendsView(mutuals: mutuals)
                
            }
        }
    }
    
    func findMutualFriends(currentUserFriends: [User], targetUserFriends: [User]) -> [User] {
        let currentSet = Set(currentUserFriends.map { $0.uid })
        return targetUserFriends.filter { currentSet.contains($0.uid) }
    }
    
    func configureMutualFriendsView(mutuals: [User]) {
        mutualFriends.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let imageStack = UIStackView()
        imageStack.axis = .horizontal
        imageStack.spacing = 12
        imageStack.alignment = .center
        imageStack.distribution = .fill
        imageStack.translatesAutoresizingMaskIntoConstraints = false

        let count = mutuals.count
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .darkGray

        if count > 3 {
            // Show only 3 overlapping profile pics + label
            for user in mutuals.prefix(3) {
                let imageView = createProfileImageView()
                imageStack.addArrangedSubview(imageView)

                let ref = Storage.storage().reference().child("\(user.uid)/profile_pic.jpg")
                fetchImage(from: ref, for: imageView, fallback: "person.circle")
            }

            label.text = "\(count)+ mutual friends here"
            mutualFriends.addArrangedSubview(imageStack)
            mutualFriends.addArrangedSubview(label)

        } else {
            for user in mutuals {
                let imageView = createProfileImageView()
                imageStack.addArrangedSubview(imageView)

                let ref = Storage.storage().reference().child("\(user.uid)/profile_pic.jpg")
                fetchImage(from: ref, for: imageView, fallback: "person.circle")

                label.text = "\(user.username) is also following"
                break // Show only 1 user with their tag line when ≤ 3
            }

            let containerStack = UIStackView()
            containerStack.axis = .horizontal
            containerStack.alignment = .center
            containerStack.spacing = 12
            containerStack.translatesAutoresizingMaskIntoConstraints = false

            containerStack.addArrangedSubview(imageStack)
            containerStack.addArrangedSubview(label)

            mutualFriends.addArrangedSubview(containerStack)
        }
    }

    func createProfileImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 30).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 30).isActive = true
        imageView.layer.cornerRadius = 15
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.white.cgColor
        return imageView
    }
    
    // Fetches the image from storage for any reference such as profile or regular pics
    func fetchImage(from ref: StorageReference, for imageView: UIImageView, fallback: String) {
        imageView.image = UIImage(systemName: fallback)
        ref.getData(maxSize: 10 * 1024 * 1024) { (data, error) in
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
    
    // For the target user, you become a pending friend they need to accept
    @IBAction func addButtonPressed(_ sender: Any) {
        let uniqueUsername = username.text!
        let db = Firestore.firestore()
        pendingButton.isHidden = false
        addButton.isHidden = true
        
        // if the add button is pressed, then you get added to the other person's pending friends array
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
                    // Adds the user to pending friends array
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
    
    // Removes you from the target's pending friends array
    @IBAction func pendingButtonPressed(_ sender: Any) {
        pendingButton.isHidden = true
        addButton.isHidden = false
        let db = Firestore.firestore()
        guard let currentUser = Auth.auth().currentUser else { return }
        
        // This unique username is for the current profile that clicked on
        guard let uniqueUsername = username.text else { return }
        db.collection("users").document(currentUser.uid).getDocument { (currentUserSnapshot, error) in
            if let error = error {
                print("Error fetching current user: \(error.localizedDescription)")
                return
            }
            
            guard let currentUserData = currentUserSnapshot?.data(),
                  let currentUserUsername = currentUserData["username"] as? String else {
                print("Could not get current user data")
                return
            }
            
            let currentUserDict: [String: Any] = [
                "uid": currentUser.uid,
                "username": currentUserUsername
            ]
            
            // Find the target user (the one you sent the request to)
            db.collection("users").whereField("username", isEqualTo: uniqueUsername).getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error fetching target user: \(error.localizedDescription)")
                    return
                }
                if let documents = snapshot?.documents, !documents.isEmpty {
                    if let document = documents.first {
                        let targetUserUUID = document.documentID
                        
                        // Remove the current user from the target user's pendingFriends array
                        db.collection("users").document(targetUserUUID).updateData([
                            "pendingFriends": FieldValue.arrayRemove([currentUserDict])
                        ]) { error in
                            if let error = error {
                                print("Error removing from pendingFriends: \(error.localizedDescription)")
                            } else {
                                print("Successfully removed pending friend request")
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
