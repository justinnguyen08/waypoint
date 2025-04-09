//  Project: Waypoint
//  Course: CS371L
//
//  CustomTableViewCell.swift
//  Waypoint
//
//  Created by Tarun Somisetty on 3/6/25.
//

import Foundation
import UIKit
import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage


class RemoveTableViewCell: UITableViewCell {
    
    // Just created some connections to the table view in profile cell
    
    @IBOutlet weak var customProfileName: UILabel!
    
    @IBOutlet weak var profilePic: UIImageView!
    
    // Removing the friend from my friends array
    @IBAction func removeButtonPressed(_ sender: Any) {
        let uniqueUsername = customProfileName.text!
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
