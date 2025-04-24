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
    
    @IBOutlet weak var mutualFriends: UIStackView!
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
            
            var targetFriends: [User] = []
            
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
                targetFriends = friends
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
                self.numberOfFriends.text = "\(count) \nfriends"
                targetFriends = friends
            }
            
            // fetch other user profile data
            if let streak = data["streak"] as? Int {
                self.numberForStreak.text = "\(streak)"
            }
            
            if let nickname = data["nickname"] as? String {
                self.nickname.text = nickname
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
        
        guard !mutuals.isEmpty else {
            return
        }

        let imageStack = UIStackView()
        imageStack.axis = .horizontal
        imageStack.spacing = -12
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
            }
            
            let names = mutuals.prefix(3).map { $0.username }
            let nameList = names.joined(separator: ", ")
            label.text = "\(nameList) \(names.count == 1 ? "is" : "are") also following"

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
