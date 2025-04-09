//  Project: Waypoint
//  Course: CS371L
//
//  SuggestedCustomTableViewCell.swift
//  Waypoint
//
//  Created by Tarun Somisetty on 3/9/25.
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseAuth

class PendingCustomTableViewCell: UITableViewCell {
    @IBOutlet weak var profilePicture: UIImageView!
    
    @IBOutlet weak var pendingProfileName: UILabel!
    
    // Makes sure that when you press accept, both the target user and current user
    // are mutual friends
    @IBAction func acceptPressed(_ sender: Any) {
        let uniqueUsername = pendingProfileName.text!
        let db = Firestore.firestore()
        let currentUser = Auth.auth().currentUser
        db.collection("users").document(currentUser!.uid).getDocument { (currentUserSnapshot, error) in
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
                                print("Error updating target's friends: \(error.localizedDescription)")
                                return
                            }
                            // Adding the target in the current user's database
                            let targetUserDict: [String: Any] = [
                                "uid": targetUserUUID,
                                "username": uniqueUsername
                            ]
                            db.collection("users").document(currentUser!.uid).updateData([
                                "friends": FieldValue.arrayUnion([targetUserDict])
                            ]) { error in
                                if let error = error {
                                    print("Error updating current user's friends: \(error.localizedDescription)")
                                    return
                                }
                                print("Successfully added \(targetUserUUID) to \(currentUserStruct.username)'s friends.")
                                
                                // Removing the target from pending friends
                                db.collection("users").document(currentUser!.uid).updateData([
                                    "pendingFriends": FieldValue.arrayRemove([targetUserDict])
                                ]) { error in
                                    if let error = error {
                                        print("Error removing user from pendingFriends: \(error.localizedDescription)")
                                        return
                                    }
                                    print("Successfully removed user from pendingFriends.")
                                }
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
    @IBAction func denyPressed(_ sender: Any) {
        let uniqueUsername = pendingProfileName.text!
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
