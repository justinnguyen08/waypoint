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
    
    @IBOutlet weak var mutualFriends: UIStackView!
    @IBOutlet weak var profilePic: UIImageView!
    @IBOutlet weak var nickname: UILabel!
    @IBOutlet weak var numberOfStreak: UILabel!
    @IBOutlet weak var numberOfFriends: UILabel!
    @IBOutlet weak var username: UILabel!
    @IBOutlet weak var denyButton: UIButton!
    
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
            var targetFriends: [User] = []
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
                self.numberOfFriends.text = "\(count)"
                targetFriends = friends
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
        var cfg = UIButton.Configuration.filled()
        cfg.title = "Deny"
        cfg.baseBackgroundColor = .systemRed
        cfg.baseForegroundColor = .white      // your text color
        denyButton.configuration = cfg
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
            var targetFriends: [User] = []
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
                self.numberOfFriends.text = "\(count)"
                targetFriends = friends
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
                
                let mutuals = self.findMutualFriends(currentUserFriends: currentFriends, targetUserFriends: targetFriends)
                print("Mutual Friends: \(mutuals.map { $0.username })")
                self.configureMutualFriendsView(mutuals: mutuals)
                
            }
            
        }
    }
    
    // Finds mutual friends and sets that up for the stack view
    func findMutualFriends(currentUserFriends: [User], targetUserFriends: [User]) -> [User] {
        let currentSet = Set(currentUserFriends.map { $0.uid })
        return targetUserFriends.filter { currentSet.contains($0.uid) }
    }
    
    // Takes care of showing up the mutual friends in the stack view for every person
    func configureMutualFriendsView(mutuals: [User]) {
        mutualFriends.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        guard !mutuals.isEmpty else {
            return
        }

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
            // Show only 3 overlapping profile pics and their username
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
                break
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

    // Makes the profile picture view for the mutual friends
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
    
    // Makes sure that when you press accept, both the target user and current user
    // are mutual friends
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
    
    // Makes sure that when you press deny, the target loses you in the pendingFriends array, and you
    // will see them back in people that you can add
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
                    
                    // Remove that pending friend
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
