//  Project: Waypoint
//  Course: CS371L
//
//  SuggestedCustomViewTableCell.swift
//  Waypoint
//
//  Created by Tarun Somisetty on 3/9/25.
//

import Foundation
import UIKit
import Firebase
import FirebaseFirestore
import FirebaseAuth

class SuggestedCustomViewTableCell: UITableViewCell {
    
    // Just created some connections to the table view in profile cell
    
    @IBOutlet weak var profilePic: UIImageView!
    
    @IBOutlet weak var profileName: UILabel!
    
    @IBOutlet weak var pendingButton: UIButton!
    
    @IBOutlet weak var addButton: UIButton!
    
    // Checks the button state, where if the user is already a friend then make it be pending and vice versa
    func updateButtonState() {
        let db = Firestore.firestore()
        guard let currentUser = Auth.auth().currentUser else { return }
        
        // Fetch current user's data
        db.collection("users").whereField("username", isEqualTo: profileName!.text).getDocuments{ (snapshot, error) in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                return
            }
            guard let documents = snapshot?.documents, !documents.isEmpty,
                  let document = documents.first else {
                print("No user found with username: \(self.profileName!.text)")
                return
            }
            let data = document.data()
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
        }
    }
        
    // For the target user, you become a pending friend they need to accept/deny
    @IBAction func addButtonPressed(_ sender: Any) {
        let uniqueUsername = profileName.text!
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
                    // Adds the user to the pending friends array
                    if let documents = snapshot?.documents, !documents.isEmpty {
                        if let document = documents.first {
                            let targetUserUUID = document.documentID
                            db.collection("users").document(targetUserUUID).updateData([
                                "pendingFriends": FieldValue.arrayUnion([currentUserDict])
                            ]) { error in
                                if let error = error {
                                    print("Error updating pendingFriends: \(error.localizedDescription)")
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
        guard let uniqueUsername = profileName.text else { return }
        // Get current user's username
        db.collection("users").document(currentUser.uid).getDocument { (currentUserSnapshot, error) in
            if let error = error {
                print("Error fetching current user: \(error.localizedDescription)")
                return
            }
            guard let currentUserData = currentUserSnapshot?.data(),
                  let username = currentUserData["username"] as? String else {
                print("Could not get current user data")
                return
            }
            let currentUserDict: [String: Any] = [
                "uid": currentUser.uid,
                "username": username
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
